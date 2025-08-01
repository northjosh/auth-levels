package northjosh.auth.dto;

import lombok.Data;

@Data
public class PushAuthResponse {
    private String otp;
    private String requestId;
    private String email;
    private UserDto user;
}
