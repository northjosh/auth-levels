package northjosh.auth.repo.webauthn.challenge;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface WebAuthnChallengeRepo extends JpaRepository<WebAuthnChallenge, UUID> {
	Optional<WebAuthnChallenge> findByEmail(String email);

	void deleteByEmail(String email);
}
