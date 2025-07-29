package northjosh.auth.controllers;

import jakarta.validation.Valid;
import java.util.Map;
import northjosh.auth.dto.*;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.auth.AuthService;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.totp.TotpService;
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

	@Autowired
	public AuthController(
			AuthService authService,
			JwtService jwtService,
			TotpService totpService,
			UserRepo userRepo,
			ModelMapper modelMapper) {
		this.authService = authService;
		this.jwtService = jwtService;
		this.totpService = totpService;
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
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
		User user = userRepo.findByEmail(email);

		System.out.println(user);
		if (user == null) {
			throw new RuntimeException("Unauthorized");
		}

		UserDto userDto = modelMapper.map(user, UserDto.class);
		userDto.setWebAuthnEnabled(!user.getCredentials().isEmpty());

		return userDto;
	}

	@PostMapping("/verify-totp")
	public ResponseEntity<?> verifyTotp(@RequestBody @Valid TotpRequest request) {
		String email = jwtService.getUsername(request.getPendingToken());

		User user = userRepo.findByEmail(email);

		boolean isTotpValid = false;

		try {
			isTotpValid = totpService.verifyCode(user, Integer.parseInt(request.getCode()));
		} catch (NumberFormatException ex) {
			isTotpValid = totpService.isBackupCodeValid(user, request.getCode());
		}

		if (!isTotpValid) {
			return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid TOTP or backup code");
		}

		String jwt = jwtService.generateToken(user.getEmail(), false);

		return ResponseEntity.ok(Map.of("token", jwt));
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
		User user = userRepo.findByEmail(email);

		String secret = totpService.generateSecret();
		user.setTotpSecret(secret);
		user.setTotpEnabled(true);
		userRepo.save(user);

		String qrUrl = totpService.getQRCodeUrl(user.getEmail(), secret);

		return new TotpResponse(qrUrl, secret);
	}

	@PostMapping("/disable-totp")
	public ResponseEntity<Map<String, String>> disableTOTP(@RequestHeader("Authorization") String authHeader) {
		if (authHeader == null || !authHeader.startsWith("Bearer ")) {
			return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
		}

		String token = authHeader.substring(7);

		if (jwtService.isPendingToken(token)) {
			throw new IllegalStateException("Unauthorized");
		}
		String email = jwtService.getUsername(token);
		User user = userRepo.findByEmail(email);

		if (user == null) {
			return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
		}

		user.setTotpSecret(null);
		user.setTotpEnabled(false);
		userRepo.save(user);

		return ResponseEntity.ok(Map.of("message", "TOTP disabled successfully"));
	}
}
