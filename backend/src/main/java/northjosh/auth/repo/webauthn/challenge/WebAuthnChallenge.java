package northjosh.auth.repo.webauthn.challenge;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
import lombok.Data;

@Entity
@Table(name = "registration_challenges")
@Data
public class WebAuthnChallenge {

	@Id
	@GeneratedValue(strategy = GenerationType.AUTO)
	private UUID id;

	@Column(nullable = false)
	private String email;

	@Column(nullable = false, columnDefinition = "TEXT")
	private String challengeJson;

	@Column(nullable = false)
	private Instant expiresAt;
}
