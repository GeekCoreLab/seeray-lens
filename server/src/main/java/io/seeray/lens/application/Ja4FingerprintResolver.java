package io.seeray.lens.application;

import io.vertx.core.http.HttpServerRequest;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.UUID;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/** Reads Cloudflare's JA4 header only from a configured trusted edge and immediately site-scopes its hash. */
@ApplicationScoped
public class Ja4FingerprintResolver {
    private final GeoLocationResolver proxyTrust;
    private final boolean enabled;

    @Inject
    public Ja4FingerprintResolver(
            GeoLocationResolver proxyTrust,
            @ConfigProperty(name = "seeray.fingerprint.ja4.enabled", defaultValue = "false") boolean enabled) {
        this.proxyTrust = proxyTrust;
        this.enabled = enabled;
    }

    public String hash(UUID siteId, HttpServerRequest request) {
        if (!enabled || siteId == null || request == null || !proxyTrust.isTrustedProxy(request)) return null;
        String ja4 = request.getHeader("cf-ja4");
        if (ja4 == null) return null;
        String normalized = ja4.trim().toLowerCase(java.util.Locale.ROOT);
        if (!normalized.matches("[a-z0-9_-]{1,128}")) return null;
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(siteId.toString().getBytes(StandardCharsets.UTF_8));
            digest.update((byte) 0);
            digest.update("ja4:v1".getBytes(StandardCharsets.UTF_8));
            digest.update((byte) 0);
            return HexFormat.of().formatHex(digest.digest(normalized.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException impossible) {
            throw new IllegalStateException("SHA-256 is not available", impossible);
        }
    }
}
