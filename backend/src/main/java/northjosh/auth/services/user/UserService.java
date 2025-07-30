package northjosh.auth.services.user;

import com.yubico.webauthn.RegistrationResult;
import jakarta.transaction.Transactional;
import java.util.Map;

import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserAdapter;
import northjosh.auth.repo.user.UserRepo;
import northjosh.auth.repo.webauthn.WebAuthnCredential;
import org.modelmapper.ModelMapper;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@Transactional
public class UserService implements UserDetailsService {

	private final UserRepo userRepo;
	private final ModelMapper modelMapper;

	public UserService(UserRepo userRepo, ModelMapper modelMapper) {
		this.userRepo = userRepo;
		this.modelMapper = modelMapper;
	}

	@Override
	public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
		User existing = get(email);
		return new UserAdapter(existing);
	}

	public User get(String email) throws EmptyResultDataAccessException {
		return userRepo.findByEmail(email)
				.orElseThrow(() -> new EmptyResultDataAccessException("User with email " + email + " not found", 1));
	}

	public User updateUser(Map<String, Object> updates) {
		User user = get(updates.get("email").toString());

		modelMapper.map(updates, user);

		return userRepo.save(user);
	}

	public void deleteUser(String email) {
		User existing = get(email);
		userRepo.delete(existing);
	}

	public User findUserByCredentialId(String credentialId) {
		return userRepo.findAll().stream()
				.filter(user -> user.getCredentials().stream().anyMatch(cred -> java.util.Base64.getUrlEncoder()
						.withoutPadding()
						.encodeToString(cred.getCredentialId())
						.equals(credentialId)))
				.findFirst()
				.orElseThrow(() -> new WebAuthnException("Credentials not Found."));
	}

	public void addCredential(String email, RegistrationResult result) {
		User user = get(email);

		WebAuthnCredential cred = WebAuthnCredential.builder()
				.user(user)
				.credentialId(result.getKeyId().getId().getBytes())
				.publicKeyCose(result.getPublicKeyCose().getBytes())
				.signatureCount(result.getSignatureCount())
				.userHandle(user.getUserId())
				.build();

		user.getCredentials().add(cred);

		userRepo.save(user);
	}

	public void updateSignatureCount(String credentialId, long newSignatureCount) {
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
