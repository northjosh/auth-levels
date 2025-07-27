package northjosh.auth.dto;

import lombok.Data;

@Data
public class UserDto {
	private Long id;
	private String firstName;
	private String lastName;
	private String email;
	private boolean totpEnabled;
	private String totpUrl;
	private boolean webAuthnEnabled;
}
