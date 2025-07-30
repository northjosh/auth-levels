package northjosh.auth.config;

import jakarta.persistence.NoResultException;
import java.util.HashMap;
import java.util.Map;
import lombok.NonNull;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.response.BaseError;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@Slf4j
@RestControllerAdvice
public class GlobalErrorHandler extends ResponseEntityExceptionHandler {


	@ExceptionHandler(exception = Exception.class)
	public ResponseEntity<Object> handleGlobal(
			Exception ex, WebRequest request) {

		HttpHeaders headers = new HttpHeaders();
		HttpStatus status = HttpStatus.INTERNAL_SERVER_ERROR
;
		BaseError error = BaseError.builder()
				.errorCode(status.value())
				.errorMessage(ex.getMessage())
				.build();

		log.error("[{}] HTTP ERROR: GlobalException {}", request.getSessionId(), ex.getMessage(), ex);

		return handleExceptionInternal(ex, error, headers, status, request);
	}


	@ExceptionHandler(exception = EmptyResultDataAccessException.class)
	public final ResponseEntity<Object> handleEmptyResultDataAccessException(
			EmptyResultDataAccessException ex,  WebRequest request) {

		HttpHeaders headers = new HttpHeaders();
		HttpStatus status = HttpStatus.NOT_FOUND;

		BaseError error = BaseError.builder()
				.errorCode(status.value())
				.errorMessage(ex.getMessage())
				.build();

		log.error("[{}] HTTP ERROR: EmptyResultDataAccessException {}", request.getSessionId(), ex.getMessage(), ex);

		return handleExceptionInternal(ex, error, headers, status, request);
	}


	@ExceptionHandler(exception = NoResultException.class)
	public final ResponseEntity<Object> handleNoResultException(
			EmptyResultDataAccessException ex, WebRequest request) {

		HttpHeaders headers = new HttpHeaders();
		HttpStatus status = HttpStatus.NOT_FOUND;

		BaseError error = BaseError.builder()
				.errorCode(status.value())
				.errorMessage(ex.getMessage())
				.build();

		log.error("[{}] HTTP ERROR: NoResultException {}", request.getSessionId(), ex.getMessage(), ex);

		return handleExceptionInternal(ex, error, headers, status, request);
	}

	@ResponseStatus(HttpStatus.BAD_REQUEST)
	@Override
	public ResponseEntity<Object> handleMethodArgumentNotValid(
			MethodArgumentNotValidException ex,
			@NonNull HttpHeaders headers,
			@NonNull HttpStatusCode status,
			WebRequest request) {


		Map<String, String> errors = new HashMap<>();
		ex.getBindingResult().getAllErrors().forEach(error -> {
			String fieldName = ((FieldError) error).getField();
			String errorMessage = error.getDefaultMessage();
			errors.put(fieldName, errorMessage);
		});

		BaseError error = BaseError.builder()
				.errorCode(HttpStatus.BAD_REQUEST.value())
				.errorMessage("invalid argument for " + errors)
				.build();

		log.error("[{}] HTTP ERROR:handleMethodArgumentNotValid {} ", request.getSessionId(), ex.getMessage());

		return handleExceptionInternal(ex, error, headers, status, request);
	}
}
