import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";

import { apiUrl, type ApiResponse } from "@/lib/api";

export interface ResetDto {
  token: string;
  password: string;
  confirmPassword: string;
}

export interface ResetRequestDto {
  email: string;
}

interface MessagePayload {
  message: string;
}

/** Requests a password-reset email for the given address. */
export const usePasswordResetRequest = () => {
  return useMutation({
    mutationFn: async (dto: ResetRequestDto) => {
      const response = await fetch(apiUrl("/request-reset"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(dto),
      });

      if (!response.ok) {
        throw new Error("Failed to request reset");
      }

      return (await response.json()) as ApiResponse<MessagePayload>;
    },
    onSuccess: () => {
      toast.success("Password reset request sent. Please check your email.");
    },
    onError: () => {
      toast.error("Failed to send password reset request.");
    },
  });
};

/** Sets a new password using the token from the reset email. */
export const usePasswordReset = () => {
  return useMutation({
    mutationFn: async (dto: ResetDto) => {
      const response = await fetch(apiUrl("/reset-password"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(dto),
      });

      if (!response.ok) {
        throw new Error("Failed to reset password");
      }

      return (await response.json()) as ApiResponse<MessagePayload>;
    },
    onSuccess: () => {
      toast.success("Password reset. You may now log in.");
    },
    onError: () => {
      toast.error("Failed to reset password");
    },
  });
};
