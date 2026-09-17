package northjosh.auth.exceptions;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class PushAuthException extends RuntimeException {
	private final String message;
	private final String error;
	private final HttpStatus httpStatus;
	private int attempts;

	public PushAuthException(HttpStatus httpStatus, String message, String error, int attempts) {
		super(message);
		this.httpStatus = httpStatus;
		this.message = message;
		this.error = error;
		this.attempts = attempts;
	}

	public PushAuthException(HttpStatus httpStatus, String message, String error, Throwable cause) {
		super(message, cause);
		this.httpStatus = httpStatus;
		this.message = message;
		this.error = error;
	}

	public PushAuthException(HttpStatus httpStatus, String message, String error) {
		super(message);
		this.httpStatus = httpStatus;
		this.message = message;
		this.error = error;
	}
}
