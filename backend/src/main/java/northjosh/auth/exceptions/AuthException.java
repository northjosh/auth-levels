package northjosh.auth.exceptions;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class AuthException extends RuntimeException {

	private final HttpStatus httpStatus;
	private final String message;
	private String error;

	public AuthException(HttpStatus httpStatus, String message) {
		super(message);
		this.httpStatus = httpStatus;
		this.message = message;
	}

	public AuthException(HttpStatus httpStatus, String message, String error) {
		super(message);
		this.httpStatus = httpStatus;
		this.message = message;
		this.error = error;
	}

	public AuthException(HttpStatus httpStatus, String message, Throwable cause) {
		super(message, cause);
		this.httpStatus = httpStatus;
		this.message = message;
	}
}
