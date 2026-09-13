package northjosh.auth.services.devices;

import io.jsonwebtoken.Claims;
import jakarta.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.PairDeviceDto;
import northjosh.auth.dto.PairDeviceResponse;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.repo.device.TrustedDeviceRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.user.UserService;
import northjosh.auth.util.DeviceUtils;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class TrustedDeviceService {

	private final UserService userService;
	private final TrustedDeviceRepo repo;
	private final JwtService jwtService;

	public TrustedDeviceService(UserService userService, TrustedDeviceRepo trustedDeviceRepo, JwtService jwtService) {
		this.userService = userService;
		this.repo = trustedDeviceRepo;
		this.jwtService = jwtService;
	}

	@Transactional
	public Map<String, String> enroll(String email) {
		User user = userService.get(email);

		TrustedDevice trustedDevice = TrustedDevice.builder()
				.user(user)
				.status(TrustedDevice.Status.PENDING)
				.build();

		TrustedDevice saved = repo.save(trustedDevice);
		String token = generateEnrollmentToken(email, saved.getId());

		return Map.of(
				"enrollmentToken",
				token,
				"expiresAt",
				LocalDateTime.now().plusHours(1).toString());
	}

	@Transactional
	public PairDeviceResponse pair(PairDeviceDto dto) {
		Claims claims = jwtService.decodeToken(dto.getEnrollmentToken());
		String deviceId = claims.get("deviceId").toString();
		String deviceToken = DeviceUtils.generateDeviceToken();

		TrustedDevice device =
				repo.findById(deviceId).orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "Device Not Found"));

		device.setStatus(TrustedDevice.Status.ACTIVE);
		device.setAppVersion(dto.getAppVersion());
		device.setFcmToken(dto.getFcmToken());
		device.setEnrollmentToken(dto.getEnrollmentToken());
		device.setDeviceTokenHash(DeviceUtils.hash256(deviceToken));
		device.setName(dto.getName());
		device.setPlatform(dto.getPlatform());
		device.setLastSeenAt(LocalDateTime.now());
		device.setPairedAt(LocalDateTime.now());

		repo.save(device);
		return new PairDeviceResponse(
				deviceId,
				deviceToken,
				new PairDeviceResponse.DeviceUser(
						device.getUser().getFirstName(), device.getUser().getEmail()));
	}

	private String generateEnrollmentToken(String email, String deviceId) {
		Map<String, String> claims = new HashMap<>();
		claims.put("email", email);
		claims.put("type", "pair_token");
		claims.put("deviceId", deviceId);
		return jwtService.generateToken(email, claims, 1);
	}

	public List<TrustedDevice> getDevicesForUser(String email) {
		return repo.findAllByUser_Email(email);
	}

	public List<TrustedDevice> getActiveDevicesForUser(String email) {
		return repo.findAllByUser_EmailAndStatusIs(email, TrustedDevice.Status.ACTIVE);
	}

	public TrustedDevice togglePush(String id) {
		return repo.togglePushEnabled(id);
	}

	public TrustedDevice updateFcm(String id, String token) {
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
}
