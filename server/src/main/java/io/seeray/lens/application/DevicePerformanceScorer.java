package io.seeray.lens.application;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Set;

/** Extracts bounded device performance signals and evaluates a 0-100 visitor device score. */
public final class DevicePerformanceScorer {
    private static final Set<String> CONNECTION_TYPES = Set.of("slow-2g", "2g", "3g", "4g");

    private DevicePerformanceScorer() {}

    public record Metrics(
            Integer hardwareConcurrency,
            Double deviceMemoryGb,
            String connectionType,
            Double connectionDownlinkMbps,
            Integer connectionRttMs,
            Boolean saveData,
            Integer ttfbMs,
            Integer domInteractiveMs,
            Integer pageLoadMs,
            Double jsHeapUsedMb,
            Double jsHeapLimitMb,
            Integer frameRateFps) {
        public static final Metrics EMPTY =
                new Metrics(null, null, null, null, null, null, null, null, null, null, null, null);
    }

    public record Rating(Integer score, String tier) {}

    public static Metrics fromContext(JsonNode context) {
        if (context == null || context.isMissingNode() || !context.isObject()) return Metrics.EMPTY;
        return new Metrics(
                boundedInt(context, "hardwareConcurrency", 1, 256),
                boundedDouble(context, "deviceMemoryGb", 0.25, 128.0),
                connectionType(context.path("connectionType")),
                boundedDouble(context, "connectionDownlinkMbps", 0.0, 10000.0),
                boundedInt(context, "connectionRttMs", 0, 60000),
                boundedBoolean(context.path("saveData")),
                boundedInt(context, "ttfbMs", 0, 600000),
                boundedInt(context, "domInteractiveMs", 0, 600000),
                boundedInt(context, "pageLoadMs", 0, 600000),
                boundedDouble(context, "jsHeapUsedMb", 0.0, 65536.0),
                boundedDouble(context, "jsHeapLimitMb", 0.0, 65536.0),
                boundedInt(context, "frameRateFps", 1, 240));
    }

    public static Metrics fromStrings(
            String hardwareConcurrency,
            String deviceMemoryGb,
            String connectionType,
            String connectionDownlinkMbps,
            String connectionRttMs,
            String saveData,
            String ttfbMs,
            String domInteractiveMs,
            String pageLoadMs,
            String jsHeapUsedMb,
            String jsHeapLimitMb,
            String frameRateFps) {
        return new Metrics(
                parseInt(hardwareConcurrency, 1, 256),
                parseDouble(deviceMemoryGb, 0.25, 128.0),
                normalizeConnectionType(connectionType),
                parseDouble(connectionDownlinkMbps, 0.0, 10000.0),
                parseInt(connectionRttMs, 0, 60000),
                parseBoolean(saveData),
                parseInt(ttfbMs, 0, 600000),
                parseInt(domInteractiveMs, 0, 600000),
                parseInt(pageLoadMs, 0, 600000),
                parseDouble(jsHeapUsedMb, 0.0, 65536.0),
                parseDouble(jsHeapLimitMb, 0.0, 65536.0),
                parseInt(frameRateFps, 1, 240));
    }

    public static Rating evaluate(Metrics metrics) {
        if (metrics == null) return new Rating(null, null);
        double weightedSum = 0.0;
        double totalWeight = 0.0;

        if (metrics.hardwareConcurrency() != null) {
            weightedSum += scoreCpu(metrics.hardwareConcurrency()) * 35.0;
            totalWeight += 35.0;
        }
        if (metrics.deviceMemoryGb() != null) {
            weightedSum += scoreMemory(metrics.deviceMemoryGb()) * 25.0;
            totalWeight += 25.0;
        }
        Double timingScore = scoreTiming(metrics);
        if (timingScore != null) {
            weightedSum += timingScore * 20.0;
            totalWeight += 20.0;
        }
        Double networkScore = scoreNetwork(metrics);
        if (networkScore != null) {
            weightedSum += networkScore * 10.0;
            totalWeight += 10.0;
        }
        if (metrics.frameRateFps() != null) {
            weightedSum += scoreFps(metrics.frameRateFps()) * 10.0;
            totalWeight += 10.0;
        }

        if (totalWeight <= 0.0) return new Rating(null, null);
        int score = Math.max(0, Math.min(100, (int) Math.round(weightedSum / totalWeight)));
        String tier = score >= 75 ? "high" : score >= 45 ? "medium" : "low";
        return new Rating(score, tier);
    }

    private static double scoreCpu(int cores) {
        if (cores >= 12) return 100.0;
        if (cores >= 8) return 90.0;
        if (cores >= 6) return 78.0;
        if (cores >= 4) return 62.0;
        if (cores >= 2) return 38.0;
        return 18.0;
    }

    private static double scoreMemory(double gb) {
        if (gb >= 8.0) return 100.0;
        if (gb >= 4.0) return 78.0;
        if (gb >= 2.0) return 48.0;
        if (gb >= 1.0) return 28.0;
        return 15.0;
    }

    private static Double scoreTiming(Metrics metrics) {
        double sum = 0.0;
        int count = 0;
        if (metrics.pageLoadMs() != null) {
            sum += scorePageLoad(metrics.pageLoadMs());
            count++;
        }
        if (metrics.domInteractiveMs() != null) {
            sum += scoreDomInteractive(metrics.domInteractiveMs());
            count++;
        }
        if (metrics.ttfbMs() != null) {
            sum += scoreTtfb(metrics.ttfbMs());
            count++;
        }
        return count == 0 ? null : sum / count;
    }

    private static double scorePageLoad(int ms) {
        if (ms <= 1500) return 100.0;
        if (ms <= 3000) return 78.0;
        if (ms <= 5000) return 52.0;
        if (ms <= 8000) return 30.0;
        return 15.0;
    }

    private static double scoreDomInteractive(int ms) {
        if (ms <= 1000) return 100.0;
        if (ms <= 2200) return 78.0;
        if (ms <= 4000) return 52.0;
        if (ms <= 7000) return 30.0;
        return 15.0;
    }

    private static double scoreTtfb(int ms) {
        if (ms <= 200) return 100.0;
        if (ms <= 500) return 80.0;
        if (ms <= 1000) return 55.0;
        if (ms <= 2000) return 30.0;
        return 15.0;
    }

    private static Double scoreNetwork(Metrics metrics) {
        Double base = null;
        if (metrics.connectionType() != null) {
            base = switch (metrics.connectionType()) {
                case "4g" -> 95.0;
                case "3g" -> 60.0;
                case "2g" -> 28.0;
                case "slow-2g" -> 12.0;
                default -> null;};
        } else if (metrics.connectionDownlinkMbps() != null) {
            double mbps = metrics.connectionDownlinkMbps();
            if (mbps >= 10.0) base = 95.0;
            else if (mbps >= 3.0) base = 75.0;
            else if (mbps >= 1.0) base = 50.0;
            else base = 25.0;
        } else if (metrics.connectionRttMs() != null) {
            int rtt = metrics.connectionRttMs();
            if (rtt <= 80) base = 95.0;
            else if (rtt <= 200) base = 75.0;
            else if (rtt <= 500) base = 45.0;
            else base = 20.0;
        }
        if (base == null) return null;
        if (Boolean.TRUE.equals(metrics.saveData())) return Math.max(5.0, base - 15.0);
        return base;
    }

    private static double scoreFps(int fps) {
        if (fps >= 55) return 100.0;
        if (fps >= 45) return 80.0;
        if (fps >= 30) return 55.0;
        if (fps >= 20) return 32.0;
        return 15.0;
    }

    private static Integer boundedInt(JsonNode context, String field, int min, int max) {
        JsonNode value = context.path(field);
        if (!value.isIntegralNumber()) return null;
        long number = value.longValue();
        return number >= min && number <= max ? (int) number : null;
    }

    private static Double boundedDouble(JsonNode context, String field, double min, double max) {
        JsonNode value = context.path(field);
        if (!value.isNumber()) return null;
        double number = value.doubleValue();
        return Double.isFinite(number) && number >= min && number <= max ? number : null;
    }

    private static Boolean boundedBoolean(JsonNode value) {
        return value.isBoolean() ? value.booleanValue() : null;
    }

    private static String connectionType(JsonNode value) {
        return value.isTextual() ? normalizeConnectionType(value.asText()) : null;
    }

    private static String normalizeConnectionType(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return CONNECTION_TYPES.contains(trimmed) ? trimmed : null;
    }

    private static Integer parseInt(String value, int min, int max) {
        if (value == null || value.isBlank()) return null;
        try {
            long parsed = Long.parseLong(value.trim());
            return parsed >= min && parsed <= max ? (int) parsed : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private static Double parseDouble(String value, double min, double max) {
        if (value == null || value.isBlank()) return null;
        try {
            double parsed = Double.parseDouble(value.trim());
            return Double.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private static Boolean parseBoolean(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        if ("true".equalsIgnoreCase(trimmed)) return Boolean.TRUE;
        if ("false".equalsIgnoreCase(trimmed)) return Boolean.FALSE;
        return null;
    }
}
