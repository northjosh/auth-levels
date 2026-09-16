package northjosh.auth.dto;

import java.util.Map;
import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class FcmMessage {
	private String title;
	private String body;
	private Map<String, String> data;
}
