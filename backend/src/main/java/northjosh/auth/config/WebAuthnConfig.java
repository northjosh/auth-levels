package northjosh.auth.config;

import com.yubico.webauthn.RelyingParty;
import com.yubico.webauthn.data.RelyingPartyIdentity;
import java.util.Set;
import northjosh.auth.repo.webauthn.DatabaseCredentialRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class WebAuthnConfig {
	@Bean
	public RelyingParty relyingParty(DatabaseCredentialRepository credentialRepository) {
		RelyingPartyIdentity rpIdentity = RelyingPartyIdentity.builder()
				.id("localhost")
				.name("Auth Levels Demo")
				.build();

		return RelyingParty.builder()
				.identity(rpIdentity)
				.credentialRepository(credentialRepository)
				.origins(Set.of("http://localhost:3000"))
				.allowUntrustedAttestation(true)
				.build();
	}
}
