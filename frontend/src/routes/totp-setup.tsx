import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

import { TotpSetup } from "@/components/totp-setup";

const searchSchema = z.object({
  url: z.string().optional(),
});

export const Route = createFileRoute("/totp-setup")({
  validateSearch: searchSchema,
  component: TotpSetupPage,
});

function TotpSetupPage() {
  const { url } = Route.useSearch();

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-md">
        <TotpSetup url={url} />
      </div>
    </div>
  );
}
