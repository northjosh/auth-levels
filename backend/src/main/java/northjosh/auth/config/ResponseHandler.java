package northjosh.auth.config;

import jakarta.servlet.http.HttpServletResponse;
import northjosh.auth.dto.response.ApiResponse;
import northjosh.auth.dto.response.BaseError;
import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;

@RestControllerAdvice
public class ResponseHandler implements ResponseBodyAdvice {
	@Override
	public boolean supports(MethodParameter returnType, Class converterType) {
		return !returnType.getParameterType().equals(ApiResponse.class);
	}

	@Override
	public Object beforeBodyWrite(
			Object body,
			MethodParameter returnType,
			MediaType selectedContentType,
			Class selectedConverterType,
			ServerHttpRequest request,
			ServerHttpResponse response) {

		if (body instanceof ApiResponse) {
			return body;
		}

		if (body instanceof HttpServletResponse) {
			return new ApiResponse<>(-1, "Failed", body, request.getURI().toString());
		}
		if (body instanceof BaseError) {
			((BaseError) body).setUrl(request.getURI().toString());
			return new ApiResponse<>(-1, "Failed", body, request.getURI().toString());
		}

		return new ApiResponse<>(0, "Success", body, request.getURI().toString());
	}
}
