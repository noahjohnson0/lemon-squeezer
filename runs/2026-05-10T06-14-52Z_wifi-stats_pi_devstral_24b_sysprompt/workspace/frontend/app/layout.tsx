import './globals.css'

export const metadata = {
  title: 'Wi-Fi Stats',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}