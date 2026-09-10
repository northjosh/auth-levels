import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

import { ResetForm } from "@/components/reset-form";

const searchSchema = z.object({
  token: z.string().optional(),
});

export const Route = createFileRoute("/password-reset")({
  validateSearch: searchSchema,
  component: ResetPage,
});

function ResetPage() {
  const { token } = Route.useSearch();

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <ResetForm token={token} />
      </div>
    </div>
  );
}
