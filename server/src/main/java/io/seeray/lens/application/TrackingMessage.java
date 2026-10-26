package io.seeray.lens.application;

import io.quarkus.runtime.annotations.RegisterForReflection;
import java.time.Instant;
import java.util.UUID;

@RegisterForReflection
public record TrackingMessage(
        int messageSchemaVersion,
        UUID ingestId,
        UUID clientEventId,
        UUID siteId,
        Instant receivedAt,
        Instant occurredAt,
        String eventType,
        TrackingSanitizer.CleanUrl page,
        TrackingSanitizer.CleanUrl referrer,
        String eventData,
        Integer durationMs,
        String visitorId,
        String sessionId,
        String userIdHash,
        String fingerprintKey,
        Integer fingerprintAlgorithmVersion,
        String fingerprintStability,
        String ja4FingerprintKey,
        String selfCheckId) {}
