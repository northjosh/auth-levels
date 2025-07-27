import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAuth } from "./useAuth";

import {
    create,
    parseCreationOptionsFromJSON,
  } from "@github/webauthn-json/browser-ponyfill";

export const useRegisterWebAuthn = () => {
  const { token, refreshUser } = useAuth();

  return useMutation({
    mutationFn: async () => {
      const optionsResponse = await fetch(
        "http://localhost:8001/webauthn/register/options",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        }
      );

      if (!optionsResponse.ok) {
        throw new Error("Failed to get registration options");
      }

      const options = (await optionsResponse.json());

      delete options.data.extensions;

      const parsedOptions = parseCreationOptionsFromJSON({
        publicKey: options.data,
      });

      const credential = await create(parsedOptions);

      if (!credential) {
        throw new Error("Failed to create credential");
      }

      // Step 3: Send credential to backend for verification
      const registrationResponse = await fetch(
        "http://localhost:8001/webauthn/register",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(credential),
        }
      );

      if (!registrationResponse.ok) {
        throw new Error("Failed to register credential");
      }

      return registrationResponse.json();
    },
    onSuccess: () => {
      toast.success("WebAuthn credential registered successfully!");
      refreshUser();
    },
    onError: (error) => {
      console.error("WebAuthn registration error:", error);
      toast.error("Failed to register WebAuthn credential");
    },
  });
};
