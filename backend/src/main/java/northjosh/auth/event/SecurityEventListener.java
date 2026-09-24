package northjosh.auth.event;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.repo.event.SecurityEvent;
import northjosh.auth.repo.event.SecurityEventRepo;
import northjosh.auth.services.email.EmailService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Slf4j
@Component
@RequiredArgsConstructor
public class SecurityEventListener {
	private final SecurityEventRepo repo;
	private final ModelMapper modelMapper;
	private final UserService userService;
	private final EmailService emailService;

	@Transactional(propagation = Propagation.REQUIRES_NEW)
	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
	public void processEvent(ActivityEvent event) {
		log.info("Logging activity for User {}", event.getEmail());

		SecurityEvent sec = new SecurityEvent();
		modelMapper.map(event, sec);
		sec.setUser(userService.get(event.getEmail()));
		log.info("{}", sec);

		repo.save(sec);
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
	public void notify(ActivityEvent event) {
		log.info("Firing Email activity for User {}", event.getEmail());
		//		emailService.sendResetEmail(event.getEmail(), event.getDeviceFamily());
	}
}
