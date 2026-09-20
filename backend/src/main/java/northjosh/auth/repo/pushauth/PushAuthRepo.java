package northjosh.auth.repo.pushauth;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PushAuthRepo extends JpaRepository<PushAuth, String> {

	Optional<PushAuth> findPushAuthByRequestId(String requestId);

	List<PushAuth> findAllByUserEmail(String email);

	void deletePushAuthByRequestId(String requestId);

	void deletePushAuthByCreatedAtBefore(Instant createdAt);
}
