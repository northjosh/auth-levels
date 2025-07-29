package northjosh.auth.controllers;

import jakarta.validation.Valid;
import java.util.Map;
import northjosh.auth.dto.*;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.auth.AuthService;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.totp.TotpService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

	private final AuthService authService;

	private final JwtService jwtService;

	private final TotpService totpService;

	private final UserRepo userRepo;

	private final ModelMapper modelMapper;
	private final UserService userService;

	@Autowired
	public AuthController(
			AuthService authService,
			JwtService jwtService,
			TotpService totpService,
			UserRepo userRepo,
			ModelMapper modelMapper, UserService userService) {
		this.authService = authService;
		this.jwtService = jwtService;
		this.totpService = totpService;
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
		this.userService = userService;
	}

	@PostMapping("/login")
	public AuthResponse login(@RequestBody @Valid LoginDto login) {
		return authService.login(login);
	}

	@GetMapping("/me")
	public UserDto getCurrentUser(@RequestHeader("Authorization") String authHeader) {
		if (authHeader == null || !authHeader.startsWith("Bearer ")) {
			throw new RuntimeException("Unauthorized");
		}

		String token = authHeader.substring(7);

		if (jwtService.isPendingToken(token)) {
			throw new IllegalStateException("Unauthorized");
		}

		String email = jwtService.getUsername(token);
		User user = userService.get(email);

		UserDto userDto = modelMapper.map(user, UserDto.class);
		userDto.setWebAuthnEnabled(!user.getCredentials().isEmpty());

		return userDto;
	}

	@PostMapping("/verify-totp")
	public Map<String, Object> verifyTotp(@RequestBody @Valid TotpRequest request) {
		String email = jwtService.getUsername(request.getPendingToken());

		User user = userService.get(email);

		boolean isTotpValid = false;

		try {
			isTotpValid = totpService.verifyCode(user, Integer.parseInt(request.getCode()));
		} catch (NumberFormatException ex) {
			isTotpValid = totpService.isBackupCodeValid(user, request.getCode());
		}

		if (!isTotpValid) {
			throw new WebAuthnException("Invalid TOTP or backup code");
		}

		String jwt = jwtService.generateToken(user.getEmail());

		return Map.of("token", jwt);
	}

	@PostMapping("/signup")
	public UserDto signup(@RequestBody @Valid SignUpDto dto) {

		User newUser = authService.signup(dto);

		UserDto user = modelMapper.map(newUser, UserDto.class);

		if (dto.isTotpEnabled()) {
			String qrcode = totpService.getQRCodeUrl(newUser.getEmail(), newUser.getTotpSecret());
			user.setTotpUrl(qrcode);
		}

		return user;
	}

	@PostMapping("/enable-totp")
	public TotpResponse enableTOTP(
			@RequestHeader("Authorization") String authHeader, @RequestBody Map<String, String> request) {
		if (authHeader == null || !authHeader.startsWith("Bearer ")) {
			throw new RuntimeException("Unauthorized");
		}

		String token = authHeader.substring(7);

		String email = jwtService.getUsername(token);
		User user = userService.get(email);

		String secret = totpService.generateSecret();
		user.setTotpSecret(secret);
		user.setTotpEnabled(true);
		userRepo.save(user);

		String qrUrl = totpService.getQRCodeUrl(user.getEmail(), secret);

		return new TotpResponse(qrUrl, secret);
	}

	@PostMapping("/disable-totp")
	public Map<String, String> disableTOTP(@RequestHeader("Authorization") String authHeader) {
		if (authHeader == null || !authHeader.startsWith("Bearer ")) {
			throw new WebAuthnException("Invalid Token");
		}

		String token = authHeader.substring(7);

		if (jwtService.isPendingToken(token)) {
			throw new WebAuthnException("Invalid Token");
		}

		String email = jwtService.getUsername(token);
		User user = userService.get(email);
		user.setTotpSecret(null);
		user.setTotpEnabled(false);
		userRepo.save(user);

		return Map.of("message", "TOTP disabled successfully");
	}
}
