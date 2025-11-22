import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "./useAuth";
import { toast } from "sonner";

export interface PushAuthAttempt {
  id: number;
  requestId: string;
  email: string;
  createdAt: string;
  expiresAt: string;
}

export const usePushAuthAttempts = () => {
  const { token } = useAuth();

  return useQuery({
    queryKey: ["push-auth-attempts"],
    queryFn: async () => {
      const response = await fetch("http://localhost:8001/push/get", {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error("Failed to fetch push auth attempts");
      }

      const data = await response.json();
      return data.data as PushAuthAttempt[];
    },
    enabled: !!token,
    refetchInterval: 10000, 
  });
};

export const useVerifyPushAuth = () => {
  const queryClient = useQueryClient();
  const { token } = useAuth();

  return useMutation({
    mutationFn: async ({
      requestId,
      otp,
    }: {
      requestId: string;
      otp: string;
    }) => {
      const response = await fetch("http://localhost:8001/push/verify", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          requestId: requestId,
          otp: otp,
        }),
      });

      if (!response.ok) {
        throw new Error("Failed to verify push auth");
      }

      return response.json();
    },
    onSuccess: () => {
      toast.success("Login attempt approved successfully!");
      // Refresh the attempts list
      queryClient.invalidateQueries({ queryKey: ["push-auth-attempts"] });
    },
    onError: (error: Error) => {
      toast.error(`Failed to approve login: ${error.message}`);
    },
  });
};
