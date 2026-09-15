package northjosh.auth.repo.pushauth;

import jakarta.persistence.Embeddable;
import jakarta.servlet.http.HttpServletRequest;
import lombok.Getter;
import lombok.Setter;
import ua_parser.Client;
import ua_parser.Parser;

@Getter
@Setter
@Embeddable
public class ClientInfo {

	private String deviceFamily;
	private String osFamily;
	private String userAgentFamily;
	private String remoteHost;
	private String remoteUser;
	private String remoteAddress;

	public ClientInfo(HttpServletRequest request) {
		String userAgent = request.getHeader("User-Agent");
		Parser uaParser = new Parser();
		Client client = uaParser.parse(userAgent);
		this.remoteAddress = request.getRemoteAddr();
		this.remoteHost = request.getRemoteHost();
		this.remoteUser = request.getRemoteUser();
		this.osFamily = client.os.family;
		this.deviceFamily = client.device.family;
		this.userAgentFamily = client.userAgent.family;
	}

	protected ClientInfo() {}
}
