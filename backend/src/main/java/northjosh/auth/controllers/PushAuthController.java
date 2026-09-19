package northjosh.auth.controllers;

import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalTime;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import lombok.RequiredArgsConstructor;
import northjosh.auth.config.DevicePrincipal;
import northjosh.auth.dto.PushAuthResponse;
import northjosh.auth.dto.response.PushAuthDto;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.interfaces.IsUserOrDevice;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.push.PushAuthService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/push")
@RequiredArgsConstructor
public class PushAuthController {

	Executor sseExecutor = Executors.newCachedThreadPool();

	private final SseEmitters emitters;

	private final UserService userService;

	private final PushAuthService pushAuthService;

	private final ModelMapper modelMapper;

	@GetMapping("/listen")
	public SseEmitter listen(@RequestParam String clientId, HttpServletRequest req) {

		ClientInfo clientInfo = new ClientInfo(req);

		SseEmitter emitter = new SseEmitter();
		sseExecutor.execute(() -> {
			try {
				for (int i = 0; true; i++) {
					SseEmitter.SseEventBuilder event = SseEmitter.event()
							.data("SSE MVC - %s ".formatted(clientInfo.getUserAgentFamily()) + LocalTime.now())
							.id(String.valueOf(i))
							.name("sse event - %s from".formatted(clientId));
					emitter.send(event);
					Thread.sleep(1000);
				}
			} catch (Exception ex) {
				emitter.completeWithError(ex);
			}
		});

		return emitter;
	}

	@GetMapping("/sse")
	public SseEmitter sse(@RequestParam String clientId) throws IOException {
		SseEmitter emitter = new SseEmitter(60L * 2000);

		String[] decoded = decode(clientId);

		String requestId = decoded[2];

		emitters.add(requestId, emitter);

		emitter.send(SseEmitter.event().data("Connection established"));

		emitter.onCompletion(() -> emitters.remove(requestId));
		emitter.onTimeout(() -> emitters.remove(requestId));

		return emitter;
	}

	@PostMapping("/generate")
	public PushAuthResponse push(@RequestBody Map<String, String> dto, HttpServletRequest request) {

		String email = dto.get("email");
		User user = userService.get(email);
		PushAuth attempt = pushAuthService.createSession(user, request);
		return modelMapper.map(attempt, PushAuthResponse.class);
	}

	@PostMapping("/{id}/verify")
	@IsUserOrDevice
	public Map<String, String> verify(@PathVariable String id, @RequestBody Map<String, String> dto) {
		String otp = dto.get("otp");
		pushAuthService.verify(id, otp);
		return Map.of("message", "Login Successful");
	}

	@PostMapping("/{id}/deny")
	@IsUserOrDevice
	public Map<String, String> deny(@PathVariable String id) {
		pushAuthService.deny(id);
		return Map.of("message", "Attempt Denied");
	}

	@GetMapping("/get")
	@IsUserOrDevice
	public List<PushAuthDto> get(@AuthenticationPrincipal Object obj) {
		String email = getAuthPrincipalEmail(obj);
		return pushAuthService.getAll(email).stream()
				.map(cred -> modelMapper.map(cred, PushAuthDto.class))
				.toList();
	}

	// spotless:off
	private static String getAuthPrincipalEmail(Object obj) {
		return switch(obj) {
			case DevicePrincipal dp -> dp.getUser().getEmail();
			case String s when !s.equals("anonymousUser") -> s;
			case null, default -> throw new AuthException(HttpStatus.UNAUTHORIZED, "You don't have permission to " +
					"access this resource");
		};
	}
	// spotless:on

	public static String[] decode(String base64Token) {
		String decoded = new String(Base64.getDecoder().decode(base64Token), StandardCharsets.UTF_8);
		// Expected format: auth_login_<sessionID>_<email>
		String[] parts = decoded.split("_", 4);

		if (parts.length != 4 || !parts[0].equals("auth") || !parts[1].equals("login")) {
			throw new IllegalArgumentException("Invalid token format");
		}

		return parts;
	}
}
