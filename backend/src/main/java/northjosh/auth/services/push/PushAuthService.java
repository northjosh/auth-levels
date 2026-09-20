package northjosh.auth.services.push;

import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.config.DevicePrincipal;
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

	private static final int TOTAL_ATTEMPTS = 3;
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
				.filter(TrustedDevice::isPushEnabled)
				.map(TrustedDevice::getFcmToken)
				.filter(Objects::nonNull)
				.toList();

		Map<String, String> data = new HashMap<>();
		data.put("type", "push_request");
		data.put("requestId", attempt.getRequestId());
		data.put("createdAt", attempt.getCreatedAt().toString());
		data.put("expiresAt", attempt.getCreatedAt().plus(2, ChronoUnit.MINUTES).toString());
		data.put("osFamily", info.getOsFamily());
		data.put("deviceFamily", info.getDeviceFamily());
		data.put("userAgentFamily", info.getUserAgentFamily());
		data.put("remoteAddress", info.getRemoteAddress());

		String notifBody = String.format(
				"%s, on %s · %s ", info.getUserAgentFamily(), info.getOsFamily(), info.getRemoteAddress());

		FcmMessage message = new FcmMessage("Login Request", notifBody, data);

		log.info("Created push request {} for {}; eligible FIDs: {}", requestId, user.getEmail(), devices.size());
		if (!devices.isEmpty()) {
			fCMService.sendBulkMessage(devices, message);
		} else {
			log.info("No eligible trusted devices for push request {}", requestId);
		}

		return attempt;
	}

	@Transactional(noRollbackFor = AuthException.class)
	public void verify(String id, String otp, Object principal) {
		PushAuth attempt = getPushAuth(id);

		if (principal instanceof DevicePrincipal device) {
			verifyOwnership(attempt, device.getUser().getEmail());
		} else if (principal instanceof String email) {
			verifyOwnership(attempt, email);
		} else {
			throw new AuthException(HttpStatus.FORBIDDEN, "Unsupported principal");
		}

		if (attempt.getCreatedAt().isBefore(Instant.now().minus(2, ChronoUnit.MINUTES))) {
			log.info("Push request {} expired", id);
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
			log.warn(
					"Push request {} rejected: invalid OTP; attempts used: {}/{}",
					id,
					attempt.getAttempts(),
					TOTAL_ATTEMPTS);

			if (attempt.getAttempts() >= TOTAL_ATTEMPTS) {
				pushAuthRepo.delete(attempt);
				throw new PushAuthException(
						HttpStatus.FORBIDDEN,
						"Invalid OTP, Attempts Exhausted. Please start a " + "new request",
						"otp_mismatch",
						TOTAL_ATTEMPTS - attempt.getAttempts());
			} else {
				pushAuthRepo.save(attempt);
				throw new PushAuthException(
						HttpStatus.FORBIDDEN, "Invalid OTP", "otp_mismatch", TOTAL_ATTEMPTS - attempt.getAttempts());
			}
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

		log.info("Push request {} approved by {}", id, principal instanceof DevicePrincipal ? "device" : "user");
		pushAuthRepo.delete(attempt);
	}

	private PushAuth getPushAuth(String id) {
		return pushAuthRepo
				.findPushAuthByRequestId(id)
				.orElseThrow(() -> new AuthException(HttpStatus.GONE, "Login Attempt Doesn't exist"));
	}

	public void deny(String id, Object principal, ClientInfo clientInfo) {
		PushAuth attempt = getPushAuth(id);

		String actorName;

		if (principal instanceof DevicePrincipal device) {
			verifyOwnership(attempt, device.getUser().getEmail());

			actorName = trustedDeviceService.getById(device.getId()).getName();
		} else if (principal instanceof String email) {
			verifyOwnership(attempt, email);
			actorName = String.format("%s on %s", clientInfo.getUserAgentFamily(), clientInfo.getOsFamily());
		} else {
			throw new AuthException(HttpStatus.FORBIDDEN, "Unsupported principal");
		}

		sseEmitters.get(id).ifPresent(emitter -> {
			try {
				emitter.send(SseEmitter.event().name("login-denied").data(Map.of("device", actorName)));
			} catch (IOException e) {
				emitter.completeWithError(e);
			} finally {
				emitter.complete();
			}
		});
		log.info("Push request {} denied by {}", id, actorName);
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
		Instant cutoff = Instant.now().plus(2, ChronoUnit.MINUTES);
		pushAuthRepo.deletePushAuthByCreatedAtBefore(cutoff);
		log.info("Entries deleted");
	}

	private void verifyOwnership(PushAuth attempt, String email) {
		if (!attempt.getUser().getEmail().equals(email)) {
			throw new AuthException(HttpStatus.NOT_FOUND, "Push Auth Attempt Not found");
		}
	}
}
