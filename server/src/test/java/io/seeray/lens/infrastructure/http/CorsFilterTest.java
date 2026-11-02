package io.seeray.lens.infrastructure.http;

import static org.junit.jupiter.api.Assertions.*;

import io.vertx.core.Handler;
import io.vertx.core.MultiMap;
import io.vertx.core.http.HttpHeaders;
import io.vertx.core.http.HttpMethod;
import io.vertx.core.http.HttpServerRequest;
import io.vertx.core.http.HttpServerResponse;
import io.vertx.core.http.impl.headers.HeadersMultiMap;
import io.vertx.ext.web.RoutingContext;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class CorsFilterTest {

    private CorsFilter filter;
    private MultiMap responseHeaders;
    private int statusCode;
    private boolean responseEnded;
    private boolean nextCalled;
    private HttpMethod requestMethod;
    private String requestPath;
    private final List<Handler<Void>> headersEndHandlers = new ArrayList<>();

    @BeforeEach
    void setUp() {
        filter = new CorsFilter();
        responseHeaders = new HeadersMultiMap();
        statusCode = 200;
        responseEnded = false;
        nextCalled = false;
        requestMethod = HttpMethod.GET;
        requestPath = "/";
        headersEndHandlers.clear();
    }

    private RoutingContext createRoutingContext() {
        HttpServerRequest request = (HttpServerRequest) Proxy.newProxyInstance(
                HttpServerRequest.class.getClassLoader(),
                new Class<?>[] {HttpServerRequest.class},
                (proxy, method, args) -> {
                    String name = method.getName();
                    if ("path".equals(name)) return requestPath;
                    if ("method".equals(name)) return requestMethod;
                    return null;
                });

        HttpServerResponse response = (HttpServerResponse) Proxy.newProxyInstance(
                HttpServerResponse.class.getClassLoader(),
                new Class<?>[] {HttpServerResponse.class},
                (proxy, method, args) -> {
                    String name = method.getName();
                    if ("headers".equals(name)) return responseHeaders;
                    if ("setStatusCode".equals(name)) {
                        statusCode = (int) args[0];
                        return proxy;
                    }
                    if ("putHeader".equals(name)) {
                        responseHeaders.set(args[0].toString(), args[1].toString());
                        return proxy;
                    }
                    if ("headersEndHandler".equals(name)) {
                        @SuppressWarnings("unchecked")
                        Handler<Void> h = (Handler<Void>) args[0];
                        headersEndHandlers.add(h);
                        return proxy;
                    }
                    if ("end".equals(name)) {
                        responseEnded = true;
                        return null;
                    }
                    return null;
                });

        return (RoutingContext) Proxy.newProxyInstance(
                RoutingContext.class.getClassLoader(), new Class<?>[] {RoutingContext.class}, (proxy, method, args) -> {
                    String name = method.getName();
                    if ("request".equals(name)) return request;
                    if ("response".equals(name)) return response;
                    if ("next".equals(name)) {
                        nextCalled = true;
                        return null;
                    }
                    return null;
                });
    }

    private void triggerHeadersEndHandlers() {
        for (Handler<Void> h : headersEndHandlers) {
            h.handle(null);
        }
    }

    @Test
    void optionsPreflightOnPublicAssetReturns204WithWildcardOrigin() {
        requestPath = "/recorder.js";
        requestMethod = HttpMethod.OPTIONS;

        filter.handle(createRoutingContext());

        assertEquals(204, statusCode);
        assertTrue(responseEnded);
        assertFalse(nextCalled);
        assertEquals("*", responseHeaders.get(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
        assertEquals("GET, HEAD, OPTIONS", responseHeaders.get(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS));
        assertEquals("86400", responseHeaders.get(HttpHeaders.ACCESS_CONTROL_MAX_AGE));
    }

    @Test
    void getPublicAssetSetsWildcardOriginAndRemovesCredentials() {
        requestPath = "/recorder.js";
        requestMethod = HttpMethod.GET;

        responseHeaders.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "https://geekcorelab.com");
        responseHeaders.set(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS, "true");

        filter.handle(createRoutingContext());

        assertTrue(nextCalled);
        assertFalse(responseEnded);

        triggerHeadersEndHandlers();

        assertEquals("*", responseHeaders.get(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
        assertNull(responseHeaders.get(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS));
        assertEquals("GET, HEAD, OPTIONS", responseHeaders.get(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS));
    }

    @Test
    void nonPublicApiWithDynamicOriginAddsVaryOriginHeader() {
        requestPath = "/api/v1/auth/login";
        requestMethod = HttpMethod.POST;

        responseHeaders.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "https://geekcorelab.com");
        responseHeaders.set(HttpHeaders.VARY, "Accept-Encoding");

        filter.handle(createRoutingContext());

        assertTrue(nextCalled);

        triggerHeadersEndHandlers();

        assertEquals("https://geekcorelab.com", responseHeaders.get(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
        assertEquals("Accept-Encoding, Origin", responseHeaders.get(HttpHeaders.VARY));
    }

    @Test
    void nonPublicApiWithNoVarySetsVaryOrigin() {
        requestPath = "/api/v1/sites";
        requestMethod = HttpMethod.GET;

        responseHeaders.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "https://www.geekcorelab.cn");

        filter.handle(createRoutingContext());

        assertTrue(nextCalled);

        triggerHeadersEndHandlers();

        assertEquals("Origin", responseHeaders.get(HttpHeaders.VARY));
    }

    @Test
    void nonPublicApiAlreadyHavingVaryOriginDoesNotDuplicate() {
        requestPath = "/api/v1/sites";
        requestMethod = HttpMethod.GET;

        responseHeaders.set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "https://www.geekcorelab.cn");
        responseHeaders.set(HttpHeaders.VARY, "Origin, Accept-Encoding");

        filter.handle(createRoutingContext());

        assertTrue(nextCalled);

        triggerHeadersEndHandlers();

        assertEquals("Origin, Accept-Encoding", responseHeaders.get(HttpHeaders.VARY));
    }
}
