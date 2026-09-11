import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { useAuth } from "./useAuth";
import { apiUrl, type ApiResponse } from "@/lib/api";

export const useVerifyTotp = () => {
  const navigate = useNavigate();
  const { login } = useAuth();

  return useMutation({
    mutationFn: async (data: { pendingToken: string; code: string }) => {
      const response = await fetch(apiUrl("/verify-totp"), {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${localStorage.getItem("token")}`,
        },
      });

      if (!response.ok) {
        throw new Error("TOTP verification failed");
      }

      return response.json();
    },
    onSuccess: (data) => {
      toast.success("TOTP verified");
      login(data.data.token);
      navigate({ to: "/" });
    },
    onError: (error) => {
      toast.error("TOTP verification failed");
      console.error(error);
    },
  });
};

/**
 * Activates a pending TOTP secret and returns the account's recovery codes.
 *
 * The codes are the whole point of this call: the backend stores only their
 * hashes, so this response is the one and only time they exist in plaintext.
 * Navigation is deliberately left to the caller — redirecting here would
 * unmount the view before the codes could be shown.
 */
export const useActivateTotp = () => {
  const { token, refreshUser } = useAuth();

  return useMutation({
    mutationFn: async (data: { code: string }) => {
      const response = await fetch(apiUrl("/activate-totp"), {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error("TOTP activation failed");
      }

      return (await response.json()) as ApiResponse<string[]>;
    },
    onSuccess: () => {
      toast.success("Two-factor authentication enabled");
      refreshUser();
    },
    onError: (error) => {
      toast.error("TOTP activation failed");
      console.error(error);
    },
  });
};
