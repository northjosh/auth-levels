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
import { useVerifyEmail } from "@/hooks/useVerifyEmail";
import { CheckCircle, XCircle, Loader2 } from "lucide-react";

export default function VerifyEmailPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const [verificationStatus, setVerificationStatus] = useState<
    "loading" | "success" | "error"
  >("loading");
  const { mutate: verifyEmail, isPending } = useVerifyEmail();

  useEffect(() => {
    const token = searchParams.get("token");

    if (!token) {
      setVerificationStatus("error");
      return;
    }

    // Verify the email with the token
    verifyEmail(
      { pendingToken: token },
      {
        onSuccess: () => {
          setVerificationStatus("success");
        },
        onError: () => {
          setVerificationStatus("error");
        },
      }
    );
  }, [searchParams, verifyEmail]);

  const handleGoToLogin = () => {
    router.push("/login");
  };

  const handleGoHome = () => {
    router.push("/");
  };

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <Card>
          <CardHeader className="text-center">
            <div className="mx-auto mb-4">
              {verificationStatus === "loading" && (
                <Loader2 className="h-12 w-12 animate-spin text-blue-500" />
              )}
              {verificationStatus === "success" && (
                <CheckCircle className="h-12 w-12 text-green-500" />
              )}
              {verificationStatus === "error" && (
                <XCircle className="h-12 w-12 text-red-500" />
              )}
            </div>
            <CardTitle>
              {verificationStatus === "loading" && "Verifying your email..."}
              {verificationStatus === "success" && "Email verified!"}
              {verificationStatus === "error" && "Verification failed"}
            </CardTitle>
            <CardDescription>
              {verificationStatus === "loading" &&
                "Please wait while we verify your email address."}
              {verificationStatus === "success" &&
                "Your email has been successfully verified. You can now sign in to your account."}
              {verificationStatus === "error" &&
                "The verification link is invalid or has expired. Please try signing up again."}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {verificationStatus === "success" && (
              <Button onClick={handleGoToLogin} className="w-full">
                Go to Sign In
              </Button>
            )}
            {verificationStatus === "error" && (
              <div className="space-y-2">
                <Button onClick={handleGoHome} className="w-full">
                  Go to Home
                </Button>
                <Button
                  onClick={() => router.push("/signup")}
                  variant="outline"
                  className="w-full"
                >
                  Sign Up Again
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
