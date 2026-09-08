package northjosh.auth.services.auth;

import io.jsonwebtoken.Claims;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.AuthResponse;
import northjosh.auth.dto.LoginDto;
import northjosh.auth.dto.ResetPasswordDto;
import northjosh.auth.dto.SignUpDto;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.email.EmailService;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.totp.TotpService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class AuthService {

	final UserRepo userRepo;
	final ModelMapper modelMapper;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;
	private final TotpService totpService;
	private final UserService userService;
	private final EmailService emailService;

	public AuthService(
			UserRepo userRepo,
			ModelMapper modelMapper,
			PasswordEncoder passwordEncoder,
			JwtService jwtService,
			TotpService totpService,
			UserService userService,
			EmailService emailService) {
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.totpService = totpService;
		this.userService = userService;
		this.emailService = emailService;
	}

	public User signup(SignUpDto dto) {

		if (userRepo.existsByEmail(dto.getEmail())) {
			log.info("Account with email {} already exists", dto.getEmail());
			throw new AuthException(HttpStatus.CONFLICT, "User with email already exists");
		}

		User newUser = new User();
		modelMapper.map(dto, newUser);
		newUser.setPassword(passwordEncoder.encode(dto.getPassword()));

		if (newUser.isTotpEnabled()) {
			newUser.setTotpSecret(totpService.generateSecret());
		}

		log.info("New user {} has been created", newUser);

		return userRepo.save(newUser);
	}

	public AuthResponse login(LoginDto dto) {
		User user = userService.get(dto.getEmail());

		if (!passwordEncoder.matches(dto.getPassword(), user.getPassword())) {
			log.warn("Invalid password");
			throw new AuthException(HttpStatus.BAD_REQUEST, "Invalid Credentials");
		}
		if (user.isTotpEnabled()) {
			String pendingToken = jwtService.generatePendingToken(user.getEmail());
			return new AuthResponse(pendingToken, true);
		} else {
			String accessToken = jwtService.generateAccessToken(user.getEmail());
			return new AuthResponse(accessToken, false);
		}
	}

	public void requestPasswordReset(String email) {
		Optional<User> user = userService.getByEmail(email);
		if (user.isEmpty()) return;
		User existing = user.get();
		String token = jwtService.generateResetToken(existing.getEmail());
		emailService.sendResetEmail(existing.getEmail(), token);
		log.info("Reset Password request for user: {}", email);
	}

	public void resetPassword(ResetPasswordDto dto) {
		Claims claims = jwtService.decodeToken(dto.getToken());
		String email = claims.get("email", String.class);
		User user = userService.get(email);
		user.setPassword(passwordEncoder.encode(dto.getPassword()));
		log.info("Reset password for user {}", user.getEmail());

		userRepo.save(user);
	}
}
