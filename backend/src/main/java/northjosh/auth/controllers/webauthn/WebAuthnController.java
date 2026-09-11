package northjosh.auth.controllers.webauthn;

import com.yubico.webauthn.*;
import com.yubico.webauthn.data.*;
import com.yubico.webauthn.exception.RegistrationFailedException;
import jakarta.persistence.NoResultException;
import java.util.List;
import java.util.Map;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.webauthn.WebAuthnCredential;
import northjosh.auth.repo.webauthn.WebAuthnCredentialRepo;
import northjosh.auth.repo.webauthn.challenge.WebAuthnChallengeRepo;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.user.UserService;
import northjosh.auth.services.webauthn.WebAuthnChallengeService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/webauthn")
public class WebAuthnController {
	private final RelyingParty rp;
	private final WebAuthnCredentialRepo webAuthnCredentialRepo;
	private final WebAuthnChallengeService webAuthnChallengeService;
	private final WebAuthnChallengeRepo webAuthnChallengeRepo;
	private final UserService userService;

	public WebAuthnController(
			RelyingParty rp,
			WebAuthnCredentialRepo webAuthnCredentialRepo,
			WebAuthnChallengeService webAuthnChallengeService,
			WebAuthnChallengeRepo webAuthnChallengeRepo,
			UserService userService) {
		this.rp = rp;
		this.webAuthnCredentialRepo = webAuthnCredentialRepo;
		this.webAuthnChallengeService = webAuthnChallengeService;
		this.webAuthnChallengeRepo = webAuthnChallengeRepo;
		this.userService = userService;
	}

	@PostMapping("/register/options")
	public PublicKeyCredentialCreationOptions start(@AuthenticationPrincipal String email) {
		User user = userService.get(email);

		StartRegistrationOptions options = StartRegistrationOptions.builder()
				.user(UserIdentity.builder()
						.name(user.getEmail())
						.displayName(user.getFirstName() + " " + user.getLastName())
						.id(new ByteArray(user.getUserId()))
						.build())
				.authenticatorSelection(AuthenticatorSelectionCriteria.builder()
						.residentKey(ResidentKeyRequirement.REQUIRED)
						.userVerification(UserVerificationRequirement.PREFERRED)
						.build())
				.build();

		PublicKeyCredentialCreationOptions pkco = rp.startRegistration(options);

		webAuthnChallengeService.store(user.getEmail(), pkco);

		return pkco;
	}

	@PostMapping("/register")
	public Map<String, String> finish(
			@AuthenticationPrincipal String email,
			@RequestBody
					PublicKeyCredential<AuthenticatorAttestationResponse, ClientRegistrationExtensionOutputs>
							response) {
		PublicKeyCredentialCreationOptions options = webAuthnChallengeService.getChallenge(email);
		webAuthnChallengeRepo.deleteByEmail(email);

		RegistrationResult result;

		try {
			result = rp.finishRegistration(FinishRegistrationOptions.builder()
					.request(options)
					.response(response)
					.build());
		} catch (RegistrationFailedException e) {
			throw new RuntimeException("Registration Failed. Invalid Credentials");
		}

		userService.addCredential(email, result);

		return Map.of("message", "WebAuthn credential registered successfully");
	}

	@GetMapping("/credentials")
	public List<Map<String, Object>> getCredentials(@AuthenticationPrincipal String email) {
		User user = userService.get(email);

		return user.getCredentials().stream()
				.map(cred -> Map.<String, Object>of(
						"id", cred.getId(),
						"credentialId", java.util.Base64.getEncoder().encodeToString(cred.getCredentialId()),
						"signatureCount", cred.getSignatureCount()))
				.toList();
	}

	@DeleteMapping("/credentials/{credentialId}")
	public Map<String, String> deleteCredential(
			@AuthenticationPrincipal String email, @PathVariable Long credentialId) {
		User user = userService.get(email);

		WebAuthnCredential credential =
				webAuthnCredentialRepo.findById(credentialId).orElse(null);
		if (credential == null || !credential.getUser().getId().equals(user.getId())) {
			throw new NoResultException("Credential Not Found");
		}

		webAuthnCredentialRepo.delete(credential);
		return Map.of("message", "WebAuthn credential deleted successfully");
	}

}
