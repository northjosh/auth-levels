import { useState } from "react";
import { Check, Copy, Download } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";

interface RecoveryCodesDialogProps {
  /** The plaintext codes, or null while there is nothing to show. */
  codes: string[] | null;
  /** Called once the user confirms they have saved the codes. */
  onAcknowledge: () => void;
}

const FILENAME = "auth-levels-recovery-codes.txt";

/**
 * Shows the recovery codes returned by TOTP activation.
 *
 * The backend stores only hashes of these codes, so this is the single moment
 * they exist in plaintext — there is no way to show them again. That is why
 * the dialog cannot be dismissed by Escape, an overlay click, or a close
 * button: an accidental keypress would destroy them permanently.
 */
export function RecoveryCodesDialog({
  codes,
  onAcknowledge,
}: RecoveryCodesDialogProps) {
  const [hasSaved, setHasSaved] = useState(false);
  const [isCopied, setIsCopied] = useState(false);

  const asText = codes?.join("\n") ?? "";

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(asText);
      setIsCopied(true);
      toast.success("Recovery codes copied to clipboard");
      setTimeout(() => setIsCopied(false), 2000);
    } catch {
      toast.error("Failed to copy recovery codes");
    }
  };

  const handleDownload = () => {
    const url = URL.createObjectURL(
      new Blob([`${asText}\n`], { type: "text/plain" }),
    );
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = FILENAME;
    anchor.click();
    URL.revokeObjectURL(url);
  };

  const handleDone = () => {
    setHasSaved(false);
    setIsCopied(false);
    onAcknowledge();
  };

  return (
    <Dialog open={codes !== null}>
      <DialogContent
        // The built-in close button is hidden rather than removed so the
        // shared Dialog primitive stays untouched for every other caller.
        className="sm:max-w-md [&>button]:hidden"
        onEscapeKeyDown={(event) => event.preventDefault()}
        onPointerDownOutside={(event) => event.preventDefault()}
        onInteractOutside={(event) => event.preventDefault()}
      >
        <DialogHeader>
          <DialogTitle>Save your recovery codes</DialogTitle>
          <DialogDescription>
            Use one of these if you lose access to your authenticator app. Each
            code works once. They will not be shown again.
          </DialogDescription>
        </DialogHeader>

        <div className="grid grid-cols-2 gap-2 rounded-md border bg-muted/40 p-4">
          {codes?.map((code) => (
            <code key={code} className="font-mono text-sm tracking-wide">
              {code}
            </code>
          ))}
        </div>

        <div className="flex gap-2">
          <Button variant="outline" className="flex-1" onClick={handleCopy}>
            {isCopied ? (
              <Check className="mr-2 h-4 w-4" />
            ) : (
              <Copy className="mr-2 h-4 w-4" />
            )}
            {isCopied ? "Copied" : "Copy all"}
          </Button>
          <Button variant="outline" className="flex-1" onClick={handleDownload}>
            <Download className="mr-2 h-4 w-4" />
            Download .txt
          </Button>
        </div>

        <div className="flex items-center space-x-2">
          <Checkbox
            id="saved-recovery-codes"
            checked={hasSaved}
            onCheckedChange={(checked) => setHasSaved(checked === true)}
          />
          <Label
            htmlFor="saved-recovery-codes"
            className="text-sm font-normal leading-none"
          >
            I have saved my recovery codes
          </Label>
        </div>

        <DialogFooter>
          <Button className="w-full" disabled={!hasSaved} onClick={handleDone}>
            Done
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
