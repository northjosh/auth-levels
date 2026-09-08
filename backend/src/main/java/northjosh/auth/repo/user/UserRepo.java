package northjosh.auth.repo.user;

import java.util.Optional;

import jakarta.validation.constraints.Email;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UserRepo extends JpaRepository<User, Long> {

	Optional<User> findByEmail(String email);

	Optional<User> findByUserId(byte[] userId);

	boolean existsByEmail(@Email String email);
}
