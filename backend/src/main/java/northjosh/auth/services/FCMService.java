package northjosh.auth.services;

import com.google.firebase.messaging.*;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.dto.FcmMessage;
import northjosh.auth.repo.device.TrustedDeviceRepo;
import northjosh.auth.services.devices.TrustedDeviceService;
import org.slf4j.MDC;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class FCMService {

	private final TrustedDeviceService trustedDeviceService;

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
			if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
				trustedDeviceService.clearFcm(fcm);
				log.warn("Sender ID {} does not registered, clearing", fcm);
			}
			if (e.getMessagingErrorCode() == MessagingErrorCode.SENDER_ID_MISMATCH) {
				log.warn("Sender ID {} does not exist", fcm);
			}

			log.error("Error sending message to Firebase", e);
		}
	}

	public void sendBulkMessage(List<String> fcmIds, FcmMessage data) {
		try {
			MulticastMessage message = MulticastMessage.builder()
					.putAllData(data.getData())
					.addAllFids(fcmIds)
					.setAndroidConfig(AndroidConfig.builder()
							.setPriority(AndroidConfig.Priority.HIGH)
							.setTtl(Duration.ofSeconds(120).toMillis())
							.setNotification(AndroidNotification.builder()
									.setTag(MDC.get("requestId"))
									.setTitle(data.getTitle())
									.setBody(data.getBody())
									.setChannelId("push_requests")
									.build())
							.build())
					.build();
			BatchResponse response = FirebaseMessaging.getInstance().sendEachForMulticast(message);

			if (response.getFailureCount() > 0) {
				List<SendResponse> responses = response.getResponses();
				List<String> failedFids = new ArrayList<>();
				for (int i = 0; i < responses.size(); i++) {
					SendResponse resp = responses.get(i);

					if (resp.isSuccessful()) {
						continue;
					}

					FirebaseMessagingException exception = resp.getException();
					switch (exception.getMessagingErrorCode()) {
						case UNREGISTERED -> {
							log.warn("Sender ID {} does not registered, clearing", fcmIds.get(i));
							trustedDeviceService.clearFcm(fcmIds.get(i));
						}
						case SENDER_ID_MISMATCH -> {
							log.warn("Sender ID {} does not exist", fcmIds.get(i));
						}
						default -> log.warn(
								"Firebase send failed with code {}: {}",
								exception.getMessagingErrorCode(),
								exception.getMessage());
					}
					if (!responses.get(i).isSuccessful()) {

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
