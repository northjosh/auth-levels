package northjosh.auth.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.response.BaseError;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class CustomAccessDeniedHandler implements AccessDeniedHandler {
	private final ObjectMapper objectMapper;

	public CustomAccessDeniedHandler(ObjectMapper jacksonObjectMapper) {
		this.objectMapper = jacksonObjectMapper;
	}

	@Override
	public void handle(
			HttpServletRequest request, HttpServletResponse response, AccessDeniedException accessDeniedException)
			throws IOException, ServletException {
		log.error("[{}] HTTP ERROR: AuthEntryPoint {}", request.getRequestId(), accessDeniedException.getMessage());

		BaseError.BaseErrorBuilder error = BaseError.builder();

		response.setHeader("Content-Type", "application/json");
		response.setStatus(HttpServletResponse.SC_FORBIDDEN);

		response.getWriter()
				.write(objectMapper.writeValueAsString(error.errorMessage(accessDeniedException.getMessage())
						.errorCode(HttpStatus.FORBIDDEN.value())
						.url(request.getRequestURI())
						.build()));
	}
}
