package northjosh.auth.services.webauthn;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.yubico.webauthn.data.PublicKeyCredentialCreationOptions;
import com.yubico.webauthn.data.PublicKeyCredentialRequestOptions;
import jakarta.persistence.NoResultException;
import jakarta.transaction.Transactional;
import java.time.Instant;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.webauthn.challenge.WebAuthnChallenge;
import northjosh.auth.repo.webauthn.challenge.WebAuthnChallengeRepo;
import org.springframework.stereotype.Component;

@Component
@Transactional
public class WebAuthnChallengeService {
	private final ObjectMapper objectMapper;
	private final WebAuthnChallengeRepo webAuthnChallengeRepo;

	public WebAuthnChallengeService(ObjectMapper objectMapper, WebAuthnChallengeRepo webAuthnChallengeRepo) {
		this.objectMapper = objectMapper;
		this.webAuthnChallengeRepo = webAuthnChallengeRepo;
	}

	public void store(String email, PublicKeyCredentialCreationOptions options) {
		try {
			storeChallenge(email, objectMapper.writeValueAsString(options));
		} catch (JsonProcessingException e) {
			throw new RuntimeException("Failed to serialize challenge");
		}
	}

	public void storeLoginChallenge(String email, PublicKeyCredentialRequestOptions options) {
		try {
			storeChallenge(email, objectMapper.writeValueAsString(options));
		} catch (JsonProcessingException e) {
			throw new RuntimeException("Failed to serialize challenge");
		}
	}

	private void storeChallenge(String email, String options) throws JsonProcessingException {
		WebAuthnChallenge challenge = new WebAuthnChallenge();
		challenge.setEmail(email);
		challenge.setChallengeJson(options);
		challenge.setExpiresAt(Instant.now().plusSeconds(300));
		webAuthnChallengeRepo.deleteByEmail(email);
		webAuthnChallengeRepo.save(challenge);
	}

	public PublicKeyCredentialCreationOptions getChallenge(String email) {
		WebAuthnChallenge challenge =
				webAuthnChallengeRepo.findByEmail(email).orElseThrow(() -> new NoResultException("No challenge found"));

		if (challenge.getExpiresAt().isBefore(Instant.now())) {
			webAuthnChallengeRepo.deleteById(challenge.getId());
			throw new WebAuthnException("Challenge expired. Try again.");
		}

		try {
			return objectMapper.readValue(challenge.getChallengeJson(), PublicKeyCredentialCreationOptions.class);
		} catch (JsonProcessingException e) {
			throw new RuntimeException("Failed to deserialize challenge", e);
		}
	}

	public PublicKeyCredentialRequestOptions getLoginChallenge(String challengeStr) {
		WebAuthnChallenge challenge = webAuthnChallengeRepo
				.findByEmail(challengeStr)
				.orElseThrow(() -> new NoResultException("No challenge found"));

		if (challenge.getExpiresAt().isBefore(Instant.now())) {
			webAuthnChallengeRepo.deleteById(challenge.getId());
			throw new WebAuthnException("Challenge expired. Try again.");
		}
		try {
			return objectMapper.readValue(challenge.getChallengeJson(), PublicKeyCredentialRequestOptions.class);
		} catch (JsonProcessingException e) {
			throw new RuntimeException("Failed to deserialize challenge", e);
		}
	}
}
