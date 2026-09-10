package northjosh.auth.repo.recovery;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import northjosh.auth.repo.user.User;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.LastModifiedBy;

@Entity
@Table(name = "user_recovery_codes")
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class RecoveryCode {

	@Id
	@GeneratedValue
	@UuidGenerator
	private String id;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "user_id", nullable = false)
	private User user;

	@Column(name = "code_hash")
	private String code;

	@Column
	private Instant usedAt;

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

	public RecoveryCode(User user, String code) {
		this.user = user;
		this.code = code;
	}
}
