package io.seeray.lens.application;

import jakarta.enterprise.context.ApplicationScoped;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;

/** Tracks one-use synthetic collection requests until their broker consumers acknowledge them. */
@ApplicationScoped
public class SelfCheckProbeRegistry {
    public static final String HEADER = "X-SeeRay-Self-Check-Id";
    public static final String TRACKING_SITE_ID = "seeray-system-health-check";
    public static final String TRACKING_HOST = "tracking-self-check.seeray.invalid";
    public static final String HEATMAP_SITE_ID = "seeray-heatmap-self-check";
    public static final String HEATMAP_HOST = "heatmap-self-check.seeray.invalid";
    private static final Duration LIFETIME = Duration.ofMinutes(2);

    private final ConcurrentHashMap<String, Probe> probes = new ConcurrentHashMap<>();

    public CompletableFuture<Void> register(String id, Pipeline pipeline) {
        Probe probe = new Probe(pipeline, Instant.now().plus(LIFETIME), new CompletableFuture<>());
        if (probes.putIfAbsent(id, probe) != null) throw new IllegalStateException("Duplicate self-check id");
        return probe.acknowledged();
    }

    public boolean isActive(String id, Pipeline pipeline) {
        if (id == null || id.isBlank()) return false;
        Probe probe = probes.get(id);
        if (probe == null) return false;
        if (probe.expiresAt().isBefore(Instant.now())) {
            probes.remove(id, probe);
            return false;
        }
        return probe.pipeline() == pipeline;
    }

    public void acknowledged(String id, Pipeline pipeline) {
        Probe probe = probes.get(id);
        if (probe != null && probe.pipeline() == pipeline && probes.remove(id, probe)) {
            probe.acknowledged().complete(null);
        }
    }

    public void discard(String id) {
        probes.remove(id);
    }

    public enum Pipeline {
        TRACKING,
        HEATMAP
    }

    private record Probe(Pipeline pipeline, Instant expiresAt, CompletableFuture<Void> acknowledged) {}
}
