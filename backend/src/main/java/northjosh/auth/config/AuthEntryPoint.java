package northjosh.auth.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.response.BaseError;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class AuthEntryPoint implements AuthenticationEntryPoint {
	private final ObjectMapper objectMapper;

	public AuthEntryPoint(ObjectMapper jacksonObjectMapper) {
		this.objectMapper = jacksonObjectMapper;
	}

	@Override
	public void commence(
			HttpServletRequest request, HttpServletResponse response, AuthenticationException authException)
			throws IOException, ServletException {

		log.error("[{}] HTTP ERROR: AuthEntryPoint {}", request.getRequestId(), authException.getMessage());

		BaseError.BaseErrorBuilder error = BaseError.builder();

		response.setHeader("Content-Type", "application/json");
		response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);

		response.getWriter()
				.write(objectMapper.writeValueAsString(error.errorMessage(authException.getMessage())
						.errorCode(HttpStatus.UNAUTHORIZED.value())
						.url(request.getRequestURI())
						.build()));
	}
}
