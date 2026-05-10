export const metadata = {
  title: 'Wi-Fi Stats',
  description: 'Display basic Wi-Fi stats about the user\'s current network on macOS.',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
