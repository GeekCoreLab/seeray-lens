# ADR 0002: Privacy-first anonymous identity and URL minimization

**Status:** Accepted

Use random, Tracking-ID-scoped visitor UUIDs in localStorage and random session UUIDs in sessionStorage. Do not use cookies, IP addresses, or fingerprinting as anonymous identity, or create cross-site identity. For the Live and Visitors inspection views, retain the numeric client IP only on raw events and session records under a 30-day policy; clear it independently of longer analytics retention and never use it for identity or aggregate metrics. Read forwarded IP headers only from configured trusted proxies. A separately enabled site may collect a consent-gated, site-scoped browser fingerprint risk signal only to flag possible same-browser activity; it must never affect UV, session identity, User ID linking, or cross-site correlation. Respect DNT by stopping all sends. Persist normalized URL origin/path only; discard fragments and arbitrary query parameters while separately extracting UTM fields.
