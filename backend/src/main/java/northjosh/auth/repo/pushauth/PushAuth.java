package northjosh.auth.repo.pushauth;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;
import northjosh.auth.repo.user.User;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

@Entity
@Table
@Getter
@Setter
public class PushAuth {

	@Id
	@GeneratedValue
	@UuidGenerator
	private String id;

	@Column(nullable = false)
	private String otp;

	@Column(nullable = false, unique = true)
	private String requestId;

	@OneToOne
	private User user;

	@CreationTimestamp
	private LocalDateTime createdAt;

	@UpdateTimestamp
	private LocalDateTime updatedAt;
}
