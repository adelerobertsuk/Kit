import { useSession } from "@tanstack/react-start/server";

function sessionConfig() {
  return {
    password: process.env["KIT_SESSION_SECRET"]!,
    name: "kit-device",
    maxAge: 60 * 60 * 24 * 365,
  };
}

// Server-signed, httpOnly cookie: the device identity can never be forged by a client.
export async function currentDeviceId(): Promise<string> {
  const session = await useSession<{ deviceId?: string }>(sessionConfig());
  const existing = session.data.deviceId;
  if (existing) return existing;
  const deviceId = `dev_${crypto.randomUUID()}`;
  await session.update({ deviceId });
  return deviceId;
}
