#!/usr/bin/env python3
# HTTP receiver: logs method, path, headers, body; writes body to received/
import http.server, socketserver, os, datetime, hashlib
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "received")
os.makedirs(OUT, exist_ok=True)
class H(http.server.BaseHTTPRequestHandler):
    def _log(self):
        n = len(self.rfile.read(int(self.headers.get('Content-Length') or 0)))
        body = self.rfile.read(n) if False else None
        return n
    def do_POST(self):
        ln = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(ln)
        ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        fn = os.path.join(OUT, f"exfil_{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d_%H%M%S_%f')}.bin")
        open(fn,'wb').write(body)
        with open(os.path.join(OUT,"index.log"),'a') as f:
            f.write(f"{ts} POST {self.path} len={len(body)} sha256={hashlib.sha256(body).hexdigest()} file={fn}\n")
        self.send_response(200); self.end_headers(); self.wfile.write(b"OK\n")
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("0.0.0.0", 8899), H) as s:
    s.serve_forever()
