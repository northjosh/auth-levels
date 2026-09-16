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

	@OneToOne
	private User user;

	@Column(nullable = false)
	private String otp;

	@Column(nullable = false)
	private int attempts = 0;

	@Column(nullable = false, unique = true)
	private String requestId;

	@Embedded
	@Column(nullable = false)
	private ClientInfo clientInfo;

	@CreationTimestamp
	private LocalDateTime createdAt;

	@UpdateTimestamp
	private LocalDateTime updatedAt;

	public void incrementAttempts() {
		this.attempts++;
	}

	public boolean isExhausted() {
		return this.attempts == 3;
	}

	private LocalDateTime getExpiresAt() {
		return this.createdAt.plusMinutes(2);
	}
}
