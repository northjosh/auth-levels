package northjosh.auth.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class ResetPasswordDto {
    @NotNull
    private String token;

    @NotBlank
    private String password;

    @NotBlank
    private String confirmPassword;

    // password validation
    @AssertTrue(message = "passwords must match")
    public boolean passwordsMatch() {
        return password.equals(confirmPassword);
    }
}

