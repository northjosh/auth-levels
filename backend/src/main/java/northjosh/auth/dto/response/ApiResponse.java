package northjosh.auth.dto.response;

import java.io.Serial;
import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class ApiResponse<T> implements Serializable {
	@Serial
	private static final long serialVersionUID = -1915951285920732398L;

	private int code;

	private String message;

	private T data;
}
