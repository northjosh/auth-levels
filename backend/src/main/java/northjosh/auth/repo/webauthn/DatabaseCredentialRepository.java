package northjosh.auth.repo.webauthn;

import com.yubico.webauthn.CredentialRepository;
import com.yubico.webauthn.RegisteredCredential;
import com.yubico.webauthn.data.ByteArray;
import com.yubico.webauthn.data.PublicKeyCredentialDescriptor;
import com.yubico.webauthn.data.PublicKeyCredentialType;
import java.util.Arrays;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserRepo;
import org.springframework.stereotype.Component;

@Component
public class DatabaseCredentialRepository implements CredentialRepository {

	final UserRepo userRepo;
	final WebAuthnCredentialRepo webAuthnCredentialRepo;

	public DatabaseCredentialRepository(UserRepo userRepo, WebAuthnCredentialRepo webAuthnCredentialRepo) {
		this.userRepo = userRepo;
		this.webAuthnCredentialRepo = webAuthnCredentialRepo;
	}

	@Override
	public Set<PublicKeyCredentialDescriptor> getCredentialIdsForUsername(String email) {
		System.out.println(email);

		System.out.println(userRepo.findByEmail(email));

		return userRepo.findByEmail(email).getCredentials().stream()
				.map(cred -> PublicKeyCredentialDescriptor.builder()
						.id(new ByteArray(cred.getCredentialId()))
						.transports(Optional.ofNullable(null))
						.type(PublicKeyCredentialType.PUBLIC_KEY)
						.build())
				.collect(Collectors.toSet());
	}

	@Override
	public Optional<ByteArray> getUserHandleForUsername(String email) {
		return Optional.of(userRepo.findByEmail(email)).map(user -> new ByteArray(user.getUserId()));
	}

	@Override
	public Optional<String> getUsernameForUserHandle(ByteArray userHandle) {
		return userRepo.findByUserId(userHandle.getBytes()).map(User::getEmail);
	}

	@Override
	public Optional<RegisteredCredential> lookup(ByteArray credentialId, ByteArray userHandle) {
		return webAuthnCredentialRepo
				.findByCredentialId(credentialId.getBytes())
				.filter(c -> Arrays.equals(c.getUserHandle(), userHandle.getBytes()))
				.map(c -> RegisteredCredential.builder()
						.credentialId(new ByteArray(c.getCredentialId()))
						.userHandle(new ByteArray(c.getUserHandle()))
						.publicKeyCose(new ByteArray(c.getPublicKeyCose()))
						.signatureCount(c.getSignatureCount())
						.build());
	}

	@Override
	public Set<RegisteredCredential> lookupAll(ByteArray credentialId) {
		return webAuthnCredentialRepo
				.findByCredentialId(credentialId.getBytes())
				.map(c -> Set.of(RegisteredCredential.builder()
						.credentialId(new ByteArray(c.getCredentialId()))
						.userHandle(new ByteArray(c.getUserHandle()))
						.publicKeyCose(new ByteArray(c.getPublicKeyCose()))
						.signatureCount(c.getSignatureCount())
						.build()))
				.orElse(Set.of());
	}
}
