"use client";

import { useEffect, useState } from "react";

type Note = { id: number; title: string; created_at: string };

export default function Home() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);

  async function loadNotes() {
    const res = await fetch("/api/notes");
    setNotes(await res.json());
  }

  async function addNote(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const res = await fetch("/api/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title }),
      });
      if (!res.ok) throw new Error(await res.text());
      setTitle("");
      await loadNotes();
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    loadNotes();
  }, []);

  return (
    <main style={{ maxWidth: 720, margin: "0 auto", padding: 24, fontFamily: "system-ui" }}>
      <h1>Notes</h1>

      <form onSubmit={addNote} style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Type a note..."
          style={{ flex: 1, padding: 10 }}
        />
        <button disabled={busy} style={{ padding: "10px 14px" }}>
          {busy ? "Adding..." : "Add"}
        </button>
      </form>

      <ul style={{ display: "grid", gap: 10, paddingLeft: 18 }}>
        {notes.map((n) => (
          <li key={n.id}>
            <div><strong>{n.title}</strong></div>
            <small>{new Date(n.created_at).toLocaleString()}</small>
          </li>
        ))}
      </ul>
    </main>
  );
}
