package northjosh.auth.event;

import java.time.Instant;
import java.util.Map;
import lombok.Data;
import northjosh.auth.repo.event.SecurityEvent;

@Data
public class ActivityEvent {
	private String email;
	private String deviceId;
	private String userAgentFamily;
	private String osFamily;
	private String deviceFamily;
	private String remoteAddress;
	private Map<String, String> details;
	private SecurityEvent.ActivityType type;
	private SecurityEvent.Method method;
	private Instant occurredAt;
}
