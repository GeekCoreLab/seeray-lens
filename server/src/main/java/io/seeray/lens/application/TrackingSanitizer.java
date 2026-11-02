package io.seeray.lens.application;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.runtime.annotations.RegisterForReflection;
import io.seeray.lens.domain.common.ControlPlaneException;
import java.net.IDN;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class TrackingSanitizer {
    private static final Pattern URL_PARSER = Pattern.compile(
            "^(?:([a-zA-Z][a-zA-Z0-9+.-]*)://)?([^/?#:]+)(?::(\\d+))?(/[^?#]*)?(?:\\?([^#]*))?(?:#(.*))?$");

    private static final Set<String> UTM =
            Set.of("utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content");
    private static final List<ClickParameter> AD_CLICK_PARAMETERS = List.of(
            new ClickParameter("gclid", "google_ads", "google", "paid_search"),
            new ClickParameter("wbraid", "google_ads", "google", "paid_search"),
            new ClickParameter("gbraid", "google_ads", "google", "paid_search"),
            new ClickParameter("dclid", "google_ads", "google", "paid_display"),
            new ClickParameter("msclkid", "microsoft_ads", "bing", "paid_search"),
            new ClickParameter("fbclid", "meta_ads", "facebook", "paid_social"),
            new ClickParameter("ttclid", "tiktok_ads", "tiktok", "paid_social"),
            new ClickParameter("li_fat_id", "linkedin_ads", "linkedin", "paid_social"),
            new ClickParameter("twclid", "x_ads", "x", "paid_social"));

    private TrackingSanitizer() {}

    public static CleanUrl referrer(String value, ObjectMapper mapper) {
        if (value == null || value.isBlank()) return null;
        try {
            CleanUrl clean = url(value, mapper);
            return clean.host() == null ? null : clean;
        } catch (Exception e) {
            return null;
        }
    }

    public static CleanUrl url(String value, ObjectMapper mapper) {
        return url(value, mapper, null);
    }

    public static CleanUrl url(String value, ObjectMapper mapper, String title) {
        return url(value, mapper, title, null);
    }

    public static CleanUrl url(String value, ObjectMapper mapper, String title, UUID siteId) {
        return url(value, mapper, title, siteId, null);
    }

    public static CleanUrl url(String value, ObjectMapper mapper, String title, UUID siteId, String baseOrigin) {
        String cleanTitle = cleanTitle(title);
        if (value == null || value.isBlank())
            return new CleanUrl(null, null, null, null, null, null, null, null, cleanTitle, null, null, null, null);
        try {
            String candidate = value.trim();
            if (candidate.startsWith("//")) {
                candidate = "https:" + candidate;
            } else if (candidate.startsWith("/") && baseOrigin != null && !baseOrigin.isBlank()) {
                String base = baseOrigin.trim().replaceAll("/+$", "");
                candidate = base + candidate;
            } else if (!candidate.contains("://") && baseOrigin != null && !baseOrigin.isBlank()) {
                String base = baseOrigin.trim().replaceAll("/+$", "");
                candidate = base + "/" + candidate;
            }

            String sanitized = sanitizeUriString(candidate);
            URI uri = null;
            try {
                uri = URI.create(sanitized);
            } catch (IllegalArgumentException ignored) {
            }

            String scheme = uri != null ? uri.getScheme() : null;
            String host = uri != null ? uri.getHost() : null;
            String path = uri != null ? uri.getPath() : null;
            String rawQuery = uri != null ? uri.getRawQuery() : null;

            if (host == null && uri != null && uri.getAuthority() != null) {
                String authority = uri.getAuthority();
                if (authority.contains("@")) authority = authority.substring(authority.indexOf("@") + 1);
                if (authority.contains(":")) authority = authority.substring(0, authority.indexOf(":"));
                if (!authority.isBlank()) host = authority;
            }

            if (host == null) {
                Matcher m = URL_PARSER.matcher(sanitized);
                if (m.matches()) {
                    if (scheme == null) scheme = m.group(1);
                    host = m.group(2);
                    if (path == null) path = m.group(4);
                    if (rawQuery == null) rawQuery = m.group(5);
                }
            }

            if (host == null && baseOrigin != null && !baseOrigin.isBlank()) {
                try {
                    URI baseUri = URI.create(sanitizeUriString(baseOrigin.trim()));
                    host = baseUri.getHost();
                    if (scheme == null) scheme = baseUri.getScheme();
                } catch (Exception ignored) {
                }
            }

            if (host == null) {
                throw new IllegalArgumentException("Host cannot be determined");
            }

            try {
                host = IDN.toASCII(host, IDN.USE_STD3_ASCII_RULES).toLowerCase(Locale.ROOT);
            } catch (Exception ignored) {
                host = host.toLowerCase(Locale.ROOT);
            }

            scheme = scheme != null ? scheme.toLowerCase(Locale.ROOT) : "https";
            path = path == null || path.isBlank() ? "/" : limit(path, 2048);

            Map<String, String> utm = new HashMap<>();
            Map<String, String> query = new HashMap<>();
            if (rawQuery != null && !rawQuery.isBlank()) {
                for (String part : rawQuery.split("&")) {
                    String[] pair = part.split("=", 2);
                    if (pair.length != 2) continue;
                    try {
                        String key = URLDecoder.decode(pair[0], StandardCharsets.UTF_8)
                                .toLowerCase(Locale.ROOT);
                        String decoded = URLDecoder.decode(pair[1], StandardCharsets.UTF_8);
                        if (UTM.contains(key)) utm.putIfAbsent(key, limit(decoded, 256));
                        else if (query.containsKey(key)
                                || AD_CLICK_PARAMETERS.stream()
                                        .anyMatch(click -> click.parameter().equals(key)))
                            query.putIfAbsent(key, decoded);
                    } catch (IllegalArgumentException ignored) {
                        // Ignore malformed percent encoding; unrelated query strings are discarded anyway.
                    }
                }
            }
            ClickParameter clickParameter = null;
            String clickId = null;
            for (ClickParameter candidateClick : AD_CLICK_PARAMETERS) {
                String candidateId = query.get(candidateClick.parameter());
                if (candidateId != null
                        && !candidateId.isBlank()
                        && candidateId.length() <= 512
                        && candidateId.chars().noneMatch(Character::isISOControl)) {
                    clickParameter = candidateClick;
                    clickId = candidateId;
                    break;
                }
            }
            String source = utm.get("utm_source");
            String medium = utm.get("utm_medium");
            if (clickParameter != null && source == null) source = clickParameter.source();
            if (clickParameter != null && medium == null) medium = clickParameter.medium();
            return new CleanUrl(
                    scheme,
                    host,
                    path,
                    source,
                    medium,
                    utm.get("utm_campaign"),
                    utm.get("utm_term"),
                    utm.get("utm_content"),
                    cleanTitle,
                    null,
                    null,
                    clickParameter == null ? null : clickParameter.platform(),
                    clickId == null ? null : TrackingIdentityHasher.hash(siteId, "ad-click:" + clickId));
        } catch (Exception e) {
            throw new ControlPlaneException(400, "INVALID_EVENT_URL", "Event URL is invalid");
        }
    }

    private static String sanitizeUriString(String raw) {
        if (raw == null) return null;
        String s = raw.trim().replaceAll("[\\p{Cc}]", "");
        return s.replace(" ", "%20")
                .replace("\"", "%22")
                .replace("<", "%3C")
                .replace(">", "%3E")
                .replace("^", "%5E")
                .replace("`", "%60")
                .replace("{", "%7B")
                .replace("}", "%7D")
                .replace("|", "%7C")
                .replace("\\", "%5C");
    }

    /** Crash reports intentionally discard query parameters, titles, and UTM values. */
    public static CleanUrl crashUrl(String value, ObjectMapper mapper) {
        return crashUrl(value, mapper, null);
    }

    public static CleanUrl crashUrl(String value, ObjectMapper mapper, String baseOrigin) {
        CleanUrl clean = url(value, mapper, null, null, baseOrigin);
        return new CleanUrl(
                clean.scheme(),
                clean.host(),
                safeCrashPath(clean.path()),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null);
    }

    /** Removes common identifiers from route and script paths before storing crash diagnostics. */
    public static String safeCrashPath(String value) {
        if (value == null || value.isBlank()) return "/";
        String path = value.replaceAll("[\\p{Cc}]", "").replace('\\', '/').split("[?#]", 2)[0];
        if (path.matches("(?i)^[a-z][a-z0-9+.-]*://.*")) {
            try {
                path = URI.create(path).getPath();
            } catch (Exception ignored) {
                return "/";
            }
        }
        if (path == null || path.isBlank()) return "/";
        if (!path.startsWith("/")) path = "/" + path;
        path = path.replaceAll("(?i)[\\w.+-]+@[\\w.-]+\\.[A-Za-z]{2,}", "<email>");
        path = path.replaceAll(
                "(?i)\\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\b", "<id>");
        path = path.replaceAll("(^|/)\\d{4,}(?=/|$)", "$1<id>");
        path = path.replaceAll("(^|/)[A-Za-z0-9_-]{32,}(?=/|$)", "$1<id>");
        return path.length() > 1024 ? path.substring(0, 1024) : path;
    }

    private static String cleanTitle(String value) {
        if (value == null || value.isBlank()) return null;
        String cleaned = value.strip().replaceAll("[\\p{Cc}]", "");
        return cleaned.isBlank() ? null : limit(cleaned, 512);
    }

    public static String json(Object value, ObjectMapper mapper) {
        try {
            if (value == null) return "{}";
            if (value instanceof com.fasterxml.jackson.databind.JsonNode node) {
                if (depth(node, 0) > 5 || node.isObject() && node.size() > 50) throw new IllegalArgumentException();
                return mapper.writeValueAsString(node);
            }
            com.fasterxml.jackson.databind.JsonNode node = mapper.valueToTree(value);
            if (depth(node, 0) > 5 || hasTooManyKeys(node)) throw new IllegalArgumentException();
            String json = mapper.writeValueAsString(node);
            if (json.length() > 16_384) throw new IllegalArgumentException();
            return json;
        } catch (JsonProcessingException | IllegalArgumentException e) {
            throw new ControlPlaneException(400, "INVALID_EVENT_DATA", "Event data is invalid");
        }
    }

    private static String limit(String s, int max) {
        if (s.length() > max) throw new IllegalArgumentException();
        return s;
    }

    private static int depth(com.fasterxml.jackson.databind.JsonNode n, int level) {
        int max = level;
        if (n.isContainerNode()) for (var child : n) max = Math.max(max, depth(child, level + 1));
        return max;
    }

    private static boolean hasTooManyKeys(com.fasterxml.jackson.databind.JsonNode n) {
        if (n.isObject() && n.size() > 50) return true;
        if (n.isContainerNode()) for (var child : n) if (hasTooManyKeys(child)) return true;
        return false;
    }

    @RegisterForReflection
    public record CleanUrl(
            String scheme,
            String host,
            String path,
            String source,
            String medium,
            String campaign,
            String term,
            String content,
            String title,
            String referrerScheme,
            String referrerHost,
            String adClickPlatform,
            String adClickIdHash) {}

    private record ClickParameter(String parameter, String platform, String source, String medium) {}
}
