package io.seeray.lens.application;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.sql.*;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import javax.sql.DataSource;

/** Reads privacy-safe browser fingerprint risk summaries without exposing the key. */
@ApplicationScoped
public class FingerprintRiskService {
    private final DataSource dataSource;

    @Inject
    public FingerprintRiskService(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public Risk risk(UUID siteId, String visitorId) {
        if (siteId == null || visitorId == null || visitorId.isBlank()) return Risk.none();
        String sql =
                """
                with current_keys as (
                  select distinct fingerprint_type,fingerprint_key from fingerprint_observation o
                  join site s on s.id=o.site_id and s.fingerprint_risk_enabled
                  where o.site_id=? and o.client_visitor_id=?
                ), related as (
                  select o.client_visitor_id,o.user_id_hash,o.observed_at,o.fingerprint_type
                  from fingerprint_observation o join current_keys k using(fingerprint_type,fingerprint_key)
                  where o.site_id=?
                )
                select count(distinct client_visitor_id) filter (where client_visitor_id<>?),
                       count(distinct user_id_hash) filter (where user_id_hash is not null),
                       max(observed_at),
                       bool_or(fingerprint_type='browser') filter (where client_visitor_id<>?),
                       bool_or(fingerprint_type='ja4') filter (where client_visitor_id<>?)
                from related
                """;
        try (Connection connection = dataSource.getConnection();
                PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setObject(1, siteId);
            statement.setString(2, visitorId);
            statement.setObject(3, siteId);
            statement.setString(4, visitorId);
            statement.setString(5, visitorId);
            statement.setString(6, visitorId);
            try (ResultSet rows = statement.executeQuery()) {
                if (!rows.next()) return Risk.none();
                int visitors = rows.getInt(1);
                int accounts = rows.getInt(2);
                Timestamp last = rows.getTimestamp(3);
                boolean browser = rows.getBoolean(4);
                boolean ja4 = rows.getBoolean(5);
                List<String> evidence = java.util.stream.Stream.of(browser ? "browser" : null, ja4 ? "ja4" : null)
                        .filter(java.util.Objects::nonNull)
                        .toList();
                String level = accounts > 1 ? "multiple_accounts" : visitors > 0 ? "possible_related_client" : "none";
                String confidence = visitors == 0 && accounts == 0 ? "none" : browser ? "medium" : "low";
                return new Risk(
                        level, visitors, accounts, last == null ? null : last.toInstant(), confidence, evidence);
            }
        } catch (SQLException error) {
            throw new IllegalStateException("Could not query fingerprint risk", error);
        }
    }

    public record Risk(
            String level,
            int relatedVisitorCount,
            int relatedAccountCount,
            Instant lastObservedAt,
            String confidence,
            List<String> evidenceTypes) {
        static Risk none() {
            return new Risk("none", 0, 0, null, "none", List.of());
        }
    }
}
