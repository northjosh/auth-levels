# Auth Levels — Frontend

A React single-page application built with [Vite](https://vite.dev) and
[TanStack Router](https://tanstack.com/router) using file-based routing.

## Getting started

```bash
pnpm install
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000). The app expects the backend
to be running on `http://localhost:8001`.

## Scripts

| Script | Description |
| --- | --- |
| `pnpm dev` | Start the Vite dev server on port 3000 |
| `pnpm build` | Produce a production build in `dist/`, then type-check |
| `pnpm preview` | Serve the production build locally |
| `pnpm lint` | Run ESLint |

## Routing

Routes are file-based. Each file under `routes/` becomes a URL:

```
src/routes/
├── __root.tsx                          # app shell: providers + <Outlet />
├── index.tsx                           # /
├── login.tsx                           # /login
├── signup.tsx                          # /signup
├── totp.tsx                            # /totp
├── totp-setup.tsx                      # /totp-setup
├── push-auth.tsx                       # /push-auth
├── verify-email.tsx                    # /verify-email
├── password-reset.tsx                  # /password-reset
├── reset-password.tsx                  # /reset-password
└── email-verification-instructions.tsx # /email-verification-instructions
```

`@tanstack/router-plugin` regenerates `src/routeTree.gen.ts` on dev and build. That
file is generated — it is gitignored and should never be edited by hand.

Search parameters are declared per route with `validateSearch` and a Zod schema,
so they are typed at both the reading and the navigating end:

```tsx
export const Route = createFileRoute("/totp")({
  validateSearch: z.object({ token: z.string().optional() }),
  component: TotpPage,
});

const { token } = Route.useSearch();
```

```tsx
navigate({ to: "/totp", search: { token } });
```

## Project layout

All source lives under `src/`, imported through the `@/` alias (`@/` → `src/`):

- `src/components/` — feature components and shadcn/ui primitives
- `src/hooks/` — data fetching and auth hooks (TanStack Query)
- `src/lib/` — `api.ts` (base URL + response envelope) and `utils.ts`
- `src/utils/` — push-auth helpers and the Query client provider
- `src/styles/globals.css` — Tailwind v4 entry point and theme tokens

Config stays at the repo root: `index.html`, `vite.config.ts`, `tsconfig.json`,
`eslint.config.mjs`, `components.json`.

## Configuration

`VITE_API_URL` sets the backend base URL; it defaults to `http://localhost:8001`
when unset. See `.env.example`.

## Deployment

`pnpm build` emits a static bundle to `dist/`. Because this is a
single-page app, the host must rewrite unknown paths to `/index.html`,
otherwise deep links such as `/verify-email?token=…` will 404.
