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
import northjosh.auth.event.ActivityEvent;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.exceptions.PushAuthException;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.repo.event.SecurityEvent;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.pushauth.PushAuthRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.FCMService;
import northjosh.auth.services.devices.TrustedDeviceService;
import northjosh.auth.services.jwt.JwtService;
import org.modelmapper.ModelMapper;
import org.springframework.context.ApplicationEventPublisher;
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
	private final ApplicationEventPublisher applicationEventPublisher;
	private final ModelMapper modelMapper;

	public PushAuthService(
			PushAuthRepo pushAuthRepo,
			SseEmitters sseEmitters,
			JwtService jwtService,
			FCMService fCMService,
			TrustedDeviceService trustedDeviceService,
			ApplicationEventPublisher applicationEventPublisher,
			ModelMapper modelMapper) {
		this.pushAuthRepo = pushAuthRepo;
		this.sseEmitters = sseEmitters;
		this.jwtService = jwtService;
		this.fCMService = fCMService;
		this.trustedDeviceService = trustedDeviceService;
		this.applicationEventPublisher = applicationEventPublisher;
		this.modelMapper = modelMapper;
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
		PushAuth saved = pushAuthRepo.saveAndFlush(attempt);

		List<String> devices = trustedDeviceService.getActiveDevicesForUser(user.getEmail()).stream()
				.filter(TrustedDevice::isPushEnabled)
				.map(TrustedDevice::getFcmToken)
				.filter(Objects::nonNull)
				.toList();

		Map<String, String> data = new HashMap<>();
		data.put("type", "push_request");
		data.put("requestId", saved.getRequestId());
		data.put("createdAt", saved.getCreatedAt().toString());
		data.put("expiresAt", saved.getCreatedAt().plus(5, ChronoUnit.MINUTES).toString());
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

		logActivity(user.getEmail(), info, SecurityEvent.ActivityType.PUSH_REQUEST_CREATED, null);
		return saved;
	}

	@Transactional(noRollbackFor = AuthException.class)
	public void verify(String id, String otp, Object principal, ClientInfo info) {
		PushAuth attempt = getPushAuth(id);
		String em;

		if (principal instanceof DevicePrincipal device) {
			em = device.getUser().getEmail();
			verifyOwnership(attempt, em);
		} else if (principal instanceof String email) {
			em = email;
			verifyOwnership(attempt, email);
		} else {
			throw new AuthException(HttpStatus.FORBIDDEN, "Unsupported principal");
		}

		if (attempt.getCreatedAt().isBefore(Instant.now().minus(5, ChronoUnit.MINUTES))) {
			log.info("Push request {} expired", id);
			pushAuthRepo.delete(attempt);
			throw new PushAuthException(HttpStatus.GONE, "Attempt Expired, Try requesting again.", "attempt_expired");
		}

		if (attempt.isExhausted()) {
			pushAuthRepo.delete(attempt);
			logActivity(em, info, SecurityEvent.ActivityType.PUSH_ATTEMPTS_EXCEEDED, null);

			throw new PushAuthException(
					HttpStatus.FORBIDDEN, "Attempts exceeded, Try requesting again.", "attempts_exceed");
		}

		if (!otp.equals(attempt.getOtp())) {
			attempt.incrementAttempts();
			logActivity(em, info, SecurityEvent.ActivityType.PUSH_ATTEMPT_FAILED, null);

			log.warn(
					"Push request {} rejected: invalid OTP; attempts used: {}/{}",
					id,
					attempt.getAttempts(),
					TOTAL_ATTEMPTS);

			if (attempt.getAttempts() >= TOTAL_ATTEMPTS) {
				pushAuthRepo.delete(attempt);
				logActivity(em, info, SecurityEvent.ActivityType.PUSH_ATTEMPTS_EXCEEDED, null);
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
		logActivity(em, info, SecurityEvent.ActivityType.LOGIN_SUCCESS, SecurityEvent.Method.PUSH);
		pushAuthRepo.delete(attempt);
	}

	private PushAuth getPushAuth(String id) {
		return pushAuthRepo
				.findPushAuthByRequestId(id)
				.orElseThrow(() -> new AuthException(HttpStatus.GONE, "Login Attempt Doesn't exist"));
	}

	public void deny(String id, Object principal, ClientInfo clientInfo) {
		PushAuth attempt = getPushAuth(id);

		String em;

		String actorName;

		if (principal instanceof DevicePrincipal device) {
			em = device.getUser().getEmail();
			verifyOwnership(attempt, em);
			actorName = trustedDeviceService.getById(device.getId()).getName();
		} else if (principal instanceof String email) {
			em = email;
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

		logActivity(em, clientInfo, SecurityEvent.ActivityType.PUSH_REQUEST_DENIED, null);
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
		Instant cutoff = Instant.now().minus(5, ChronoUnit.MINUTES);
		pushAuthRepo.deletePushAuthByCreatedAtBefore(cutoff);
		log.info("Entries deleted");
	}

	private void verifyOwnership(PushAuth attempt, String email) {
		if (!attempt.getUser().getEmail().equals(email)) {
			throw new AuthException(HttpStatus.NOT_FOUND, "Push Auth Attempt Not found");
		}
	}

	private void logActivity(
			String email, ClientInfo info, SecurityEvent.ActivityType type, SecurityEvent.Method method) {
		ActivityEvent event = new ActivityEvent();
		modelMapper.map(info, event);
		event.setMethod(method);
		event.setType(type);
		event.setEmail(email);
		event.setOccurredAt(Instant.now());

		applicationEventPublisher.publishEvent(event);
	}
}
