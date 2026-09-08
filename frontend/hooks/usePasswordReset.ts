import { toast } from "sonner";

export interface ResetDto {
  token: string;
  password: string;
  confirmPassword: string;
}

export interface ResetRequestDto {
  email: string;
}

export function usePasswordResetRequest() {
  const reset = async (dto: ResetRequestDto) => {
    const response = await fetch("http://localhost:8001/auth/request-reset", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(dto),
    });

    if (!response.ok) {
      throw new Error("Failed to request reset");
    }

    const data = await response.json();
    return data;
  };

  return { reset };
}

export function usePasswordReset() {
  const reset = async (dto: ResetDto) => {
    const response = await fetch("http://localhost:8001/auth/reset-password", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(dto),
    });

    if (!response.ok) {
      toast("Failed to reset password");
      console.error(await response.json());
      return;
    }

    const data = await response.json();
    return data;
  };

  return { reset };
}
