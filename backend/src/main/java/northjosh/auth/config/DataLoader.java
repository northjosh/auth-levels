package northjosh.auth.config;

import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class DataLoader implements CommandLineRunner {
	@Autowired
	private UserRepo userRepo;

	@Autowired
	private PasswordEncoder encoder;

	@Override
	public void run(String... args) {
		User user = new User();
		user.setEmail("test@example.com");
		user.setFirstName("Man");
		user.setLastName("Dem");
		user.setTotpEnabled(true);
		user.setPassword(encoder.encode("password123"));
		userRepo.save(user);
	}
}
