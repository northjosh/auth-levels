import { useQuery } from "@tanstack/react-query";
import { useAuth } from "./useAuth";
import { apiUrl, ApiResponse } from "@/lib/api";

export interface SecurityEvent {
  id: string;
  type: string;
  method: string;
  userAgentFamily?: string | null;
  osFamily?: string | null;
  deviceFamily?: string | null;
  remoteAddress?: string | null;
  createdBy?: string | null;
  createdAt: string;
  details?: Record<string, string>;
}

export interface SecurityEventPage {
  data: SecurityEvent[];
  next: string | null;
  previous: string | null;
}

export interface SecurityEventsQuery {
  method?: string;
  type?: string;
  osFamily?: string;
  deviceFamily?: string;
  remoteAddress?: string;
  from?: string;
  to?: string;
  next?: string;
  prev?: string;
  size?: number;
}

export const METHOD_OPTIONS = [
  "PASSWORD",
  "TOTP",
  "RECOVERY_CODE",
  "PASSKEY",
  "MAGIC_LINK",
  "PUSH",
] as const;

export const TYPE_OPTIONS = [
  "LOGIN_SUCCESS",
  "LOGIN_FAILURE",
  "SIGNUP",
  "EMAIL_VERIFIED",
  "TOTP_ENABLED",
  "TOTP_ACTIVATED",
  "TOTP_DISABLED",
  "RECOVERY_CODES_GENERATED",
  "RECOVERY_CODE_USED",
  "PASSKEY_ADDED",
  "PASSKEY_REMOVED",
  "PASSWORD_RESET_REQUESTED",
  "PASSWORD_RESET_COMPLETED",
  "PUSH_REQUEST_CREATED",
  "PUSH_ATTEMPT_FAILED",
  "PUSH_ATTEMPTS_EXCEEDED",
  "PUSH_REQUEST_DENIED",
  "TRUSTED_DEVICE_PAIRED",
  "TRUSTED_DEVICE_REMOVED",
  "TOTP_ATTEMPT_FAILED",
] as const;

export const useSecurityEvents = (query: SecurityEventsQuery) => {
  const { token } = useAuth();

  return useQuery({
    queryKey: ["security-events", query],
    queryFn: async () => {
      const params = new URLSearchParams();
      params.set("size", String(query.size ?? 20));
      for (const key of [
        "method",
        "type",
        "osFamily",
        "deviceFamily",
        "remoteAddress",
        "from",
        "to",
        "next",
        "prev",
      ] as const) {
        const value = query[key];
        if (value !== undefined && value !== "") {
          params.set(key, value);
        }
      }

      const response = await fetch(
        `${apiUrl("/activity")}?${params.toString()}`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        },
      );

      if (!response.ok) {
        throw new Error("Failed to fetch security events");
      }

      const body = (await response.json()) as ApiResponse<SecurityEventPage>;
      return body.data;
    },
    enabled: !!token,
  });
};