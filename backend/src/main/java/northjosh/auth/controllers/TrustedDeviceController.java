package northjosh.auth.controllers;

import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.config.DevicePrincipal;
import northjosh.auth.dto.DeviceResponse;
import northjosh.auth.dto.PairDeviceDto;
import northjosh.auth.dto.PairDeviceResponse;
import northjosh.auth.repo.device.TrustedDevice;
import northjosh.auth.services.devices.TrustedDeviceService;
import org.modelmapper.ModelMapper;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/devices")
public class TrustedDeviceController {

	private final TrustedDeviceService trustedDeviceService;
	private final ModelMapper modelMapper;

	public TrustedDeviceController(TrustedDeviceService trustedDeviceService, ModelMapper modelMapper) {
		this.trustedDeviceService = trustedDeviceService;
		this.modelMapper = modelMapper;
	}

	@PostMapping("/enroll")
	public Map<String, String> enroll(@AuthenticationPrincipal String email) {
		return trustedDeviceService.enroll(email);
	}

	@GetMapping
	public List<DeviceResponse> listDevices(@AuthenticationPrincipal String email) {
		List<TrustedDevice> devices = trustedDeviceService.getDevicesForUser(email);
		return devices.stream()
				.map(device -> modelMapper.map(device, DeviceResponse.class))
				.toList();
	}

	@PostMapping("/pair")
	public PairDeviceResponse pair(PairDeviceDto dto) {
		return trustedDeviceService.pair(dto);
	}

	@PutMapping("/{id}/toggle-push")
	public PairDeviceResponse togglePush(@PathVariable String id) {
		TrustedDevice device = trustedDeviceService.togglePush(id);
		return modelMapper.map(device, PairDeviceResponse.class);
	}

	@PutMapping("/me/fcm-token")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public PairDeviceResponse updateFcm(@AuthenticationPrincipal DevicePrincipal principal, Map<String, String> dto) {
		TrustedDevice device = trustedDeviceService.updateFcm(principal.getId(), dto.get("fcmToken"));
		return modelMapper.map(device, PairDeviceResponse.class);
	}

	@DeleteMapping("/devices/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void unpair(@PathVariable String id) {
		trustedDeviceService.unpair(id);
	}

	@DeleteMapping("/devices/me")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void unpairUserDevice(@AuthenticationPrincipal DevicePrincipal principal) {
		trustedDeviceService.unpair(principal.getId());
	}
}
