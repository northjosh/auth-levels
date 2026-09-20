package northjosh.auth.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.repo.device.TrustedDeviceRepo;
import northjosh.auth.util.DeviceUtils;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@RequiredArgsConstructor
public class DeviceFilter extends OncePerRequestFilter {

	private final TrustedDeviceRepo trustedDeviceRepo;

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {

		String authHeader = request.getHeader("Authorization");

		if (authHeader == null || !authHeader.startsWith("Bearer ")) {
			doFilter(request, response, filterChain);
			return;
		}

		try {
			String token = authHeader.substring(7);
			if (isJwt(token)) {
				doFilter(request, response, filterChain);
				return;
			}

			Optional<TrustedDevice> device = trustedDeviceRepo.findByDeviceTokenHashAndStatusIs(
					DeviceUtils.hash256(token), TrustedDevice.Status.ACTIVE);

			if (device.isEmpty()) {
				throw new AuthException(HttpStatus.UNAUTHORIZED, "Device token does not exist");
			}

			TrustedDevice exists = device.get();
			var auth = new UsernamePasswordAuthenticationToken(
					new DevicePrincipal(exists.getId(), exists.getUser()), null, null);
			auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
			SecurityContextHolder.getContext().setAuthentication(auth);
			exists.setLastSeenAt(Instant.now());
			trustedDeviceRepo.save(exists);
		} catch (Exception e) {
			SecurityContextHolder.clearContext();
		}
		filterChain.doFilter(request, response);
	}

	private boolean isJwt(String jwt) {
		return jwt.chars().filter(ch -> ch == '.').count() == 2;
	}
}
