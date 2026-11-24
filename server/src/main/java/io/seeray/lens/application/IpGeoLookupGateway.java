package io.seeray.lens.application;

/** Gateway for resolving coarse geolocation metadata from an IP address via an external lookup provider. */
public interface IpGeoLookupGateway {
    LookupResult lookup(String ip);

    enum Status {
        FOUND,
        NOT_FOUND,
        ERROR
    }

    record LookupResult(Status status, GeoLocationResolver.Location location) {
        public static LookupResult found(GeoLocationResolver.Location location) {
            return new LookupResult(Status.FOUND, location);
        }

        public static LookupResult notFound() {
            return new LookupResult(Status.NOT_FOUND, GeoLocationResolver.Location.empty());
        }

        public static LookupResult error() {
            return new LookupResult(Status.ERROR, GeoLocationResolver.Location.empty());
        }
    }
}
