package medify.backend.api.config;

import medify.backend.api.device.DeviceAuthHandshakeInterceptor;
import medify.backend.api.device.DeviceWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final DeviceWebSocketHandler deviceWebSocketHandler;
    private final DeviceAuthHandshakeInterceptor deviceAuthHandshakeInterceptor;

    public WebSocketConfig(DeviceWebSocketHandler deviceWebSocketHandler,
                            DeviceAuthHandshakeInterceptor deviceAuthHandshakeInterceptor) {
        this.deviceWebSocketHandler = deviceWebSocketHandler;
        this.deviceAuthHandshakeInterceptor = deviceAuthHandshakeInterceptor;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(deviceWebSocketHandler, "/ws/device")
                .addInterceptors(deviceAuthHandshakeInterceptor)
                .setAllowedOrigins("*");
    }
}
