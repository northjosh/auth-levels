import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useEffect, useState } from "react";

import { apiUrl, type ApiResponse } from "@/lib/api";

export interface User {
  id: number;
  firstName: string;
  lastName: string;
  email: string;
  totpEnabled: boolean;
  webAuthnEnabled: boolean;
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (token: string) => void;
  logout: () => void;
  loading: boolean;
  isAuthenticated: boolean;
  refreshUser: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextType | null>(null);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};

const TOKEN_STORAGE_KEY = "auth_token";

const AUTH_QUERY_KEY = ["me"] as const;

/** The token was rejected — the session is over and must be cleared. */
class AuthRejectedError extends Error {}

const fetchUser = async (authToken: string): Promise<User> => {
  const response = await fetch(apiUrl("/me"), {
    headers: {
      Authorization: `Bearer ${authToken}`,
    },
  });

  if (response.status === 401 || response.status === 403) {
    throw new AuthRejectedError("Session expired");
  }

  if (!response.ok) {
    throw new Error("Failed to fetch user");
  }

  const body = (await response.json()) as ApiResponse<User>;
  return body.data;
};

export const useAuthState = (): AuthContextType => {
  const queryClient = useQueryClient();

  // Read synchronously on the first render. Deferring this to an effect would
  // leave `token` null for one render, and the redirect guards in the routes
  // key off `!loading && !isAuthenticated` — they would bounce an authenticated
  // user to /login before the token ever loaded.
  const [token, setToken] = useState<string | null>(() =>
    localStorage.getItem(TOKEN_STORAGE_KEY),
  );

  const query = useQuery({
    queryKey: [...AUTH_QUERY_KEY, token],
    queryFn: () => fetchUser(token as string),
    enabled: !!token,
    retry: false,
    // The session is only revalidated on mount and on explicit refreshUser(),
    // matching the previous hand-rolled behaviour.
    refetchOnWindowFocus: false,
  });

  const logout = useCallback(() => {
    setToken(null);
    localStorage.removeItem(TOKEN_STORAGE_KEY);
    queryClient.removeQueries({ queryKey: AUTH_QUERY_KEY });
  }, [queryClient]);

  const login = useCallback((newToken: string) => {
    localStorage.setItem(TOKEN_STORAGE_KEY, newToken);
    // Changing the token changes the query key, which triggers the fetch.
    setToken(newToken);
  }, []);

  // A rejected token is unrecoverable, so drop the session. Transport failures
  // and 5xx are left alone — they should not sign the user out.
  useEffect(() => {
    if (query.error instanceof AuthRejectedError) {
      logout();
    } else if (query.error) {
      console.error("Failed to fetch user:", query.error);
    }
  }, [query.error, logout]);

  const { refetch } = query;
  const refreshUser = useCallback(async () => {
    if (!token) return;
    await refetch();
  }, [token, refetch]);

  const user = query.data ?? null;

  return {
    user,
    token,
    login,
    logout,
    // A disabled query (no token) reports isLoading === false, which is exactly
    // the "nothing to load, not signed in" state the guards expect.
    loading: query.isLoading,
    isAuthenticated: !!user && !!token,
    refreshUser,
  };
};
