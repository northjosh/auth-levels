package northjosh.auth.services.devices;

import jakarta.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.PairDeviceDto;
import northjosh.auth.dto.PairDeviceResponse;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.repo.device.TrustedDeviceRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.user.UserService;
import northjosh.auth.util.DeviceUtils;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class TrustedDeviceService {

	private final UserService userService;
	private final TrustedDeviceRepo repo;

	public TrustedDeviceService(UserService userService, TrustedDeviceRepo trustedDeviceRepo) {
		this.userService = userService;
		this.repo = trustedDeviceRepo;
	}

	@Transactional
	public Map<String, String> enroll(String email) {
		User user = userService.get(email);
		String token = DeviceUtils.generateDeviceToken();

		TrustedDevice trustedDevice = TrustedDevice.builder()
				.user(user)
				.enrollmentToken(token)
				.status(TrustedDevice.Status.PENDING)
				.enrollmentExpiresAt(LocalDateTime.now().plusMinutes(2))
				.build();

		repo.save(trustedDevice);

		return Map.of(
				"enrollmentToken",
				token,
				"expiresAt",
				LocalDateTime.now().plusHours(1).toString());
	}

	@Transactional
	public PairDeviceResponse pair(PairDeviceDto dto) {
		String deviceToken = DeviceUtils.generateDeviceToken();

		TrustedDevice device = repo.findById(dto.getEnrollmentToken())
				.orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "Device Not Found"));

		if (device.getEnrollmentExpiresAt().isBefore(LocalDateTime.now().plusMinutes(2))) {
			throw new AuthException(HttpStatus.FORBIDDEN, "Device Expired");
		}

		if(device.getPairedAt() != null) {
			throw new AuthException(HttpStatus.CONFLICT, "Device Already Paired");
		}

		device.setStatus(TrustedDevice.Status.ACTIVE);
		device.setAppVersion(dto.getAppVersion());
		device.setFcmToken(dto.getFcmToken());
		device.setEnrollmentToken(null);
		device.setDeviceTokenHash(DeviceUtils.hash256(deviceToken));
		device.setName(dto.getName());
		device.setPlatform(dto.getPlatform());
		device.setLastSeenAt(LocalDateTime.now());
		device.setPairedAt(LocalDateTime.now());

		repo.save(device);
		return new PairDeviceResponse(
				device.getId(),
				deviceToken,
				new PairDeviceResponse.DeviceUser(
						device.getUser().getFirstName(), device.getUser().getEmail()));
	}

	public List<TrustedDevice> getDevicesForUser(String email) {
		return repo.findAllByUser_Email(email);
	}

	public List<TrustedDevice> getActiveDevicesForUser(String email) {
		return repo.findAllByUser_EmailAndStatusIs(email, TrustedDevice.Status.ACTIVE);
	}

	public int togglePush(String id) {
		return repo.togglePushEnabled(id);
	}

	public int updateFcm(String id, String token) {
		return repo.updateFcm(id, token);
	}

	@Transactional
	public void unpair(String deviceId) {
		repo.deleteById(deviceId);
	}

	@Transactional
	public void unpairSelf(String tokenHash) {
		repo.deleteByDeviceTokenHash(tokenHash);
	}

	@Scheduled(fixedRate = 2000)
	private void removeExpiredDevices() {
		LocalDateTime cutoff = LocalDateTime.now().plusMinutes(2);
		int count = repo.deleteByEnrollmentExpiresAtBeforeAndStatus(cutoff, TrustedDevice.Status.PENDING);
		log.info("Removed expired devices: {}", count);
	}
}
