package northjosh.auth.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;
import lombok.Data;
import northjosh.auth.repo.pushauth.ClientInfo;

@Data
public class PushAuthDto {
	private String id;

	@JsonProperty("client")
	private ClientInfo clientInfo;

	private LocalDateTime createdAt;
	private LocalDateTime expiresAt;
}
