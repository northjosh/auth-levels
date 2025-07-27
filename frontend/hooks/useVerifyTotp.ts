import { useMutation } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useAuth } from "./useAuth";

export const useVerifyTotp = () => {
  const router = useRouter();
  const { login } = useAuth();

  return useMutation({
    mutationFn: async (data: { pendingToken: string; code: string }) => {
      const response = await fetch("http://localhost:8001/auth/verify-totp", {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
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
      router.push("/");
    },
    onError: (error) => {
      toast.error("TOTP verification failed");
      console.error(error);
    },
  });
};
