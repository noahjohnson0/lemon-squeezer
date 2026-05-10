import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Wi‑Fi Stats',
  description: 'Display current Wi‑Fi network information on macOS',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
