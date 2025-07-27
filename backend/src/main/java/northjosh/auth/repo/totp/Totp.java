package northjosh.auth.repo.totp;

import jakarta.persistence.*;
import java.util.List;

@Entity
public class Totp {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;

	private String secret;

	@ElementCollection
	private List<String> backupCodes;
}
