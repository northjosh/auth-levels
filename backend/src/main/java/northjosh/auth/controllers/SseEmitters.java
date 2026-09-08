package northjosh.auth.controllers;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Component
public class SseEmitters {
	private final Map<String, SseEmitter> emitters =
			new ConcurrentHashMap<>();

	public void add(String sessionId, SseEmitter emitter) {
		emitters.put(sessionId, emitter);
	}

	public Optional<SseEmitter> get(String sessionId) {
		return Optional.ofNullable(emitters.get(sessionId));
	}

	public void remove(String sessionId) {
		emitters.remove(sessionId);
	}
}
