package northjosh.auth.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.core.io.DefaultResourceLoader;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class FirebaseConfig {

	@Bean
	public FirebaseApp fireBaseApp() {

		try {
			ResourceLoader resourceLoader = new DefaultResourceLoader();
			Resource resource = resourceLoader.getResource(
					"classpath:/auth-levels-northjosh-firebase-adminsdk-fbsvc-7fac400e42.json");

			FileInputStream serviceAccount = new FileInputStream(resource.getFile());

			FirebaseOptions options = FirebaseOptions.builder()
					.setCredentials(GoogleCredentials.fromStream(serviceAccount))
					.build();
			return FirebaseApp.initializeApp(options);

		} catch (FileNotFoundException e) {
			log.error("Firebase Config Not Found");
			throw new IllegalStateException("No Firebase Config");
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}
}
