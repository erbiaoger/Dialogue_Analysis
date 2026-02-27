#!/usr/bin/env bash
set -euo pipefail

# One-click deploy for api-gateway + clash with OpenAI connectivity validation.
#
# Usage:
#   bash scripts/deploy_llm.sh
#   PREFERRED_NODE="🇺🇲 美国 01" bash scripts/deploy_llm.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREFERRED_NODE="${PREFERRED_NODE:-🇺🇲 美国 01}"
CLASH_CONFIG="${APP_DIR}/clash/config.yaml"

echo "[1/7] Enter repo: ${APP_DIR}"
cd "${APP_DIR}"

echo "[2/7] Check required files"
if [[ ! -f "${CLASH_CONFIG}" ]]; then
  echo "ERROR: missing ${CLASH_CONFIG}"
  exit 1
fi

echo "[3/7] Backup and sanitize clash rules (remove GEOIP to avoid MMDB download failure)"
cp "${CLASH_CONFIG}" "${CLASH_CONFIG}.bak.$(date +%s)"
sed -i '/^- GEOIP,/d' "${CLASH_CONFIG}"

echo "[4/7] Recreate services"
docker compose down || true
docker compose up -d --build

echo "[5/7] Wait for clash control API"
ready=0
for _ in $(seq 1 40); do
  if docker compose exec -T api-gateway sh -lc 'wget -qO- http://clash:9090/version >/dev/null'; then
    ready=1
    break
  fi
  sleep 2
done
if [[ "${ready}" -ne 1 ]]; then
  echo "ERROR: clash control API not ready at http://clash:9090"
  docker compose logs --tail=120 clash || true
  exit 1
fi

echo "[6/7] Set ChatGPT proxy group node: ${PREFERRED_NODE}"
docker compose exec -T api-gateway sh -lc "node -e '
fetch(\"http://clash:9090/proxies/%F0%9F%A4%96%20ChatGPT\",{
  method:\"PUT\",
  headers:{\"Content-Type\":\"application/json\"},
  body:JSON.stringify({name:process.argv[1]})
}).then(r=>{console.log(\"set status=\",r.status); if(!r.ok) process.exit(2);})
  .catch(e=>{console.error(e);process.exit(1)});
' \"${PREFERRED_NODE}\""

echo "[7/7] Verify OpenAI API via clash"
docker compose exec -T api-gateway sh -lc 'node -e "
const { ProxyAgent, setGlobalDispatcher } = require(\"undici\");
setGlobalDispatcher(new ProxyAgent(\"http://clash:7890\"));
fetch(\"https://api.openai.com/v1/models\", {
  headers: { Authorization: \"Bearer \" + process.env.OPENAI_API_KEY }
}).then(async r => {
  const text = await r.text();
  console.log(\"OpenAI status=\", r.status);
  console.log(text.slice(0, 300));
  if (!(r.status === 200 || r.status === 401)) process.exit(3);
}).catch(e => { console.error(e); process.exit(1); });
"'

echo
echo "Done. Current services:"
docker compose ps
