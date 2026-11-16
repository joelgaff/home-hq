# GHSA-2gff-2mmg-m73p and GHSA-qfgr-crr9-7r49: kamal-proxy sets X-Forwarded-For
# but passes a client-supplied RFC 7239 Forwarded header through untouched.
# Rack 3 prefers Forwarded by default, so Rack's req.ip, host and scheme could
# come from values the client chose. Rails 8.1.4.1 only guards
# request.remote_ip. Our proxy never sets Forwarded, so ignoring it loses
# nothing legitimate.
Rack::Request.forwarded_priority = [ :x_forwarded ]
