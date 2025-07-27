/* This code contains copyright information which is the proprietary property
 *  of Terydin Incorporated. No part of this code may be reproduced,
 *  stored or transmitted in any form without the prior written permission of Terydin.
 *  Copyright © Terydin Incorporated (C) 2024-2025.
 *  Confidential. All rights reserved.
 */
package northjosh.auth.dto.response;

import java.io.Serial;
import java.io.Serializable;
import java.util.List;
import lombok.Data;
import org.springframework.data.domain.Page;

@Data
public class PagedContent<T> implements Serializable {

	@Serial
	private static final long serialVersionUID = 5519514434563204524L;

	private long totalElements;
	private int totalPages;
	private int page;
	private int size;
	private boolean hasNextPage;
	private boolean hasPreviousPage;
	private boolean isFirst;
	private boolean isLast;

	private List<T> data;

	public PagedContent(Page<?> pagedData, List<T> data) {
		this.setData(data);
		this.setTotalElements(pagedData.getTotalElements());
		this.setTotalPages(pagedData.getTotalPages());
		this.setPage(pagedData.getPageable().getPageNumber());
		this.setSize(pagedData.getPageable().getPageSize());
		this.setHasNextPage(pagedData.hasNext());
		this.setHasPreviousPage(pagedData.hasPrevious());
		this.setFirst(pagedData.isFirst());
		this.setLast(pagedData.isLast());
	}
}
