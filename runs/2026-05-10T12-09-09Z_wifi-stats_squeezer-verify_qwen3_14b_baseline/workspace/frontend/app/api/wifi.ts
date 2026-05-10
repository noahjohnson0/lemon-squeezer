export async function GET() {
  try {
    const res = await fetch('http://localhost:8000/api/wifi')
    const data = await res.json()
    return Response.json(data)
  } catch (error) {
    return Response.json({ error: 'Failed to fetch WiFi data' }, { status: 500 })
  }
}