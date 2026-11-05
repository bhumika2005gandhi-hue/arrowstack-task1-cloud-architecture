###############################################################################
# Smoke tests — Task 1 Cloud-Hosted Business API
# Run: ALB_URL=http://<alb-dns-name> npm test
###############################################################################
const request = require("supertest");
const BASE = process.env.ALB_URL || "http://localhost:3000";

describe("Health check", () => {
  test("GET /health returns 200 with status=ok", async () => {
    const r = await request(BASE).get("/health").expect(200);
    expect(r.body.status).toBe("ok");
    expect(r.body.host).toBeTruthy();
  });
});

describe("Root", () => {
  test("GET / returns service metadata", async () => {
    const r = await request(BASE).get("/").expect(200);
    expect(r.body.service).toBe("arrowstack-t1-app");
    expect(r.body.version).toMatch(/^\d/);
  });
});

describe("Items CRUD", () => {
  let id;
  test("POST /items creates an item", async () => {
    const r = await request(BASE)
      .post("/items")
      .send({ name: "Test Widget", description: "from jest", price: 9.99 })
      .expect(201);
    expect(r.body.id).toBeGreaterThan(0);
    id = r.body.id;
  });

  test("GET /items/:id returns the created item", async () => {
    const r = await request(BASE).get(`/items/${id}`).expect(200);
    expect(r.body.name).toBe("Test Widget");
  });

  test("POST /items without name returns 400", async () => {
    await request(BASE).post("/items").send({}).expect(400);
  });

  test("GET /items/:99999 returns 404", async () => {
    await request(BASE).get("/items/99999").expect(404);
  });
});
