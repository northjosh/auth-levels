import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { useAuth } from "./useAuth";
import { useRouter } from "next/navigation";
import {
    get,
    parseRequestOptionsFromJSON,
  } from "@github/webauthn-json/browser-ponyfill";

export const useWebAuthnLogin = () => {
  const { login } = useAuth();
  const router = useRouter();

  return useMutation({
    mutationFn: async () => {
      // Check if WebAuthn is supported
      if (!window.PublicKeyCredential) {
        throw new Error("WebAuthn is not supported in this browser");
      }

      try {

        const optionsResponse = await fetch(
          "http://localhost:8001/webauthn/auth/options",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
          }
        );

        if (!optionsResponse.ok) {
          throw new Error("Failed to get authentication options");
        }

        const optionsData = await optionsResponse.json();

        delete optionsData.data.data.allowCredentials;
        delete optionsData.data.data.extensions;

        const parsedOptions = parseRequestOptionsFromJSON({publicKey:optionsData.data.data});

        console.log(parsedOptions);

        
        const credential = await get({publicKey: parsedOptions.publicKey});

        if (!credential) {
          throw new Error("No credential received");
        }

        const verifyResponse = await fetch(
          "http://localhost:8001/webauthn/auth/verify",
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify(credential),
          }
        );

        if (!verifyResponse.ok) {
          throw new Error("Authentication failed");
        }

        const result = await verifyResponse.json();
        return result;
      } catch (error) {
        console.error("WebAuthn authentication error:", error);
        throw error;
      }
    },
    onSuccess: (data) => {
      toast.success("Logged in with passkey!");
      login(data.data.token);
      router.push("/");
    },
    onError: (error: Error) => {
      console.error("WebAuthn login failed:", error);
      toast.error(`Passkey login failed: ${error.message}`);
    },
  });
};
