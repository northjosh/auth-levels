import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

import { useAuth } from "@/hooks/useAuth";
import { apiUrl, type ApiResponse } from "@/lib/api";

export interface TrustedDevice {
  id: string;
  name: string | null;
  platform: string | null;
  appVersion: string | null;
  pushEnabled: boolean;
  status: string;
  pairedAt: string | null;
  lastSeenAt: string | null;
}

export interface DeviceEnrollment {
  enrollmentToken: string;
  expiresAt: string;
}

const DEVICES_QUERY_KEY = ["trusted-devices"] as const;

const errorMessage = async (response: Response, fallback: string) => {
  try {
    const body = (await response.json()) as {
      data?: { errorMessage?: string };
    };
    return body.data?.errorMessage ?? fallback;
  } catch {
    return fallback;
  }
};

export function useTrustedDevices(polling = false) {
  const { token } = useAuth();

  return useQuery({
    queryKey: DEVICES_QUERY_KEY,
    queryFn: async (): Promise<TrustedDevice[]> => {
      const response = await fetch(apiUrl("/devices"), {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) {
        throw new Error(await errorMessage(response, "Failed to load devices"));
      }
      const body = (await response.json()) as ApiResponse<TrustedDevice[]>;
      return body.data;
    },
    enabled: Boolean(token),
    refetchInterval: polling ? 2_000 : false,
    refetchOnWindowFocus: false,
  });
}

export function useEnrollTrustedDevice() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (): Promise<DeviceEnrollment> => {
      const response = await fetch(apiUrl("/devices/enroll"), {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) {
        throw new Error(
          await errorMessage(response, "Failed to create pairing link"),
        );
      }
      const body = (await response.json()) as ApiResponse<DeviceEnrollment>;
      return body.data;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: DEVICES_QUERY_KEY });
    },
    onError: (error) => toast.error(error.message),
  });
}

export function useRemoveTrustedDevice() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (deviceId: string) => {
      const response = await fetch(apiUrl(`/devices/${deviceId}`), {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) {
        throw new Error(await errorMessage(response, "Failed to remove device"));
      }
    },
    onSuccess: () => {
      toast.success("Device removed");
      void queryClient.invalidateQueries({ queryKey: DEVICES_QUERY_KEY });
    },
    onError: (error) => toast.error(error.message),
  });
}
