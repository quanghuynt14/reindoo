import { env } from "@/config/env";
import { createAuthClient } from "better-auth/client";

export const authClient = createAuthClient({
  baseURL: env.VITE_API_URL, 
  credentials: "include",
});

export type Session = typeof authClient.$Infer.Session;
