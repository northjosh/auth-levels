package northjosh.auth.config;

import northjosh.auth.exceptions.AuthException;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

@Component("principalResolver")
public class PrincipalResolver {

	public boolean isUser(Authentication authentication) {
		return authentication.getPrincipal() instanceof String;
	}

	public String requireEmail() {
		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

		if (authentication == null || authentication instanceof AnonymousAuthenticationToken) {
			throw new AuthException(HttpStatus.FORBIDDEN, "Authentication required");
		}

		if (authentication.getPrincipal() instanceof DevicePrincipal) {
			throw new AuthException(HttpStatus.FORBIDDEN, "Authentication required");
		}

		if (authentication.getPrincipal() instanceof String email) {
			return email;
		}

		throw new AuthException(HttpStatus.FORBIDDEN, "Authentication required");
	}

	public DevicePrincipal requireDevice() {
		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

		if (authentication == null || authentication instanceof AnonymousAuthenticationToken) {
			throw new AuthException(HttpStatus.FORBIDDEN, "Authentication required");
		}

		if (authentication.getPrincipal() instanceof String) {
			throw new AuthException(HttpStatus.FORBIDDEN, "Authentication required");
		}

		if (authentication.getPrincipal() instanceof DevicePrincipal device) {
			return device;
		}

		return null;
	}

	public boolean isDevice(Authentication authentication) {
		return isAuthenticated(authentication) && authentication.getPrincipal() instanceof DevicePrincipal;
	}

	public boolean isUserOrDevice(Authentication authentication) {
		return isAuthenticated(authentication) && isUser(authentication) || isDevice(authentication);
	}

	private boolean isAuthenticated(Authentication authentication) {
		return authentication.isAuthenticated();
	}
}
