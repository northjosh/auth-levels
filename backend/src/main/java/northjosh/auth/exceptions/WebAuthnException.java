package northjosh.auth.exceptions;

import org.springframework.security.core.AuthenticationException;

public class WebAuthnException extends AuthenticationException {

	public WebAuthnException(String msg) {
		super(msg);
	}
}
