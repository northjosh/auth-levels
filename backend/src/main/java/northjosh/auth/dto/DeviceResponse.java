package northjosh.auth.dto;

import lombok.Data;

@Data
public class DeviceResponse {
	private String deviceId;
	private String name;
	private String platform;
	private String deviceType;
	private String status;
	private String appVersion;
	private String fcmToken;
	private boolean pushEnabled;
}
