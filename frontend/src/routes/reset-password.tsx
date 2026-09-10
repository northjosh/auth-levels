import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { usePasswordResetRequest } from "@/hooks/usePasswordReset";

export const Route = createFileRoute("/reset-password")({
  component: ResetRequestPage,
});

function ResetRequestPage() {
  const [email, setEmail] = useState("");
  const { mutate: requestReset, isPending } = usePasswordResetRequest();

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <h1 className="text-2xl font-bold">Reset Password</h1>
        <p className="mt-4">Enter your email to request a password reset.</p>
        <Input
          type="email"
          placeholder="Email"
          className="w-full"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <Button
          className="mt-4 w-full"
          disabled={isPending || !email}
          onClick={() => requestReset({ email })}
        >
          {isPending ? "Sending..." : "Request Reset"}
        </Button>
      </div>
    </div>
  );
}
