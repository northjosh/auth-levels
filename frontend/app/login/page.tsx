"use client";

import { LoginForm } from "@/components/login-form";
import { PushAuthDemo } from "@/components/push-auth";
import { useState } from "react";

export default function Page() {
  const [activeTab, setActiveTab] = useState<"login" | "push-auth">("login");
  return (
    <div className="flex flex-col min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="flex space-x-1 mb-4">
        <button
          onClick={() => setActiveTab("login")}
          className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
            activeTab === "login"
              ? "border-primary text-primary"
              : "border-transparent text-muted-foreground hover:text-foreground"
          }`}
        >
          Login
        </button>
        <button
          onClick={() => setActiveTab("push-auth")}
          className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
            activeTab === "push-auth"
              ? "border-primary text-primary"
              : "border-transparent text-muted-foreground hover:text-foreground"
          }`}
        >
          Passwordless Login
        </button>
      </div>
      <div className="w-full max-w-sm">
        {activeTab === "login" && <LoginForm />}
        {activeTab === "push-auth" && <PushAuthDemo />}
      </div>
    </div>
  );
}
