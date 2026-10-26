# Anonymous visitor profiles

The Visitors report lists recent site-scoped visits for the selected date range and saved segment. Search by the currently selected IP/fingerprint view or entry/exit path, then open a profile to inspect matching visits and the page/event timeline. The UI displays IP addresses instead of visitor IDs. IPs follow a 30-day retention policy; older visits and pre-migration visits can have no IP. TLS and browser fingerprint views use temporary group labels and never return raw fingerprint keys.

The APIs are:

```text
GET /api/v1/sites/{siteId}/analytics/visitor-log?from=YYYY-MM-DD&to=YYYY-MM-DD&limit=100&segmentId={optional}
GET /api/v1/sites/{siteId}/analytics/visitors/{visitorId}?from=YYYY-MM-DD&to=YYYY-MM-DD&segmentId={optional}
GET /api/v1/sites/{siteId}/analytics/visitors/{visitorId}/history?from=YYYY-MM-DD&to=YYYY-MM-DD&sessionsCursor={optional}&actionsCursor={optional}&segmentId={optional}
```

Visitor IDs are scoped to the authorized site. A profile returns period totals, up to the latest 50 matching sessions, and up to the latest 100 actions. When older history exists, `hasMoreSessions` / `hasMoreActions` are true and the corresponding `nextSessionsCursor` / `nextActionsCursor` can be passed to the history endpoint. The UI loads visits and actions independently; callers may supply either cursor or both, and only the requested collection is returned. Each history page contains at most 50 sessions and 100 actions, with a new cursor when more remain. Cursors are URL-safe continuation markers tied to the visitor and cursor type; clients should treat them as opaque and still send the normal authenticated, site-scoped request. Invalid or mismatched cursors return HTTP 400.

Sessions are ordered newest-first by start time and session ID; actions are ordered newest-first by event time and ingestion ID. Keyset pagination uses the last row's ordering keys, so records sharing a timestamp do not repeat or disappear between pages. Keep the original date range and saved segment fixed while traversing pages. The date range selects sessions by their start date in the site's timezone; actions include the complete accepted journey inside each matching session, even when it crosses the selected period boundary. Lifetime first/last-seen timestamps and lifetime session count are not filtered by the selected period or saved segment; period totals, session history, and actions are.

For privacy, profile actions expose only the event type, minimized page path/title, timestamp, and opaque session ID. They do not expose arbitrary event properties or cross-site visitor identifiers. The profile shows the IP recorded on each session while it remains within the 30-day retention policy. Location fields are the trusted-proxy-derived facts stored on session records.
