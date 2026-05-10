/* Next.js uses the new App Router. Minimal layout to provide Tailwind styles.
   We import the global Tailwind CSS file, so it compiles into the bundle. */
import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Wi‑Fi Info',
  description: 'Display current Wi‑Fi connection details',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang='en'><body>{children}</body></html>
}
