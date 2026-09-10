import { useMutation, useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAuth } from "./useAuth";
import { useNavigate } from "@tanstack/react-router";
import { apiUrl } from "@/lib/api";

export const useEnableTotp = () => {
  const { token, refreshUser } = useAuth();
  const navigate = useNavigate();

  return useMutation({
    mutationFn: async () => {
      const response = await fetch(apiUrl("/enable-totp"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({}),
      });

      if (!response.ok) {
        throw new Error("Failed to enable TOTP");
      }

      return response.json();
    },
    onSuccess: (data) => {
      toast.success("TOTP enabled successfully");
      navigate({ to: "/totp-setup", search: { url: data.data.qrUrl } });
      refreshUser();
    },
    onError: () => {
      toast.error("Failed to enable TOTP");
    },
  });
};

export const useDisableTotp = () => {
  const { token, refreshUser } = useAuth();

  return useMutation({
    mutationFn: async () => {
      const response = await fetch(apiUrl("/disable-totp"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error("Failed to disable TOTP");
      }

      return response.json();
    },
    onSuccess: () => {
      toast.success("TOTP disabled successfully");
      refreshUser();
    },
    onError: () => {
      toast.error("Failed to disable TOTP");
    },
  });
};

export const useWebAuthnCredentials = () => {
  const { token } = useAuth();

  return useQuery({
    queryKey: ["webauthn-credentials"],
    queryFn: async () => {
      const response = await fetch(
        apiUrl("/webauthn/credentials"),
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );

      if (!response.ok) {
        throw new Error("Failed to fetch WebAuthn credentials");
      }

      return response.json();
    },
    enabled: !!token,
  });
};

export const useDeleteWebAuthnCredential = () => {
  const { token, refreshUser } = useAuth();

  return useMutation({
    mutationFn: async (credentialId: number) => {
      const response = await fetch(
        apiUrl(`/webauthn/credentials/${credentialId}`),
        {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );

      if (!response.ok) {
        throw new Error("Failed to delete WebAuthn credential");
      }

      return response.json();
    },
    onSuccess: () => {
      toast.success("WebAuthn credential deleted successfully");
      refreshUser();
    },
    onError: () => {
      toast.error("Failed to delete WebAuthn credential");
    },
  });
};
