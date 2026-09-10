import { Outlet, createRootRoute } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/react-router-devtools";

import { AuthProvider } from "@/components/auth-provider";
import { Toaster } from "@/components/ui/sonner";
import { ReactQueryClientProvider } from "@/utils/query-client";

export const Route = createRootRoute({
  component: RootLayout,
});

function RootLayout() {
  return (
    <ReactQueryClientProvider>
      <AuthProvider>
        <Outlet />
        <Toaster />
        {import.meta.env.DEV && <TanStackRouterDevtools position="bottom-left" />}
      </AuthProvider>
    </ReactQueryClientProvider>
  );
}
