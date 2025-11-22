import { useEffect, useState, useCallback, useRef } from "react";
import { useAuth } from "./useAuth";

interface PushAuthState {
  status: "connecting" | "waiting" | "success" | "error" | "timeout";
  error?: string;
}

interface PushAuthOptions {
  clientId: string;
  onSuccess?: (token: string) => void;
  onError?: (error: string) => void;
  timeout?: number; 
}

export const usePushAuth = (options: PushAuthOptions) => {
  const { login } = useAuth();
  const [state, setState] = useState<PushAuthState>({ status: "connecting" });
  const eventSourceRef = useRef<EventSource | null>(null);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);

  const { clientId, onSuccess, onError, timeout = 120000 } = options;
  
  const cleanup = useCallback(() => {
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
    }
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
  }, []);

  const connect = useCallback(() => {
    if (!clientId) {
      setState({ status: "error", error: "Client ID is required" });
      return;
    }

    cleanup();

    try {

      const url = `http://localhost:8001/push/sse?clientId=${
        clientId
      }`;
      const eventSource = new EventSource(url);
      eventSourceRef.current = eventSource;

      setState({ status: "connecting" });

      eventSource.onopen = () => {
        console.log("SSE connection opened");
        setState({ status: "waiting" });
      };

      eventSource.addEventListener("login-success", (event) => {
        console.log("Login success event received:", event.data);
        try {
          const data = JSON.parse(event.data);
          const token = data.token;
          if (token) {
            setState({ status: "success" });
            login(token);
            onSuccess?.(token);
          } else {
            const error = "No token received";
            setState({ status: "error", error });
            onError?.(error);
          }
        } catch (err) {
          const error = "Failed to parse login response";
          setState({ status: "error", error });
          onError?.(error);
        }
        cleanup();
      });

      eventSource.onerror = (event) => {
        console.error("SSE error:", event);
        const error = "Connection failed";
        setState({ status: "error", error });
        onError?.(error);
        cleanup();
      };

      // Set up timeout
      timeoutRef.current = setTimeout(() => {
        setState({ status: "timeout" });
        onError?.("Authentication request timed out");
        cleanup();
      }, timeout);
    } catch (err) {
      const error = err instanceof Error ? err.message : "Failed to connect";
      setState({ status: "error", error });
      onError?.(error);
    }
  }, [clientId]);

  const disconnect = useCallback(() => {
    cleanup();
    setState({ status: "connecting" });
  }, [cleanup]);


  useEffect(() => {
    if (clientId) {
      connect();
    }
    return cleanup;
  }, [clientId]);

  return {
    state,
    connect,
    disconnect,
    isConnecting: state.status === "connecting",
    isWaiting: state.status === "waiting",
    isSuccess: state.status === "success",
    isError: state.status === "error",
    isTimeout: state.status === "timeout",
  };
};
