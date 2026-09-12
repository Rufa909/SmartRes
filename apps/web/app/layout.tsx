import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SmartRes",
  description: "Smart restaurant and self-service ordering system"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}

