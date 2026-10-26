package io.seeray.lens.infrastructure.ingestion;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.seeray.lens.application.HeatmapMessage;
import io.seeray.lens.application.SelfCheckProbeRegistry;
import io.smallrye.reactive.messaging.annotations.Blocking;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.concurrent.CompletionStage;
import org.eclipse.microprofile.reactive.messaging.Incoming;
import org.eclipse.microprofile.reactive.messaging.Message;

@ApplicationScoped
public class HeatmapIngestionWorker {
    private final ObjectMapper mapper;
    private final HeatmapBatchPersistence persistence;
    private final SelfCheckProbeRegistry selfCheckProbes;

    public HeatmapIngestionWorker(
            ObjectMapper mapper, HeatmapBatchPersistence persistence, SelfCheckProbeRegistry selfCheckProbes) {
        this.mapper = mapper;
        this.persistence = persistence;
        this.selfCheckProbes = selfCheckProbes;
    }

    @Incoming("heatmap-in")
    @Blocking
    public CompletionStage<Void> consume(Message<?> message) {
        try {
            HeatmapMessage payload = mapper.readValue(String.valueOf(message.getPayload()), HeatmapMessage.class);
            if (payload.selfCheckId() == null) {
                persistence.persist(payload.siteId(), payload.effectiveSampleRate(), payload.payload());
            }
            return message.ack().whenComplete((ignored, failure) -> {
                if (failure == null && payload.selfCheckId() != null) {
                    selfCheckProbes.acknowledged(payload.selfCheckId(), SelfCheckProbeRegistry.Pipeline.HEATMAP);
                }
            });
        } catch (Exception error) {
            return message.nack(error);
        }
    }
}
