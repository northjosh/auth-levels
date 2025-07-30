"use client";

import { useSearchParams, useRouter } from "next/navigation";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Mail, RefreshCw } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

export default function EmailVerificationInstructionsPage() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const [isResending, setIsResending] = useState(false);
  const email = searchParams.get("email");

  const handleResendEmail = async () => {
    if (!email) {
      toast.error("No email address found");
      return;
    }

    setIsResending(true);
    try {
      // This would need to be implemented - a resend verification email endpoint
      toast.info("Resend feature not yet implemented");
    } catch (error) {
      toast.error("Failed to resend verification email");
    } finally {
      setIsResending(false);
    }
  };

  const handleGoToLogin = () => {
    router.push("/login");
  };

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-md">
        <Card>
          <CardHeader className="text-center">
            <div className="mx-auto mb-4">
              <Mail className="h-12 w-12 text-blue-500" />
            </div>
            <CardTitle>Check your email</CardTitle>
            <CardDescription>
              We&apos;ve sent a verification link to{email && ` ${email}`}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="text-sm text-muted-foreground space-y-2">
              <p>To complete your account setup:</p>
              <ol className="list-decimal list-inside space-y-1 ml-4">
                <li>Check your email inbox (and spam folder)</li>
                <li>Click the verification link in the email</li>
                <li>You&apos;ll be redirected back here once verified</li>
                <li>Then you can sign in to your account</li>
              </ol>
            </div>

            <div className="space-y-3">
              <Button
                onClick={handleResendEmail}
                variant="outline"
                className="w-full"
                disabled={isResending}
              >
                {isResending ? (
                  <>
                    <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                    Resending...
                  </>
                ) : (
                  <>
                    <RefreshCw className="mr-2 h-4 w-4" />
                    Resend verification email
                  </>
                )}
              </Button>

              <Button onClick={handleGoToLogin} className="w-full">
                I&apos;ve verified my email - Go to Sign In
              </Button>
            </div>

            <div className="text-center text-sm text-muted-foreground">
              <p>
                Didn&apos;t receive the email? Check your spam folder or try
                resending.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
