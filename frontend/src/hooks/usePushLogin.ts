import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { User } from "./useAuth";
import { encodeClientId } from "@/utils/pushAuth";
import { apiUrl } from "@/lib/api";

interface PushLoginResponse {
    requestId: string;
    email: string;
    otp: string;
    user: User;
}

export const usePushLogin = () => {
  const navigate = useNavigate();
  return useMutation({
    mutationFn: async (email: string) => {
      const response = await fetch(apiUrl("/push/generate"), {
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
        navigate({ to: "/push-auth", search: { clientId, otp } });
    },
    onError: (error) => {
      console.error(error);
    },
  });
};