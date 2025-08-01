package northjosh.auth.controllers;

import jakarta.servlet.http.HttpServletRequest;
import northjosh.auth.dto.PushAuthResponse;
import northjosh.auth.dto.response.PushAuthDto;
import northjosh.auth.exceptions.WebAuthnException;
import northjosh.auth.repo.pushauth.ClientInfo;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.user.User;
import northjosh.auth.services.jwt.JwtService;
import northjosh.auth.services.otp.PushAuthService;
import northjosh.auth.services.user.UserService;
import org.modelmapper.ModelMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalTime;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

@RestController
@RequestMapping("/push")
public class PushAuthController {

    Executor sseExecutor = Executors.newCachedThreadPool();

    @Autowired
    private SseEmitters emitters;
    @Autowired
    private UserService userService;
    @Autowired
    private PushAuthService pushAuthService;
    @Autowired
    private ModelMapper modelMapper;
    @Autowired
    private JwtService jwtService;

    @GetMapping("/listen")
    public SseEmitter listen(@RequestParam String clientId, HttpServletRequest req) {

        ClientInfo clientInfo = new ClientInfo(req);

        SseEmitter emitter = new SseEmitter();
        sseExecutor.execute(() -> {
            try {
                for (int i = 0; true; i++) {
                    SseEmitter.SseEventBuilder event = SseEmitter.event()
                            .data("SSE MVC - %s ".formatted(clientInfo.getUserAgentFamily()) + LocalTime.now())
                            .id(String.valueOf(i))
                            .name("sse event - %s from".formatted(clientId));
                    emitter.send(event);
                    Thread.sleep(1000);
                }
            } catch (Exception ex) {
                emitter.completeWithError(ex);
            }
        });

        return emitter;
    }

    @GetMapping("/sse")
    public SseEmitter verify(@RequestParam String clientId) throws IOException {
        SseEmitter emitter = new SseEmitter(60L * 2000);

        String[] decoded = decode(clientId);

        String requestId = decoded[2];

        emitters.add(requestId, emitter);

        emitter.send(SseEmitter.event().data("Connection established"));
        
        emitter.onCompletion(() -> emitters.remove(requestId));
        emitter.onTimeout(() -> emitters.remove(requestId));

        return emitter;
    }

    @PostMapping("/generate")
    public PushAuthResponse push(@RequestBody Map<String, String> dto, HttpServletRequest request){

        String email = dto.get("email");

        User user = userService.get(email);

        PushAuth attempt = pushAuthService.createSession(user, request);

        return modelMapper.map(attempt, PushAuthResponse.class);
    }

    @PostMapping("/verify")
    public Map<String, String> verify( @RequestHeader("Authorization") String authHeader,@RequestBody Map<String, String> dto){
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            throw new WebAuthnException("Invalid Token");
        }
        String token = authHeader.substring(7);

        if (jwtService.isPendingToken(token)) {
            throw new WebAuthnException("Invalid Token");
        }

        pushAuthService.verify(dto);
        return Map.of("message", "Login Successful");
    }

    @GetMapping("/get")
    public List<PushAuthDto> get(@RequestHeader("Authorization") String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            throw new WebAuthnException("Invalid Token");
        }
        String token = authHeader.substring(7);

        if (jwtService.isPendingToken(token)) {
            throw new WebAuthnException("Invalid Token");
        }

        String email = jwtService.getUsername(token);

        return pushAuthService.getAll(email).stream().map(cred -> modelMapper.map(cred, PushAuthDto.class)).toList();
    }

    public static String[] decode(String base64Token) {
        String decoded = new String(Base64.getDecoder().decode(base64Token), StandardCharsets.UTF_8);
        // Expected format: auth_login_<sessionID>_<email>
        String[] parts = decoded.split("_", 4);

        if (parts.length != 4 || !parts[0].equals("auth") || !parts[1].equals("login")) {
            throw new IllegalArgumentException("Invalid token format");
        }

        return parts;
    }



}
