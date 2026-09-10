package northjosh.auth.repo.totp;

import northjosh.auth.repo.user.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TotpRepo extends JpaRepository<Totp, String> {
	Totp findByUser(User user);

	@Modifying
	@Transactional
	@Query(
			value = """
			UPDATE user_totp SET last_used_step = :matched
			WHERE user_id = :id
			AND last_used_step = :lastUsed""",
					nativeQuery = true)
	int updateLastUsedStep(@Param("id") Long id, @Param("matched") Long matched, @Param("lastUsed") int lastUsed);
}
