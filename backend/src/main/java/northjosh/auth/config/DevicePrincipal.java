package northjosh.auth.config;

import lombok.AllArgsConstructor;
import lombok.Data;
import northjosh.auth.repo.user.User;

@Data
@AllArgsConstructor
public class DevicePrincipal {
	private String id;
	private User user;
}
