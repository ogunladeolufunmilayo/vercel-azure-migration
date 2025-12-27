import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

export async function GET() {
  const result = await pool.query(
    "select id, title, created_at from notes order by created_at desc limit 50"
  );
  return Response.json(result.rows);
}

export async function POST(req: Request) {
  const { title } = await req.json();
  const cleanTitle = (title ?? "").toString().trim();

  if (!cleanTitle) return new Response("title is required", { status: 400 });

  const result = await pool.query(
    "insert into notes (title) values ($1) returning id, title, created_at",
    [cleanTitle]
  );

  return Response.json(result.rows[0], { status: 201 });
}
