# Device performance analytics

SeeRay Lens automatically collects normalized, privacy-safe client hardware, network, and runtime performance metrics on tracked visits to help identify visitors experiencing slow or low-end devices.

## Collected signals

Every tracked event attaches available bounded attributes inside `raw_event.event_data.context` (respecting the tracker's Do Not Track and consent settings, with no extra network requests and no canvas/WebGL probing):

| Field | Source | Bounds |
| --- | --- | --- |
| `hardwareConcurrency` | `navigator.hardwareConcurrency` | `1..256` integer |
| `deviceMemoryGb` | `navigator.deviceMemory` | `0.25..128` GB |
| `connectionType` | `navigator.connection.effectiveType` | `slow-2g`, `2g`, `3g`, `4g` |
| `connectionDownlinkMbps` | `navigator.connection.downlink` | `0..10000` Mbps |
| `connectionRttMs` | `navigator.connection.rtt` | `0..60000` ms |
| `saveData` | `navigator.connection.saveData` | boolean |
| `ttfbMs` | Navigation timing `responseStart - activationStart` | `0..600000` ms |
| `domInteractiveMs` | Navigation timing `domInteractive - activationStart` | `0..600000` ms |
| `pageLoadMs` | Navigation timing `loadEventEnd - activationStart` | `0..600000` ms |
| `jsHeapUsedMb` | `performance.memory.usedJSHeapSize` | `0..65536` MB |
| `jsHeapLimitMb` | `performance.memory.jsHeapSizeLimit` | `0..65536` MB |
| `frameRateFps` | Passive bounded `requestAnimationFrame` burst (max 12 frames) | `1..240` FPS |

Browsers that restrict `navigator.deviceMemory`, `navigator.connection`, or `performance.memory` (such as Safari and Firefox) omit unsupported fields.

## Server-side scoring and tiers

During fact building (`AnalyticsFactBuilder`) and realtime inspection (`AnalyticsQueryService.realtime`), the backend merges session signals and computes a `0–100` performance score dynamically weighted across available dimensions:

- **CPU (`hardwareConcurrency`)**: weight `35`
- **Device memory (`deviceMemoryGb`)**: weight `25`
- **Load & runtime timing (`pageLoadMs`, `domInteractiveMs`, `ttfbMs`)**: weight `20`
- **Network (`connectionType` / `connectionDownlinkMbps` / `connectionRttMs`, with `saveData` penalty)**: weight `10`
- **Rendering smoothness (`frameRateFps`)**: weight `10`

Weights are renormalized over the signals present in a session, so browsers exposing fewer APIs are still evaluated fairly. Tiers map as:

- **High (`high`)**: score `>= 75`
- **Medium (`medium`)**: score `45..74`
- **Low (`low`)**: score `< 45`

## Privacy boundaries

- No raw User-Agent strings, GPU renderer names, canvas hashes, or font metrics are collected for device performance statistics.
- When `requireConsent` or `Do Not Track` blocks collection, no metrics or `requestAnimationFrame` sampling run; withdrawing consent cancels any active sampling immediately.
- Reports display numeric client IPs (subject to the site's 30-day retention policy) rather than raw anonymous visitor IDs.

## API endpoint

```text
GET /api/v1/sites/{siteId}/analytics/device-performance?from=YYYY-MM-DD&to=YYYY-MM-DD&segmentId={optional}&limit=100
```

Returns:
- Summary KPIs: `totalSessions`, `measuredSessions`, `totalVisitors`, `measuredVisitors`, `averagePerformanceScore`, `medianPerformanceScore`, `highTierSessions`, `mediumTierSessions`, `lowTierSessions`, `averageCpuCores`, `averageDeviceMemoryGb`, `p75PageLoadMs`, `p75DomInteractiveMs`, `p75TtfbMs`, `averageFrameRateFps`
- Distributions: `tierBreakdown`, `cpuBreakdown`, `memoryBreakdown`, `networkBreakdown`, `loadTimeBreakdown`, `fpsBreakdown`
- Per-visitor rows (`visitors`, up to `limit` max `200`): representative session performance snapshot, hardware/network/timing fields, `performanceScore`, and `performanceTier`.
