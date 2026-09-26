package northjosh.auth.controllers;

import jakarta.validation.Valid;
import northjosh.auth.dto.CursorPageable;
import northjosh.auth.dto.PagedResponse;
import northjosh.auth.interfaces.IsUserOrDevice;
import northjosh.auth.repo.event.SecurityEvent;
import northjosh.auth.services.events.SecurityEventService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SecurityEventController {

	private final SecurityEventService securityEventService;

	public SecurityEventController(SecurityEventService securityEventService) {
		this.securityEventService = securityEventService;
	}

	@IsUserOrDevice
	@RequestMapping(method = RequestMethod.GET, path = "/activity")
	public PagedResponse<SecurityEvent> getEvents(
			@Valid CursorPageable query, @AuthenticationPrincipal Object principal) {
		return securityEventService.getAll(principal, query);
	}
}
