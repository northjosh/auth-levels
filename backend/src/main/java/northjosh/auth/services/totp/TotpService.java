package northjosh.auth.services.totp;

import com.warrenstrange.googleauth.GoogleAuthenticator;
import com.warrenstrange.googleauth.GoogleAuthenticatorKey;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import northjosh.auth.repo.user.User;
import org.springframework.stereotype.Service;

@Service
public class TotpService {
	private final GoogleAuthenticator gAuth = new GoogleAuthenticator();

	public boolean verifyCode(User user, int code) {
		return gAuth.authorize(user.getTotpSecret(), code);
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
		return false;
	}
}
