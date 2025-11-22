package northjosh.auth.services.otp;

import jakarta.persistence.NoResultException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.transaction.Transactional;
import java.io.IOException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import northjosh.auth.controllers.SseEmitters;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.pushauth.PushAuthRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.jwt.JwtService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
@Transactional
public class PushAuthService {

	private final PushAuthRepo pushAuthRepo;
	private final SseEmitters sseEmitters;
	private final JwtService jwtService;

	public PushAuthService(PushAuthRepo pushAuthRepo, SseEmitters sseEmitters, JwtService jwtService) {
		this.pushAuthRepo = pushAuthRepo;
		this.sseEmitters = sseEmitters;
		this.jwtService = jwtService;
	}

	public PushAuth createSession(User user, HttpServletRequest request) {

		String requestId = request.getSession().getId();
		String otp = generateOTP();

		PushAuth attempt = new PushAuth();
		attempt.setOtp(otp);
		attempt.setRequestId(requestId);
		attempt.setUser(user);
		pushAuthRepo.deletePushAuthByRequestId(requestId);

		return pushAuthRepo.save(attempt);
	}

	public void verify(Map<String, String> dto) {

		String requestId = dto.get("requestId");

		PushAuth attempt = pushAuthRepo
				.findPushAuthByRequestId(requestId)
				.orElseThrow(() -> new NoResultException("Login Attempt Doesn't exist"));

		if (!dto.get("otp").equals(attempt.getOtp())) {
			pushAuthRepo.delete(attempt);
			throw new WebAuthnException("invalid OTP, Please try logging in again session again");
		}

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
		System.out.println("Entries deleted");
	}
}
