package northjosh.auth.controllers.webauthn;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.yubico.webauthn.*;
import com.yubico.webauthn.data.*;
import com.yubico.webauthn.exception.AssertionFailedException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Optional;
import northjosh.auth.dto.AuthResponse;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.webauthn.WebAuthnChallengeService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/webauthn/auth")
public class WebAuthnAuthController {

	private final RelyingParty relyingParty;
	private final WebAuthnChallengeService challengeService;
	private final UserRepo userRepo;
	private final JwtService jwtService;

	public WebAuthnAuthController(
			RelyingParty relyingParty,
			WebAuthnChallengeService challengeService,
			UserRepo userRepo,
			JwtService jwtService) {
		this.relyingParty = relyingParty;
		this.challengeService = challengeService;
		this.userRepo = userRepo;
		this.jwtService = jwtService;
	}

	@PostMapping("/options")
	public ResponseEntity<Map<String, Object>> getAuthenticationOptions(
			@RequestBody(required = false) Map<String, String> request) {
		try {
			StartAssertionOptions.StartAssertionOptionsBuilder optionsBuilder = StartAssertionOptions.builder();

			if (request != null && request.containsKey("email")) {
				String email = request.get("email");
				User user = userRepo.findByEmail(email);
				if (user != null && !user.getCredentials().isEmpty()) {
					// Get user's credentials and add them as allowed credentials
					optionsBuilder.userHandle(Optional.of(new ByteArray(user.getUserId())));
				}
			}

			optionsBuilder.userVerification(UserVerificationRequirement.PREFERRED);

			StartAssertionOptions startOptions = optionsBuilder.build();
			AssertionRequest assertionRequest = relyingParty.startAssertion(startOptions);
			PublicKeyCredentialRequestOptions requestOptions = assertionRequest.getPublicKeyCredentialRequestOptions();

			// Store challenge for verification - use challenge as key
			String challengeB64 = requestOptions.getChallenge().getBase64Url();
			challengeService.storeLoginChallenge(challengeB64, requestOptions);

			return ResponseEntity.ok(Map.of("data", requestOptions));

		} catch (Exception e) {
			return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
					.body(Map.of("error", "Failed to generate authentication options: " + e.getMessage()));
		}
	}

	@PostMapping("/verify")
	public ResponseEntity<AuthResponse> verifyAuthentication(@RequestBody String credentialJson) {
		try {

			PublicKeyCredential<AuthenticatorAssertionResponse, ClientAssertionExtensionOutputs> credential =
					PublicKeyCredential.parseAssertionResponseJson(credentialJson);

			String clientDataStr =
					new String(credential.getResponse().getClientDataJSON().getBytes(), StandardCharsets.UTF_8);
			String challengeB64 = extractChallengeFromClientData(clientDataStr);

			PublicKeyCredentialRequestOptions storedOptions = challengeService.getLoginChallenge(challengeB64);
			System.out.println("Options: " + storedOptions);

			AssertionRequest assertionRequest = AssertionRequest.builder()
					.publicKeyCredentialRequestOptions(storedOptions)
					.build();

			User user = findUserByCredentialId(credential.getId().getBase64Url());
			if (user == null) {
				return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
						.body(new AuthResponse("Credential not found", false));
			}
			System.out.println("User found " + user.getFirstName());

			// Create finish assertion options
			FinishAssertionOptions finishOptions = FinishAssertionOptions.builder()
					.request(assertionRequest)
					.response(credential)
					.build();

			// Verify the assertion
			AssertionResult result = relyingParty.finishAssertion(finishOptions);
			System.out.println("Assertion Error here");

			if (result.isSuccess()) {
				// Update signature count in database
				updateSignatureCount(credential.getId().getBase64Url(), result.getSignatureCount());

				// Generate JWT token
				String token = jwtService.generateToken(user.getEmail(), false);

				return ResponseEntity.ok(new AuthResponse(token, false));
			} else {
				return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
						.body(new AuthResponse("Authentication failed", false));
			}

		} catch (AssertionFailedException e) {
			return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
					.body(new AuthResponse("Failed: " + e.getMessage(), false));
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	private String extractChallengeFromClientData(String clientDataJSON) {
		try {
			ObjectMapper mapper = new ObjectMapper();
			JsonNode root = mapper.readTree(clientDataJSON);
			return root.get("challenge").asText();
		} catch (Exception e) {
			throw new RuntimeException("Could not extract challenge from clientData", e);
		}
	}

	private User findUserByCredentialId(String credentialId) {
		return userRepo.findAll().stream()
				.filter(user -> user.getCredentials().stream().anyMatch(cred -> java.util.Base64.getUrlEncoder()
						.withoutPadding()
						.encodeToString(cred.getCredentialId())
						.equals(credentialId)))
				.findFirst()
				.orElse(null);
	}

	private void updateSignatureCount(String credentialId, long newSignatureCount) {
		userRepo.findAll().stream()
				.flatMap(user -> user.getCredentials().stream())
				.filter(cred -> java.util.Base64.getUrlEncoder()
						.withoutPadding()
						.encodeToString(cred.getCredentialId())
						.equals(credentialId))
				.findFirst()
				.ifPresent(cred -> {
					cred.setSignatureCount(newSignatureCount);
					userRepo.save(cred.getUser());
				});
	}
}
