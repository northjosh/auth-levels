package northjosh.auth.repo.totp;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;
import northjosh.auth.repo.user.User;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.LastModifiedBy;

@Entity
@Table(name = "user_totp")
@Getter
@Setter
public class Totp {
	@Id
	@UuidGenerator
	@GeneratedValue
	private String id;

	@OneToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "user_id", unique = true, nullable = false, insertable = false, updatable = false)
	private User user;

	@Column
	private String secret;

	@Column
	@Enumerated(EnumType.STRING)
	private TotpStatus status;

	@Column
	private int lastUsedStep = 0;

	@CreatedBy
	@Column(updatable = false)
	private String createdBy;

	@LastModifiedBy
	@Column
	private String lastModifiedBy;

	@CreationTimestamp
	@Column(updatable = false)
	private LocalDateTime createdAt;

	@UpdateTimestamp
	@Column
	private LocalDateTime updatedAt;

	public enum TotpStatus {
		PENDING,
		ACTIVE,
		INACTIVE
	}
}
