package northjosh.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class TrustedDeviceDto {
	@JsonProperty("deviceId")
	private String id;

	private String name;
	private String platform;
	private String deviceType;
	private String status;
	private String pairedAt;
	private String lastSeenAt;
	private String appVersion;
	private boolean pushEnabled;
}
