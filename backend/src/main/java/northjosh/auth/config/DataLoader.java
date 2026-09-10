package northjosh.auth.config;

import lombok.AllArgsConstructor;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@AllArgsConstructor
public class DataLoader implements CommandLineRunner {
	private UserRepo userRepo;

	private PasswordEncoder encoder;

	@Override
	public void run(String... args) {
		User user = new User();
		user.setEmail("test@example.com");
		user.setFirstName("Man");
		user.setLastName("Dem");
		user.setTotpEnabled(false);
		user.setPassword(encoder.encode("password123"));
		userRepo.save(user);
	}
}
