package io.seeray.lens.application;

import static org.junit.jupiter.api.Assertions.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.seeray.lens.domain.site.Site;
import io.vertx.core.MultiMap;
import io.vertx.core.http.HttpServerRequest;
import io.vertx.core.net.SocketAddress;
import java.lang.reflect.Proxy;
import java.util.Map;
import org.junit.jupiter.api.Test;

class GeoLocationResolverTest {
    @Test
    void resolvesOnlyTrustedProxyHeadersAndNormalizesValues() {
        GeoLocationResolver resolver = new GeoLocationResolver(true, "192.0.2.0/24");
        MultiMap headers = MultiMap.caseInsensitiveMultiMap()
                .add("CF-IPCountry", "us")
                .add("cf-ipcontinent", "na")
                .add("cf-region-code", "ca")
                .add("cf-region", "California")
                .add("cf-ipcity", "San Francisco")
                .add("cf-timezone", "America/Los_Angeles");

        GeoLocationResolver.Location location = resolver.resolve("192.0.2.18", headers);
        assertEquals("US", location.countryCode());
        assertEquals("NA", location.continentCode());
        assertEquals("CA", location.regionCode());
        assertEquals("California", location.region());
        assertEquals("San Francisco", location.city());
        assertEquals("America/Los_Angeles", location.timezone());
    }

    @Test
    void ignoresSpoofedHeadersFromUntrustedPeersAndUnknownCountryCodes() {
        GeoLocationResolver resolver = new GeoLocationResolver(true, "192.0.2.0/24");
        MultiMap headers = MultiMap.caseInsensitiveMultiMap().add("cf-ipcountry", "US");

        assertTrue(resolver.resolve("198.51.100.7", headers).isEmpty());
        assertTrue(
                resolver.resolve("192.0.2.7", MultiMap.caseInsensitiveMultiMap().add("cf-ipcountry", "T1"))
                        .isEmpty());
    }

    @Test
    void trustedProxyConfigurationMustUseNumericAddresses() {
        assertThrows(IllegalArgumentException.class, () -> new GeoLocationResolver(true, "proxy.example"));
    }

    @Test
    void resolvesClientIpFromNetworkConnectionIgnoringHeaders() {
        GeoLocationResolver resolver = new GeoLocationResolver(true, "192.0.2.0/24");
        Site site = new Site();
        site.ipLookupMode = "NETWORK";

        HttpServerRequest request = mockRequest(
                "198.51.100.12",
                Map.of(
                        "x-forwarded-for", "203.0.113.195",
                        "cf-connecting-ip", "203.0.113.200"));
        assertEquals("198.51.100.12", resolver.clientIp(site, request));
    }

    @Test
    void resolvesClientIpFromPresetHttpHeaderWithoutNeedingTrustedProxyCidr() {
        GeoLocationResolver resolver = new GeoLocationResolver(false, "");
        Site site = new Site();
        site.ipLookupMode = "HEADER";
        site.ipLookupHeader = "X-Forwarded-For";

        HttpServerRequest request = mockRequest("10.0.0.5", Map.of("X-Forwarded-For", "203.0.113.195, 10.0.0.1"));
        assertEquals("203.0.113.195", resolver.clientIp(site, request));
    }

    @Test
    void resolvesClientIpFromCustomHttpHeader() {
        GeoLocationResolver resolver = new GeoLocationResolver(false, "");
        Site site = new Site();
        site.ipLookupMode = "HEADER";
        site.ipLookupHeader = "X-Custom-Client-IP";

        HttpServerRequest request = mockRequest("10.0.0.5", Map.of("X-Custom-Client-IP", "198.51.100.88"));
        assertEquals("198.51.100.88", resolver.clientIp(site, request));
    }

    @Test
    void fallsBackToNetworkAddressWhenHeaderIsMissingOrInvalid() {
        GeoLocationResolver resolver = new GeoLocationResolver(false, "");
        Site site = new Site();
        site.ipLookupMode = "HEADER";
        site.ipLookupHeader = "X-Real-IP";

        HttpServerRequest requestMissing = mockRequest("198.51.100.77", Map.of());
        assertEquals("198.51.100.77", resolver.clientIp(site, requestMissing));

        HttpServerRequest requestInvalid = mockRequest("198.51.100.77", Map.of("X-Real-IP", "not-an-ip"));
        assertEquals("198.51.100.77", resolver.clientIp(site, requestInvalid));
    }

    @Test
    void defaultModeRespectsTrustedProxyConfiguration() {
        GeoLocationResolver resolver = new GeoLocationResolver(true, "192.0.2.0/24");
        Site site = new Site();
        site.ipLookupMode = "DEFAULT";

        // Untrusted peer -> ignore CF-Connecting-IP
        HttpServerRequest untrusted = mockRequest("198.51.100.5", Map.of("CF-Connecting-IP", "203.0.113.10"));
        assertEquals("198.51.100.5", resolver.clientIp(site, untrusted));

        // Trusted proxy -> use CF-Connecting-IP
        HttpServerRequest trusted = mockRequest("192.0.2.18", Map.of("CF-Connecting-IP", "203.0.113.10"));
        assertEquals("203.0.113.10", resolver.clientIp(site, trusted));
    }

    @Test
    void configuredAndFallsBackToIpLookupUsingSiteIpMode() {
        IpGeoLookupGateway gateway = ip -> {
            if ("114.114.114.114".equals(ip)) {
                return IpGeoLookupGateway.LookupResult.found(
                        new GeoLocationResolver.Location("CN", "AS", null, "江苏省", "南京市", null));
            }
            if ("1.1.1.1".equals(ip)) {
                return IpGeoLookupGateway.LookupResult.found(
                        new GeoLocationResolver.Location("AU", "OC", null, "Queensland", "Brisbane", null));
            }
            return IpGeoLookupGateway.LookupResult.notFound();
        };
        IpGeoLookupService lookupService =
                new IpGeoLookupService(gateway, null, new ObjectMapper(), true, "community", 3600, 300);
        GeoLocationResolver resolver = new GeoLocationResolver(false, "", lookupService);

        assertTrue(resolver.configured());

        Site headerSite = new Site();
        headerSite.ipLookupMode = "HEADER";
        headerSite.ipLookupHeader = "X-Forwarded-For";
        HttpServerRequest headerRequest =
                mockRequest("10.0.0.1", Map.of("X-Forwarded-For", "114.114.114.114, 10.0.0.2"));
        GeoLocationResolver.Location headerLocation = resolver.resolve(headerSite, headerRequest);
        assertEquals("CN", headerLocation.countryCode());
        assertEquals("南京市", headerLocation.city());

        Site networkSite = new Site();
        networkSite.ipLookupMode = "NETWORK";
        HttpServerRequest networkRequest = mockRequest("1.1.1.1", Map.of("X-Forwarded-For", "114.114.114.114"));
        GeoLocationResolver.Location networkLocation = resolver.resolve(networkSite, networkRequest);
        assertEquals("AU", networkLocation.countryCode());
        assertEquals("Brisbane", networkLocation.city());
    }

    private HttpServerRequest mockRequest(String remoteHost, Map<String, String> headers) {
        SocketAddress socketAddress = SocketAddress.inetSocketAddress(12345, remoteHost);
        return (HttpServerRequest) Proxy.newProxyInstance(
                HttpServerRequest.class.getClassLoader(),
                new Class<?>[] {HttpServerRequest.class},
                (proxy, method, args) -> {
                    if ("remoteAddress".equals(method.getName())) return socketAddress;
                    if ("getHeader".equals(method.getName()) && args != null && args.length == 1) {
                        String name = (String) args[0];
                        return headers.entrySet().stream()
                                .filter(e -> e.getKey().equalsIgnoreCase(name))
                                .map(Map.Entry::getValue)
                                .findFirst()
                                .orElse(null);
                    }
                    return null;
                });
    }
}
