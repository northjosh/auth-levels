package northjosh.auth.repo.webauthn;

import java.util.List;
import java.util.Optional;
import northjosh.auth.repo.user.User;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WebAuthnCredentialRepo extends JpaRepository<WebAuthnCredential, Long> {
	Optional<WebAuthnCredential> findByCredentialId(byte[] credentialId);

	List<WebAuthnCredential> findAllByUser(User user);
}
