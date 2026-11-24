package io.seeray.lens.infrastructure.geo;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.seeray.lens.application.GeoContinentMapping;
import io.seeray.lens.application.GeoLocationResolver;
import io.seeray.lens.application.IpGeoLookupGateway;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.Locale;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/** Queries the configured IP geolocation HTTP API (e.g. ipnest.mliev.com) using Jackson tree parsing. */
@ApplicationScoped
public class IpNestGeoLookupHttpGateway implements IpGeoLookupGateway {
    private static final Logger LOG = Logger.getLogger(IpNestGeoLookupHttpGateway.class);

    private final ObjectMapper mapper;
    private final String baseUrl;
    private final String dataset;
    private final int timeoutMs;
    private final HttpClient httpClient;

    @Inject
    public IpNestGeoLookupHttpGateway(
            ObjectMapper mapper,
            @ConfigProperty(
                            name = "seeray.geo.ip-lookup.base-url",
                            defaultValue = "https://ipnest.mliev.com/api/v1/lookup")
                    String baseUrl,
            @ConfigProperty(name = "seeray.geo.ip-lookup.dataset", defaultValue = "community") String dataset,
            @ConfigProperty(name = "seeray.geo.ip-lookup.timeout-ms", defaultValue = "2500") int timeoutMs) {
        this.mapper = mapper;
        this.baseUrl = baseUrl == null ? "" : baseUrl.trim();
        this.dataset = dataset == null || dataset.isBlank() ? "community" : dataset.trim();
        this.timeoutMs = Math.max(250, timeoutMs);
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(Math.min(this.timeoutMs, 2000)))
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
    }

    @Override
    public LookupResult lookup(String ip) {
        if (ip == null || ip.isBlank() || baseUrl.isBlank()) {
            return LookupResult.notFound();
        }
        try {
            String separator = baseUrl.contains("?") ? "&" : "?";
            URI uri = URI.create(baseUrl + separator + "ip=" + encode(ip.trim()) + "&dataset=" + encode(dataset));
            HttpRequest request = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofMillis(timeoutMs))
                    .header("Accept", "application/json")
                    .header("User-Agent", "SeeRay-Lens")
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                LOG.warnf("IP geolocation lookup returned HTTP %d", response.statusCode());
                return LookupResult.error();
            }
            JsonNode root = mapper.readTree(response.body());
            if (root == null || root.path("code").asInt(-1) != 0) {
                return LookupResult.error();
            }
            JsonNode data = root.path("data");
            if (!data.isObject() || !data.path("found").asBoolean(false)) {
                return LookupResult.notFound();
            }
            String countryCode = isoCountryCode(data.path("country_code"));
            if (countryCode == null) {
                return LookupResult.notFound();
            }
            String continentCode = GeoContinentMapping.resolve(text(data, "continent", 32), countryCode);
            String regionCode = token(data.path("area_code"), 16);
            String region = text(data, "region", 120);
            String city = text(data, "city", 120);
            String timezone = timezone(data.path("time_zone"));
            return LookupResult.found(
                    new GeoLocationResolver.Location(countryCode, continentCode, regionCode, region, city, timezone));
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            LOG.debugf("IP geolocation lookup interrupted for %s", ip);
            return LookupResult.error();
        } catch (Exception error) {
            LOG.debugf("IP geolocation lookup failed (%s)", error.getClass().getSimpleName());
            return LookupResult.error();
        }
    }

    private static String isoCountryCode(JsonNode node) {
        if (!node.isTextual()) return null;
        String code = node.asText().trim().toUpperCase(Locale.ROOT);
        return Arrays.asList(Locale.getISOCountries()).contains(code) ? code : null;
    }

    private static String token(JsonNode node, int maxLength) {
        if (!node.isTextual()) return null;
        String normalized = node.asText().strip();
        return normalized.matches("[A-Za-z0-9-]{1," + maxLength + "}") ? normalized.toUpperCase(Locale.ROOT) : null;
    }

    private static String text(JsonNode parent, String field, int maxLength) {
        JsonNode node = parent.path(field);
        if (!node.isTextual()) return null;
        String cleaned = node.asText().strip().replaceAll("[\\p{Cc}]", "");
        if (cleaned.isBlank() || "0".equals(cleaned) || cleaned.length() > maxLength) return null;
        return cleaned;
    }

    private static String timezone(JsonNode node) {
        if (!node.isTextual()) return null;
        String cleaned = node.asText().strip().replaceAll("[\\p{Cc}]", "");
        if (cleaned.isBlank() || cleaned.length() > 64) return null;
        try {
            return ZoneId.of(cleaned).getId();
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
