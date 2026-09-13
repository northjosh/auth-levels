package northjosh.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class PairDeviceResponse {
	private String deviceId;
	private String deviceToken;
	private DeviceUser user;

	@Data
	@AllArgsConstructor
	public static class DeviceUser {
		private String fullName;
		private String email;
	}
}
