package northjosh.auth.repo.pushauth;

import jakarta.servlet.http.HttpServletRequest;
import lombok.Getter;
import ua_parser.Client;
import ua_parser.Parser;

@Getter
public class ClientInfo {

	private final String deviceFamily;
	private final String osFamily;
	private final String userAgentFamily;
	private final String remoteHost;
	private final String remoteUser;
	private final String remoteAddress;

	public ClientInfo(HttpServletRequest request) {
		String userAgent = request.getHeader("user-agent");
		Parser uaParser = new Parser();
		Client client = uaParser.parse(userAgent);
		this.remoteAddress = request.getRemoteAddr();
		this.remoteHost = request.getRemoteHost();
		this.remoteUser = request.getRemoteUser();
		this.osFamily = client.os.family;
		this.deviceFamily = client.device.family;
		this.userAgentFamily = client.userAgent.family;
	}
}
