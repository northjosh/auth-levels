"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";

export default function ResetRequestPage() {
  const [email, setEmail] = useState("");
  const onSubmit = async () => {
    try {
      const response = await fetch("http://localhost:8001/auth/request-reset", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email }),
      });
      const data = await response.json();
      if (data.success) {
        toast.success("Password reset request sent. Please check your email.");
      }
    } catch {
      toast.error("Failed to send password reset request.");
    }
  };
  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <h1 className="text-2xl font-bold">Reset Password</h1>
        <p className="mt-4">Enter your email to request a password reset.</p>
        <Input type="email" placeholder="Email" className="w-full" value={email} onChange={(e) => setEmail(e.target.value)} />
        <Button className="mt-4 w -full" onClick={onSubmit}>Request Reset</Button>
      </div>
    </div>
  );
}
