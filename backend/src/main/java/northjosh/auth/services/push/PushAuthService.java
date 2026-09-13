package northjosh.auth.services.push;

import jakarta.persistence.NoResultException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.transaction.Transactional;
import java.io.IOException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.controllers.SseEmitters;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.pushauth.PushAuthRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.FCMService;
import northjosh.auth.services.devices.TrustedDeviceService;
import northjosh.auth.services.jwt.JwtService;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Slf4j
@Service
@Transactional
public class PushAuthService {

	private final PushAuthRepo pushAuthRepo;
	private final SseEmitters sseEmitters;
	private final JwtService jwtService;
	private final FCMService fCMService;
	private final TrustedDeviceService trustedDeviceService;

	public PushAuthService(
			PushAuthRepo pushAuthRepo,
			SseEmitters sseEmitters,
			JwtService jwtService,
			FCMService fCMService,
			TrustedDeviceService trustedDeviceService) {
		this.pushAuthRepo = pushAuthRepo;
		this.sseEmitters = sseEmitters;
		this.jwtService = jwtService;
		this.fCMService = fCMService;
		this.trustedDeviceService = trustedDeviceService;
	}

	public PushAuth createSession(User user, HttpServletRequest request) {

		String requestId = request.getSession().getId();
		String otp = generateOTP();

		ClientInfo info = new ClientInfo(request);

		PushAuth attempt = new PushAuth();
		attempt.setOtp(otp);
		attempt.setRequestId(requestId);
		attempt.setUser(user);
		attempt.setClientInfo(info);

		pushAuthRepo.deletePushAuthByRequestId(requestId);
		pushAuthRepo.save(attempt);

		List<String> devices = trustedDeviceService.getActiveDevicesForUser(user.getEmail()).stream()
				.map(TrustedDevice::getFcmToken)
				.toList();

		Map<String, String> message = new HashMap<>();
		message.put("type", "push_request");
		message.put("requestId", MDC.get("requestId"));
		message.put("createdAt", attempt.getCreatedAt().toString());
		message.put("expiresAt", attempt.getCreatedAt().plusMinutes(2).toString());
		message.put("osFamily", info.getUserAgentFamily());
		message.put("deviceFamily", info.getUserAgentFamily());
		message.put("ttl","120");

		if(!devices.isEmpty()) {
			fCMService.sendBulkMessage(devices, message);
		}

		return attempt;
	}

	public void verify(Map<String, String> dto) {

		String requestId = dto.get("requestId");

		PushAuth attempt = pushAuthRepo
				.findPushAuthByRequestId(requestId)
				.orElseThrow(() -> new NoResultException("Login Attempt Doesn't exist"));

		if(!attempt.getCreatedAt().isBefore(LocalDateTime.now().minusMinutes(2))) {
			pushAuthRepo.delete(attempt);
			throw new AuthException(HttpStatus.BAD_REQUEST, "Attempt Expired, Try requesting again.");
		}

		if (!dto.get("otp").equals(attempt.getOtp())) {
			pushAuthRepo.delete(attempt);
			throw new WebAuthnException("invalid OTP, Please try logging in again session again");
		}


		// use an actual login method.
		String token = jwtService.generateAccessToken(attempt.getUser().getEmail());

		sseEmitters.get(requestId).ifPresent(emitter -> {
			try {
				emitter.send(SseEmitter.event().name("login-success").data(Map.of("token", token)));
			} catch (IOException e) {
				emitter.completeWithError(e);
			}
		});

		pushAuthRepo.delete(attempt);
	}

	public List<PushAuth> getAll(String email) {
		return pushAuthRepo.findAllByUserEmail(email);
	}

	private String generateOTP() {
		SecureRandom random = new SecureRandom();
		int randomNumber = random.nextInt(900000) + random.nextInt(900000);
		return String.valueOf(randomNumber);
	}

	@Scheduled(fixedRate = 60000)
	public void deleteExpiredEntries() {
		LocalDateTime cutoff = LocalDateTime.now().minusMinutes(2);
		pushAuthRepo.deletePushAuthByCreatedAtBefore(cutoff);
		log.info("Entries deleted");
	}
}
