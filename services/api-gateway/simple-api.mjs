import http from 'node:http';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ProxyAgent, setGlobalDispatcher } from 'undici';

const sessions = new Map();
const images = new Map();
const jobs = new Map();
const evidences = new Map();
const factsBySession = new Map();
const imagePayloads = new Map();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..', '..');

const tryLoadEnvFile = (filePath) => {
  if (!fs.existsSync(filePath)) return;
  const text = fs.readFileSync(filePath, 'utf8');
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    if (!key || process.env[key] !== undefined) continue;
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith('\'') && value.endsWith('\''))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
};

tryLoadEnvFile(path.join(repoRoot, '.env.local'));
tryLoadEnvFile(path.join(repoRoot, '.env'));

const pickProxyURL = () => {
  const candidates = [
    process.env.HTTPS_PROXY,
    process.env.HTTP_PROXY,
    process.env.ALL_PROXY,
    process.env.https_proxy,
    process.env.http_proxy,
    process.env.all_proxy,
  ];
  for (const value of candidates) {
    const v = String(value || '').trim();
    if (v) return v;
  }
  return '';
};

const proxyURL = pickProxyURL();
if (proxyURL) {
  try {
    setGlobalDispatcher(new ProxyAgent(proxyURL));
    console.log(`[simple-api] outbound proxy enabled: ${proxyURL}`);
  } catch (err) {
    console.error('[simple-api] failed to initialize proxy dispatcher:', String(err));
  }
}

const openAIKey = process.env.OPENAI_API_KEY || '';
const openAIModel = process.env.OPENAI_MODEL || 'gpt-4o-mini';
const openAIVisionModel = process.env.OPENAI_VISION_MODEL || 'gpt-4o-mini';
const openAIBaseURL = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';

const send = (res, code, body) => {
  res.writeHead(code, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
};

const parseBody = (req) => new Promise((resolve, reject) => {
  let data = '';
  req.on('data', (c) => { data += c; });
  req.on('end', () => {
    if (!data) return resolve({});
    try { resolve(JSON.parse(data)); } catch (e) { reject(new Error('invalid_json_body')); }
  });
  req.on('error', reject);
});

const normalizeImagePayload = (item) => {
  if (!item || typeof item !== 'object') return null;
  const imageId = String(item.image_id || '').trim();
  const mimeType = String(item.mime_type || 'image/jpeg').trim();
  const imageBase64 = String(item.image_base64 || '').trim();
  if (!imageId || !imageBase64) return null;
  return {
    image_id: imageId,
    mime_type: mimeType || 'image/jpeg',
    image_base64: imageBase64,
  };
};

const normalizeMessage = (item, idx) => {
  if (!item || typeof item !== 'object') return null;
  const text = String(item.text || '').trim();
  if (!text) return null;
  const sideRaw = String(item.side || 'unknown').trim().toLowerCase();
  const side = sideRaw === 'left' || sideRaw === 'right' ? sideRaw : 'unknown';
  const rawOrder = Number(item.order);
  const order = Number.isFinite(rawOrder) ? rawOrder : idx;
  return { text, side, order };
};

const normalizeOcrJson = (raw) => {
  const messages = Array.isArray(raw?.messages)
    ? raw.messages.map((x, idx) => normalizeMessage(x, idx)).filter(Boolean)
    : [];
  const lines = Array.isArray(raw?.transcript_lines) ? raw.transcript_lines.map((x) => String(x).trim()).filter(Boolean) : [];
  const entities = Array.isArray(raw?.entities) ? raw.entities.map((x) => String(x).trim()).filter(Boolean) : [];
  const emotionCues = Array.isArray(raw?.emotion_cues) ? raw.emotion_cues.map((x) => String(x).trim()).filter(Boolean) : [];
  const riskPoints = Array.isArray(raw?.risk_points) ? raw.risk_points.map((x) => String(x).trim()).filter(Boolean) : [];
  if (messages.length === 0 && lines.length > 0) {
    lines.forEach((line, idx) => messages.push({ text: line, side: 'unknown', order: idx }));
  }
  return { messages, lines, entities, emotionCues, riskPoints };
};

const callVisionExtractOnce = async ({ imageBase64, mimeType }) => {
  if (!openAIKey) return null;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try {
    const resp = await fetch(`${openAIBaseURL}/chat/completions`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${openAIKey}`,
      },
      body: JSON.stringify({
        model: openAIVisionModel,
        temperature: 0.1,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: [
              '你是截图OCR与聊天语义抽取器。',
              '请只返回JSON，不要markdown。',
              'JSON schema:',
              '{"messages":[{"text":string,"side":"left"|"right"|"unknown","order":number}],"transcript_lines":string[],"entities":string[],"emotion_cues":string[],"risk_points":string[]}',
            ].join('\n'),
          },
          {
            role: 'user',
            content: [
              { type: 'text', text: '请优先按聊天气泡逐条提取消息，给出每条是左侧还是右侧（side=left/right/unknown）及顺序order；并补充transcript_lines、关键实体、情绪线索、风险点。' },
              { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
            ],
          },
        ],
      }),
      signal: controller.signal,
    });
    if (!resp.ok) {
      const t = await resp.text();
      throw new Error(`openai_error_${resp.status}: ${t.slice(0, 300)}`);
    }
    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content || '';
    const parsed = parseModelJSON(content);
    if (!parsed) throw new Error('openai_invalid_json');
    return normalizeOcrJson(parsed);
  } finally {
    clearTimeout(timeout);
  }
};

const callVisionExtractWithRetry = async (payload) => {
  try {
    return await callVisionExtractOnce(payload);
  } catch (err) {
    const text = String(err || '');
    if (text.includes('openai_invalid_json')) {
      return await callVisionExtractOnce(payload);
    }
    throw err;
  }
};

const mapSideToSpeakerRole = (side) => {
  if (side === 'left') return 'other';
  if (side === 'right') return 'self';
  return 'unknown';
};

const buildFactsFromVision = (sessionId, imageId, ocr) => {
  const facts = [];
  const messages = ocr.messages.length > 0
    ? ocr.messages.slice(0, 30)
    : ocr.lines.slice(0, 24).map((line, idx) => ({ text: line, side: 'unknown', order: idx }));
  messages.forEach((message, idx) => {
    facts.push({
      id: randomUUID(),
      sessionId,
      imageId,
      type: 'paragraph',
      text: message.text,
      bbox: { x: 0.05, y: Math.min(0.9, 0.05 + idx * 0.03), w: 0.9, h: 0.028 },
      confidence: 0.9,
      speakerRole: mapSideToSpeakerRole(message.side),
      order: Number.isFinite(message.order) ? message.order : idx,
    });
  });
  ocr.entities.slice(0, 8).forEach((entity) => {
    facts.push({
      id: randomUUID(),
      sessionId,
      imageId,
      type: 'entity',
      text: entity,
      bbox: { x: 0.06, y: 0.88, w: 0.5, h: 0.04 },
      confidence: 0.78,
      speakerRole: 'unknown',
      order: 9000,
    });
  });
  ocr.emotionCues.slice(0, 6).forEach((cue) => {
    facts.push({
      id: randomUUID(),
      sessionId,
      imageId,
      type: 'entity',
      text: `情绪线索: ${cue}`,
      bbox: { x: 0.06, y: 0.92, w: 0.5, h: 0.04 },
      confidence: 0.74,
      speakerRole: 'unknown',
      order: 9100,
    });
  });
  if (facts.length === 0) {
    facts.push({
      id: randomUUID(),
      sessionId,
      imageId,
      type: 'paragraph',
      text: '未能提取到可读聊天文本',
      bbox: { x: 0.1, y: 0.1, w: 0.8, h: 0.1 },
      confidence: 0.3,
      speakerRole: 'unknown',
      order: 9999,
    });
  }
  return facts;
};

const buildFacts = (sessionId, imageIds) => {
  return imageIds.flatMap((imageId, idx) => ([
    {
      id: randomUUID(),
      sessionId,
      imageId,
      type: 'paragraph',
      text: `Screenshot ${idx + 1} left bubble`,
      bbox: { x: 0.1, y: 0.15, w: 0.65, h: 0.1 },
      confidence: 0.64,
      speakerRole: 'other',
      order: idx * 10,
    },
    {
      id: randomUUID(),
      sessionId,
      imageId,
      type: 'paragraph',
      text: `Screenshot ${idx + 1} right bubble`,
      bbox: { x: 0.25, y: 0.3, w: 0.65, h: 0.1 },
      confidence: 0.64,
      speakerRole: 'self',
      order: idx * 10 + 1,
    },
  ]));
};


const dedupeLines = (lines) => {
  const result = [];
  let lastNorm = '';
  for (const line of lines) {
    const text = String(line || '').trim();
    if (!text) continue;
    const normalized = text.replace(/\s+/g, ' ').toLowerCase();
    if (normalized === lastNorm) continue;
    result.push(text);
    lastNorm = normalized;
  }
  return result;
};

const buildSpeakerSplit = (facts) => {
  const paragraphs = facts
    .filter((f) => f.type === 'paragraph' && !String(f.text || '').includes('未能提取到可读聊天文本'))
    .sort((a, b) => (Number(a.order || 0) - Number(b.order || 0)));
  const other = [];
  const mine = [];
  let unknownCount = 0;

  paragraphs.forEach((item) => {
    const role = item.speakerRole || 'unknown';
    const text = String(item.text || '').trim();
    if (!text) return;
    if (role === 'other') {
      other.push(text);
      return;
    }
    if (role === 'self') {
      mine.push(text);
      return;
    }
    unknownCount += 1;
    if (other.length <= mine.length) other.push(text);
    else mine.push(text);
  });

  const otherLines = dedupeLines(other);
  const selfLines = dedupeLines(mine);
  const baseCount = Math.max(1, otherLines.length + selfLines.length);
  const confidence = Math.max(0, Math.min(1, 1 - (unknownCount / (baseCount + unknownCount))));
  const lowConfidenceReason = confidence <= 0.5 ? '分人可能不准，已按默认规则推断' : '';

  return {
    other_lines: otherLines,
    self_lines: selfLines,
    mapping_rule: 'left_other_right_self',
    confidence,
    low_confidence_reason: lowConfidenceReason,
  };
};

const buildFallbackIntent = (speakerSplit) => {
  const hasOther = speakerSplit.other_lines.length > 0;
  const hasSelf = speakerSplit.self_lines.length > 0;
  return {
    other_intent: hasOther
      ? `对方重点在表达：${speakerSplit.other_lines.slice(0, 2).join('；')}`
      : '证据不足，暂无法准确判断对方意图。',
    self_intent: hasSelf
      ? `你当前重点在表达：${speakerSplit.self_lines.slice(0, 2).join('；')}`
      : '证据不足，暂无法准确判断你的意图。',
  };
};

const scoreFacts = (facts, query) => {
  const q = String(query || '').toLowerCase().trim();
  if (!q) return facts.slice(0, 5);
  const matched = facts.filter((f) => f.text.toLowerCase().includes(q));
  if (matched.length > 0) return matched;
  return facts.slice(0, 5);
};

const parseModelJSON = (raw) => {
  try {
    const first = raw.indexOf('{');
    const last = raw.lastIndexOf('}');
    if (first < 0 || last < 0 || last <= first) return null;
    return JSON.parse(raw.slice(first, last + 1));
  } catch {
    return null;
  }
};

const classifyLLMError = (err) => {
  const t = String(err || '');
  if (t.includes('openai_error_401')) return '鉴权失败（API Key 无效）';
  if (t.includes('openai_error_403')) return '权限不足（模型/账号不可用）';
  if (t.includes('openai_error_429')) return '请求过多（限流），已降级本地';
  if (t.includes('openai_error_5')) return 'OpenAI 服务异常，已降级本地';
  if (t.includes('AbortError') || t.includes('timeout')) return 'OpenAI 超时，已降级本地';
  if (t.includes('openai_invalid_json')) return '模型输出非JSON，已降级本地';
  return '云端不可用，已降级本地';
};

const buildFallbackStructured = (question, relevant, speakerSplit) => {
  const meaningful = relevant.filter((f) => !String(f.text || '').includes('未能提取到可读聊天文本'));
  const joined = meaningful.map((f) => f.text).join(' | ');
  const hasEvidence = meaningful.length > 0;
  const emotion = hasEvidence ? '对方可能处于需要被理解或被明确回应的状态。' : '证据不足，无法准确判断情绪。';
  const coreNeed = hasEvidence ? '希望得到清晰回复、确认立场或推进下一步。' : '建议补充更完整对话截图。';
  const riskPoint = hasEvidence ? '直接反驳或情绪化表述，可能导致关系恶化。' : '在证据不足时给出确定判断，容易误导。';
  const intent = buildFallbackIntent(speakerSplit);

  const replyOptions = [
    {
      style: '温和',
      text: '我理解你的想法，也谢谢你直接说明。我们先把重点对齐一下，我这边的考虑是……你看这样处理可行吗？',
    },
    {
      style: '坚定',
      text: '我尊重你的意见，但这个边界我需要明确：我可以配合A和B，不会接受C。我们按这个范围推进。',
    },
    {
      style: '幽默',
      text: '我们先别开“火力全开”模式，先开“问题解决模式”😄 我提议先定两个共识，再看分歧怎么收敛。',
    },
  ];

  return {
    analysis: {
      emotion,
      core_need: coreNeed,
      risk_point: riskPoint,
    },
    reply_options: replyOptions,
    best_reply: replyOptions[0].text,
    why: hasEvidence
      ? '温和版更利于先降温并建立合作语气，再推进实质问题。'
      : '在信息不足时优先使用稳妥、低冲突表达。',
    followups: [
      '要我按你们关系（同事/客户/伴侣）重写一版吗？',
      '要我改成更短的一句话版吗？',
    ],
    confidence: hasEvidence ? 0.64 : 0.35,
    is_speculative: !hasEvidence,
    analysis_steps: [
      '已完成分人识别（左=对方，右=我）',
      hasEvidence ? `已抽取证据：${joined.slice(0, 80)}` : '证据不足，使用保守策略',
      `问题目标：${String(question || '').slice(0, 40)}`,
      '已生成三种语气回复与推荐发送版本',
    ],
    speaker_split: speakerSplit,
    intent,
  };
};

const normalizeStructured = (raw) => {
  const analysis = raw?.analysis && typeof raw.analysis === 'object'
    ? {
        emotion: String(raw.analysis.emotion || ''),
        core_need: String(raw.analysis.core_need || ''),
        risk_point: String(raw.analysis.risk_point || ''),
      }
    : { emotion: '', core_need: '', risk_point: '' };

  const options = Array.isArray(raw?.reply_options) ? raw.reply_options : [];
  const replyOptions = options
    .filter((x) => x && typeof x === 'object')
    .slice(0, 3)
    .map((x, idx) => ({
      style: String(x.style || ['温和', '坚定', '幽默'][idx] || `版本${idx + 1}`),
      text: String(x.text || '').trim(),
    }))
    .filter((x) => x.text.length > 0);

  const bestReply = String(raw?.best_reply || replyOptions[0]?.text || '').trim();
  const why = String(raw?.why || '').trim();
  const followups = Array.isArray(raw?.followups) ? raw.followups.map((x) => String(x)) : [];
  const confidence = Number.isFinite(raw?.confidence) ? Number(raw.confidence) : 0.6;
  const isSpeculative = Boolean(raw?.is_speculative);
  const analysisSteps = Array.isArray(raw?.analysis_steps) ? raw.analysis_steps.map((x) => String(x)) : [];
  const speakerSplitRaw = raw?.speaker_split && typeof raw.speaker_split === 'object' ? raw.speaker_split : {};
  const speakerSplit = {
    other_lines: Array.isArray(speakerSplitRaw.other_lines)
      ? speakerSplitRaw.other_lines.map((x) => String(x).trim()).filter(Boolean)
      : [],
    self_lines: Array.isArray(speakerSplitRaw.self_lines)
      ? speakerSplitRaw.self_lines.map((x) => String(x).trim()).filter(Boolean)
      : [],
    mapping_rule: String(speakerSplitRaw.mapping_rule || 'left_other_right_self'),
    confidence: Number.isFinite(speakerSplitRaw.confidence) ? Math.max(0, Math.min(1, Number(speakerSplitRaw.confidence))) : 0,
    low_confidence_reason: String(speakerSplitRaw.low_confidence_reason || '').trim(),
  };
  const intentRaw = raw?.intent && typeof raw.intent === 'object' ? raw.intent : {};
  const intent = {
    other_intent: String(intentRaw.other_intent || '').trim(),
    self_intent: String(intentRaw.self_intent || '').trim(),
  };

  return {
    analysis,
    reply_options: replyOptions,
    best_reply: bestReply,
    why,
    followups,
    confidence: Math.max(0, Math.min(1, confidence)),
    is_speculative: isSpeculative,
    analysis_steps: analysisSteps,
    speaker_split: speakerSplit,
    intent,
  };
};

const buildAnswerText = (structured) => {
  const sections = [
    structured.speaker_split?.other_lines?.length
      ? `【对方说了什么】\n${structured.speaker_split.other_lines.map((x) => `- ${x}`).join('\n')}`
      : '',
    structured.speaker_split?.self_lines?.length
      ? `【我说了什么】\n${structured.speaker_split.self_lines.map((x) => `- ${x}`).join('\n')}`
      : '',
    structured.intent?.other_intent ? `【对方意思】${structured.intent.other_intent}` : '',
    structured.intent?.self_intent ? `【我方意思】${structured.intent.self_intent}` : '',
    structured.analysis.emotion ? `【情绪判断】${structured.analysis.emotion}` : '',
    structured.analysis.core_need ? `【核心诉求】${structured.analysis.core_need}` : '',
    structured.analysis.risk_point ? `【风险点】${structured.analysis.risk_point}` : '',
    structured.reply_options.length
      ? ['【高情商回复候选】', ...structured.reply_options.map((x, i) => `${i + 1}. ${x.style}版：${x.text}`)].join('\n')
      : '',
    structured.best_reply ? `【推荐发送】${structured.best_reply}` : '',
    structured.why ? `【推荐理由】${structured.why}` : '',
  ].filter(Boolean);

  return sections.join('\n\n');
};

const callOpenAIOnce = async ({ question, relevantFacts, allFacts, mode, speakerSplit }) => {
  const system = [
    '你是高情商沟通教练，擅长聊天截图分析与可直接发送的回复生成。',
    '你必须基于给定证据回答，禁止编造截图中不存在的信息。',
    '必须先基于speaker_split分别总结对方意思与我方意思。',
    '返回严格 JSON，不要 markdown。',
    'JSON schema:',
    '{"speaker_split":{"other_lines":string[],"self_lines":string[],"mapping_rule":"left_other_right_self","confidence":number,"low_confidence_reason":string},',
    '"intent":{"other_intent":string,"self_intent":string},',
    '"analysis":{"emotion":string,"core_need":string,"risk_point":string},',
    '"reply_options":[{"style":"温和"|"坚定"|"幽默","text":string}],',
    '"best_reply":string,"why":string,',
    '"followups":string[],"confidence":number,"is_speculative":boolean}',
  ].join('\n');

  const evidenceText = relevantFacts.length
    ? relevantFacts.map((f, i) => `${i + 1}) [image:${f.imageId}] ${f.text}`).join('\n')
    : '(no evidence)';

  const user = [
    `任务模式: ${mode || 'hq_reply'}`,
    `用户问题: ${question}`,
    `分人结果(左=对方,右=我): ${JSON.stringify(speakerSplit)}`,
    `相关证据:\n${evidenceText}`,
    `总证据条数: ${allFacts.length}`,
    '要求: 输出可直接复制发送的短句；若证据不足请明确写证据不足。',
  ].join('\n\n');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const resp = await fetch(`${openAIBaseURL}/chat/completions`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${openAIKey}`,
      },
      body: JSON.stringify({
        model: openAIModel,
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
      }),
      signal: controller.signal,
    });

    if (!resp.ok) {
      const t = await resp.text();
      throw new Error(`openai_error_${resp.status}: ${t.slice(0, 300)}`);
    }
    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content || '';
    const parsed = parseModelJSON(content);
    if (!parsed) throw new Error('openai_invalid_json');
    return normalizeStructured(parsed);
  } finally {
    clearTimeout(timeout);
  }
};

const callOpenAIWithRetry = async (payload) => {
  try {
    return await callOpenAIOnce(payload);
  } catch (err) {
    const text = String(err || '');
    if (text.includes('openai_invalid_json')) {
      return await callOpenAIOnce(payload);
    }
    throw err;
  }
};

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', 'http://127.0.0.1');
    const path = url.pathname;

    if (req.method === 'GET' && path === '/healthz') return send(res, 200, { ok: true });

    if (req.method === 'POST' && path === '/v1/sessions') {
      const body = await parseBody(req);
      const id = randomUUID();
      sessions.set(id, { id, deviceId: body.device_id || 'unknown' });
      return send(res, 200, { session_id: id });
    }

    const presign = path.match(/^\/v1\/sessions\/([^/]+)\/images:presign$/);
    if (req.method === 'POST' && presign) {
      const sessionId = presign[1];
      if (!sessions.has(sessionId)) return send(res, 404, { error: 'session not found' });
      const imageId = randomUUID();
      images.set(imageId, { id: imageId, sessionId });
      return send(res, 200, { image_id: imageId, upload_url: `https://mock-s3.local/upload/${sessionId}/${imageId}` });
    }

    const commit = path.match(/^\/v1\/sessions\/([^/]+)\/images:commit$/);
    if (req.method === 'POST' && commit) {
      const sessionId = commit[1];
      const body = await parseBody(req);
      const accepted = [];
      const rejected = [];
      const payloadMap = new Map();
      for (const raw of body.payloads || []) {
        const payload = normalizeImagePayload(raw);
        if (payload) payloadMap.set(payload.image_id, payload);
      }
      for (const imageId of body.image_ids || []) {
        const img = images.get(imageId);
        if (!img || img.sessionId !== sessionId) {
          rejected.push(imageId);
          continue;
        }
        const payload = payloadMap.get(imageId);
        if (payload) {
          imagePayloads.set(imageId, payload);
        }
        accepted.push(imageId);
      }
      return send(res, 200, { accepted, rejected });
    }

    const analysis = path.match(/^\/v1\/sessions\/([^/]+)\/analysis$/);
    if (req.method === 'POST' && analysis) {
      const started = Date.now();
      const sessionId = analysis[1];
      const body = await parseBody(req);
      const imageIds = body.image_ids || [];
      const jobId = randomUUID();
      jobs.set(jobId, { id: jobId, sessionId, status: 'running', progress: 10 });

      const aggregated = [];
      for (const imageId of imageIds) {
        const payload = imagePayloads.get(imageId);
        if (payload && openAIKey) {
          try {
            const ocr = await callVisionExtractWithRetry({
              imageBase64: payload.image_base64,
              mimeType: payload.mime_type,
            });
            if (ocr && (ocr.messages.length > 0 || ocr.lines.length > 0 || ocr.entities.length > 0 || ocr.emotionCues.length > 0)) {
              aggregated.push(...buildFactsFromVision(sessionId, imageId, ocr));
              continue;
            }
            throw new Error('ocr_empty_result');
          } catch (err) {
            console.log(JSON.stringify({
              event: 'analysis_ocr_failed',
              session_id: sessionId,
              image_id: imageId,
              error: classifyLLMError(err),
            }));
          }
        }
        aggregated.push(...buildFacts(sessionId, [imageId]));
      }
      factsBySession.set(sessionId, aggregated);
      jobs.set(jobId, { id: jobId, sessionId, status: 'done', progress: 100 });
      console.log(JSON.stringify({
        event: 'analysis_completed',
        session_id: sessionId,
        image_ids: imageIds.slice(0, 10),
        model: openAIKey ? `openai:${openAIModel}` : 'fallback:local',
        latency_ms: Date.now() - started,
        facts_count: aggregated.length,
      }));
      return send(res, 200, { job_id: jobId });
    }

    const job = path.match(/^\/v1\/jobs\/([^/]+)$/);
    if (req.method === 'GET' && job) {
      const item = jobs.get(job[1]);
      if (!item) return send(res, 404, { error: 'job not found' });
      return send(res, 200, { status: item.status, progress: item.progress });
    }

    const summary = path.match(/^\/v1\/sessions\/([^/]+)\/summary$/);
    if (req.method === 'GET' && summary) {
      const facts = factsBySession.get(summary[1]) || [];
      return send(res, 200, {
        highlights: facts.slice(0, 3).map((f) => f.text),
        entities: facts.filter((f) => f.type === 'entity').map((f) => f.text),
        timelines: [],
      });
    }

    const chat = path.match(/^\/v1\/sessions\/([^/]+)\/chat$/);
    if (req.method === 'POST' && chat) {
      const started = Date.now();
      const sessionId = chat[1];
      const body = await parseBody(req);
      const mode = String(body.mode || 'hq_reply');
      const question = String(body.message || '');

      const allFacts = factsBySession.get(sessionId) || [];
      const contextIds = Array.isArray(body?.context?.image_ids) ? body.context.image_ids.map((x) => String(x)) : [];
      const facts = contextIds.length > 0
        ? allFacts.filter((f) => contextIds.includes(f.imageId))
        : allFacts;
      const relevant = scoreFacts(facts, question);
      const speakerSplit = buildSpeakerSplit(facts);
      const citations = relevant.slice(0, 3).map((f) => {
        const evidenceId = randomUUID();
        evidences.set(evidenceId, {
          image_id: f.imageId,
          bbox: f.bbox,
          excerpt: f.text,
          fact_id: f.id,
          confidence: f.confidence,
        });
        return {
          id: evidenceId,
          evidenceId,
          factId: f.id,
          reasoningRole: 'support',
          score: f.confidence,
        };
      });

      let structured = buildFallbackStructured(question, relevant, speakerSplit);
      let modelUsed = 'fallback:local';
      let llmError = null;

      if (openAIKey) {
        try {
          structured = await callOpenAIWithRetry({
            question,
            relevantFacts: relevant,
            allFacts: facts,
            mode,
            speakerSplit,
          });
          if (!structured.speaker_split.other_lines.length && !structured.speaker_split.self_lines.length) {
            structured.speaker_split = speakerSplit;
          }
          if (!structured.intent.other_intent && !structured.intent.self_intent) {
            structured.intent = buildFallbackIntent(structured.speaker_split);
          }
          modelUsed = `openai:${openAIModel}`;
        } catch (err) {
          llmError = classifyLLMError(err);
        }
      }

      if (!structured.analysis_steps.includes('已完成分人识别（左=对方，右=我）')) {
        structured.analysis_steps.unshift('已完成分人识别（左=对方，右=我）');
      }
      if (structured.speaker_split.confidence <= 0.5 && structured.speaker_split.low_confidence_reason) {
        structured.analysis_steps.push(structured.speaker_split.low_confidence_reason);
      }
      const imageSet = new Set(facts.map((x) => x.imageId));
      if (imageSet.size > 1) {
        structured.analysis_steps.push('检测到多段上下文，建议按单个会话分批导入');
      }

      const answer = buildAnswerText(structured);
      const latencyMs = Date.now() - started;
      console.log(JSON.stringify({
        event: 'chat_completed',
        session_id: sessionId,
        image_ids: (body?.context?.image_ids || []).slice(0, 10),
        model: modelUsed,
        latency_ms: latencyMs,
      }));

      return send(res, 200, {
        answer,
        analysis: structured.analysis,
        reply_options: structured.reply_options,
        best_reply: structured.best_reply,
        why: structured.why,
        citations,
        followups: structured.followups,
        confidence: structured.confidence,
        is_speculative: structured.is_speculative,
        analysis_steps: structured.analysis_steps,
        speaker_split: structured.speaker_split,
        intent: structured.intent,
        model: modelUsed,
        llm_error: llmError,
      });
    }

    const evidence = path.match(/^\/v1\/sessions\/([^/]+)\/evidences\/([^/]+)$/);
    if (req.method === 'GET' && evidence) {
      const item = evidences.get(evidence[2]);
      if (!item) return send(res, 404, { error: 'evidence not found' });
      return send(res, 200, item);
    }

    const delSession = path.match(/^\/v1\/sessions\/([^/]+)$/);
    if (req.method === 'DELETE' && delSession) {
      sessions.delete(delSession[1]);
      factsBySession.delete(delSession[1]);
      return send(res, 200, { ok: true, cleanup_queued: true });
    }

    return send(res, 404, { error: 'not found', path });
  } catch (err) {
    const message = String(err?.message || err);
    if (message.includes('invalid_json_body')) {
      return send(res, 400, { error: 'invalid_json_body' });
    }
    return send(res, 500, { error: String(err) });
  }
});

const rawPort = process.env.PORT;
const port = rawPort && Number(rawPort) > 0 ? Number(rawPort) : 8080;
const host = process.env.HOST && process.env.HOST.trim() ? process.env.HOST : '0.0.0.0';

server.listen(port, host, () => {
  console.log(`[simple-api] listening on http://${host}:${port}`);
  if (openAIKey) {
    console.log(`[simple-api] OpenAI enabled model=${openAIModel} vision_model=${openAIVisionModel}`);
  } else {
    console.log('[simple-api] OpenAI disabled (OPENAI_API_KEY missing), using local fallback');
  }
});
