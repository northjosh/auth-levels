"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { usePushLogin } from "@/hooks/usePushLogin";
import { Label } from "./ui/label";

export function PushAuthDemo() {
  const { mutate: login } = usePushLogin();
  const [email, setEmail] = useState("");

  const handleStartPushAuth = () => {
    if (!email) {
      toast.error("Please enter an email address");
      return;
    }
    login(email);
  };

  return (
    <Card className="w-full max-w-md">
      <CardHeader className="text-start">
        <CardTitle>Passwordless Login</CardTitle>
        <CardDescription>Enter your email to login</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            placeholder="user@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div className="space-y-2">
          <Button onClick={handleStartPushAuth} className="w-full">
            Login
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
