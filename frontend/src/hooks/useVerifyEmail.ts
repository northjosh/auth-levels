import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { apiUrl } from "@/lib/api";

interface VerifyEmailRequest {
  pendingToken: string;
}

interface VerifyEmailResponse {
  message: string;
}

export const useVerifyEmail = () => {
  return useMutation({
    mutationFn: async (
      data: VerifyEmailRequest
    ): Promise<VerifyEmailResponse> => {
      const response = await fetch(apiUrl("/auth/verify-email"), {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!response.ok) {
        throw new Error("Failed to verify email");
      }

      return response.json();
    },
    onSuccess: (data) => {
      toast.success(data.message || "Email verified successfully!");
    },
    onError: (error) => {
      toast.error(
        error instanceof Error ? error.message : "Email verification failed"
      );
    },
  });
};
