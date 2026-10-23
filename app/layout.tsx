import type { Metadata } from "next";
import "./globals.css";
import "./brand.css";
import "./workflows.css";

export const metadata: Metadata = {
  title: "AHF Workspace | Aminia Hope Foundation",
  description: "The private team workspace for Aminia Hope Foundation.",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "AHF Workspace", statusBarStyle: "default" },
  robots: { index: false, follow: false },
  icons: {
    icon: "/icons/icon-192.png",
    apple: "/icons/icon-192.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
