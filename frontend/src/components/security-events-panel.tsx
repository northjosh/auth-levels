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
import {
  METHOD_OPTIONS,
  TYPE_OPTIONS,
  useSecurityEvents,
  type SecurityEventsQuery,
} from "@/hooks/useSecurityEvents";

const inputClass =
  "h-9 rounded-md border border-input bg-background px-3 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring";

const filterFields = [
  { key: "osFamily", label: "OS" },
  { key: "deviceFamily", label: "Device" },
  { key: "remoteAddress", label: "IP" },
] as const;

function formatTime(dt: string) {
  return new Date(dt).toLocaleString();
}

export function SecurityEventsPanel() {
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [filters, setFilters] = useState<Record<string, string>>({});
  const [cursor, setCursor] = useState<{ next?: string; prev?: string }>({});

  const query: SecurityEventsQuery = {
    size: 20,
    ...filters,
    ...cursor,
  };

  const { data, isLoading, isFetching, error } = useSecurityEvents(query);

  const now = Date.now();

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
          <CardDescription>
            Narrow the event log by method, activity or origin
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">
                Method
              </label>
              <select
                className={`${inputClass} w-full`}
                value={draft.method ?? ""}
                onChange={(e) =>
                  setDraft((d) => ({ ...d, method: e.target.value }))
                }
              >
                <option value="">All</option>
                {METHOD_OPTIONS.map((m) => (
                  <option key={m} value={m}>
                    {m.toLowerCase().replace("_", " ")}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">
                Activity type
              </label>
              <select
                className={`${inputClass} w-full`}
                value={draft.type ?? ""}
                onChange={(e) =>
                  setDraft((d) => ({ ...d, type: e.target.value }))
                }
              >
                <option value="">All</option>
                {TYPE_OPTIONS.map((t) => (
                  <option key={t} value={t}>
                    {t.toLowerCase().replaceAll("_", " ")}
                  </option>
                ))}
              </select>
            </div>

            {filterFields.map(({ key, label }) => (
              <div key={key} className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">
                  {label}
                </label>
                <input
                  className={`${inputClass} w-full`}
                  value={draft[key] ?? ""}
                  placeholder={`Filter by ${label.toLowerCase()}`}
                  onChange={(e) =>
                    setDraft((d) => ({ ...d, [key]: e.target.value }))
                  }
                />
              </div>
            ))}

            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">
                From
              </label>
              <input
                type="datetime-local"
                className={`${inputClass} w-full`}
                value={draft.from ?? ""}
                onChange={(e) =>
                  setDraft((d) => ({ ...d, from: e.target.value }))
                }
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">
                To
              </label>
              <input
                type="datetime-local"
                className={`${inputClass} w-full`}
                value={draft.to ?? ""}
                onChange={(e) => setDraft((d) => ({ ...d, to: e.target.value }))}
              />
            </div>
          </div>

          <div className="flex gap-3 mt-4">
            <Button
              onClick={() => {
                const applied: Record<string, string> = {};
                for (const [key, value] of Object.entries(draft)) {
                  if (
                    key !== "from" &&
                    key !== "to" &&
                    value.trim() !== ""
                  ) {
                    applied[key] = value.trim();
                  }
                }
                if (draft.from) {
                  applied.from = new Date(draft.from).toISOString();
                }
                if (draft.to) {
                  applied.to = new Date(draft.to).toISOString();
                }
                setFilters(applied);
                setCursor({});
              }}
            >
              Apply
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                setDraft({});
                setFilters({});
                setCursor({});
              }}
            >
              Reset
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            Security Events
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                disabled={!data?.previous}
                onClick={() => setCursor({ prev: data!.previous! })}
              >
                Previous
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={!data?.next}
                onClick={() => setCursor({ next: data!.next! })}
              >
                Next
              </Button>
            </div>
          </CardTitle>
          <CardDescription>
            {isLoading
              ? "Loading events..."
              : isFetching
                ? "Refreshing..."
                : data?.data.length
                  ? "Your authentication activity"
                  : "No events match your filters"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {error && (
            <p className="text-sm text-destructive">
              Failed to load events:{" "}
              {error instanceof Error ? error.message : String(error)}
            </p>
          )}

          {data?.data.map((event) => {
            const isSuccess = event.type.endsWith("SUCCESS");
            return (
              <div
                key={event.id}
                className="flex items-center justify-between p-3 border rounded-lg mb-2"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <Badge
                    variant={isSuccess ? "default" : "destructive"}
                    className="shrink-0"
                  >
                    {event.type}
                  </Badge>
                  <Badge variant="outline" className="shrink-0">
                    {event.method.toLowerCase()}
                  </Badge>
                  <div className="text-sm text-muted-foreground truncate">
                    {[event.osFamily, event.deviceFamily, event.remoteAddress]
                      .filter(Boolean)
                      .join(" · ") || "unknown origin"}
                  </div>
                </div>
                <div className="text-right shrink-0">
                  <div className="text-sm">
                    {formatTime(event.createdAt)}
                  </div>
                  {Math.abs(now - new Date(event.createdAt).getTime()) <
                    3600_000 && <div className="text-xs text-muted-foreground">recent</div>}
                </div>
              </div>
            );
          })}
        </CardContent>
      </Card>
    </div>
  );
}