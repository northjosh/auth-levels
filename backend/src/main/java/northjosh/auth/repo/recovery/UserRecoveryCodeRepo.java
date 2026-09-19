package northjosh.auth.repo.recovery;

import northjosh.auth.repo.user.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface UserRecoveryCodeRepo extends JpaRepository<RecoveryCode, String> {

	void deleteByUser(User user);

	@Modifying
	@Query(value = """
		UPDATE user_recovery_code
		SET used_at = now()
		where user_id = :userId and code_hash = :code
		""", nativeQuery = true)
	int markUsed(Long userId, String code);
}
