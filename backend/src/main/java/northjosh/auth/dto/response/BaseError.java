/* This code contains copyright information which is the proprietary property
 *  of Terydin Incorporated. No part of this code may be reproduced,
 *  stored or transmitted in any form without the prior written permission of Terydin.
 *  Copyright © Terydin Incorporated (C) 2024-2025.
 *  Confidential. All rights reserved.
 */
package northjosh.auth.dto.response;

import java.io.Serial;
import java.io.Serializable;
import lombok.Builder;
import lombok.Data;

@Builder
@Data
public class BaseError implements Serializable {

	@Serial
	private static final long serialVersionUID = -2518961146692095092L;

	private int errorCode;

	private String errorMessage;

	private String url;
}
