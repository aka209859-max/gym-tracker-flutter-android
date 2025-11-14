#!/usr/bin/env python3
import http.server
import socketserver
from datetime import datetime

class NoCacheCORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        
        # NO CACHE headers - 強制的にキャッシュを無効化
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        
        # ETag無効化
        self.send_header('ETag', f'"{datetime.now().timestamp()}"')
        
        super().end_headers()

PORT = 5060
Handler = NoCacheCORSRequestHandler

with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"✅ NO-CACHE CORS Server running on port {PORT}")
    httpd.serve_forever()
