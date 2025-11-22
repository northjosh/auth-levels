/**
 * Utility functions for push authentication
 */

export interface ClientIdData {
  requestId: string;
  email: string;
}

/**
 * Encodes client data into a base64 clientId for push authentication
 * Format: auth_login_<sessionID>_<email>
 */
export function encodeClientId(data: ClientIdData): string {
  const formatted = `auth_login_${data.requestId}_${data.email}`;
  return btoa(formatted);
}

/**
 * Decodes a base64 clientId to extract session and email information
 */
export function decodeClientId(clientId: string): ClientIdData {
  try {
    const decoded = atob(clientId);
    const parts = decoded.split("_");

    if (parts.length !== 4 || parts[0] !== "auth" || parts[1] !== "login") {
      throw new Error("Invalid client ID format");
    }

    return {
      requestId: parts[2],
      email: parts[3],
    };
  } catch (error) {
    throw new Error("Failed to decode client ID");
  }
}


export function generateSessionId(): string {
  return (
    Math.random().toString(36).substring(2, 15) +
    Math.random().toString(36).substring(2, 15)
  );
}

/**
 * Creates a push authentication URL with the given client data
 */
export function createPushAuthUrl(
  data: ClientIdData,
  baseUrl: string = ""
): string {
  const clientId = encodeClientId(data);
  return `${baseUrl}/push-auth?clientId=${encodeURIComponent(clientId)}`;
}
