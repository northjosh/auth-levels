package northjosh.auth.services;

import com.resend.core.exception.ResendException;
import com.resend.services.emails.model.CreateEmailOptions;
import com.resend.services.emails.model.CreateEmailResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import com.resend.*;

@Slf4j
@Service
public class EmailService {

    private final Resend resend;
    private final String frontendUrl;

    public EmailService(@Value("${resend.apikey}") String resendKey, @Value("${frontend.url}") String frontendUrl){
    this.resend = new Resend(resendKey);
    this.frontendUrl = frontendUrl;
    }

    public void sendVerifyEmail(String recipient, String token) {
        String url = "%s/verify-email?token=%s".formatted(frontendUrl, token);
        String emailHtml = """
            <p>Please click the link below to verify your email:</p>
            <a href="%s">Verify Email</a>
            """.formatted(url);

        CreateEmailOptions params = CreateEmailOptions.builder()
                .from("Test <onboarding@resend.dev>")
                .to(recipient)
                .subject("Verify Your Email")
                .html(emailHtml)
                .build();
        try {
            CreateEmailResponse data = resend.emails().send(params);
            System.out.println(data.getId());

            log.info("{} Email Sent to {}", data.getId(), recipient);

        } catch (
                ResendException e) {
            log.error(e.getMessage());
        }
    }

    public void sendWelcomeEmail(String recipient) {

        String emailHtml = """
                  <p>Your email has now been verified</p>
                """;

        CreateEmailOptions params = CreateEmailOptions.builder()
                .from("Test <onboarding@resend.dev>")
                .to(recipient)
                .subject("Your Email has now been Verified")
                .html(emailHtml)
                .build();
        try {
            CreateEmailResponse data = resend.emails().send(params);
            System.out.println(data.getId());
            log.info("{} Welcome Email Sent to {}", data.getId(), recipient);
        } catch (
                ResendException e) {
            log.error(e.getMessage());
        }
    }
}
