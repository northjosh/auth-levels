package northjosh.auth.repo.event;

import org.jspecify.annotations.NonNull;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

@Repository
public interface SecurityEventRepo
		extends JpaRepository<SecurityEvent, String>, JpaSpecificationExecutor<SecurityEvent> {

	@Override
	@EntityGraph(attributePaths = "user")
	Page<SecurityEvent> findAll(Specification spec,
                                @NonNull Pageable pageable);
}
