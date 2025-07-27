package northjosh.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SignUpDto {
	@NotNull private String firstName;

	@NotNull private String lastName;

	@Email
	private String email;

	@NotNull private String password;

	private boolean totpEnabled;
}
