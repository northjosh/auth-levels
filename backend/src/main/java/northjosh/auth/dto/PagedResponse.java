package northjosh.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class PagedResponse<T> {
	private List<T> data;
	private String next;
	private String previous;

	@JsonProperty("count")
	public int getCount() {
		return data.size();
	}
	;

	@JsonProperty("hasNext")
	public boolean hasNext() {
		return next != null;
	}

	@JsonProperty("hasPrev")
	public boolean hasPrev() {
		return previous != null;
	}
}
