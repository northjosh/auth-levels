package northjosh.auth.repo.user;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UserRepo extends JpaRepository<User, Long> {

	User findByEmail(String email);

	Optional<User> findByUserId(byte[] userId);
}
