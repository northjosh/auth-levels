package northjosh.auth.repo.device;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.*;
import northjosh.auth.repo.user.User;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

@Entity
@Table
@Getter
@Setter
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class TrustedDevice {
	@Id
	@GeneratedValue
	@UuidGenerator
	private String id;

	@ManyToOne(fetch = FetchType.LAZY)
	private User user;

	@Column
	private Status status;

	@Column
	private String enrollmentToken;

	@Column
	private String name;

	@Column
	private boolean pushEnabled = true;

	@Column
	private Platform platform;

	@Column
	private String appVersion;

	@Column
	private String deviceTokenHash;

	@Column
	private String fcmToken;

	@Column
	@CreationTimestamp
	private LocalDateTime createdAt;

	@Column
	@UpdateTimestamp
	private LocalDateTime updatedAt;

	@Column
	private LocalDateTime lastSeenAt;

	@Column
	private LocalDateTime pairedAt;

	public enum Status {
		PENDING("pending"),
		ACTIVE("active"),
		DELETED("deleted");

		private final String name;

		Status(String name) {
			this.name = name;
		}

		public String getName() {
			return this.name;
		}

		public static Status fromString(String name) {
			for (Status status : Status.values()) {
				if (status.name().equalsIgnoreCase(name)) {
					return status;
				}
			}
			return Status.PENDING;
		}
	}

	public enum Platform {
		ANDROID("ios"),
		IOS("ios");

		Platform(String platform) {}
	}
}
