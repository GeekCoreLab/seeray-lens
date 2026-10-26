package io.seeray.lens.application;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Assigns request-local labels so fingerprint keys never leave the analytics service. */
public final class VisitorAssociationGroups {
    private VisitorAssociationGroups() {}

    public static Map<String, Labels> assign(List<Signal> signals) {
        Map<String, String> tlsLabels = new LinkedHashMap<>();
        Map<String, String> browserLabels = new LinkedHashMap<>();
        Map<String, Labels> result = new LinkedHashMap<>();
        for (Signal signal : signals) {
            String tls = label(tlsLabels, signal.tlsKey());
            String browser = label(browserLabels, signal.browserKey());
            result.put(signal.recordKey(), new Labels(tls, browser));
        }
        return result;
    }

    private static String label(Map<String, String> labels, String key) {
        if (key == null || key.isBlank()) return null;
        return labels.computeIfAbsent(key, ignored -> Integer.toString(labels.size() + 1));
    }

    public record Signal(String recordKey, String tlsKey, String browserKey) {}

    public record Labels(String tlsFingerprintGroup, String browserFingerprintGroup) {}
}
