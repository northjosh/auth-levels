package northjosh.auth.controllers.webauthn;

import com.yubico.webauthn.*;
import com.yubico.webauthn.data.*;
import com.yubico.webauthn.exception.RegistrationFailedException;
import jakarta.transaction.Transactional;
import northjosh.auth.repo.WebAuthnChallengeRepo;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.repo.webauthn.WebAuthnCredential;
import northjosh.auth.repo.webauthn.WebAuthnCredentialRepo;
import northjosh.auth.services.WebAuthnChallengeService;
import northjosh.auth.services.JwtService;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;

import java.security.SecureRandom;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/webauthn")
@Transactional
public class WebAuthnController {
    private final RelyingParty rp;
    private final WebAuthnCredentialRepo webAuthnCredentialRepo;
    private final UserRepo userRepo;
    private final WebAuthnChallengeService webAuthnChallengeService;
    private final JwtService jwtService;
    private final WebAuthnChallengeRepo webAuthnChallengeRepo;
    private static final SecureRandom random = new SecureRandom();

    public WebAuthnController(
            RelyingParty rp,
            WebAuthnCredentialRepo webAuthnCredentialRepo,
            UserRepo userRepo,
            WebAuthnChallengeService webAuthnChallengeService,
            JwtService jwtService, WebAuthnChallengeRepo webAuthnChallengeRepo) {
        this.rp = rp;
        this.webAuthnCredentialRepo = webAuthnCredentialRepo;
        this.userRepo = userRepo;
        this.webAuthnChallengeService = webAuthnChallengeService;
        this.jwtService = jwtService;
        this.webAuthnChallengeRepo = webAuthnChallengeRepo;
    }

    @PostMapping("/register/options")
    public ResponseEntity<PublicKeyCredentialCreationOptions> start(@RequestHeader("Authorization") String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String token = authHeader.substring(7);

        if (jwtService.isPendingToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String email = jwtService.getUsername(token);
        User user = userRepo.findByEmail(email);

        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

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

        PublicKeyCredentialCreationOptions cleanPkco = PublicKeyCredentialCreationOptions.builder()
                .rp(pkco.getRp())
                .user(pkco.getUser())
                .challenge(pkco.getChallenge())
                .pubKeyCredParams(pkco.getPubKeyCredParams())
                .timeout(pkco.getTimeout())
                .excludeCredentials(pkco.getExcludeCredentials())
                .authenticatorSelection(pkco.getAuthenticatorSelection())
                .attestation(pkco.getAttestation())
                .build();

        webAuthnChallengeService.store(email, cleanPkco);

        return ResponseEntity.ok(cleanPkco);
    }


    @PostMapping("/register")
    public ResponseEntity<Map<String, String>> finish(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody PublicKeyCredential<AuthenticatorAttestationResponse, ClientRegistrationExtensionOutputs> response) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String token = authHeader.substring(7);

        if (jwtService.isPendingToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String email = jwtService.getUsername(token);
        PublicKeyCredentialCreationOptions options = webAuthnChallengeService.getChallenge(email);
        webAuthnChallengeRepo.deleteByEmail(email);

        RegistrationResult result;

        try {
            result = rp.finishRegistration(FinishRegistrationOptions.builder()
                    .request(options)
                    .response(response)
                    .build());
        } catch (RegistrationFailedException e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Invalid Credentials"));
        }

        User user = userRepo.findByEmail(email);

        WebAuthnCredential cred = WebAuthnCredential.builder()
                .user(user)
                .credentialId(result.getKeyId().getId().getBytes())
                .publicKeyCose(result.getPublicKeyCose().getBytes())
                .signatureCount(result.getSignatureCount())
                .userHandle(user.getUserId())
                .build();
        user.getCredentials().add(cred);

        userRepo.save(user);

        return ResponseEntity.ok(Map.of("message", "WebAuthn credential registered successfully"));
    }

    @GetMapping("/credentials")
    public ResponseEntity<List<Map<String, Object>>> getCredentials(@RequestHeader("Authorization") String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String token = authHeader.substring(7);

        if (jwtService.isPendingToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String email = jwtService.getUsername(token);
        User user = userRepo.findByEmail(email);

        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        List<Map<String, Object>> credentials = user.getCredentials().stream()
                .map(cred -> Map.<String, Object>of(
                        "id", cred.getId(),
                        "credentialId", java.util.Base64.getEncoder().encodeToString(cred.getCredentialId()),
                        "signatureCount", cred.getSignatureCount()))
                .toList();

        return ResponseEntity.ok(credentials);
    }

    @DeleteMapping("/credentials/{credentialId}")
    public ResponseEntity<Map<String, String>> deleteCredential(
            @RequestHeader("Authorization") String authHeader, @PathVariable Long credentialId) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String token = authHeader.substring(7);

        if (jwtService.isPendingToken(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String email = jwtService.getUsername(token);
        User user = userRepo.findByEmail(email);

        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        WebAuthnCredential credential = webAuthnCredentialRepo.findById(credentialId).orElse(null);
        if (credential == null || !credential.getUser().getId().equals(user.getId())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Credential not found"));
        }

        webAuthnCredentialRepo.delete(credential);
        return ResponseEntity.ok(Map.of("message", "WebAuthn credential deleted successfully"));
    }


}
