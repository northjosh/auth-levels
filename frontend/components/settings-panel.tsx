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
import { useAuth } from "@/hooks/useAuth";
import {
  useEnableTotp,
  useDisableTotp,
  useWebAuthnCredentials,
  useDeleteWebAuthnCredential,
} from "@/hooks/useSettings";
import { toast } from "sonner";
import { useRegisterWebAuthn } from "@/hooks/useWebAuthn";

export function SettingsPanel() {
  const { user } = useAuth();
  const enableTotp = useEnableTotp();
  const disableTotp = useDisableTotp();
  const { data: webAuthnCredentials = [] } = useWebAuthnCredentials();
  const deleteWebAuthnCredential = useDeleteWebAuthnCredential();
  const { mutate: registerWebAuthn } = useRegisterWebAuthn();

  if (!user) return null;

  const handleToggleTotp = () => {
    if (user.totpEnabled) {
      disableTotp.mutate();
    } else {
      enableTotp.mutate();
    }
  };

  const handleDeleteWebAuthnCredential = (credentialId: number) => {
    if (confirm("Are you sure you want to delete this WebAuthn credential?")) {
      deleteWebAuthnCredential.mutate(credentialId);
    }
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Two-Factor Authentication (TOTP)</CardTitle>
          <CardDescription>
            Secure your account with time-based one-time passwords
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">
                Status: {user.totpEnabled ? "Enabled" : "Disabled"}
              </p>
              <p className="text-sm text-muted-foreground">
                {user.totpEnabled
                  ? "TOTP is currently protecting your account"
                  : "Enable TOTP for additional security"}
              </p>
            </div>
            <Button
              onClick={handleToggleTotp}
              variant={user.totpEnabled ? "destructive" : "default"}
              disabled={enableTotp.isPending || disableTotp.isPending}
            >
              {enableTotp.isPending || disableTotp.isPending
                ? "Loading..."
                : user.totpEnabled
                ? "Disable TOTP"
                : "Enable TOTP"}
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>WebAuthn / Passkeys</CardTitle>
          <CardDescription>
            Manage your WebAuthn credentials and passkeys
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium">
                Status: {user.webAuthnEnabled ? "Enabled" : "Disabled"}
              </p>
              <p className="text-sm text-muted-foreground">
                {webAuthnCredentials.length} credential(s) registered
              </p>
            </div>
            <Button onClick={() => registerWebAuthn()}>Add Credential</Button>
          </div>

          {webAuthnCredentials.length > 0 && (
            <div className="space-y-2">
              <h4 className="font-medium">Registered Credentials</h4>
              {webAuthnCredentials.map((credential: any) => (
                <div
                  key={credential.id}
                  className="flex items-center justify-between p-3 border rounded-lg"
                >
                  <div>
                    <p className="font-medium">Credential {credential.id}</p>
                    <p className="text-sm text-muted-foreground">
                      Sign count: {credential.signatureCount}
                    </p>
                  </div>
                  <Button
                    variant="destructive"
                    size="sm"
                    onClick={() =>
                      handleDeleteWebAuthnCredential(credential.id)
                    }
                    disabled={deleteWebAuthnCredential.isPending}
                  >
                    Delete
                  </Button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
