import http from 'node:http';
const server = http.createServer((req,res)=>{
  if(req.url === '/healthz'){res.writeHead(200, {'content-type':'application/json'});res.end('{"ok":true}');return;}
  res.writeHead(404);res.end('not found');
});
server.listen(8080,'127.0.0.1',()=>console.log('tmp health server listening 127.0.0.1:8080'));
