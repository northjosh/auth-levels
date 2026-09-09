package northjosh.auth.services.recovery;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.repo.recovery.RecoveryCode;
import northjosh.auth.repo.recovery.UserRecoveryCodeRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.user.UserService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class RecoveryCodeService {
	private final UserService userService;
	private static final SecureRandom RAND = new SecureRandom();
	private static final String ALPHABETS = "abcdefghjklmnpqrstuvwxyz23456789";
	public UserRecoveryCodeRepo userRecoveryCodeRepo;
	public PasswordEncoder passwordEncoder;

	public RecoveryCodeService(UserRecoveryCodeRepo userRecoveryCodeRepo, UserService userService) {
		this.userRecoveryCodeRepo = userRecoveryCodeRepo;
		this.userService = userService;
	}

	public List<String> generateRecoveryCode(String username) {
		User user = userService.get(username);
		List<String> plain = new ArrayList<>(10);
		List<RecoveryCode> codes = new ArrayList<>(10);

		log.info("Generating recovery code for user {}", username);

		for (int i = 0; i < 10; i++) {
			String code = ran(10);
			plain.add(code);
			codes.add(new RecoveryCode(user, passwordEncoder.encode(normalize(code)))); // simple encoding for now
		}

		userRecoveryCodeRepo.deleteByUser(user);
		userRecoveryCodeRepo.saveAll(codes);
		log.info("Generated recovery code for user {}", username);

		return plain;
	}

	public boolean useRecoveryCode(String username, String code) {
		log.info("Trying to use recovery code for user {}", username);
		User user = userService.get(username);
		String hashed_code = passwordEncoder.encode(normalize(code));
		return userRecoveryCodeRepo.markUsed(user.getId(), hashed_code) == 1;
	}

	private String ran(int len) {
		StringBuilder sb = new StringBuilder();
		for (int i = 0; i < len; i++) {
			if (i > 0 && i % 4 == 0) sb.append('-');
			sb.append(ALPHABETS.charAt(RAND.nextInt(ALPHABETS.length())));
		}

		return sb.toString();
	}

	private String normalize(String code) {
		return code.toUpperCase().replace("-", "").trim();
	}
}
