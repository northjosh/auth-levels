"use client";

import { useState } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { RefreshCw, Monitor, MapPin, Clock, AlertCircle } from "lucide-react";
import { usePushAuthAttempts } from "@/hooks/usePushAuthAttempts";
import { PushAuthApprovalModal } from "./push-auth-approval-modal";
import type { PushAuthAttempt } from "@/hooks/usePushAuthAttempts";

export function PushAuthPanel() {
  const { data: attempts, isLoading, refetch } = usePushAuthAttempts();
  const [selectedAttempt, setSelectedAttempt] =
    useState<PushAuthAttempt | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);


  const handleApproveAttempt = (attempt: PushAuthAttempt) => {
    setSelectedAttempt(attempt);
    setIsModalOpen(true);
  };

  const isExpired = (expiresAt: string) => {
    return new Date(expiresAt) < new Date();
  };

  const formatTimeAgo = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);

    if (diffMins < 1) return "Just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
  };

  return (
    <div className="space-y-6">
      {/* Active Login Attempts */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
          <div>
            <CardTitle className="flex items-center gap-2">
              <AlertCircle className="h-5 w-5 text-orange-500" />
              Pending Login Attempts
            </CardTitle>
            <CardDescription>
              Review and approve active login requests
            </CardDescription>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            disabled={isLoading}
          >
            <RefreshCw
              className={`h-4 w-4 ${isLoading ? "animate-spin" : ""}`}
            />
          </Button>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto"></div>
              <p className="text-sm text-muted-foreground mt-2">
                Loading attempts...
              </p>
            </div>
          ) : attempts?.length === 0 ? (
            <div className="text-center py-8">
              <AlertCircle className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <p className="text-lg font-medium">No pending login attempts</p>
              <p className="text-sm text-muted-foreground">
                When someone tries to log in to your account, you'll see it here
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {attempts && attempts.length > 0 && attempts.map((attempt) => (
                <div
                  key={attempt.id}
                  className="border rounded-lg p-4 space-y-3"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Badge
                        variant={
                          isExpired(attempt.expiresAt)
                            ? "destructive"
                            : "default"
                        }
                      >
                        {isExpired(attempt.expiresAt) ? "EXPIRED" : "PENDING"}
                      </Badge>
                      <span className="text-sm text-muted-foreground">
                        {formatTimeAgo(attempt.createdAt)}
                      </span>
                    </div>
                    {!isExpired(attempt.expiresAt) && (
                      <Button
                        size="sm"
                        onClick={() => handleApproveAttempt(attempt)}
                      >
                        Review
                      </Button>
                    )}
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                    <div className="flex items-center gap-2">
                      <Monitor className="h-4 w-4 text-muted-foreground" />
                      {/* <span>{attempt.userAgent || "Unknown device"}</span> */}
                    </div>
                    <div className="flex items-center gap-2">
                      <MapPin className="h-4 w-4 text-muted-foreground" />
                      {/* <span>{attempt.ipAddress || "Unknown location"}</span> */}
                    </div>
                    <div className="flex items-center gap-2">
                      <Clock className="h-4 w-4 text-muted-foreground" />
                      <span>
                        Expires: {new Date(attempt.expiresAt).toLocaleString()}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Recent Login Attempts */}
      {attempts && attempts.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Recent Login Activity</CardTitle>
            <CardDescription>
              Your recent login attempts and their status
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {attempts?.map((attempt) => (
                <div
                  key={attempt.id}
                  className="flex items-center justify-between p-3 border rounded-lg"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <Badge variant="secondary">COMPLETED</Badge>
                      <span className="text-sm font-medium">
                        {attempt.email || "Unknown device"}
                      </span>
                    </div>
                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
                      <span>{formatTimeAgo(attempt.createdAt)}</span>
                      <span>{attempt.email || "Unknown IP"}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Approval Modal */}
      <PushAuthApprovalModal
        attempt={selectedAttempt}
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false);
          setSelectedAttempt(null);
        }}
      />
    </div>
  );
}
