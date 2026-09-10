import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { useAuth } from "./useAuth";
import { apiUrl } from "@/lib/api";

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

export const useActivateTotp = () => {
  const navigate = useNavigate();
  const { login } = useAuth();

  return useMutation({
    mutationFn: async (data: { pendingToken: string; code: string }) => {
      const response = await fetch(apiUrl("/activate-totp"), {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${localStorage.getItem("auth_token")}`,
        },
      });

      if (!response.ok) {
        throw new Error("TOTP activation failed");
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
