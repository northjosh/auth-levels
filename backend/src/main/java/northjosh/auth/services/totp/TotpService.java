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
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.totp.Totp;
import northjosh.auth.repo.totp.TotpRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.recovery.RecoveryCodeService;
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

	@Transactional
	public Totp create(User user) {
		Totp totp = new Totp();
		totp.setSecret(generateSecret());
		totp.setUser(user);
		totp.setStatus(Totp.TotpStatus.PENDING);
		return totpRepo.save(totp);
	}

	public List<String> activate(User user, int code) {
		Totp totp = totpRepo.findByUser(user);

		if (!verifyCode(totp.getUser(), code)) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "Not matching code. Could not activate");
		}

		if (totp.getStatus().equals(Totp.TotpStatus.PENDING)) {
			totp.setStatus(Totp.TotpStatus.ACTIVE);
		}

		totpRepo.save(totp);
		// send an email

		// generate recovery codes after activation
		return recoveryCodeService.generateRecoveryCode(user.getEmail());
	}

	private Totp getTotp(String id) {
		return totpRepo.findById(id)
				.orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "TOTP for user not found"));
	}

	@Transactional
	public void deactivate(String id) {
		Totp totp = getTotp(id);
		if (!totp.getStatus().equals(Totp.TotpStatus.INACTIVE)) {
			totp.setStatus(Totp.TotpStatus.INACTIVE);
		}
		log.info("TOTP deactivated for user {}", totp.getUser().getEmail());

		totpRepo.save(totp);
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
	public boolean verifyCode(User user, int code) {
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
		if (matched == null) throw new AuthException(HttpStatus.FORBIDDEN, "Invalid Code");

		if (matched <= totp.getLastUsedStep()) throw new AuthException(HttpStatus.FORBIDDEN, "Already used");

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

	public boolean isBackupCodeValid(User user, String code) {
		return recoveryCodeService.useRecoveryCode(user.getEmail(), code);
	}
}
