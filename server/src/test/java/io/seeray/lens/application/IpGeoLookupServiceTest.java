package io.seeray.lens.application;

import static org.junit.jupiter.api.Assertions.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

class IpGeoLookupServiceTest {
    @Test
    void filtersNonPublicIpAddresses() {
        assertFalse(IpGeoLookupService.isPublicIp(null));
        assertFalse(IpGeoLookupService.isPublicIp(""));
        assertFalse(IpGeoLookupService.isPublicIp("127.0.0.1"));
        assertFalse(IpGeoLookupService.isPublicIp("10.0.0.1"));
        assertFalse(IpGeoLookupService.isPublicIp("172.16.0.1"));
        assertFalse(IpGeoLookupService.isPublicIp("192.168.1.1"));
        assertFalse(IpGeoLookupService.isPublicIp("100.64.0.1"));
        assertFalse(IpGeoLookupService.isPublicIp("203.0.113.10"));
        assertFalse(IpGeoLookupService.isPublicIp("::1"));
        assertFalse(IpGeoLookupService.isPublicIp("fc00::1"));

        assertTrue(IpGeoLookupService.isPublicIp("1.1.1.1"));
        assertTrue(IpGeoLookupService.isPublicIp("114.114.114.114"));
        assertTrue(IpGeoLookupService.isPublicIp("2400:3200::1"));
    }

    @Test
    void cachesFoundAndNotFoundResultsAndDeduplicatesBatchRequests() {
        AtomicInteger calls = new AtomicInteger();
        IpGeoLookupGateway gateway = ip -> {
            calls.incrementAndGet();
            if ("1.1.1.1".equals(ip)) {
                return IpGeoLookupGateway.LookupResult.found(
                        new GeoLocationResolver.Location("AU", "OC", null, "Queensland", "Brisbane", null));
            }
            if ("8.8.8.8".equals(ip)) {
                return IpGeoLookupGateway.LookupResult.notFound();
            }
            return IpGeoLookupGateway.LookupResult.error();
        };

        IpGeoLookupService service =
                new IpGeoLookupService(gateway, null, new ObjectMapper(), true, "community", 3600, 300);

        GeoLocationResolver.Location first = service.lookup("1.1.1.1");
        GeoLocationResolver.Location second = service.lookup("1.1.1.1");
        assertEquals("AU", first.countryCode());
        assertEquals("Brisbane", second.city());
        assertEquals(1, calls.get());

        assertTrue(service.lookup("8.8.8.8").isEmpty());
        assertTrue(service.lookup("8.8.8.8").isEmpty());
        assertEquals(2, calls.get());

        // Non-public IP does not hit gateway.
        assertTrue(service.lookup("127.0.0.1").isEmpty());
        assertEquals(2, calls.get());

        // Error response degrades gracefully to empty.
        assertTrue(service.lookup("9.9.9.9").isEmpty());

        Map<String, GeoLocationResolver.Location> batch =
                service.lookupBatch(List.of("1.1.1.1", "1.1.1.1", "127.0.0.1", "8.8.8.8"));
        assertEquals(1, batch.size());
        assertEquals("Brisbane", batch.get("1.1.1.1").city());
    }

    @Test
    void disabledServiceNeverInvokesGateway() {
        AtomicInteger calls = new AtomicInteger();
        IpGeoLookupGateway gateway = ip -> {
            calls.incrementAndGet();
            return IpGeoLookupGateway.LookupResult.found(
                    new GeoLocationResolver.Location("AU", "OC", null, "Queensland", "Brisbane", null));
        };
        IpGeoLookupService service =
                new IpGeoLookupService(gateway, null, new ObjectMapper(), false, "community", 3600, 300);

        assertTrue(service.lookup("1.1.1.1").isEmpty());
        assertTrue(service.lookupBatch(List.of("1.1.1.1")).isEmpty());
        assertEquals(0, calls.get());
    }
}
