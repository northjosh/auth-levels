import { useEffect, useMemo, useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import {
  Copy,
  Loader2,
  MonitorSmartphone,
  Plus,
  Trash2,
} from "lucide-react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useAuth } from "@/hooks/useAuth";
import {
  type DeviceEnrollment,
  type TrustedDevice,
  useEnrollTrustedDevice,
  useRemoveTrustedDevice,
  useTrustedDevices,
} from "@/hooks/useTrustedDevices";
import { MOBILE_API_BASE_URL } from "@/lib/api";

const normalize = (value: string | null) => value?.toLowerCase() ?? "unknown";

const formatDate = (value: string | null) => {
  if (!value) return "Not yet";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
};

const formatCountdown = (seconds: number) => {
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return `${minutes}:${remainder.toString().padStart(2, "0")}`;
};

function DeviceRow({ device }: { device: TrustedDevice }) {
  const removeDevice = useRemoveTrustedDevice();
  const status = normalize(device.status);
  const isRemoving =
    removeDevice.isPending && removeDevice.variables === device.id;

  const handleRemove = () => {
    if (confirm(`Remove ${device.name ?? "this device"}?`)) {
      removeDevice.mutate(device.id);
    }
  };

  return (
    <div className="flex flex-col gap-4 rounded-lg border p-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex min-w-0 gap-3">
        <MonitorSmartphone
          aria-hidden="true"
          className="mt-0.5 size-5 shrink-0 text-muted-foreground"
        />
        <div className="min-w-0 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="truncate font-medium">
              {device.name ?? "Pending device"}
            </p>
            <Badge variant={status === "active" ? "default" : "secondary"}>
              {status}
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground">
            {[device.platform, device.appVersion].filter(Boolean).join(" · ") ||
              "Waiting for device details"}
          </p>
          <p className="text-xs text-muted-foreground">
            Paired {formatDate(device.pairedAt)} · Last seen{" "}
            {formatDate(device.lastSeenAt)} · Push{" "}
            {device.pushEnabled ? "on" : "off"}
          </p>
        </div>
      </div>
      <Button
        variant="outline"
        size="sm"
        disabled={isRemoving}
        onClick={handleRemove}
        aria-label={`Remove ${device.name ?? "pending device"}`}
      >
        {isRemoving ? (
          <Loader2 aria-hidden="true" className="animate-spin" />
        ) : (
          <Trash2 aria-hidden="true" />
        )}
        Remove
      </Button>
    </div>
  );
}

interface PairDeviceDialogProps {
  enrollment: DeviceEnrollment | null;
  pairingLink: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onRegenerate: () => void;
  regenerating: boolean;
}

function PairDeviceDialog({
  enrollment,
  pairingLink,
  open,
  onOpenChange,
  onRegenerate,
  regenerating,
}: PairDeviceDialogProps) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (!open) return;
    setNow(Date.now());
    const timer = window.setInterval(() => setNow(Date.now()), 1_000);
    return () => window.clearInterval(timer);
  }, [open]);

  const secondsLeft = enrollment
    ? Math.max(0, Math.ceil((Date.parse(enrollment.expiresAt) - now) / 1_000))
    : 0;
  const expired = enrollment !== null && secondsLeft === 0;

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(pairingLink);
      toast.success("Pairing link copied");
    } catch {
      toast.error("Could not copy the pairing link");
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Pair a trusted device</DialogTitle>
          <DialogDescription>
            Scan this QR code in the Auth Levels mobile app. The link expires
            after five minutes.
          </DialogDescription>
        </DialogHeader>

        {enrollment ? (
          <div className="space-y-4">
            <div className="mx-auto rounded-xl border bg-white p-4">
              <QRCodeSVG
                value={pairingLink}
                size={220}
                level="M"
                aria-label="Trusted device pairing QR code"
              />
            </div>

            <div className="text-center" aria-live="polite">
              <p className={expired ? "font-medium text-destructive" : "font-medium"}>
                {expired
                  ? "This pairing link has expired"
                  : `Expires in ${formatCountdown(secondsLeft)}`}
              </p>
              {!expired ? (
                <p className="text-sm text-muted-foreground">
                  Waiting for the mobile app to finish pairing…
                </p>
              ) : null}
            </div>

            <div className="space-y-2">
              <label htmlFor="pairing-link" className="text-sm font-medium">
                Pairing link
              </label>
              <div className="flex gap-2">
                <input
                  id="pairing-link"
                  readOnly
                  value={pairingLink}
                  className="h-9 min-w-0 flex-1 rounded-md border bg-muted px-3 font-mono text-xs"
                />
                <Button
                  type="button"
                  variant="outline"
                  size="icon"
                  onClick={copyLink}
                  aria-label="Copy pairing link"
                >
                  <Copy aria-hidden="true" />
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Mobile API: {MOBILE_API_BASE_URL}
              </p>
            </div>

            {expired ? (
              <Button
                className="w-full"
                onClick={onRegenerate}
                disabled={regenerating}
              >
                {regenerating ? (
                  <Loader2 aria-hidden="true" className="animate-spin" />
                ) : null}
                Generate a new link
              </Button>
            ) : null}
          </div>
        ) : (
          <div className="flex justify-center py-12">
            <Loader2
              aria-label="Creating pairing link"
              className="size-6 animate-spin"
            />
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

export function TrustedDevicesCard() {
  const { user } = useAuth();
  const [enrollment, setEnrollment] = useState<DeviceEnrollment | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [existingDeviceIds, setExistingDeviceIds] = useState<Set<string>>(
    () => new Set(),
  );
  const devicesQuery = useTrustedDevices(dialogOpen && enrollment !== null);
  const enrollDevice = useEnrollTrustedDevice();
  const devices = useMemo(() => devicesQuery.data ?? [], [devicesQuery.data]);

  const pairingLink = useMemo(() => {
    if (!enrollment || !user) return "";
    const query = new URLSearchParams({
      token: enrollment.enrollmentToken,
      api: MOBILE_API_BASE_URL,
      email: user.email,
    });
    return `authlevels://pair?${query.toString()}`;
  }, [enrollment, user]);

  useEffect(() => {
    if (!dialogOpen || !enrollment) return;
    const pairedDevice = devices.find(
      (device) =>
        !existingDeviceIds.has(device.id) && normalize(device.status) === "active",
    );
    if (!pairedDevice) return;

    setDialogOpen(false);
    setEnrollment(null);
    toast.success(`${pairedDevice.name ?? "Device"} paired successfully`);
  }, [devices, dialogOpen, enrollment, existingDeviceIds]);

  const createEnrollment = async () => {
    setExistingDeviceIds(new Set(devices.map((device) => device.id)));
    setDialogOpen(true);
    setEnrollment(null);
    try {
      setEnrollment(await enrollDevice.mutateAsync());
    } catch {
      setDialogOpen(false);
    }
  };

  const handleOpenChange = (open: boolean) => {
    setDialogOpen(open);
    if (!open) setEnrollment(null);
  };

  return (
    <>
      <Card>
        <CardHeader>
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div className="space-y-1.5">
              <CardTitle>Trusted Devices</CardTitle>
              <CardDescription>
                Pair phones that can review and approve login requests.
              </CardDescription>
            </div>
            <Button onClick={createEnrollment} disabled={enrollDevice.isPending}>
              {enrollDevice.isPending ? (
                <Loader2 aria-hidden="true" className="animate-spin" />
              ) : (
                <Plus aria-hidden="true" />
              )}
              Pair a device
            </Button>
          </div>
        </CardHeader>
        <CardContent className="space-y-3">
          {devicesQuery.isLoading ? (
            <p className="text-sm text-muted-foreground">Loading devices…</p>
          ) : devicesQuery.isError ? (
            <div className="flex items-center justify-between gap-4 rounded-lg border border-destructive/30 p-4">
              <p className="text-sm text-destructive">
                {devicesQuery.error.message}
              </p>
              <Button variant="outline" size="sm" onClick={() => devicesQuery.refetch()}>
                Retry
              </Button>
            </div>
          ) : devices.length === 0 ? (
            <p className="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground">
              No trusted devices yet.
            </p>
          ) : (
            devices.map((device) => <DeviceRow key={device.id} device={device} />)
          )}
        </CardContent>
      </Card>

      <PairDeviceDialog
        enrollment={enrollment}
        pairingLink={pairingLink}
        open={dialogOpen}
        onOpenChange={handleOpenChange}
        onRegenerate={createEnrollment}
        regenerating={enrollDevice.isPending}
      />
    </>
  );
}
