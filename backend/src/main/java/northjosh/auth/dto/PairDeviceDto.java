package northjosh.auth.dto;

import lombok.Data;
import northjosh.auth.repo.device.TrustedDevice;

@Data
public class PairDeviceDto {

	private String enrollmentToken;
	private String fcmToken;
	private String name;
	// add an enum converter
	private TrustedDevice.Platform platform;
	private String appVersion;
}
