/* This code contains copyright information which is the proprietary property
 *  of Terydin Incorporated. No part of this code may be reproduced,
 *  stored or transmitted in any form without the prior written permission of Terydin.
 *  Copyright © Terydin Incorporated (C) 2024-2025.
 *  Confidential. All rights reserved.
 */
package northjosh.auth.config;

import java.util.Optional;
import northjosh.auth.services.jwt.JwtService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.AuditorAware;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {

	@Bean
	public AuditorAware<String> auditorProvider(JwtService jwtService) {
		return () -> {
			Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
			if (authentication instanceof AnonymousAuthenticationToken) return Optional.of("system");
			Object a = authentication == null ? null : authentication.getPrincipal();

			if (a instanceof DevicePrincipal device)
				return Optional.of(device.getUser().getEmail()); // watch out for a lazy initialization exception

			if (a instanceof String email) return Optional.of(email);
			return Optional.of("system");
		};
	}
}
