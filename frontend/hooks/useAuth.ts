import { useState, useEffect, createContext, useContext } from "react";

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

export const useAuthState = () => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    const init = async () => {
      const savedToken = localStorage.getItem("auth_token");

      if (savedToken) {
        setToken(savedToken);
        await fetchUser(savedToken);
      } else {
        setLoading(false);
      }
    };

    init();
  }, []);

  const fetchUser = async (authToken: string) => {
    try {
      const response = await fetch("http://localhost:8001/auth/me", {
        headers: {
          Authorization: `Bearer ${authToken}`,
        },
      });

      if (response.ok) { 
        const userData = await response.json();
        setUser(userData.data);
      } else {
        logout();
      }
    } catch (error) {
      console.error("Failed to fetch user:", error);
      logout();
    } finally {
      setLoading(false);
    }
  };

  const login = (newToken: string) => {
    setToken(newToken);
    localStorage.setItem("auth_token", newToken);
    fetchUser(newToken);
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem("auth_token");
  };

  const refreshUser = async () => {
    if (token) {
      await fetchUser(token);
    }
  };

  return {
    user,
    token,
    login,
    logout,
    isAuthenticated: !!user && !!token,
    refreshUser,
    loading,
  };
};
