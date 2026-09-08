import { expect, test } from "vitest";
import { GET as health } from "../app/health/route";
import { GET as ready } from "../app/ready/route";

test("GET /health returns 200 and status ok", async () => {
  const response = await health();
  const body = await response.json();

  expect(response.status).toBe(200);
  expect(body).toEqual({ status: "ok" });
});

test("GET /ready returns 200 and status ready", async () => {
  const response = await ready();
  const body = await response.json();

  expect(response.status).toBe(200);
  expect(body.status).toBe("ready");
});
