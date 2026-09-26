package northjosh.auth.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.validation.constraints.AssertFalse;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.Base64;
import lombok.AllArgsConstructor;
import lombok.Data;
import northjosh.auth.repo.event.SecurityEvent;
import org.springframework.format.annotation.DateTimeFormat;

@Data
public class CursorPageable {
	private SecurityEvent.Method method;
	private SecurityEvent.ActivityType type;
	private String osFamily;
	private String deviceFamily;
	private String remoteAddress;

	@DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
	private OffsetDateTime from;

	@DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
	private OffsetDateTime to;

	private String query;
	private String prev;
	private String next;
	private int size = 20;

	@JsonIgnore
	@AssertFalse(message = "Set either next or previous, or none. You cannot set both") public boolean eitherNextOrPrev() {
		return next != null && !next.isBlank() && prev != null && !prev.isBlank();
	}

	@JsonIgnore
	@AssertFalse(message = "You can only request up to 50 rows at a time") public boolean isLimit() {
		return size > 50;
	}

	public static String encode(Instant createdAt, String id) {
		String raw = createdAt.toString() + "|" + id;
		return Base64.getEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
	}

	public static DecodedCursor decode(String cursor) {
		String raw = new String(Base64.getDecoder().decode(cursor), StandardCharsets.UTF_8);
		String[] parts = raw.split("\\|", 2);

		return new DecodedCursor(Instant.parse(parts[0]), parts[1]);
	}

	@Data
	@AllArgsConstructor
	public static class DecodedCursor {
		private Instant createdAt;
		private String id;
	}
}
