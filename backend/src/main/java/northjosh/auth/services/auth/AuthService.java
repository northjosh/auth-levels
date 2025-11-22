package northjosh.auth.services.auth;

import northjosh.auth.dto.AuthResponse;
import northjosh.auth.dto.LoginDto;
import northjosh.auth.dto.SignUpDto;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.totp.TotpService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

	final UserRepo userRepo;
	final ModelMapper modelMapper;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;
	private final TotpService totpService;
	private final UserService userService;

	public AuthService(
			UserRepo userRepo,
			ModelMapper modelMapper,
			PasswordEncoder passwordEncoder,
			JwtService jwtService,
			TotpService totpService,
			UserService userService) {
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.totpService = totpService;
		this.userService = userService;
	}

	public User signup(SignUpDto dto) {

		User newUser = new User();
		modelMapper.map(dto, newUser);
		newUser.setPassword(passwordEncoder.encode(dto.getPassword()));

		if (newUser.isTotpEnabled()) {
			newUser.setTotpSecret(totpService.generateSecret());
		}

		return userRepo.save(newUser);
	}

	public AuthResponse login(LoginDto dto) {
		User user = userService.get(dto.getEmail());

		if (!passwordEncoder.matches(dto.getPassword(), user.getPassword())) {
			throw new WebAuthnException("Invalid Credentials");
		}
		if (user.isTotpEnabled()) {
			String pendingToken = jwtService.generatePendingToken(user.getEmail());
			return new AuthResponse(pendingToken, true);
		} else {
			String accessToken = jwtService.generateAccessToken(user.getEmail());
			return new AuthResponse(accessToken, false);
		}
	}
}
