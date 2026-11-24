package io.seeray.lens.infrastructure.geo;

import static org.junit.jupiter.api.Assertions.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import io.seeray.lens.application.IpGeoLookupGateway;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class IpNestGeoLookupHttpGatewayTest {
    private HttpServer server;
    private String baseUrl;
    private final AtomicReference<String> lastQuery = new AtomicReference<>();
    private final AtomicInteger statusCode = new AtomicInteger(200);
    private final AtomicReference<String> responseBody = new AtomicReference<>("");

    @BeforeEach
    void setUp() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/api/v1/lookup", exchange -> {
            lastQuery.set(exchange.getRequestURI().getRawQuery());
            byte[] payload = responseBody.get().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(statusCode.get(), payload.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(payload);
            }
        });
        server.start();
        baseUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/api/v1/lookup";
    }

    @AfterEach
    void tearDown() {
        if (server != null) server.stop(0);
    }

    @Test
    void parsesPublicIpv4ResponseAndDerivesContinent() {
        responseBody.set(
                """
                {"code":0,"message":"success","data":{"ip":"1.1.1.1","ip_version":4,"found":true,"scope":"public","continent":null,"country":"Australia","region":"Queensland","city":"Brisbane","district":null,"isp":null,"country_code":"AU","time_zone":null}}
                """);
        IpNestGeoLookupHttpGateway gateway =
                new IpNestGeoLookupHttpGateway(new ObjectMapper(), baseUrl, "community", 1500);

        IpGeoLookupGateway.LookupResult result = gateway.lookup("1.1.1.1");
        assertEquals(IpGeoLookupGateway.Status.FOUND, result.status());
        assertEquals("ip=1.1.1.1&dataset=community", lastQuery.get());
        assertEquals("AU", result.location().countryCode());
        assertEquals("OC", result.location().continentCode());
        assertEquals("Queensland", result.location().region());
        assertEquals("Brisbane", result.location().city());
        assertNull(result.location().timezone());
    }

    @Test
    void parsesChineseIpv4AndIpv6Responses() {
        responseBody.set(
                """
                {"code":0,"message":"success","data":{"ip":"114.114.114.114","ip_version":4,"found":true,"scope":"public","continent":null,"country":"中国","region":"江苏省","city":"南京市","country_code":"CN","time_zone":"Asia/Shanghai"}}
                """);
        IpNestGeoLookupHttpGateway gateway =
                new IpNestGeoLookupHttpGateway(new ObjectMapper(), baseUrl, "community", 1500);

        IpGeoLookupGateway.LookupResult ipv4 = gateway.lookup("114.114.114.114");
        assertEquals(IpGeoLookupGateway.Status.FOUND, ipv4.status());
        assertEquals("CN", ipv4.location().countryCode());
        assertEquals("AS", ipv4.location().continentCode());
        assertEquals("江苏省", ipv4.location().region());
        assertEquals("南京市", ipv4.location().city());
        assertEquals("Asia/Shanghai", ipv4.location().timezone());

        responseBody.set(
                """
                {"code":0,"message":"success","data":{"ip":"2400:3200::1","ip_version":6,"found":true,"scope":"public","continent":null,"country":"中国","region":"浙江省","city":"杭州市","country_code":"CN"}}
                """);
        IpGeoLookupGateway.LookupResult ipv6 = gateway.lookup("2400:3200::1");
        assertEquals(IpGeoLookupGateway.Status.FOUND, ipv6.status());
        assertEquals("ip=2400%3A3200%3A%3A1&dataset=community", lastQuery.get());
        assertEquals("CN", ipv6.location().countryCode());
        assertEquals("浙江省", ipv6.location().region());
        assertEquals("杭州市", ipv6.location().city());
    }

    @Test
    void returnsNotFoundWhenDatasetDoesNotMatchIp() {
        responseBody.set(
                """
                {"code":0,"message":"success","data":{"ip":"127.0.0.1","ip_version":4,"found":false,"scope":"special","country":null,"region":null,"city":null,"country_code":null}}
                """);
        IpNestGeoLookupHttpGateway gateway =
                new IpNestGeoLookupHttpGateway(new ObjectMapper(), baseUrl, "community", 1500);

        IpGeoLookupGateway.LookupResult result = gateway.lookup("127.0.0.1");
        assertEquals(IpGeoLookupGateway.Status.NOT_FOUND, result.status());
        assertTrue(result.location().isEmpty());
    }

    @Test
    void returnsErrorOnServerFailureOrInvalidJson() {
        IpNestGeoLookupHttpGateway gateway =
                new IpNestGeoLookupHttpGateway(new ObjectMapper(), baseUrl, "community", 1500);

        statusCode.set(500);
        responseBody.set("error");
        assertEquals(IpGeoLookupGateway.Status.ERROR, gateway.lookup("1.1.1.1").status());

        statusCode.set(200);
        responseBody.set("{not-json");
        assertEquals(IpGeoLookupGateway.Status.ERROR, gateway.lookup("1.1.1.1").status());
    }
}
