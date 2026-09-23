package northjosh.auth.services.totp;

import com.warrenstrange.googleauth.GoogleAuthenticator;
import com.warrenstrange.googleauth.GoogleAuthenticatorKey;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.stream.LongStream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.event.ActivityEvent;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.event.SecurityEvent;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.totp.Totp;
import northjosh.auth.repo.totp.TotpRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.recovery.RecoveryCodeService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class TotpService {
	private final TotpRepo totpRepo;
	private final GoogleAuthenticator gAuth = new GoogleAuthenticator();
	private final RecoveryCodeService recoveryCodeService;
	private final UserService userService;
	private final ModelMapper modelMapper;
	private final ApplicationEventPublisher applicationEventPublisher;

	@Transactional
	public Totp create(User user) {
		Totp totp = new Totp();
		totp.setSecret(generateSecret());
		totp.setUser(user);
		totp.setStatus(Totp.TotpStatus.PENDING);
		return totpRepo.save(totp);
	}

	@Transactional
	public List<String> activate(User user, int code, ClientInfo info) {
		Totp totp = totpRepo.findByUser(user);

		if (!verifyCode(totp.getUser(), code, info)) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "Not matching code. Could not activate");
		}

		if (totp.getStatus().equals(Totp.TotpStatus.PENDING)) {
			totp.setStatus(Totp.TotpStatus.ACTIVE);
		}

		totpRepo.save(totp);
		user.setTotpEnabled(true);
		// send an email

		logActivity(user.getEmail(), info, SecurityEvent.ActivityType.TOTP_ENABLED, null);
		// generate recovery codes after activation
		return recoveryCodeService.generateRecoveryCode(user.getEmail(), info);
	}

	private Totp getTotp(String id) {
		return totpRepo.findById(id)
				.orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "TOTP for user not found"));
	}

	@Transactional
	public void deactivate(String email, ClientInfo info) {
		User user = userService.get(email);
		Totp totp = getTotp(email);

		if (!totp.getStatus().equals(Totp.TotpStatus.INACTIVE)) {
			totp.setStatus(Totp.TotpStatus.INACTIVE);
		}
		// ideally, should be deleting with recovery codes
		totpRepo.save(totp);
		user.setTotpEnabled(false);
		log.info("TOTP deactivated for user {}", totp.getUser().getEmail());
		logActivity(user.getEmail(), info, SecurityEvent.ActivityType.TOTP_DISABLED, null);
		// send another email
	}

	@Transactional
	public void delete(String id) {
		Totp totp = getTotp(id);
		totpRepo.delete(totp);
		log.info("TOTP deleted for user {}", totp.getUser().getEmail());
		// audit and send another email(notify)
	}

	@Transactional
	public boolean verifyCode(User user, int code, ClientInfo info) {
		Totp totp = totpRepo.findByUser(user);

		log.info("Verifying code for user {}", totp.getLastUsedStep());

		long step = Instant.now().getEpochSecond() / 30;
		Long matched = LongStream.rangeClosed(step - 1, step + 1)
				.filter(s -> {
					int res = gAuth.getTotpPassword(totp.getSecret(), s * 30_000L);
					return res == code;
				})
				.boxed()
				.findFirst()
				.orElse(null);
		if (matched == null) {
			logActivity(user.getEmail(), info, SecurityEvent.ActivityType.TOTP_ATTEMPT_FAILED, null);
			throw new AuthException(HttpStatus.FORBIDDEN, "Invalid Code");
		}

		if (matched <= totp.getLastUsedStep()) {
			logActivity(user.getEmail(), info, SecurityEvent.ActivityType.TOTP_ATTEMPT_FAILED, null);
			throw new AuthException(HttpStatus.FORBIDDEN, "Already used");
		}

		int updated = totpRepo.updateLastUsedStep(user.getId(), matched, totp.getLastUsedStep());
		return updated != 0;
	}

	public String generateSecret() {
		GoogleAuthenticatorKey key = gAuth.createCredentials();
		return key.getKey();
	}

	public String getQRCodeUrl(String email, String secret) {
		String issuer = "JoshAuth";
		String encodedIssuer = URLEncoder.encode(issuer, StandardCharsets.UTF_8);
		String encodedEmail = URLEncoder.encode(email, StandardCharsets.UTF_8);

		return String.format(
				"otpauth://totp/%s:%s?secret=%s&issuer=%s", encodedIssuer, encodedEmail, secret, encodedIssuer);
	}

	public boolean isBackupCodeValid(User user, String code, ClientInfo info) {
		return recoveryCodeService.useRecoveryCode(user.getEmail(), code, info);
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
