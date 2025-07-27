import { SignUpFormData } from "@/components/signup-form";
import { useMutation } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

export const useSignup = () => {
  const router = useRouter();

  return useMutation({
    mutationFn: (data: SignUpFormData) => {
      return fetch("http://localhost:8001/auth/signup", {
        method: "POST",
        body: JSON.stringify(data),
        headers: {
          "Content-Type": "application/json",
        },
      });
    },
    onSuccess: (data) => {
      data.json().then((data) => {
        console.log(data);
        if (data.data.totpEnabled) {
          router.push("/totp-setup?" + new URLSearchParams({ url: data.data.totpUrl }).toString());
        } else {
          router.push("/login");
        }
      });
      toast.success("Signup successful");
    },
    onError: () => {
      toast.error("Signup failed");
    },
  });
};