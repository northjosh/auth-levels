package northjosh.auth.repo.event;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import lombok.Generated;
import lombok.Getter;
import lombok.Setter;
import northjosh.auth.repo.user.User;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.LastModifiedBy;
import org.springframework.data.annotation.LastModifiedDate;

@Entity
@Getter
@Setter
@Table
public class SecurityEvent {

	@Id
	@Generated
	@UuidGenerator
	private String id;

	@ManyToOne
	private User user;

	@Column
	private String userAgentFamily;

	@Column
	private ActivityType type;

	@Column
	private Method method;

	@Column(columnDefinition = "json")
	@JdbcTypeCode(SqlTypes.JSON)
	private Map<String, String> details = new HashMap<>();

	@Column
	private String osFamily;

	@Column
	private String deviceFamily;

	@Column
	private String remoteAddress;

	@Column
	@LastModifiedBy
	private String lastModifiedBy;

	@Column
	@CreatedBy
	private String createdBy;

	@CreationTimestamp
	private Instant createdAt;

	@Column
	@LastModifiedDate
	private Instant lastModifiedAt;

	public enum ActivityType {
		LOGIN_SUCCESS,
		LOGIN_FAILURE,
		SIGNUP,
		EMAIL_VERIFIED,
		TOTP_ENABLED,
		TOTP_ACTIVATED,
		TOTP_DISABLED,
		RECOVERY_CODES_GENERATED,
		RECOVERY_CODE_USED,
		PASSKEY_ADDED,
		PASSKEY_REMOVED,
		PASSWORD_RESET_REQUESTED,
		PASSWORD_RESET_COMPLETED,
		PUSH_REQUEST_CREATED,
		PUSH_ATTEMPT_FAILED,
		PUSH_ATTEMPTS_EXCEEDED,
		PUSH_REQUEST_DENIED,
		TRUSTED_DEVICE_PAIRED,
		TRUSTED_DEVICE_REMOVED,
		TOTP_ATTEMPT_FAILED;
	}

	public enum Method {
		PASSWORD,
		TOTP,
		RECOVERY_CODE,
		PASSKEY,
		MAGIC_LINK,
		PUSH;
	}
}
