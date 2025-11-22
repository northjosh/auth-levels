package northjosh.auth.dto.response;

import java.time.LocalDateTime;
import lombok.Data;

@Data
public class PushAuthDto {
	private String requestId;
	private String email;
	private LocalDateTime createdAt;
}
