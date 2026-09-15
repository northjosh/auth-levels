package northjosh.auth.services;

import com.google.firebase.messaging.*;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.repo.device.TrustedDeviceRepo;
import org.slf4j.MDC;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class FCMService {

	private final TrustedDeviceRepo trustedDeviceRepo;

	public void sendMessage(String fcm, Map<String, String> data) {

		try {
			Message message = Message.builder()
					.putAllData(data)
					.setFid(fcm) // mobile apps need to send fid not fcm
					.setAndroidConfig(AndroidConfig.builder()
							.setPriority(AndroidConfig.Priority.HIGH)
							.setTtl(Duration.ofSeconds(120).toMillis())
							.setNotification(AndroidNotification.builder()
									.setTag(MDC.get("requestId"))
									.setTitle("Push Request")
									.setChannelId("push_requests")
									.build())
							.build())
					.build();
			FirebaseMessaging.getInstance().send(message);
		} catch (FirebaseMessagingException e) {
			//			if(e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED){
			//			}
			//
			//			if(e.getMessagingErrorCode() == MessagingErrorCode.SENDER_ID_MISMATCH){
			//
			//			}

			log.error("Error sending message to Firebase", e);
		}
	}

	public void sendBulkMessage(List<String> fcmIds, Map<String, String> data) {
		try {
			MulticastMessage message = MulticastMessage.builder()
					.putAllData(data)
					.addAllFids(fcmIds)
					.setAndroidConfig(AndroidConfig.builder()
							.setPriority(AndroidConfig.Priority.HIGH)
							.setTtl(Duration.ofSeconds(120).toMillis())
							.setNotification(AndroidNotification.builder()
									.setTag(MDC.get("requestId"))
									.setTitle("Push Request")
									.setChannelId("push_requests")
									.build())
							.build())
					.build();
			BatchResponse response = FirebaseMessaging.getInstance().sendEachForMulticast(message);
			if (response.getFailureCount() > 0) {
				List<SendResponse> responses = response.getResponses();
				List<String> failedFids = new ArrayList<>();
				for (int i = 0; i < responses.size(); i++) {
					if (!responses.get(i).isSuccessful()) {
						// The order of responses corresponds to the order of the destination FIDs.
						failedFids.add(fcmIds.get(i));
					}
				}
				log.info("List of FIDs that caused failures: {}", failedFids);
			}
		} catch (FirebaseMessagingException e) {
			log.error("Error sending message to Firebase", e);
		}
	}
}
