package northjosh.auth.services;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.yubico.webauthn.data.PublicKeyCredentialCreationOptions;
import com.yubico.webauthn.data.PublicKeyCredentialRequestOptions;
import jakarta.transaction.Transactional;
import northjosh.auth.repo.WebAuthnChallenge;
import northjosh.auth.repo.WebAuthnChallengeRepo;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.UUID;

@Component
@Transactional
public class WebAuthnChallengeService {
    private final ObjectMapper objectMapper;
    private final WebAuthnChallengeRepo webAuthnChallengeRepo;
 

    public WebAuthnChallengeService(ObjectMapper objectMapper, WebAuthnChallengeRepo webAuthnChallengeRepo) {
        this.objectMapper = objectMapper;
        this.webAuthnChallengeRepo = webAuthnChallengeRepo;
    }

    public UUID store(String email, PublicKeyCredentialCreationOptions options) {
        try {
            String json = objectMapper.writeValueAsString(options);
            WebAuthnChallenge challenge = new WebAuthnChallenge();
            challenge.setEmail(email);
            challenge.setChallengeJson(json);
            challenge.setExpiresAt(Instant.now().plusSeconds(300));
            webAuthnChallengeRepo.deleteByEmail(email);
            WebAuthnChallenge saved = webAuthnChallengeRepo.save(challenge);
            return saved.getId();

        } catch (JsonProcessingException e) {
            throw new RuntimeException("Failed to serialize challenge", e);
        }

    }

    public UUID storeloginChallenge(String email, PublicKeyCredentialRequestOptions options) {
        try {
            String json = objectMapper.writeValueAsString(options);
            WebAuthnChallenge challenge = new WebAuthnChallenge();
            challenge.setEmail(email);
            challenge.setChallengeJson(json);
            challenge.setExpiresAt(Instant.now().plusSeconds(300));
            webAuthnChallengeRepo.deleteByEmail(email);
            WebAuthnChallenge saved = webAuthnChallengeRepo.save(challenge);
            return saved.getId();

        } catch (JsonProcessingException e) {
            throw new RuntimeException("Failed to serialize challenge", e);
        }

    }

    public PublicKeyCredentialCreationOptions getChallenge(String email) {
        WebAuthnChallenge challenge = webAuthnChallengeRepo.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("No challenge found"));

        if (challenge.getExpiresAt().isBefore(Instant.now())) {
            webAuthnChallengeRepo.deleteById(challenge.getId());
            throw new IllegalStateException("Challenge expired. Try again.");
        }

        try {
            return objectMapper.readValue(challenge.getChallengeJson(), PublicKeyCredentialCreationOptions.class);
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Failed to deserialize challenge", e);
        }
    }
    public PublicKeyCredentialRequestOptions getLoginChallenge(String challengeStr) {
        WebAuthnChallenge challenge = webAuthnChallengeRepo.findByEmail(challengeStr)
                .orElseThrow(() -> new IllegalStateException("No challenge found"));

        if (challenge.getExpiresAt().isBefore(Instant.now())) {
            webAuthnChallengeRepo.deleteById(challenge.getId());
            throw new IllegalStateException("Challenge expired. Try again.");
        }

        try {
            return objectMapper.readValue(challenge.getChallengeJson(), PublicKeyCredentialRequestOptions.class);
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Failed to deserialize challenge", e);
        }
    }


}
