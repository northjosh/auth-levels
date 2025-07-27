package northjosh.auth.dto;

import lombok.Data;

@Data
public class TotpRequest {
	private String pendingToken;
	private String code;
}
