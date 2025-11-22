package northjosh.auth.controllers;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

@Component
public class SseEmitters {
	private final Map<String, org.springframework.web.servlet.mvc.method.annotation.SseEmitter> emitters =
			new ConcurrentHashMap<>();

	public void add(String sessionId, org.springframework.web.servlet.mvc.method.annotation.SseEmitter emitter) {
		emitters.put(sessionId, emitter);
	}

	public Optional<org.springframework.web.servlet.mvc.method.annotation.SseEmitter> get(String sessionId) {
		return Optional.ofNullable(emitters.get(sessionId));
	}

	public void remove(String sessionId) {
		emitters.remove(sessionId);
	}
}
