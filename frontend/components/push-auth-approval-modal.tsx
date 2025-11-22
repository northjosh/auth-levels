"use client";

import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  MapPin,
  Monitor,
  Clock,
  Shield,
  AlertTriangle,
  Smartphone,
} from "lucide-react";
import {
  PushAuthAttempt,
  useVerifyPushAuth,
} from "@/hooks/usePushAuthAttempts";
import { useCountdown } from "@/hooks/useCountdown";

interface PushAuthApprovalModalProps {
  attempt: PushAuthAttempt | null;
  isOpen: boolean;
  onClose: () => void;
}

export function PushAuthApprovalModal({
  attempt,
  isOpen,
  onClose,
}: PushAuthApprovalModalProps) {
  const verifyMutation = useVerifyPushAuth();
  const [enteredOtp, setEnteredOtp] = useState("");

  const isExpired = false;

  console.log(isExpired);

  if (!attempt) return null;

  const handleApprove = async () => {
    if (!enteredOtp.trim()) {
      return;
    }

    await verifyMutation.mutateAsync({
      requestId: attempt.requestId,
      otp: enteredOtp.trim(),
    });
    onClose();
  };

  const handleDeny = () => {
    setEnteredOtp("");
    onClose();
  };

  const formatTimeRemaining = (seconds: number) => {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, "0")}`;
  };

  return (
    <Dialog key={attempt.id} open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-blue-500" />
            Login Approval Required
          </DialogTitle>
          <DialogDescription>
            Someone is trying to access your account. Review the details below.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {/* Time remaining */}
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
            <div className="flex items-center gap-2">
              <Clock className="h-4 w-4 text-gray-500" />
              <span className="text-sm font-medium">Time remaining:</span>
            </div>
            <Badge variant={isExpired ? "destructive" : "secondary"}>
              {isExpired ? "EXPIRED" : formatTimeRemaining(new Date(attempt.expiresAt).getTime() - Date.now() / 1000)}
            </Badge>
          </div>

          {/* Login attempt info */}
          <div className="space-y-3 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-center gap-2 text-blue-700">
              <Smartphone className="h-4 w-4" />
              <span className="text-sm font-medium">Login Attempt Details</span>
            </div>

            <div className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-gray-600">Email:</span>
                <span className="font-medium">{attempt.email}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-600">Request ID:</span>
                <span className="font-mono text-xs">{attempt.requestId}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-600">Requested at:</span>
                <span>{new Date(attempt.createdAt).toLocaleString()}</span>
              </div>
            </div>
          </div>

          {/* Warning if expired */}
          {isExpired && (
            <div className="flex items-center gap-2 p-3 bg-red-50 border border-red-200 rounded-lg">
              <AlertTriangle className="h-4 w-4 text-red-500" />
              <span className="text-sm text-red-700">
                This login attempt has expired
              </span>
            </div>
          )}

          {/* OTP Input */}
          {!isExpired && (
            <div className="space-y-3">
              <div className="p-3 bg-green-50 border border-green-200 rounded-lg">
                <div className="flex items-center gap-2 text-green-700 mb-2">
                  <Smartphone className="h-4 w-4" />
                  <span className="text-sm font-medium">
                    Authentication Required
                  </span>
                </div>
                <p className="text-sm text-green-600">
                  An OTP has been sent to your registered device/email. Enter it
                  below to approve this login attempt.
                </p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="otp">Enter OTP</Label>
                <Input
                  id="otp"
                  type="text"
                  placeholder="Enter the 6-digit code"
                  value={enteredOtp}
                  onChange={(e) => setEnteredOtp(e.target.value)}
                  maxLength={6}
                  className="text-center text-lg tracking-wider font-mono"
                />
              </div>
            </div>
          )}

          {/* Action buttons */}
          <div className="flex gap-3 pt-4">
            {!isExpired ? (
              <>
                <Button
                  onClick={handleApprove}
                  className="flex-1"
                  disabled={verifyMutation.isPending || !enteredOtp.trim()}
                >
                  {verifyMutation.isPending ? "Approving..." : "Approve Login"}
                </Button>
                <Button
                  variant="outline"
                  onClick={handleDeny}
                  className="flex-1"
                >
                  Deny
                </Button>
              </>
            ) : (
              <Button variant="outline" onClick={onClose} className="w-full">
                Close
              </Button>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
