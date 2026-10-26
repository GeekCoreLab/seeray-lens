package io.seeray.lens.application;

import io.quarkus.runtime.annotations.RegisterForReflection;
import java.util.UUID;

/** Broker payload for the isolated heatmap ingestion route. */
@RegisterForReflection
public record HeatmapMessage(UUID siteId, int effectiveSampleRate, HeatmapPayload payload) {}
