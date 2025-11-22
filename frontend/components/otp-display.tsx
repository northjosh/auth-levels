"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Copy, Shield, Clock } from "lucide-react";
import { toast } from "sonner";
import { useCountdown } from "@/hooks/useCountdown";

interface OtpDisplayProps {
  otp: string;
  onExpired: () => void;
  expiryTime?: number;
}

export function OtpDisplay({
  otp,
  onExpired,
  expiryTime = 120,
}: OtpDisplayProps) {
  const { timeLeft, formatTime, isExpired } = useCountdown({
    initialTime: expiryTime,
    onComplete: onExpired,
  });

  const copyOtpToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(otp);
      toast.success("OTP copied to clipboard!");
    } catch (error) {
      toast.error("Failed to copy OTP");
    }
  };

  const getTimeColor = () => {
    if (timeLeft > 60) return "text-green-600";
    if (timeLeft > 30) return "text-yellow-600";
    return "text-red-600";
  };

  return (
    <Card className="border-2 border-dashed border-blue-200 bg-blue-50/50">
      <CardHeader className="text-center pb-3">
        <div className="mx-auto mb-2">
          <Shield className="h-8 w-8 text-blue-600" />
        </div>
        <CardTitle className="text-lg">Your Authentication Code</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-center space-y-3">
          <div
            className="inline-flex items-center justify-center p-4 bg-white border-2 border-blue-200 rounded-lg cursor-pointer hover:bg-blue-50 transition-colors group"
            onClick={copyOtpToClipboard}
          >
            <span className="text-3xl font-mono font-bold text-blue-700 tracking-wider mr-3">
              {otp}
            </span>
            <Copy className="h-5 w-5 text-blue-500 opacity-0 group-hover:opacity-100 transition-opacity" />
          </div>
          <p className="text-sm text-muted-foreground">
            Click to copy the code above
          </p>
        </div>

        <div className="text-center space-y-2">
          <div className="flex items-center justify-center space-x-2">
            <Clock className="h-4 w-4 text-muted-foreground" />
            <span className="text-sm text-muted-foreground">
              Time remaining:
            </span>
          </div>
          <div className="text-center">
            <div
              className={`inline-block text-lg font-mono px-4 py-2 rounded-md border-2 ${
                isExpired
                  ? "bg-red-100 border-red-300 text-red-700"
                  : "bg-gray-100 border-gray-300"
              } ${getTimeColor()}`}
            >
              {formatTime(timeLeft)}
            </div>
          </div>
          {timeLeft <= 30 && timeLeft > 0 && (
            <p className="text-sm text-red-600 font-medium animate-pulse">
              Code expires soon!
            </p>
          )}
          {isExpired && (
            <p className="text-sm text-red-600 font-medium">Code has expired</p>
          )}
        </div>

        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className={`h-2 rounded-full transition-all duration-1000 ${
              timeLeft > 60
                ? "bg-green-500"
                : timeLeft > 30
                ? "bg-yellow-500"
                : "bg-red-500"
            }`}
            style={{
              width: `${(timeLeft / expiryTime) * 100}%`,
            }}
          />
        </div>

        <div className="text-center text-xs text-muted-foreground">
          <p>Enter this code in your authenticator app to approve the login</p>
        </div>
      </CardContent>
    </Card>
  );
}
