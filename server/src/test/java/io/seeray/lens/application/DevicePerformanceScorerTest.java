package io.seeray.lens.application;

import static org.junit.jupiter.api.Assertions.*;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class DevicePerformanceScorerTest {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Test
    void evaluatesHighMediumLowAndPartialBrowserSignals() {
        var high =
                new DevicePerformanceScorer.Metrics(12, 16.0, "4g", 50.0, 25, false, 120, 750, 1100, 42.5, 2048.0, 60);
        var highRating = DevicePerformanceScorer.evaluate(high);
        assertNotNull(highRating.score());
        assertTrue(highRating.score() >= 90);
        assertEquals("high", highRating.tier());

        var safariPartial =
                new DevicePerformanceScorer.Metrics(8, null, null, null, null, null, 250, 950, 1400, null, null, 60);
        var partialRating = DevicePerformanceScorer.evaluate(safariPartial);
        assertNotNull(partialRating.score());
        assertTrue(partialRating.score() >= 75);
        assertEquals("high", partialRating.tier());

        var medium =
                new DevicePerformanceScorer.Metrics(4, 4.0, "3g", 2.0, 180, false, 600, 2400, 3400, 80.0, 1024.0, 40);
        var mediumRating = DevicePerformanceScorer.evaluate(medium);
        assertNotNull(mediumRating.score());
        assertTrue(mediumRating.score() >= 45 && mediumRating.score() < 75);
        assertEquals("medium", mediumRating.tier());

        var low = new DevicePerformanceScorer.Metrics(2, 1.0, "2g", 0.5, 650, true, 2400, 7500, 9000, 200.0, 512.0, 18);
        var lowRating = DevicePerformanceScorer.evaluate(low);
        assertNotNull(lowRating.score());
        assertTrue(lowRating.score() < 45);
        assertEquals("low", lowRating.tier());
    }

    @Test
    void returnsNullRatingWhenNoScoreableSignalsExist() {
        var empty = DevicePerformanceScorer.evaluate(DevicePerformanceScorer.Metrics.EMPTY);
        assertNull(empty.score());
        assertNull(empty.tier());
        assertNull(DevicePerformanceScorer.evaluate(null).score());
    }

    @Test
    void ignoresOutOfBoundsContextAndStringInputs() throws Exception {
        JsonNode node = MAPPER.readTree(
                """
                {
                  "hardwareConcurrency": 0,
                  "deviceMemoryGb": 512.0,
                  "connectionType": "5g",
                  "connectionDownlinkMbps": -1.0,
                  "connectionRttMs": 100000,
                  "saveData": "yes",
                  "ttfbMs": -5,
                  "domInteractiveMs": 700000,
                  "pageLoadMs": 1200,
                  "jsHeapUsedMb": -1.0,
                  "jsHeapLimitMb": 99999.0,
                  "frameRateFps": 300
                }
                """);
        var metrics = DevicePerformanceScorer.fromContext(node);
        assertNull(metrics.hardwareConcurrency());
        assertNull(metrics.deviceMemoryGb());
        assertNull(metrics.connectionType());
        assertNull(metrics.connectionDownlinkMbps());
        assertNull(metrics.connectionRttMs());
        assertNull(metrics.saveData());
        assertNull(metrics.ttfbMs());
        assertNull(metrics.domInteractiveMs());
        assertEquals(1200, metrics.pageLoadMs());
        assertNull(metrics.jsHeapUsedMb());
        assertNull(metrics.jsHeapLimitMb());
        assertNull(metrics.frameRateFps());

        var parsed = DevicePerformanceScorer.fromStrings(
                "8", "8.0", "4g", "12.5", "40", "true", "180", "900", "1400", "32.5", "1024", "60");
        assertEquals(8, parsed.hardwareConcurrency());
        assertEquals(8.0, parsed.deviceMemoryGb());
        assertEquals("4g", parsed.connectionType());
        assertEquals(Boolean.TRUE, parsed.saveData());
        assertEquals(60, parsed.frameRateFps());

        var invalid = DevicePerformanceScorer.fromStrings(
                "abc", "0.1", "ethernet", "NaN", "-1", "maybe", "", "9999999", "x", "y", "z", "0");
        assertEquals(DevicePerformanceScorer.Metrics.EMPTY, invalid);
    }
}
