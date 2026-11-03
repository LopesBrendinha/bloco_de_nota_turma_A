import {createServer} from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import {resolve, sep, extname} from 'node:path';
const root = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 7358);
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.wasm':'application/wasm',
  '.json':'application/json','.png':'image/png','.woff2':'font/woff2','.ttf':'font/ttf'};
createServer(async (req,res) => {
  try {
    let path = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname));
    if (path !== root && !path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
    if ((await stat(path)).isDirectory()) path = resolve(path,'index.html');
    const data = await readFile(path);
    res.writeHead(200, {'Content-Type':types[extname(path)] ?? 'application/octet-stream','Cache-Control':'no-store'}).end(data);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log(`Aplicativo em http://localhost:${port}`));
