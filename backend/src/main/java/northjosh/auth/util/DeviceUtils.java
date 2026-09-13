package northjosh.auth.util;

import lombok.extern.slf4j.Slf4j;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

@Slf4j
public class DeviceUtils {
	private static final SecureRandom RANDOM = new SecureRandom();

	public static String generateDeviceToken() {
		byte[] raw = new byte[32];
		RANDOM.nextBytes(raw);
		return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
	}

	public static String hash256(String token) {
		try {
			MessageDigest digest = MessageDigest.getInstance("SHA-256");
			byte[] hash = digest.digest(token.getBytes());
			StringBuilder hexString = new StringBuilder(2 * hash.length);
			for (byte b : hash) {
				String hex = Integer.toHexString(b & 0xff);
				if (hex.length() == 1) {
					hexString.append('0');
				}
			}
			return hexString.toString();

		} catch (NoSuchAlgorithmException e) {
			log.error(e.getMessage());
			throw new RuntimeException("SHA-256 Algorithm Not Supported", e);
		}
	}
}
