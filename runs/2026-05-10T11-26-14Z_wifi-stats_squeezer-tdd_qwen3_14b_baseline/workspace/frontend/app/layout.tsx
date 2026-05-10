import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Wi-Fi Stats',
  description: 'Display current Wi-Fi network statistics on macOS',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-100 min-h-screen flex flex-col">
        <header className="p-6 bg-white shadow">
          <h1 className="text-2xl font-bold">Wi-Fi Stats</h1>
        </header>
        <main className="flex-grow p-6">
          {children}
        </main>
      </body>
    </html>
  )
}