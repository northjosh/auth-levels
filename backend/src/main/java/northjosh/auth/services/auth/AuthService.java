package northjosh.auth.services.auth;

import io.jsonwebtoken.Claims;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.*;
import northjosh.auth.event.ActivityEvent;
import northjosh.auth.exceptions.AuthException;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.event.SecurityEvent;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.email.EmailService;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.totp.TotpService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@Transactional
public class AuthService {

	final UserRepo userRepo;
	final ModelMapper modelMapper;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;
	private final UserService userService;
	private final EmailService emailService;
	private final ApplicationEventPublisher applicationEventPublisher;
	private final TotpService totpService;

	public AuthService(
			UserRepo userRepo,
			ModelMapper modelMapper,
			PasswordEncoder passwordEncoder,
			JwtService jwtService,
			UserService userService,
			EmailService emailService,
			ApplicationEventPublisher applicationEventPublisher,
			TotpService totpService) {
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.userService = userService;
		this.emailService = emailService;
		this.applicationEventPublisher = applicationEventPublisher;
		this.totpService = totpService;
	}

	public User signup(SignUpDto dto, ClientInfo info) {

		if (userRepo.existsByEmail(dto.getEmail())) {
			log.info("Account with email {} already exists", dto.getEmail());
			throw new AuthException(HttpStatus.CONFLICT, "User with email already exists");
		}
		User newUser = new User();
		modelMapper.map(dto, newUser);
		newUser.setPassword(passwordEncoder.encode(dto.getPassword()));

		log.info("New user {} has been created", newUser.getEmail());
		logActivity(newUser.getEmail(), info, SecurityEvent.ActivityType.SIGNUP, null);
		User saved = userRepo.saveAndFlush(newUser);

		String token = jwtService.generateVerificationToken(saved.getEmail());
		emailService.sendVerifyEmail(saved.getEmail(), token);
		return saved;
	}

	public AuthResponse login(LoginDto dto, ClientInfo info) {
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
			logActivity(user.getEmail(), info, SecurityEvent.ActivityType.LOGIN_SUCCESS, SecurityEvent.Method.PASSWORD);
			return new AuthResponse(accessToken, false);
		}
	}

	public String totpLogin(TotpRequest request, ClientInfo info) {
		String email = jwtService.getUsername(request.getPendingToken());

		User user = userService.get(email);

		boolean isTotpValid;

		try {
			isTotpValid = totpService.verifyCode(user, Integer.parseInt(request.getCode()), info);
		} catch (NumberFormatException ex) {
			isTotpValid = totpService.isBackupCodeValid(user, request.getCode(), info);
		}

		if (!isTotpValid) {
			throw new WebAuthnException("Invalid TOTP or backup code");
		}
		String jwt = jwtService.generateAccessToken(user.getEmail());
		logActivity(email, info, SecurityEvent.ActivityType.LOGIN_SUCCESS, SecurityEvent.Method.TOTP);
		return jwt;
	}

	public String loginMagic(String pendingToken, ClientInfo info) {
		if (!jwtService.isVerificationToken(pendingToken)) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "Invalid Token");
		}
		String email = jwtService.getUsername(pendingToken);
		String token = jwtService.generateAccessToken(email);
		logActivity(email, info, SecurityEvent.ActivityType.LOGIN_SUCCESS, SecurityEvent.Method.MAGIC_LINK);

		return token;
	}

	public void requestPasswordReset(String email, ClientInfo info) {
		Optional<User> user = userService.getByEmail(email);
		if (user.isEmpty()) return;
		User existing = user.get();
		String token = jwtService.generateResetToken(existing.getEmail());
		emailService.sendResetEmail(existing.getEmail(), token);
		log.info("Reset Password request for user: {}", email);
		logActivity(existing.getEmail(), info, SecurityEvent.ActivityType.PASSWORD_RESET_REQUESTED, null);
	}

	public void resetPassword(ResetPasswordDto dto, ClientInfo info) {
		Claims claims = jwtService.decodeToken(dto.getToken());
		String email = claims.get("email", String.class);
		User user = userService.get(email);
		user.setPassword(passwordEncoder.encode(dto.getPassword()));
		log.info("Reset password for user {}", user.getEmail());
		userRepo.save(user);
		logActivity(user.getEmail(), info, SecurityEvent.ActivityType.PASSWORD_RESET_COMPLETED, null);
	}

	public void verifyEmail(String token, ClientInfo info) {
		if (!jwtService.isVerificationToken(token)) {
			throw new WebAuthnException("Invalid Token");
		}
		String email = jwtService.getUsername(token);

		userService.updateUser(Map.of("email", email, "emailVerified", true));
		emailService.sendWelcomeEmail(email);
		logActivity(email, info, SecurityEvent.ActivityType.EMAIL_VERIFIED, null);
	}

	private void logActivity(
			String email, ClientInfo info, SecurityEvent.ActivityType type, SecurityEvent.Method method) {
		ActivityEvent event = new ActivityEvent();
		modelMapper.map(info, event);
		event.setMethod(method);
		event.setType(type);
		event.setEmail(email);
		event.setOccurredAt(Instant.now());

		applicationEventPublisher.publishEvent(event);
	}
}
