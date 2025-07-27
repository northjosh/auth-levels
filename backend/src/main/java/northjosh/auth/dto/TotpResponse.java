package northjosh.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class TotpResponse {

	private String qrUrl;
	private String secret;
}
