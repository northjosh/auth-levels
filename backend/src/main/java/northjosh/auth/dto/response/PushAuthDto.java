package northjosh.auth.dto.response;

import lombok.Data;
import northjosh.auth.repo.user.User;
import ua_parser.Client;

import java.time.LocalDateTime;

@Data
public class PushAuthDto {
    private String requestId;
    private String email;
    private LocalDateTime createdAt;
}
