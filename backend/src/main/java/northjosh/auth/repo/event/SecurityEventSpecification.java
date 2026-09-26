package northjosh.auth.repo.event;

import jakarta.persistence.criteria.Predicate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import northjosh.auth.dto.CursorPageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Component;

@Component
public class SecurityEventSpecification {

	public Specification<SecurityEvent> withFilters(Long userId, CursorPageable pageable) {

		return Specification.<SecurityEvent>unrestricted()
				.and(hasOsFamily(pageable.getOsFamily()))
				.and(haDeviceFamily(pageable.getDeviceFamily()))
				.and(hasRemoteAddress(pageable.getRemoteAddress()))
				.and(hasMethod(pageable.getMethod()))
				.and(hasType(pageable.getType()))
				.and(next(pageable.getNext())) // at least one is gonna be null;
				.and(prev(pageable.getPrev())) // same here
				.and(forUser(userId))
				.and(inDateTimeRange(pageable.getFrom(), pageable.getTo()));
	}

	private Specification<SecurityEvent> forUser(Long id) {
		if (id == null) return Specification.unrestricted();
		return ((root, query, cb) -> cb.equal(root.get("user").get("id"), id));
	}

	private Specification<SecurityEvent> hasOsFamily(String osFamily) {
		if (osFamily == null || osFamily.isBlank()) return Specification.unrestricted();

		return ((root, query, cb) -> cb.equal(root.get("osFamily"), osFamily));
	}

	private Specification<SecurityEvent> haDeviceFamily(String deviceFamily) {
		if (deviceFamily == null || deviceFamily.isBlank()) return Specification.unrestricted();

		return ((root, query, cb) -> cb.equal(root.get("deviceFamily"), deviceFamily));
	}

	private Specification<SecurityEvent> hasRemoteAddress(String addr) {
		if (addr == null || addr.isBlank()) return Specification.unrestricted();
		return ((root, query, cb) -> cb.equal(root.get("remoteAddress"), addr));
	}

	private Specification<SecurityEvent> hasMethod(SecurityEvent.Method method) {
		if (method == null) return Specification.unrestricted();
		return ((root, query, cb) -> cb.equal(root.get("method"), method));
	}

	private Specification<SecurityEvent> hasType(SecurityEvent.ActivityType type) {
		if (type == null) return Specification.unrestricted();
		return ((root, query, cb) -> cb.equal(root.get("type"), type));
	}

	private Specification<SecurityEvent> prev(String cursor) {
		if (cursor == null) return Specification.unrestricted();
		CursorPageable.DecodedCursor decoded = CursorPageable.decode(cursor);
		return ((root, query, cb) -> cb.or(
				cb.greaterThan(root.get("createdAt"), decoded.getCreatedAt()),
				cb.and(
						cb.equal(root.get("createdAt"), decoded.getCreatedAt()),
						cb.greaterThan(root.get("id"), decoded.getId()) // uuids? smh
						)));
	}

	private Specification<SecurityEvent> next(String cursor) {
		if (cursor == null) return Specification.unrestricted();
		CursorPageable.DecodedCursor decoded = CursorPageable.decode(cursor);
		return ((root, query, cb) -> cb.or(
				cb.lessThan(root.get("createdAt"), decoded.getCreatedAt()),
				cb.and(
						cb.equal(root.get("createdAt"), decoded.getCreatedAt()),
						cb.lessThan(root.get("id"), decoded.getId()))));
	}

	private Specification<SecurityEvent> inDateTimeRange(OffsetDateTime from, OffsetDateTime to) {
		return ((root, query, cb) -> {
			List<Predicate> predicates = new ArrayList<>();
			if (from != null) {
				predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), from.toInstant()));
			}
			if (to != null) {
				predicates.add(cb.lessThanOrEqualTo(root.get("createdAt"), to.toInstant()));
			}
			return predicates.isEmpty() ? null : cb.and(predicates.toArray(new Predicate[0]));
		});
	}
}
