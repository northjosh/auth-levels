import { useMutation } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { User } from "./useAuth";
import { encodeClientId } from "@/utils/pushAuth";

interface PushLoginResponse {
    requestId: string;
    email: string;
    otp: string;
    user: User;
}

export const usePushLogin = () => {
    const router = useRouter();
  return useMutation({
    mutationFn: async (email: string) => {
      const response = await fetch("http://localhost:8001/push/generate", {
        method: "POST",
        body: JSON.stringify({ email: email }),
        headers: {
          "Content-Type": "application/json",
        },
      });
      const data = await response.json();
      return data.data as PushLoginResponse;
    },
    onSuccess: (data) => {
        const { requestId, user, otp } = data;
        const clientData = { requestId, email: user.email };
        const clientId = encodeClientId(clientData);
        router.push(`/push-auth?clientId=${clientId}&otp=${otp}`);
    },
    onError: (error) => {
      console.error(error);
    },
  });
};