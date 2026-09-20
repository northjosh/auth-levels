package northjosh.auth.services.devices;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
import org.springframework.transaction.annotation.Transactional;

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
				.enrollmentExpiresAt(Instant.now().plus(5, ChronoUnit.MINUTES))
				.build();

		repo.save(trustedDevice);
		log.info("Created device enrollment for user {}", email);

		return Map.of(
				"enrollmentToken",
				token,
				"expiresAt",
				trustedDevice.getEnrollmentExpiresAt().toString());
	}

	@Transactional
	public PairDeviceResponse pair(PairDeviceDto dto) {
		String deviceToken = DeviceUtils.generateDeviceToken();

		TrustedDevice device = repo.findByEnrollmentToken(dto.getEnrollmentToken())
				.orElseThrow(() -> new AuthException(HttpStatus.GONE, "Device Not Found"));

		if (device.getEnrollmentExpiresAt().isBefore(Instant.now())) {
			throw new AuthException(HttpStatus.GONE, "Device Expired", "enrollment_expired");
		}

		if (device.getPairedAt() != null) {
			throw new AuthException(HttpStatus.CONFLICT, "Device Already Paired", "already_paired");
		}

		device.setStatus(TrustedDevice.Status.ACTIVE);
		device.setAppVersion(dto.getAppVersion());
		device.setFcmToken(dto.getFcmToken());
		device.setEnrollmentToken(null);
		device.setDeviceTokenHash(DeviceUtils.hash256(deviceToken));
		device.setName(dto.getName());
		device.setPlatform(dto.getPlatform());
		device.setLastSeenAt(Instant.now());
		device.setPairedAt(Instant.now());

		repo.save(device);
		log.info(
				"Paired trusted device {} ({}) for user {}; FID present: {}",
				device.getId(),
				device.getName(),
				device.getUser().getEmail(),
				device.getFcmToken() != null);
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

	@Transactional
	public int togglePush(String id) {
		return repo.togglePushEnabled(id);
	}

	@Transactional
	public int updateFcm(String id, String token) {
		int updated = repo.updateFcm(id, token);
		log.info("Updated FID for trusted device {}; present: {}; rows updated: {}", id, token != null, updated);
		return updated;
	}

	@Transactional
	public void unpair(String deviceId) {
		log.info("Unpairing trusted device {}", deviceId);
		repo.deleteById(deviceId);
	}

	@Transactional
	public void unpairSelf(String tokenHash) {
		repo.deleteByDeviceTokenHash(tokenHash);
	}

	@Scheduled(fixedRate = 200000)
	@Transactional
	public void removeExpiredDevices() {
		Instant cutoff = Instant.now();
		int count = repo.deleteByEnrollmentExpiresAtBeforeAndStatus(cutoff, TrustedDevice.Status.PENDING);
		log.info("Removed expired devices: {}", count);
	}

	@Transactional
	public void clearFcm(String fcm) {
		TrustedDevice trustedDevice =
				repo.findByFcmToken(fcm).orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "Device Not Found"));
		trustedDevice.setFcmToken(null);
		log.info("Cleared unregistered FID from trusted device {}", trustedDevice.getId());
	}

	public TrustedDevice getById(String id) {
		return repo.findById(id).orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "Not found"));
	}
}
