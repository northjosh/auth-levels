package northjosh.auth.repo.webauthn;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.*;
import northjosh.auth.repo.user.User;

@Entity
@Table(name = "webauthn_credentials")
@AllArgsConstructor
@NoArgsConstructor
@Builder(access = AccessLevel.PUBLIC)
@Data
public class WebAuthnCredential {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;

	@ManyToOne(optional = false)
	@JoinColumn(name = "user_id")
	@ToString.Exclude
	private User user;

	@Column(nullable = false, unique = true)
	private byte[] credentialId;

	@Column(nullable = false)
	private byte[] publicKeyCose;

	@Column(nullable = false)
	private long signatureCount;

	@Column(nullable = false)
	private byte[] userHandle;
}
