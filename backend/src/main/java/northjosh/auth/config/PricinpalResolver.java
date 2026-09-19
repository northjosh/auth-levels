package northjosh.auth.config;

import northjosh.auth.exceptions.AuthException;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.nio.file.AccessDeniedException;

@Component("principalResolver")
public class PricinpalResolver {

    public boolean isUser(Authentication authentication) {
        return authentication.getPrincipal() instanceof String;
    }

    public String requireEmail(){
        Authentication authentication =  SecurityContextHolder.getContext().getAuthentication();

        if (authentication == null
                || authentication instanceof AnonymousAuthenticationToken) {
            throw new AuthException("Authentication required");
        }

        if (authentication.getPrincipal() instanceof DevicePrincipal) {
            throw new AuthException(
                    "This endpoint requires a user access token");
        }

        if (authentication.getPrincipal() instanceof String email) {
            return email;
        }
    }

    public DevicePrincipal requireDevice(){
        Authentication authentication =  SecurityContextHolder.getContext().getAuthentication();

        if (authentication == null
                || authentication instanceof AnonymousAuthenticationToken) {
            throw new AccessDeniedException("Authentication required");
        }

        if (authentication.getPrincipal() instanceof String) {
            throw new AccessDeniedException(
                    "This endpoint requires a user access token");
        }

        if (authentication.getPrincipal() instanceof DevicePrincipal device) {
            return device;
        }

    }

    public boolean isDevice(Authentication authentication) {
        return isAuthenticated(authentication) && authentication.getPrincipal() instanceof DevicePrincipal;
    }

    public boolean isUserOrDevice(Authentication authentication) {
        return  isAuthenticated(authentication) && isUser(authentication) || isDevice(authentication);
    }

    private boolean isAuthenticated(Authentication authentication){
        return authentication.isAuthenticated();
    }
}
