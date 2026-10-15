const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const APK_DIR = path.resolve(__dirname, '../build/app/outputs/flutter-apk');
const RELEASE_APK = path.join(APK_DIR, 'app-release.apk');
const DEBUG_APK = path.join(APK_DIR, 'app-debug.apk');

const server = http.createServer((req, res) => {
  if (req.url === '/CodeXa.apk' || req.url === '/app-release.apk' || req.url === '/download' || req.url === '/release') {
    if (!fs.existsSync(RELEASE_APK)) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      return res.end('Release APK not found');
    }
    const stat = fs.statSync(RELEASE_APK);
    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': stat.size,
      'Content-Disposition': 'attachment; filename="CodeXa.apk"',
    });
    return fs.createReadStream(RELEASE_APK).pipe(res);
  }

  if (req.url === '/app-debug.apk' || req.url === '/debug') {
    if (!fs.existsSync(DEBUG_APK)) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      return res.end('Debug APK not found');
    }
    const stat = fs.statSync(DEBUG_APK);
    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': stat.size,
      'Content-Disposition': 'attachment; filename="codexa-debug.apk"',
    });
    return fs.createReadStream(DEBUG_APK).pipe(res);
  }

  // HTML download landing page
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Install CodeXa Mobile V5</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    body { background: #0a0a0f; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
    .card { background: #161622; border: 1px solid #2a2a3c; border-radius: 20px; max-width: 420px; width: 100%; padding: 32px 24px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .logo { width: 72px; height: 72px; background: #e50914; border-radius: 18px; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; font-size: 32px; font-weight: bold; }
    h1 { font-size: 22px; font-weight: 700; margin-bottom: 8px; letter-spacing: 0.5px; }
    p { color: #9e9eb4; font-size: 14px; margin-bottom: 24px; line-height: 1.5; }
    .btn { display: block; width: 100%; padding: 16px; background: #e50914; color: #fff; text-decoration: none; font-size: 16px; font-weight: 600; border-radius: 12px; margin-bottom: 12px; transition: opacity 0.2s; }
    .btn:active { opacity: 0.8; }
    .btn-secondary { background: #262638; color: #c4c4d4; }
    .meta { font-size: 12px; color: #6b6b80; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">CX</div>
    <h1>CodeXa Mobile V7</h1>
    <p>Liquid Glass Design &bull; Account OTP Root-Cause Fix &bull; 5-Tab Swipe Navigation &bull; Crew Group Details &bull; Branded Agency Chat Wallpaper</p>
    <a href="/CodeXa.apk" class="btn">⬇️ Install Release APK (CodeXa.apk)</a>
    <a href="/app-debug.apk" class="btn btn-secondary">⬇️ Install Debug APK</a>
    <div class="meta">Build 10-Oct-2026 &bull; Verified Production Release (1.0.0+7)</div>
  </div>
</body>
</html>`);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[APK_SERVER] Serving at http://0.0.0.0:${PORT}`);
  console.log(`[APK_SERVER] Local LAN URL: http://192.168.1.8:${PORT}`);
});
