import { useMutation, useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAuth } from "./useAuth";
import { useRouter } from "next/navigation";

export const useEnableTotp = () => {
  const { token, refreshUser } = useAuth();
  const router = useRouter();

  return useMutation({
    mutationFn: async () => {
      const response = await fetch("http://localhost:8001/auth/enable-totp", {
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
      router.push(`/totp-setup?url=${data.data.qrUrl}`);
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
      const response = await fetch("http://localhost:8001/auth/disable-totp", {
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
        "http://localhost:8001/webauthn/credentials",
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
        `http://localhost:8001/webauthn/credentials/${credentialId}`,
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
