import { SignUpFormData } from "@/components/signup-form";
import { useMutation } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { apiUrl } from "@/lib/api";

export const useSignup = () => {
  const navigate = useNavigate();

  return useMutation({
    mutationFn: (data: SignUpFormData) => {
      return fetch(apiUrl("/signup"), {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
        },
      });
    },
    onSuccess: (data) => {
      data.json().then((response) => {
        console.log(response);
        if (response.data.totpEnabled) {
          navigate({
            to: "/totp-setup",
            search: { url: response.data.totpUrl },
          });
        } else {
          navigate({
            to: "/email-verification-instructions",
            search: { email: response.data.email },
          });
        }
      });
      toast.success(
        "Account created! Please check your email to verify your account."
      );
    },
    onError: () => {
      toast.error("Signup failed");
    },
  });
};
