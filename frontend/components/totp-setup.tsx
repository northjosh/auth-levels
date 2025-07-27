"use client";

import { useState, useEffect } from "react";
import { QRCodeCanvas } from "qrcode.react";
import { toast } from "sonner";
import { Copy, Check } from "lucide-react";

import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useSearchParams } from "next/navigation";
import { useVerifyTotp } from "@/hooks/useVerifyTotp";
import { useAuth } from "@/hooks/useAuth";

interface TotpSetupProps {
  className?: string;
}

export function TotpSetup({ className }: TotpSetupProps) {
  const [secretKey, setSecretKey] = useState("");
  const [qrCodeUrl, setQrCodeUrl] = useState("");
  const [isCopied, setIsCopied] = useState(false);
  const [verificationCode, setVerificationCode] = useState("");
  const { mutate: verifyTotp, isPending: isVerifying } = useVerifyTotp();
  const { token } = useAuth();

  const url = useSearchParams().get("url");

  const extractSecretKey = (url: string) => {
      const urlObj = new URL(url);
      const secret = urlObj.searchParams.get("secret");
      return secret;
    };
    useEffect(() => {
      setQrCodeUrl(url || "");
      setSecretKey(extractSecretKey(url || "") || "");
    }, [url]);  


  const copySecretKey = async () => {
    try {
      await navigator.clipboard.writeText(secretKey);
      setIsCopied(true);
      toast.success("Secret key copied to clipboard!");
      setTimeout(() => setIsCopied(false), 2000);
    } catch (error) {
      toast.error("Failed to copy secret key");
    }
  };

  const handleVerification = async () => {
    if (!verificationCode || verificationCode.length !== 6) {
      toast.error("Please enter a 6-digit verification code");
      return;
    }

    if (token) {
      verifyTotp({
        pendingToken: token,
        code: verificationCode,
      });
    }
  };

  return (
    <div className={cn("flex flex-col gap-6", className)}>
      <Card>
        <CardHeader>
          <CardTitle>Set up Two-Factor Authentication</CardTitle>
          <CardDescription>
            Scan the QR code below with your authenticator app to complete setup
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* QR Code Section */}
          <div className="flex flex-col items-center space-y-4">
            <div className="p-4 bg-white rounded-lg">
              {qrCodeUrl && (
                <QRCodeCanvas
                  value={qrCodeUrl}
                  size={200}
                  level="M"
                />
              )}
            </div>

            <div className="text-center">
              <p className="text-sm text-muted-foreground mb-2">
                Can't scan the QR code?
              </p>
              <div className="flex items-center space-x-2">
                <Input
                  value={secretKey}
                  readOnly
                  className="font-mono text-xs"
                />
                <Button
                  size="sm"
                  variant="outline"
                  onClick={copySecretKey}
                  className="shrink-0"
                >
                  {isCopied ? (
                    <Check className="h-4 w-4" />
                  ) : (
                    <Copy className="h-4 w-4" />
                  )}
                </Button>
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                Enter this key manually in your authenticator app
              </p>
            </div>
          </div>

          {/* Instructions */}
          <div className="space-y-2">
            <h4 className="font-medium">Instructions:</h4>
            <ol className="text-sm text-muted-foreground space-y-1 list-decimal list-inside">
              <li>
                Install an authenticator app (Google Authenticator, Authy, etc.)
              </li>
              <li>Scan the QR code or enter the secret key manually</li>
              <li>Enter the 6-digit code from your app below to verify</li>
            </ol>
          </div>

          {/* Verification Section */}
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="verification-code">Verification Code</Label>
              <Input
                id="verification-code"
                type="text"
                placeholder="Enter 6-digit code"
                value={verificationCode}
                onChange={(e) =>
                  setVerificationCode(
                    e.target.value.replace(/\D/g, "").slice(0, 6)
                  )
                }
                maxLength={6}
              />
            </div>

            <div className="flex gap-2">
              <Button
                onClick={handleVerification}
                disabled={isVerifying || verificationCode.length !== 6}
                className="flex-1"
              >
                {isVerifying ? "Verifying..." : "Verify & Enable"}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
