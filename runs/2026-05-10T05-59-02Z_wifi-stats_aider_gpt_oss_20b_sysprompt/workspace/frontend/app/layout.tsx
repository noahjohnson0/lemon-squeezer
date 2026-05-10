export const metadata = {
  title: 'Wi‑Fi Stats',
  description: 'Displays Wi‑Fi statistics for macOS',
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
