package io.seeray.lens.application;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.redis.datasource.RedisDataSource;
import io.quarkus.redis.datasource.value.ValueCommands;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.net.InetAddress;
import java.util.*;
import java.util.concurrent.*;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * Resolves coarse geolocation for public visitor IPs using L1 in-memory caching, L2 Redis caching,
 * and in-flight request deduplication before calling {@link IpGeoLookupGateway}.
 */
@ApplicationScoped
public class IpGeoLookupService {
    private static final Logger LOG = Logger.getLogger(IpGeoLookupService.class);
    private static final int MAX_L1_ENTRIES = 10_000;
    private static final long ERROR_CACHE_SECONDS = 60L;
    private static final String REDIS_NEGATIVE_MARKER = "NONE";
    private static final long BATCH_TIMEOUT_MS = 3_000L;

    private final IpGeoLookupGateway gateway;
    private final ValueCommands<String, String> redisValues;
    private final ObjectMapper mapper;
    private final boolean enabled;
    private final String dataset;
    private final long cacheTtlSeconds;
    private final long negativeCacheTtlSeconds;
    private final ConcurrentHashMap<String, CacheEntry> l1Cache = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, CompletableFuture<GeoLocationResolver.Location>> inFlight =
            new ConcurrentHashMap<>();
    private final ExecutorService batchExecutor = Executors.newFixedThreadPool(8, r -> {
        Thread thread = new Thread(r, "seeray-ip-geo-lookup");
        thread.setDaemon(true);
        return thread;
    });

    @Inject
    public IpGeoLookupService(
            IpGeoLookupGateway gateway,
            RedisDataSource redis,
            ObjectMapper mapper,
            @ConfigProperty(name = "seeray.geo.ip-lookup.enabled", defaultValue = "true") boolean enabled,
            @ConfigProperty(name = "seeray.geo.ip-lookup.dataset", defaultValue = "community") String dataset,
            @ConfigProperty(name = "seeray.geo.ip-lookup.cache-ttl-seconds", defaultValue = "86400")
                    long cacheTtlSeconds,
            @ConfigProperty(name = "seeray.geo.ip-lookup.negative-cache-ttl-seconds", defaultValue = "3600")
                    long negativeCacheTtlSeconds) {
        this.gateway = gateway;
        this.redisValues = redis == null ? null : redis.value(String.class, String.class);
        this.mapper = mapper;
        this.enabled = enabled;
        this.dataset = dataset == null || dataset.isBlank() ? "community" : dataset.trim();
        this.cacheTtlSeconds = Math.max(60L, cacheTtlSeconds);
        this.negativeCacheTtlSeconds = Math.max(60L, negativeCacheTtlSeconds);
    }

    public boolean isEnabled() {
        return enabled;
    }

    @PreDestroy
    void shutdown() {
        batchExecutor.shutdownNow();
    }

    public GeoLocationResolver.Location lookup(String rawIp) {
        if (!enabled) return GeoLocationResolver.Location.empty();
        String ip = normalizePublicIp(rawIp);
        if (ip == null) return GeoLocationResolver.Location.empty();
        GeoLocationResolver.Location cached = readCached(ip);
        if (cached != null) return cached;
        return resolveWithDeduplication(ip);
    }

    public Map<String, GeoLocationResolver.Location> lookupBatch(Collection<String> rawIps) {
        if (!enabled || rawIps == null || rawIps.isEmpty()) return Map.of();
        Map<String, GeoLocationResolver.Location> resolved = new LinkedHashMap<>();
        List<String> uncached = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();
        for (String rawIp : rawIps) {
            String normalized = normalizePublicIp(rawIp);
            if (normalized == null || !seen.add(normalized)) continue;
            GeoLocationResolver.Location cached = readCached(normalized);
            if (cached != null) {
                if (!cached.isEmpty()) resolved.put(normalized, cached);
            } else {
                uncached.add(normalized);
            }
        }
        if (uncached.isEmpty()) return Map.copyOf(resolved);

        Map<String, CompletableFuture<GeoLocationResolver.Location>> futures = new LinkedHashMap<>();
        for (String ip : uncached) {
            futures.put(ip, CompletableFuture.supplyAsync(() -> resolveWithDeduplication(ip), batchExecutor));
        }
        long deadlineNanos = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(BATCH_TIMEOUT_MS);
        for (Map.Entry<String, CompletableFuture<GeoLocationResolver.Location>> entry : futures.entrySet()) {
            long remainingMs = Math.max(1L, TimeUnit.NANOSECONDS.toMillis(deadlineNanos - System.nanoTime()));
            try {
                GeoLocationResolver.Location location = entry.getValue().get(remainingMs, TimeUnit.MILLISECONDS);
                if (location != null && !location.isEmpty()) {
                    resolved.put(entry.getKey(), location);
                }
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception ignored) {
                // Skip timed-out or failed entries so the analytics query remains responsive.
            }
        }
        return Map.copyOf(resolved);
    }

    public static String normalizePublicIp(String rawIp) {
        if (rawIp == null || rawIp.isBlank()) return null;
        String cleaned = rawIp.trim();
        if (cleaned.startsWith("[") && cleaned.contains("]")) {
            cleaned = cleaned.substring(1, cleaned.indexOf(']'));
        } else if (cleaned.indexOf(':') > 0 && cleaned.indexOf(':') == cleaned.lastIndexOf(':')) {
            cleaned = cleaned.substring(0, cleaned.indexOf(':'));
        }
        InetAddress address = parseNumericAddress(cleaned);
        if (address == null || !isPublicAddress(address)) return null;
        String host = address.getHostAddress();
        int scope = host.indexOf('%');
        return scope < 0 ? host : host.substring(0, scope);
    }

    public static boolean isPublicIp(String ip) {
        return normalizePublicIp(ip) != null;
    }

    private GeoLocationResolver.Location readCached(String ip) {
        long now = System.currentTimeMillis();
        CacheEntry l1 = l1Cache.get(ip);
        if (l1 != null) {
            if (l1.expiresAtMs() > now) return l1.location();
            l1Cache.remove(ip, l1);
        }
        if (redisValues == null) return null;
        try {
            String raw = redisValues.get(redisKey(ip));
            if (raw == null) return null;
            if (REDIS_NEGATIVE_MARKER.equals(raw)) {
                putL1(ip, GeoLocationResolver.Location.empty(), negativeCacheTtlSeconds);
                return GeoLocationResolver.Location.empty();
            }
            GeoLocationResolver.Location decoded = deserializeLocation(raw);
            if (decoded != null && !decoded.isEmpty()) {
                putL1(ip, decoded, cacheTtlSeconds);
                return decoded;
            }
        } catch (Exception error) {
            LOG.debugf("Redis IP geo cache read failed (%s)", error.getClass().getSimpleName());
        }
        return null;
    }

    private GeoLocationResolver.Location resolveWithDeduplication(String ip) {
        CompletableFuture<GeoLocationResolver.Location> created = new CompletableFuture<>();
        CompletableFuture<GeoLocationResolver.Location> existing = inFlight.putIfAbsent(ip, created);
        if (existing != null) {
            try {
                return existing.get(BATCH_TIMEOUT_MS, TimeUnit.MILLISECONDS);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return GeoLocationResolver.Location.empty();
            } catch (Exception ignored) {
                return GeoLocationResolver.Location.empty();
            }
        }
        try {
            GeoLocationResolver.Location result = fetchAndCache(ip);
            created.complete(result);
            return result;
        } catch (Throwable failure) {
            created.complete(GeoLocationResolver.Location.empty());
            return GeoLocationResolver.Location.empty();
        } finally {
            inFlight.remove(ip, created);
        }
    }

    private GeoLocationResolver.Location fetchAndCache(String ip) {
        IpGeoLookupGateway.LookupResult result =
                gateway == null ? IpGeoLookupGateway.LookupResult.error() : gateway.lookup(ip);
        if (result.status() == IpGeoLookupGateway.Status.FOUND
                && result.location() != null
                && !result.location().isEmpty()) {
            putL1(ip, result.location(), cacheTtlSeconds);
            writeRedis(ip, serializeLocation(result.location()), cacheTtlSeconds);
            return result.location();
        }
        if (result.status() == IpGeoLookupGateway.Status.NOT_FOUND) {
            putL1(ip, GeoLocationResolver.Location.empty(), negativeCacheTtlSeconds);
            writeRedis(ip, REDIS_NEGATIVE_MARKER, negativeCacheTtlSeconds);
            return GeoLocationResolver.Location.empty();
        }
        // Transient provider/network error: short L1-only cache so recovery is immediate once upstream recovers.
        putL1(ip, GeoLocationResolver.Location.empty(), ERROR_CACHE_SECONDS);
        return GeoLocationResolver.Location.empty();
    }

    private void putL1(String ip, GeoLocationResolver.Location location, long ttlSeconds) {
        if (l1Cache.size() >= MAX_L1_ENTRIES) {
            long now = System.currentTimeMillis();
            l1Cache.entrySet().removeIf(entry -> entry.getValue().expiresAtMs() <= now);
            if (l1Cache.size() >= MAX_L1_ENTRIES) {
                l1Cache.clear();
            }
        }
        l1Cache.put(ip, new CacheEntry(location, System.currentTimeMillis() + ttlSeconds * 1000L));
    }

    private void writeRedis(String ip, String payload, long ttlSeconds) {
        if (redisValues == null || payload == null) return;
        try {
            redisValues.setex(redisKey(ip), ttlSeconds, payload);
        } catch (Exception error) {
            LOG.debugf("Redis IP geo cache write failed (%s)", error.getClass().getSimpleName());
        }
    }

    private String redisKey(String ip) {
        return "seeray:geo:ip:" + dataset + ":" + ip;
    }

    private String serializeLocation(GeoLocationResolver.Location location) {
        try {
            Map<String, String> payload = new LinkedHashMap<>();
            if (location.countryCode() != null) payload.put("countryCode", location.countryCode());
            if (location.continentCode() != null) payload.put("continentCode", location.continentCode());
            if (location.regionCode() != null) payload.put("regionCode", location.regionCode());
            if (location.region() != null) payload.put("region", location.region());
            if (location.city() != null) payload.put("city", location.city());
            if (location.timezone() != null) payload.put("timezone", location.timezone());
            return mapper.writeValueAsString(payload);
        } catch (Exception ignored) {
            return null;
        }
    }

    private GeoLocationResolver.Location deserializeLocation(String json) {
        try {
            JsonNode node = mapper.readTree(json);
            if (!node.isObject()) return null;
            String countryCode = textOrNull(node, "countryCode");
            if (countryCode == null) return null;
            return new GeoLocationResolver.Location(
                    countryCode,
                    textOrNull(node, "continentCode"),
                    textOrNull(node, "regionCode"),
                    textOrNull(node, "region"),
                    textOrNull(node, "city"),
                    textOrNull(node, "timezone"));
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String textOrNull(JsonNode node, String field) {
        JsonNode child = node.path(field);
        if (!child.isTextual()) return null;
        String text = child.asText();
        return text.isBlank() ? null : text;
    }

    private static InetAddress parseNumericAddress(String value) {
        if (value == null || value.isBlank()) return null;
        if (value.indexOf(':') < 0 && !value.matches("[0-9.]+")) return null;
        if (value.indexOf(':') >= 0 && !value.matches("[0-9A-Fa-f:.%A-Za-z0-9_-]+")) return null;
        try {
            return InetAddress.getByName(value);
        } catch (Exception invalidAddress) {
            return null;
        }
    }

    private static boolean isPublicAddress(InetAddress address) {
        if (address.isAnyLocalAddress()
                || address.isLoopbackAddress()
                || address.isLinkLocalAddress()
                || address.isSiteLocalAddress()
                || address.isMulticastAddress()) {
            return false;
        }
        byte[] bytes = address.getAddress();
        if (bytes.length == 4) {
            int b0 = bytes[0] & 0xFF;
            int b1 = bytes[1] & 0xFF;
            int b2 = bytes[2] & 0xFF;
            if (b0 == 0) return false; // 0.0.0.0/8
            if (b0 == 100 && (b1 >= 64 && b1 <= 127)) return false; // 100.64.0.0/10 CGNAT
            if (b0 == 192 && b1 == 0 && b2 == 0) return false; // 192.0.0.0/24
            if (b0 == 192 && b1 == 0 && b2 == 2) return false; // 192.0.2.0/24 TEST-NET-1
            if (b0 == 198 && (b1 == 18 || b1 == 19)) return false; // 198.18.0.0/15
            if (b0 == 198 && b1 == 51 && b2 == 100) return false; // 198.51.100.0/24 TEST-NET-2
            if (b0 == 203 && b1 == 0 && b2 == 113) return false; // 203.0.113.0/24 TEST-NET-3
            if (b0 >= 240) return false; // 240.0.0.0/4 reserved & broadcast
            return true;
        }
        if (bytes.length == 16) {
            int b0 = bytes[0] & 0xFF;
            int b1 = bytes[1] & 0xFF;
            if ((b0 & 0xFE) == 0xFC) return false; // fc00::/7 ULA
            if (b0 == 0x20 && b1 == 0x01 && (bytes[2] & 0xFF) == 0x0D && (bytes[3] & 0xFF) == 0xB8) {
                return false; // 2001:db8::/32 documentation
            }
            return true;
        }
        return false;
    }

    private record CacheEntry(GeoLocationResolver.Location location, long expiresAtMs) {}
}
