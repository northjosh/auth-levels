package northjosh.auth.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Optional;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Slf4j
@Component
public class MdcLoggingFilter extends OncePerRequestFilter {

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		return request.getRequestURI().startsWith("/actuator");
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
		try {
			String requestId = Optional.ofNullable(request.getHeader("X-Request-Id"))
					.filter(s -> !s.isEmpty())
					.orElse(UUID.randomUUID().toString());

			MDC.put("requestId", requestId);
			MDC.put("method", request.getMethod());
			MDC.put("uri", request.getRequestURI());

			response.setHeader("X-Request-Id", requestId);

			filterChain.doFilter(request, response);
		} finally {
			MDC.clear();
		}
	}
}
