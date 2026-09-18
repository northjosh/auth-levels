package northjosh.auth.services.push;

import jakarta.persistence.NoResultException;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.controllers.SseEmitters;
import northjosh.auth.dto.FcmMessage;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.exceptions.PushAuthException;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.pushauth.PushAuthRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.FCMService;
import northjosh.auth.services.devices.TrustedDeviceService;
import northjosh.auth.services.jwt.JwtService;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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
				.filter(Objects::nonNull)
				.toList();

		Map<String, String> data = new HashMap<>();
		data.put("type", "push_request");
		data.put("requestId", attempt.getRequestId());
		data.put("createdAt", attempt.getCreatedAt().toString());
		data.put("expiresAt", attempt.getCreatedAt().plusMinutes(2).toString());
		data.put("osFamily", info.getOsFamily());
		data.put("deviceFamily", info.getDeviceFamily());

		FcmMessage message = new FcmMessage("Login Request", "", data);

		if (!devices.isEmpty()) {
			fCMService.sendBulkMessage(devices, message);
		}

		return attempt;
	}

	@Transactional(noRollbackFor = AuthException.class)
	public void verify(String id, String otp) {
		PushAuth attempt = getPushAuth(id);

		if (attempt.getCreatedAt().isBefore(LocalDateTime.now().minusMinutes(2))) {
			pushAuthRepo.delete(attempt);
			throw new PushAuthException(HttpStatus.GONE, "Attempt Expired, Try requesting again.", "attempts_exceeded");
		}

		if (attempt.isExhausted()) {
			pushAuthRepo.delete(attempt);
			throw new PushAuthException(
					HttpStatus.FORBIDDEN, "Attempts exceeded, Try requesting again.", "attempts_exceed");
		}

		if (!otp.equals(attempt.getOtp())) {
			attempt.incrementAttempts();
			pushAuthRepo.save(attempt);
			throw new PushAuthException(HttpStatus.FORBIDDEN, "Invalid OTP", "otp_mismatch", attempt.getAttempts());
		}

		// use an actual login method.
		String token = jwtService.generateAccessToken(attempt.getUser().getEmail());

		sseEmitters.get(id).ifPresent(emitter -> {
			try {
				emitter.send(SseEmitter.event().name("login-success").data(Map.of("token", token)));
			} catch (IOException e) {
				emitter.completeWithError(e);
			} finally {
				emitter.complete();
			}
		});

		pushAuthRepo.delete(attempt);
	}

	private PushAuth getPushAuth(String id) {
		return pushAuthRepo
				.findPushAuthByRequestId(id)
				.orElseThrow(() -> new NoResultException("Login Attempt Doesn't exist"));
	}

	public void deny(String id) {
		PushAuth attempt = getPushAuth(id);
		ClientInfo clientInfo = attempt.getClientInfo();
		sseEmitters.get(id).ifPresent(emitter -> {
			try {
				emitter.send(
						SseEmitter.event().name("login-denied").data(Map.of("device", clientInfo.getDeviceFamily())));
			} catch (IOException e) {
				emitter.completeWithError(e);
			} finally {
				emitter.complete();
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
