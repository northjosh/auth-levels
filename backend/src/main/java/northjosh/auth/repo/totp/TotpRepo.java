package northjosh.auth.repo.totp;

import northjosh.auth.repo.user.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TotpRepo extends JpaRepository<Totp, String> {
	Totp findByUser(User user);

	@Modifying
	@Query(
			value = "UPDATE user_totp " + "SET last_used_step = :matched"
					+ "WHERE user_id = :id  "
					+ "AND last_used_step = :lastUsed"
					+ "")
	int updateLastUsedStep(@Param("id") String id, @Param("matched") Long matched, @Param("lastUsed") int lastUsed);
}
