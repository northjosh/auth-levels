"use client";

import { useEffect, useState } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { usePushAuth } from "@/hooks/usePushAuth";
import {
  Smartphone,
  CheckCircle,
  XCircle,
  Loader2,
  Clock,
  Wifi,
} from "lucide-react";
import { toast } from "sonner";
import { useAuth } from "@/hooks/useAuth";
import { OtpDisplay } from "@/components/otp-display";

export default function PushAuthPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const { login } = useAuth();
  const [clientId, setClientId] = useState<string>("");
  const [otp, setOtp] = useState<string>("");
  useEffect(() => {
    const id = searchParams.get("clientId");
    const otp = searchParams.get("otp");
    if (id && otp) {
      setClientId(id);
      setOtp(otp);
    }
  }, [searchParams]);

  const {
    state,
    disconnect,
    isConnecting,
    isWaiting,
    isSuccess,
    isError,
    isTimeout,
  } = usePushAuth({
    clientId,
    onSuccess: (token) => {
      toast.success("Authentication successful! Redirecting...");
      login(token);
      setTimeout(() => router.push("/"), 1500);
    },
    onError: (error) => {
      console.error("Push authentication failed:", error);
      toast.error(`Authentication failed: ${error}`);
    },
    timeout: 120000, // 2 minutes
  });

  const handleCancel = () => {
    disconnect();
    router.push("/signup");
  };

  const handleRetry = () => {
    router.refresh();
  };

  const handleOtpExpired = () => {
    toast.error("Authentication code has expired. Please sign up again.");
    setTimeout(() => {
      router.push("/signup");
    }, 1500);
  };

  if (!clientId || !otp) {
    return (
      <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
        <div className="w-full max-w-md">
          <Card>
            <CardHeader className="text-center">
              <div className="mx-auto mb-4">
                <XCircle className="h-12 w-12 text-red-500" />
              </div>
              <CardTitle>Invalid Request</CardTitle>
              <CardDescription>
                {!clientId && !otp
                  ? "No authentication session found. Please try logging in again."
                  : "Missing authentication code. Please try again."}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Button onClick={() => router.push("/signup")} className="w-full">
                Back to Sign Up
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  const getStatusIcon = () => {
    if (isConnecting)
      return <Wifi className="h-12 w-12 animate-pulse text-blue-500" />;
    if (isWaiting)
      return <Smartphone className="h-12 w-12 animate-pulse text-orange-500" />;
    if (isSuccess) return <CheckCircle className="h-12 w-12 text-green-500" />;
    if (isTimeout) return <Clock className="h-12 w-12 text-yellow-500" />;
    if (isError) return <XCircle className="h-12 w-12 text-red-500" />;
    return <Loader2 className="h-12 w-12 animate-spin text-blue-500" />;
  };

  const getStatusTitle = () => {
    if (isConnecting) return "Connecting...";
    if (isWaiting) return "Waiting for approval";
    if (isSuccess) return "Authentication successful!";
    if (isTimeout) return "Request timed out";
    if (isError) return "Authentication failed";
    return "Processing...";
  };

  const getStatusDescription = () => {
    if (isConnecting) return "Establishing secure connection...";
    if (isWaiting)
      return "Please approve the login request on your mobile device or authenticator app.";
    if (isSuccess)
      return "You have been successfully authenticated. Redirecting...";
    if (isTimeout)
      return "The authentication request has expired. Please try again.";
    if (isError)
      return state.error || "An error occurred during authentication.";
    return "Please wait...";
  };

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-md space-y-6">
        <OtpDisplay otp={otp} onExpired={handleOtpExpired} expiryTime={120} />
        <Card>
          <CardHeader className="text-center">
            <div className="mx-auto mb-4">{getStatusIcon()}</div>
            <CardTitle>{getStatusTitle()}</CardTitle>
            <CardDescription>{getStatusDescription()}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {isWaiting && (
              <div className="text-center space-y-4">
                <div className="text-sm text-muted-foreground">
                  <p>
                    Enter the code above in your authenticator app to approve
                    this login.
                  </p>
                </div>
                <div className="flex justify-center">
                  <div className="flex space-x-1">
                    <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
                    <div
                      className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"
                      style={{ animationDelay: "0.2s" }}
                    ></div>
                    <div
                      className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"
                      style={{ animationDelay: "0.4s" }}
                    ></div>
                  </div>
                </div>
              </div>
            )}

            {(isError || isTimeout) && (
              <div className="space-y-2">
                <Button onClick={handleRetry} className="w-full">
                  Try Again
                </Button>
                <Button
                  onClick={handleCancel}
                  variant="outline"
                  className="w-full"
                >
                  Back to Sign Up
                </Button>
              </div>
            )}

            {(isConnecting || isWaiting) && (
              <Button
                onClick={handleCancel}
                variant="outline"
                className="w-full"
              >
                Cancel
              </Button>
            )}

            {isSuccess && (
              <div className="text-center text-sm text-muted-foreground">
                <p>Redirecting to dashboard...</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
