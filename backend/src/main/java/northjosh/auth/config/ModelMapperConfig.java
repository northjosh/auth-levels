package northjosh.auth.config;

import org.modelmapper.ModelMapper;
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
