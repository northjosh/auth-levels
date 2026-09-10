import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { useAuth } from "./useAuth";
import { apiUrl } from "@/lib/api";

export function useLogin() {
  const navigate = useNavigate();
  const { login } = useAuth();

  return useMutation({
    mutationFn: async (data: { email: string; password: string }) => {
      const response = await fetch(apiUrl("/login"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(data),
      });

      if (!response.ok) {
        throw new Error("Login failed");
      }

      return response.json();
    },
    onSuccess: (data) => {
      if (data.data.totpRequired) {
        navigate({ to: "/totp", search: { token: data.data.token } });
      } else {
        login(data.data.token);
        navigate({ to: "/" });
      }
    },
  });
}
