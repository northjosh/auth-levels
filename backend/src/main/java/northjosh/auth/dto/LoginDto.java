package northjosh.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class LoginDto {

	@Email
	@NotNull private String email;

	@NotNull @NotBlank
	private String password;
}
