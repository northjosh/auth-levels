package northjosh.auth.services.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import java.security.Key;
import java.util.Date;
import java.util.Map;
import northjosh.auth.exceptions.WebAuthnException;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

	private final Key key = Keys.secretKeyFor(SignatureAlgorithm.HS256);

	public String generateAccessToken(String username) {
		long expiration = 60 * 60 * 1000;

		return Jwts.builder()
				.setSubject(username)
				.setIssuer("northjosh")
				.setClaims(Map.of("type", "access", "email", username))
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public String generateVerificationToken(String username) {
		long expiration = 60 * 60 * 1000; // 1 hour minutes

		return Jwts.builder()
				.setSubject(username)
				.setClaims(Map.of("type", "verification", "email", username))
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public String generateRefreshToken(String username) {
		long expiration = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

		return Jwts.builder()
				.setSubject(username)
				.setClaims(Map.of("type", "refresh", "email", username))
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public boolean isRefreshToken(String token) {
		return "refresh".equals(validate(token).getBody().get("type"));
	}

	public String generatePendingToken(String username) {
		long expiration = 5 * 60 * 1000;

		return Jwts.builder()
				.setSubject(username)
				.setClaims(Map.of("type", "pending", "email", username))
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public Jws<Claims> validate(String token) {
		return Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token);
	}

	public String getUsername(String token) {
		return validate(token).getBody().get("email").toString();
	}

	public boolean isTokenValid(String token) {
		try {
			validate(token);
			return true;
		} catch (Exception e) {
			throw new WebAuthnException(e.getMessage());
		}
	}

	public boolean isPendingToken(String token) {
		return "pending".equals(validate(token).getBody().get("type"));
	}

	public boolean isVerificationToken(String token) {
		return "verification".equals(validate(token).getBody().get("type"));
	}
}
