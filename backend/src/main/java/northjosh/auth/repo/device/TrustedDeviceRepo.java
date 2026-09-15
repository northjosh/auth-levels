package northjosh.auth.repo.device;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
public interface TrustedDeviceRepo extends JpaRepository<TrustedDevice, String> {
	List<TrustedDevice> findAllByUser_Email(@NotNull String email);

	List<TrustedDevice> findAllByUser_EmailAndStatusIs(@NotNull String email, TrustedDevice.Status status);

	@Transactional
	@Modifying(clearAutomatically = true)
	@Query("UPDATE TrustedDevice d SET d.pushEnabled = NOT d.pushEnabled WHERE d.id = :id")
	int togglePushEnabled(String id);

	@Transactional
	@Modifying(clearAutomatically = true)
	@Query("UPDATE TrustedDevice d SET d.fcmToken = :token WHERE d.id = :id")
	int updateFcm(String id, String token);

	Optional<TrustedDevice> findByDeviceTokenHashAndStatusIs(String token, TrustedDevice.Status status);

	void deleteByDeviceTokenHash(String tokenHash);

	int deleteByEnrollmentExpiresAtBeforeAndStatus(LocalDateTime cutoff, TrustedDevice.Status status);
}
