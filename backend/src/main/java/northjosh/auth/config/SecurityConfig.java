package northjosh.auth.config;

import java.util.Arrays;
import java.util.List;
import lombok.AllArgsConstructor;
import northjosh.auth.services.user.UserService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
@AllArgsConstructor
public class SecurityConfig {

	private UserService userService;

	@Bean
	public PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder();
	}

	@Bean
	public SecurityFilterChain filterChain(
			HttpSecurity http, AuthEntryPoint authEntryPoint, CustomAccessDeniedHandler customAccessDeniedHandler)
			throws Exception {

		http.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth.requestMatchers(
								"/auth/signup", "/auth/login", "/login", "/auth/verify-totp", "/auth/verify-email")
						.permitAll()
						.requestMatchers(
								"/auth/me",
								"/auth/request-reset",
								"/auth/reset-password",
								"/push/**",
								"/auth/enable-totp",
								"/auth/disable-totp",
								"/webauthn/**")
						.permitAll()
						.anyRequest()
						.authenticated())
				.formLogin(Customizer.withDefaults())
				.httpBasic(Customizer.withDefaults());
		//				.logout(Customizer.withDefaults())
		http.exceptionHandling(
				ex -> ex.authenticationEntryPoint(authEntryPoint).accessDeniedHandler(customAccessDeniedHandler));

		return http.build();
	}

	@Bean
	public UrlBasedCorsConfigurationSource corsConfigurationSource() {
		CorsConfiguration configuration = new CorsConfiguration();
		configuration.setAllowedOriginPatterns(List.of("*"));
		configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
		configuration.setAllowedHeaders(Arrays.asList("Authorization", "Content-Type"));
		configuration.setAllowCredentials(true);
		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
		source.registerCorsConfiguration("/**", configuration);
		return source;
	}

	@Bean
	public AuthenticationManager authenticationManager(
			UserDetailsService userDetailsService, PasswordEncoder passwordEncoder) {
		DaoAuthenticationProvider provider = new DaoAuthenticationProvider(userDetailsService);
		provider.setPasswordEncoder(passwordEncoder());

		return new ProviderManager(provider);
	}

	//	@Bean
	//	public CorsConfigurationSource prodCorsConfig(@Value("${cors.origins}") String origins){
	//		CorsConfiguration cors = new CorsConfiguration();
	//		cors.setAllowedOrigins(List.of(origins));
	//		cors.setAllowedMethods(List.of("GET", "OPTIONS", "POST", "DELETE", "PATCH"));
	//		cors.setAllowedHeaders(List.of("Baggage", "Allow-Encoding")); // whatever
	//		cors.setAllowCredentials(true);
	//		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
	//		source.registerCorsConfiguration("/**", cors);
	//		return source;
	//	}

	//	@Bean
	//	public AuthenticationProvider authenticationProvider() {
	//		DaoAuthenticationProvider provider = new DaoAuthenticationProvider(userService);
	//		provider.setPasswordEncoder(passwordEncoder());
	//		return provider;
	//	}
}
