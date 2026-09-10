package northjosh.auth.services.jwt;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import java.security.Key;
import java.util.Date;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.exceptions.WebAuthnException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class JwtService {

	private static final String ISSUER = "northjosh";

	private final Key key = Keys.secretKeyFor(SignatureAlgorithm.HS256);

	public String generateAccessToken(String username) {
		long expiration = 60 * 60 * 1000;

		return Jwts.builder()
				.setClaims(Map.of("type", "access", "email", username))
				.setSubject(username)
				.setIssuer(ISSUER)
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public String generateVerificationToken(String username) {
		long expiration = 60 * 60 * 1000; // 1 hour minutes

		return Jwts.builder()
				.setClaims(Map.of("type", "verification", "email", username))
				.setSubject(username)
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public String generateRefreshToken(String username) {
		long expiration = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

		return Jwts.builder()
				.setClaims(Map.of("type", "refresh", "email", username))
				.setSubject(username)
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public String generateResetToken(String username) {
		long expiration = 30 * 60 * 1000; // 30 minutes in milliseconds

		return Jwts.builder()
				.setClaims(Map.of("type", "password_reset", "email", username))
				.setSubject(username)
				.setIssuedAt(new Date())
				.setExpiration(new Date(System.currentTimeMillis() + expiration))
				.signWith(key)
				.compact();
	}

	public Claims decodeToken(String token) {
		try {
			return Jwts.parserBuilder()
					.setSigningKey(key)
					.requireIssuer(ISSUER)
					.build()
					.parseClaimsJws(token)
					.getBody();
		} catch (JwtException e) {
			log.warn("Jwt Error while decoding token");
			throw new AuthException(HttpStatus.UNAUTHORIZED, e.getMessage(), e);
		}
	}

	public boolean isRefreshToken(String token) {
		return "refresh".equals(validate(token).getBody().get("type"));
	}

	public String generatePendingToken(String username) {
		long expiration = 5 * 60 * 1000;

		return Jwts.builder()
				.setClaims(Map.of("type", "pending", "email", username))
				.setSubject(username)
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
