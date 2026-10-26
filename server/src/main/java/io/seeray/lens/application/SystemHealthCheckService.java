package io.seeray.lens.application;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.runtime.annotations.RegisterForReflection;
import jakarta.enterprise.context.ApplicationScoped;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/** Runs periodic real HTTP collection probes and records a safe summary for system administrators. */
@ApplicationScoped
public class SystemHealthCheckService {
    private static final Logger LOG = Logger.getLogger(SystemHealthCheckService.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(8);
    private static final Duration PROBE_TIMEOUT = Duration.ofSeconds(8);

    private final ObjectMapper mapper;
    private final SelfCheckProbeRegistry probes;
    private final HttpClient client;
    private final int httpPort;
    private final AtomicBoolean running = new AtomicBoolean();
    private final AtomicReference<Report> report =
            new AtomicReference<>(new Report("pending", null, Instant.now().plusSeconds(10), false, List.of()));

    public SystemHealthCheckService(
            ObjectMapper mapper,
            SelfCheckProbeRegistry probes,
            @ConfigProperty(name = "quarkus.http.port", defaultValue = "8080") int httpPort) {
        this.mapper = mapper;
        this.probes = probes;
        this.httpPort = httpPort;
        this.client =
                HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
    }

    @io.quarkus.scheduler.Scheduled(
            every = "2h",
            delay = 10,
            delayUnit = TimeUnit.SECONDS,
            identity = "system-health-self-check")
    void scheduledCheck() {
        runCheck();
    }

    public Report currentReport() {
        return report.get();
    }

    private void runCheck() {
        if (!running.compareAndSet(false, true)) return;
        Instant startedAt = Instant.now();
        report.set(new Report("running", startedAt, startedAt.plus(Duration.ofHours(2)), true, List.of()));
        List<Check> checks = new ArrayList<>();
        try {
            checks.addAll(checkReadiness());
            checks.add(runPipelineProbe(SelfCheckProbeRegistry.Pipeline.TRACKING));
            checks.add(runPipelineProbe(SelfCheckProbeRegistry.Pipeline.HEATMAP));
            String overall = checks.stream().allMatch(check -> "pass".equals(check.status())) ? "pass" : "fail";
            report.set(new Report(overall, startedAt, startedAt.plus(Duration.ofHours(2)), false, List.copyOf(checks)));
        } catch (Exception failure) {
            LOG.errorf(
                    "System self-check failed (exceptionType=%s)",
                    failure.getClass().getSimpleName());
            checks.add(new Check("self_check", "fail", null, failure.getClass().getSimpleName()));
            report.set(new Report("fail", startedAt, startedAt.plus(Duration.ofHours(2)), false, List.copyOf(checks)));
        } finally {
            running.set(false);
        }
    }

    private List<Check> checkReadiness() {
        long started = System.nanoTime();
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(baseUrl() + "/q/health/ready"))
                    .timeout(REQUEST_TIMEOUT)
                    .GET()
                    .build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            long latency = elapsedMillis(started);
            JsonNode root = mapper.readTree(response.body());
            JsonNode healthChecks = root.path("checks");
            return List.of(
                    readinessComponent("database", healthChecks, "database", latency),
                    readinessComponent("redis", healthChecks, "redis", latency),
                    readinessComponent("rabbitmq", healthChecks, "messaging", latency));
        } catch (Exception failure) {
            long latency = elapsedMillis(started);
            String error = failure.getClass().getSimpleName();
            return List.of(
                    new Check("database", "fail", latency, error),
                    new Check("redis", "fail", latency, error),
                    new Check("rabbitmq", "fail", latency, error));
        }
    }

    private Check readinessComponent(String key, JsonNode healthChecks, String nameFragment, long latency) {
        boolean found = false;
        boolean healthy = true;
        for (JsonNode healthCheck : healthChecks) {
            String name = healthCheck.path("name").asText("").toLowerCase(java.util.Locale.ROOT);
            if (!name.contains(nameFragment)) continue;
            found = true;
            if (!"UP".equalsIgnoreCase(healthCheck.path("status").asText())) healthy = false;
        }
        if (!found) return new Check(key, "fail", latency, "CHECK_NOT_REPORTED");
        return new Check(key, healthy ? "pass" : "fail", latency, healthy ? null : "DEPENDENCY_DOWN");
    }

    private Check runPipelineProbe(SelfCheckProbeRegistry.Pipeline pipeline) {
        String id = UUID.randomUUID().toString();
        long started = System.nanoTime();
        CompletableFuture<Void> acknowledged = probes.register(id, pipeline);
        try {
            String endpoint;
            String body;
            if (pipeline == SelfCheckProbeRegistry.Pipeline.TRACKING) {
                endpoint = "/api/v1/collect";
                body = trackingPayload();
            } else {
                endpoint = "/api/v1/collect/heatmaps";
                body = heatmapPayload();
            }
            HttpRequest request = HttpRequest.newBuilder(URI.create(baseUrl() + endpoint))
                    .timeout(REQUEST_TIMEOUT)
                    .header("Content-Type", "application/json")
                    .header(SelfCheckProbeRegistry.HEADER, id)
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();
            HttpResponse<Void> response = client.send(request, HttpResponse.BodyHandlers.discarding());
            if (response.statusCode() != 202) {
                return new Check(key(pipeline), "fail", elapsedMillis(started), "HTTP_" + response.statusCode());
            }
            acknowledged.get(PROBE_TIMEOUT.toMillis(), TimeUnit.MILLISECONDS);
            return new Check(key(pipeline), "pass", elapsedMillis(started), null);
        } catch (Exception failure) {
            Throwable cause = failure;
            while (cause.getCause() != null && cause.getCause() != cause) cause = cause.getCause();
            return new Check(
                    key(pipeline),
                    "fail",
                    elapsedMillis(started),
                    cause.getClass().getSimpleName());
        } finally {
            probes.discard(id);
        }
    }

    private String trackingPayload() throws Exception {
        String now = Instant.now().toString();
        return mapper.writeValueAsString(Map.of(
                "schemaVersion",
                1,
                "siteId",
                SelfCheckProbeRegistry.TRACKING_SITE_ID,
                "sentAt",
                now,
                "events",
                List.of(Map.of(
                        "eventId",
                        UUID.randomUUID().toString(),
                        "type",
                        "page_view",
                        "occurredAt",
                        now,
                        "url",
                        "https://" + SelfCheckProbeRegistry.TRACKING_HOST + "/status-check",
                        "title",
                        "System self-check",
                        "referrer",
                        "https://" + SelfCheckProbeRegistry.TRACKING_HOST + "/"))));
    }

    private String heatmapPayload() throws Exception {
        return mapper.writeValueAsString(Map.of(
                "schemaVersion",
                1,
                "siteId",
                SelfCheckProbeRegistry.HEATMAP_SITE_ID,
                "clientBatchId",
                UUID.randomUUID().toString(),
                "events",
                List.of(Map.ofEntries(
                        Map.entry("type", "start"),
                        Map.entry("instanceId", UUID.randomUUID().toString()),
                        Map.entry("url", "https://" + SelfCheckProbeRegistry.HEATMAP_HOST + "/status-check"),
                        Map.entry("layoutVersion", "system-self-check"),
                        Map.entry("targetId", "system-self-check"),
                        Map.entry("viewportWidth", 1),
                        Map.entry("viewportHeight", 1),
                        Map.entry("contentWidth", 1),
                        Map.entry("contentHeight", 1),
                        Map.entry("scrollBins", List.of()),
                        Map.entry("truncated", false),
                        Map.entry("dropped", 0)))));
    }

    private String baseUrl() {
        return "http://127.0.0.1:" + httpPort;
    }

    private static String key(SelfCheckProbeRegistry.Pipeline pipeline) {
        return pipeline == SelfCheckProbeRegistry.Pipeline.TRACKING ? "tracking_pipeline" : "heatmap_pipeline";
    }

    private static long elapsedMillis(long started) {
        return TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started);
    }

    @RegisterForReflection
    public record Report(
            String overallStatus, Instant checkedAt, Instant nextCheckAt, boolean running, List<Check> checks) {}

    @RegisterForReflection
    public record Check(String key, String status, Long latencyMs, String errorType) {}
}
