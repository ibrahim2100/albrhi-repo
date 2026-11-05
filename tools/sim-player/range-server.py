#!/usr/bin/env python3
"""A stand-in for googlevideo for the harness: GET /blob?...&range=A-B answers exactly those bytes of a
deterministic stream (byte i = (i*7) % 251), after a delay, and logs every request it gets.
   python3 tools/sim-player/range-server.py [port] [delay-seconds]"""
import sys, time, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
DELAY = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
lock = threading.Lock()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        q = parse_qs(urlparse(self.path).query)
        try:
            a, b = (int(x) for x in q["range"][0].split("-"))
        except Exception:
            self.send_error(400); return
        with lock:
            print("REQUEST %d-%d" % (a, b), flush=True)
        time.sleep(DELAY)
        body = bytes(((i * 7) % 251) for i in range(a, b + 1))
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try: self.wfile.write(body)
        except BrokenPipeError: pass
    def log_message(self, *args): pass

ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
