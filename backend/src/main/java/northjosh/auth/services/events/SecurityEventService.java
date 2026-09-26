package northjosh.auth.services.events;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import northjosh.auth.config.DevicePrincipal;
import northjosh.auth.dto.CursorPageable;
import northjosh.auth.dto.PagedResponse;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.event.SecurityEvent;
import northjosh.auth.repo.event.SecurityEventRepo;
import northjosh.auth.repo.event.SecurityEventSpecification;
import northjosh.auth.services.user.UserService;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class SecurityEventService {

	private final SecurityEventRepo repo;
	private final UserService userService;
	private final SecurityEventSpecification spec;

	public SecurityEventService(SecurityEventRepo repo, UserService userService, SecurityEventSpecification spec) {
		this.repo = repo;
		this.userService = userService;
		this.spec = spec;
	}

	public PagedResponse<SecurityEvent> getAll(Object principal, CursorPageable pageable) {

		List<SecurityEvent> events;
		String next = null;
		String prev = null;

		int limit = pageable.getSize();

		Long id = resolveId(principal);
		boolean isBackwards = pageable.getPrev() != null;
		events = new ArrayList<>(repo.findAll(
						spec.withFilters(id, pageable), PageRequest.of(0, pageable.getSize() + 1, getSort(isBackwards)))
				.getContent());
		boolean hasMore = events.size() > limit;

		if (isBackwards) {
			Collections.reverse(events);
			if (hasMore) {
				events.removeFirst();
				prev = CursorPageable.encode(
						events.getFirst().getCreatedAt(), events.getFirst().getId());
			}

			if (!events.isEmpty()) {
				next = CursorPageable.encode(
						events.getLast().getCreatedAt(), events.getLast().getId());
			}

		} else {
			if (hasMore) {
				events.removeLast();
				next = CursorPageable.encode(
						events.getLast().getCreatedAt(), events.getLast().getId());
			}
			if (pageable.getNext() != null && !events.isEmpty()) {
				prev = CursorPageable.encode(
						events.getFirst().getCreatedAt(), events.getFirst().getId());
			}
		}
		return new PagedResponse<>(events, next, prev);
	}

	private Long resolveId(Object principal) {
		Long id;
		if (principal instanceof DevicePrincipal device) {
			id = device.getUser().getId();
		} else if (principal instanceof String email) {
			id = userService.get(email).getId();
		} else {
			throw new AuthException(HttpStatus.FORBIDDEN, "Unsupported principal");
		}
		return id;
	}

	private Sort getSort(boolean isBackwards) {
		Sort.Direction dir = isBackwards ? Sort.Direction.ASC : Sort.Direction.DESC;
		return Sort.by(dir, "createdAt").and(Sort.by(dir, "id"));
	}
}
