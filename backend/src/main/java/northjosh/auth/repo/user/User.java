package northjosh.auth.repo.user;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.*;
import northjosh.auth.repo.totp.Totp;
import northjosh.auth.repo.webauthn.WebAuthnCredential;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.LastModifiedBy;

@Entity
@Table(name = "users")
@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class User {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;

	@Column
	@NotNull private String firstName;

	@Column
	@NotNull private String lastName;

	@Column(unique = true)
	@NotNull private String email;

	@Column(nullable = false, unique = true)
	private byte[] userId;

	@PrePersist
	public void generateUserHandle() {
		if (userId == null) {
			SecureRandom random = new SecureRandom();
			userId = new byte[32];
			random.nextBytes(userId);
		}
	}

	@NotNull @Column
	private String password;

	@Column
	private String totpSecret;

	@Column
	private boolean totpEnabled;

	@OneToOne(cascade = CascadeType.ALL)
	private Totp totpSettings;

	@OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.EAGER, orphanRemoval = true)
	private List<WebAuthnCredential> credentials = new ArrayList<>();

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
}
