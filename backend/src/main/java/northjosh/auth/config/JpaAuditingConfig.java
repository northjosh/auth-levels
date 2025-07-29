/* This code contains copyright information which is the proprietary property
 *  of Terydin Incorporated. No part of this code may be reproduced,
 *  stored or transmitted in any form without the prior written permission of Terydin.
 *  Copyright © Terydin Incorporated (C) 2024-2025.
 *  Confidential. All rights reserved.
 */
package northjosh.auth.config;

import io.jsonwebtoken.Jwt;
import java.util.Optional;
import northjosh.auth.services.jwt.JwtService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.AuditorAware;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {

	@Bean
	public AuditorAware<String> auditorProvider(JwtService jwtService) {
		return () -> {
			Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
			if (authentication != null && authentication.isAuthenticated()) {
				String username = authentication.getName();
				if (authentication.getPrincipal() instanceof Jwt jwt && jwt.getBody() != null) {
					username = jwtService.getUsername(jwt.toString());
				}
				return Optional.of(username);
			} else {
				return Optional.of("system");
			}
		};
	}
}
