package northjosh.auth.controllers;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import northjosh.auth.dto.*;
import northjosh.auth.interfaces.IsUser;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.totp.Totp;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.auth.AuthService;
import northjosh.auth.services.email.EmailService;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.totp.TotpService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
public class AuthController {

	private static final Logger log = LoggerFactory.getLogger(AuthController.class);
	private final AuthService authService;

	private final JwtService jwtService;

	private final TotpService totpService;

	private final UserRepo userRepo;

	private final ModelMapper modelMapper;
	private final UserService userService;
	private final EmailService emailService;

	@Autowired
	public AuthController(
			AuthService authService,
			JwtService jwtService,
			TotpService totpService,
			UserRepo userRepo,
			ModelMapper modelMapper,
			UserService userService,
			EmailService emailService) {
		this.authService = authService;
		this.jwtService = jwtService;
		this.totpService = totpService;
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
		this.userService = userService;
		this.emailService = emailService;
	}

	@PostMapping("/login")
	public AuthResponse login(@RequestBody @Valid LoginDto login, HttpServletRequest req) {
		return authService.login(login, new ClientInfo(req));
	}

	@GetMapping("/me")
	public UserDto getCurrentUser(@AuthenticationPrincipal String email) {
		User user = userService.get(email);
		UserDto userDto = modelMapper.map(user, UserDto.class);
		userDto.setWebAuthnEnabled(!user.getCredentials().isEmpty());
		return userDto;
	}

	@PostMapping("/verify-totp")
	public Map<String, Object> verifyTotp(@RequestBody @Valid TotpRequest request, HttpServletRequest req) {
		String jwt = authService.totpLogin(request, new ClientInfo(req));
		return Map.of("token", jwt);
	}

	@PostMapping("/verify-email")
	public Map<String, Object> verifyEmail(@RequestBody Map<String, String> request, HttpServletRequest req) {
		String token = request.get("pendingToken");
		authService.verifyEmail(token, new ClientInfo(req));
		return Map.of("message", "Email Verified");
	}

	@PostMapping("/signup")
	public UserDto signup(@RequestBody @Valid SignUpDto dto, HttpServletRequest req) {
		ClientInfo info = new ClientInfo(req);
		User newUser = authService.signup(dto, info);
		UserDto user = modelMapper.map(newUser, UserDto.class);

		return user;
	}

	// request magic link
	@PostMapping("/magic/request")
	public Map<String, String> request(@RequestBody LoginDto login) {

		User user;
		try {
			user = userService.get(login.getEmail());
		} catch (EmptyResultDataAccessException e) {
			return Map.of("message", "Check your email for link");
		}
		String token = jwtService.generatePendingToken(user.getEmail());
		emailService.sendVerifyEmail(user.getEmail(), token);
		return Map.of("message", "Check your email for link");
	}

	// verify magic link
	@PostMapping("/magic/verify")
	public Map<String, String> verify(@RequestBody Map<String, String> request, HttpServletRequest req) {

		String token = authService.loginMagic(request.get("pendingToken"), new ClientInfo(req));

		return Map.of("token", token);
	}

	@PostMapping("/enable-totp")
	public TotpResponse enableTOTP(@AuthenticationPrincipal String email, HttpServletRequest req) {
		ClientInfo info = new ClientInfo(req);

		User user = userService.get(email);
		log.info("Enabling TOTP for {}", user.getEmail());

		Totp secret = totpService.create(user);
		user.setTotpEnabled(true);
		userRepo.save(user);

		String qrUrl = totpService.getQRCodeUrl(user.getEmail(), secret.getSecret());

		return new TotpResponse(qrUrl, secret.getSecret());
	}

	@IsUser
	@PostMapping("/activate-totp")
	public List<String> enableTOTP(
			@AuthenticationPrincipal String email, @RequestBody Map<String, String> request, HttpServletRequest req) {
		ClientInfo info = new ClientInfo(req);

		int code = Integer.parseInt(request.get("code"));
		User user = userService.get(email);
		return totpService.activate(user, code, info);
	}

	@IsUser
	@PostMapping("/disable-totp")
	public Map<String, String> disableTOTP(@AuthenticationPrincipal String email, HttpServletRequest req) {
		ClientInfo info = new ClientInfo(req);

		totpService.deactivate(email, info);

		return Map.of("message", "TOTP disabled successfully");
	}

	@RequestMapping("/request-reset")
	public Map<String, Object> requestReset(@RequestBody Map<String, String> request, HttpServletRequest req) {
		ClientInfo info = new ClientInfo(req);
		authService.requestPasswordReset(request.get("email"), info);
		return Map.of("message", "Password reset initiated");
	}

	@RequestMapping("/reset-password")
	public Map<String, Object> resetPassword(@RequestBody @Valid ResetPasswordDto dto, HttpServletRequest req) {
		ClientInfo info = new ClientInfo(req);
		authService.resetPassword(dto, info);
		return Map.of("message", "Password reset, you may login.");
	}
}
