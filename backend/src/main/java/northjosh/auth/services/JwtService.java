package northjosh.auth.services;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import java.security.Key;
import java.util.Date;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

	private final Key key = Keys.secretKeyFor(SignatureAlgorithm.HS256);

	public String generateToken(String username, boolean isPending) {
		long expiration = isPending ? 5 * 60 * 1000 : 60 * 60 * 1000;

		return Jwts.builder()
				.setSubject(username)
				.setClaims(Map.of("type", isPending ? "pending" : "access", "email", username))
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
			return false;
		}
	}

	public boolean isPendingToken(String token) {
		return "pending".equals(validate(token).getBody().get("type"));
	}
}
