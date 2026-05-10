package medify.backend.api.controller;

import medify.backend.api.service.NotificationLogService;
import medify.backend.domain.model.NotificationLog;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/notifications-log")
@CrossOrigin(origins = "*")
public class NotificationLogController {

    private final NotificationLogService service;

    public NotificationLogController(NotificationLogService service) {
        this.service = service;
    }

    @GetMapping
    public List<NotificationLog> getLog(
            @RequestParam("userId") Long userId,
            @RequestParam(value = "from", required = false)
                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(value = "to", required = false)
                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        return service.getByUserIdAndRange(userId, from, to);
    }
}
