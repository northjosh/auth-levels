package northjosh.auth.config;

import northjosh.auth.dto.response.PushAuthDto;
import northjosh.auth.repo.pushauth.PushAuth;
import northjosh.auth.repo.user.User;
import org.modelmapper.ModelMapper;
import org.modelmapper.PropertyMap;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ModelMapperConfig {

	@Bean
	public ModelMapper modelMapper() {
		ModelMapper mapper = new ModelMapper();
		mapper.getConfiguration().setSkipNullEnabled(true);

//		PropertyMap<PushAuth, PushAuthDto> pushAuthMap = new PropertyMap<>() {
//			@Override
//			protected void configure() {
//				map().setId(source.getRequestId());
//				map().setCreatedAt(source.getCreatedAt());
//			}
//		};
//
//		mapper.addMappings(pushAuthMap);
		return mapper;
	}
}
