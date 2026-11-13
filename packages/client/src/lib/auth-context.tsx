import { createContext, useContext, useEffect, useState } from "react";
import { authClient, type Session } from "./auth-client";

// Allow seeding the session from SSR route context to avoid double fetching.
// If an initial session is provided we skip the first getSession() call.

interface AuthContextType {
  session: Session | null;
  isLoading: boolean;
  signIn: (email: string, password: string, turnstileToken?: string) => Promise<void>;
  signUp: (email: string, password: string, name?: string, turnstileToken?: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children, initialSession }: { children: React.ReactNode; initialSession?: Session | null }) {
  const [session, setSession] = useState<Session | null>(initialSession ?? null);
  const [isLoading, setIsLoading] = useState(!initialSession);

  useEffect(() => {
    if (initialSession) {
      return;
    }

    let cancelled = false;

    const checkSession = async () => {
      try {
        const { data } = await authClient.getSession();

        if (!cancelled) setSession(data);
      } catch (error) {
        if (!cancelled) {
          console.error("Failed to get session:", error);
          setSession(null);
        }
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    checkSession();
    return () => { cancelled = true; };
  }, [initialSession]);

  const signIn = async (email: string, password: string, turnstileToken?: string) => {
    console.log("Signing in with email:", email);
    const { error } = await authClient.signIn.email({
      email,
      password,
      fetchOptions: {
        headers: turnstileToken ? { 'x-turnstile-token': turnstileToken } : {},
      },
    });

    console.log("Sign in response error:", error);

    if (error) {
      throw new Error(error.message);
    }

    console.log("Sign in successful");

    // Refresh session after sign in
    const sessionData = await authClient.getSession();

    console.log("Fetched session data after sign in:", sessionData);

    setSession(sessionData.data);
  };

  const signUp = async (email: string, password: string, name?: string, turnstileToken?: string) => {
    const { error } = await authClient.signUp.email({
      email,
      password,
      name: name || email.split("@")[0],
      fetchOptions: {
        headers: turnstileToken ? { 'x-turnstile-token': turnstileToken } : {},
      },
    });

    if (error) {
      throw new Error(error.message);
    }

    // Refresh session after sign up
    const sessionData = await authClient.getSession();
    setSession(sessionData.data);
  };

  const signOut = async () => {
    await authClient.signOut();
    setSession(null);
  };

  return (
    <AuthContext.Provider value={{ session, isLoading, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
