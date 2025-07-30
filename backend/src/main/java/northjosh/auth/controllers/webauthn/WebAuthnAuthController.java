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
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.AuthResponse;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.user.UserService;
import northjosh.auth.services.webauthn.WebAuthnChallengeService;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/webauthn/auth")
public class WebAuthnAuthController {

	private final RelyingParty relyingParty;
	private final WebAuthnChallengeService challengeService;
	private final JwtService jwtService;
	private final UserService userService;

	public WebAuthnAuthController(
			RelyingParty relyingParty,
			WebAuthnChallengeService challengeService,
			JwtService jwtService,
			UserService userService) {
		this.relyingParty = relyingParty;
		this.challengeService = challengeService;
		this.jwtService = jwtService;
		this.userService = userService;
	}

	@PostMapping("/options")
	public Map<String, Object> getAuthenticationOptions(@RequestBody(required = false) Map<String, String> request) {
		try {
			StartAssertionOptions.StartAssertionOptionsBuilder optionsBuilder = StartAssertionOptions.builder();

			if (request != null && request.containsKey("email")) {
				String email = request.get("email");
				User user = userService.get(email);
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

			return Map.of("data", requestOptions);

		} catch (Exception e) {
			throw new RuntimeException("Failed to generate authentication options: " + e.getMessage());
		}
	}

	@PostMapping("/verify")
	public AuthResponse verifyAuthentication(@RequestBody String credentialJson) {
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

			User user = userService.findUserByCredentialId(credential.getId().getBase64Url());

			// Create finish assertion options
			FinishAssertionOptions finishOptions = FinishAssertionOptions.builder()
					.request(assertionRequest)
					.response(credential)
					.build();

			// Verify the assertion
			AssertionResult result = relyingParty.finishAssertion(finishOptions);

			if (result.isSuccess()) {
				// Update signature count in database
				userService.updateSignatureCount(credential.getId().getBase64Url(), result.getSignatureCount());

				// Generate JWT token
				String token = jwtService.generateAccessToken(user.getEmail());

				return new AuthResponse(token, false);
			} else {
				throw new WebAuthnException("Authentication Failed");
			}

		} catch (AssertionFailedException e) {
			throw new WebAuthnException("Invalid Credentials " + e.getMessage());
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
}
