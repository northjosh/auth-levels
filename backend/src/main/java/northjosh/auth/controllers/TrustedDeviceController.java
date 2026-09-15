package northjosh.auth.controllers;

import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import northjosh.auth.config.DevicePrincipal;
import northjosh.auth.dto.PairDeviceDto;
import northjosh.auth.dto.PairDeviceResponse;
import northjosh.auth.dto.TrustedDeviceDto;
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
	public List<TrustedDeviceDto> listDevices(@AuthenticationPrincipal String email) {
		List<TrustedDevice> devices = trustedDeviceService.getDevicesForUser(email);
		return devices.stream()
				.map(device -> modelMapper.map(device, TrustedDeviceDto.class))
				.toList();
	}

	@PostMapping("/pair")
	public PairDeviceResponse pair(@RequestBody PairDeviceDto dto) {
		return trustedDeviceService.pair(dto);
	}

	@PutMapping("/{id}/toggle-push")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void togglePush(@AuthenticationPrincipal DevicePrincipal principal, @PathVariable String id) {
		trustedDeviceService.togglePush(id);
	}

	@PutMapping("/me/fcm-token")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void updateFcm(@AuthenticationPrincipal DevicePrincipal principal, @RequestBody Map<String, String> dto) {
		trustedDeviceService.updateFcm(principal.getId(), dto.get("fcmToken"));
	}

	@DeleteMapping("/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void unpair(@AuthenticationPrincipal DevicePrincipal principal, @PathVariable String id) {
		trustedDeviceService.unpair(id);
	}

	@DeleteMapping("/me")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void unpairUserDevice(@AuthenticationPrincipal DevicePrincipal principal) {
		trustedDeviceService.unpair(principal.getId());
	}
}
