package medify.backend.api.device;

import medify.backend.api.service.DeviceService;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.web.util.UriComponentsBuilder;
import java.util.Map;

/**
 * Authenticates a device before its WebSocket connection is accepted.
 * The device presents deviceId + token as query params (Arduino WebSocket
 * clients generally can't set arbitrary headers, so query params it is).
 */
@Component
public class DeviceAuthHandshakeInterceptor implements HandshakeInterceptor {

    public static final String DEVICE_KEY_ATTR = "deviceKey";

    private final DeviceService deviceService;

    public DeviceAuthHandshakeInterceptor(DeviceService deviceService) {
        this.deviceService = deviceService;
    }

    @Override
    public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                    WebSocketHandler wsHandler, Map<String, Object> attributes) {
        var params = UriComponentsBuilder.fromUri(request.getURI()).build().getQueryParams();
        String deviceKey = params.getFirst("deviceId");
        String token = params.getFirst("token");

        if (deviceKey == null || token == null) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }

        boolean authenticated = deviceService.authenticate(deviceKey, token).isPresent();
        if (!authenticated) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }

        attributes.put(DEVICE_KEY_ATTR, deviceKey);
        return true;
    }

    @Override
    public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                WebSocketHandler wsHandler, Exception exception) {
        // no-op
    }
}
