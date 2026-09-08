export async function GET() {
  return Response.json({
    status: "ready",
    environment: process.env.APP_ENV ?? "local",
  });
}
