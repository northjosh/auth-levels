package northjosh.auth.repo.event;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface SecurityEventRepo extends JpaRepository<SecurityEvent, String> {}
