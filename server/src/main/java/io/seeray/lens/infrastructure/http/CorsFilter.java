package io.seeray.lens.infrastructure.http;

import io.quarkus.vertx.http.runtime.filters.Filters;
import io.vertx.core.http.HttpHeaders;
import io.vertx.core.http.HttpMethod;
import io.vertx.core.http.HttpServerRequest;
import io.vertx.core.http.HttpServerResponse;
import io.vertx.ext.web.RoutingContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;

/**
 * Custom CORS filter that disables restrictive cross-origin controls for public,
 * non-sensitive assets (such as recorder.js, tracker.js, consent.js, styles, and maps)
 * by exposing them with {@code Access-Control-Allow-Origin: *} and without credentials,
 * allowing CDN edge caching without cross-origin cache pollution.
 *
 * For all other requests that carry dynamic CORS origins, it ensures {@code Vary: Origin}
 * is included so intermediate proxies and browsers cache responses strictly per-origin.
 */
@ApplicationScoped
public class CorsFilter {

    private static final int FILTER_PRIORITY = 1000;

    void init(@Observes Filters filters) {
        filters.register(this::handle, FILTER_PRIORITY);
    }

    void handle(RoutingContext context) {
        HttpServerRequest request = context.request();
        HttpServerResponse response = context.response();
        String path = request.path();

        if (isPublicAsset(path)) {
            // Handle preflight OPTIONS immediately for public static assets
            if (HttpMethod.OPTIONS.equals(request.method())) {
                response.setStatusCode(204)
                        .putHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                        .putHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS")
                        .putHeader(HttpHeaders.ACCESS_CONTROL_ALLOW_HEADERS, "*")
                        .putHeader(HttpHeaders.ACCESS_CONTROL_MAX_AGE, "86400")
                        .end();
                return;
            }

            // For GET/HEAD requests to public static assets: allow wildcard origin without credentials
            response.headersEndHandler(v -> {
                response.headers().set(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, "*");
                response.headers().remove(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS);
                response.headers().set(HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS");
            });
            context.next();
            return;
        }

        // For all other endpoints (APIs/collector/auth):
        // If Quarkus CORS filter dynamically sets Access-Control-Allow-Origin, ensure Vary: Origin is present.
        response.headersEndHandler(v -> {
            String allowOrigin = response.headers().get(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN);
            if (allowOrigin != null && !"*".equals(allowOrigin)) {
                String vary = response.headers().get(HttpHeaders.VARY);
                if (vary == null) {
                    response.headers().set(HttpHeaders.VARY, "Origin");
                } else if (!containsHeaderToken(vary, "Origin")) {
                    response.headers().set(HttpHeaders.VARY, vary + ", Origin");
                }
            }
        });

        context.next();
    }

    private boolean isPublicAsset(String path) {
        if (path == null) {
            return false;
        }
        if (path.equals("/recorder.js")
                || path.equals("/tracker.js")
                || path.equals("/consent.js")
                || path.startsWith("/privacy/")
                || path.equals("/heatmap-fixture.html")
                || path.equals("/favicon.ico")) {
            return true;
        }
        return path.endsWith(".js")
                || path.endsWith(".js.map")
                || path.endsWith(".css")
                || path.endsWith(".css.map")
                || path.endsWith(".svg")
                || path.endsWith(".png")
                || path.endsWith(".ico")
                || path.endsWith(".woff")
                || path.endsWith(".woff2");
    }

    private boolean containsHeaderToken(String headerValue, String token) {
        for (String part : headerValue.split(",")) {
            if (part.trim().equalsIgnoreCase(token)) {
                return true;
            }
        }
        return false;
    }
}
