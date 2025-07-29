package northjosh.auth.services.user;

import jakarta.transaction.Transactional;
import java.util.Map;
import northjosh.auth.repo.user.User;
import northjosh.auth.repo.user.UserAdapter;
import northjosh.auth.repo.user.UserRepo;
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

	User get(String email) throws EmptyResultDataAccessException {
		return userRepo.findByEmail(email)
				.orElseThrow(() -> new EmptyResultDataAccessException("User with email " + email + " not found", 1));
	}

	public User updateUser(Map<String, String> updates) {
		User user = get(updates.get("email"));
		modelMapper.map(updates, user);

		return userRepo.save(user);
	}

	public void deleteUser(String email) {
		User existing = get(email);

		userRepo.delete(existing);
	}
}
