package northjosh.auth.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import northjosh.auth.repo.pushauth.ClientInfo;

@Data
public class PushAuthDto {
	private String id;
	private String requestId;

	@JsonProperty("client")
	private ClientInfo clientInfo;

	private String createdAt;
	private String expiresAt;
}
