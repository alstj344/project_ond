// Explicit apply + count confirmation; create-only writes preserve existing documents.
const fs = require("node:fs");
const readline = require("node:readline");
const path = require("node:path");

async function main() {
  const args = process.argv.slice(2);
  const option = name => args[args.indexOf(name) + 1];
  if (!args.includes("--input")) throw Error("--input is required");
  const docs = [];
  for await (const line of readline.createInterface({ input: fs.createReadStream(option("--input")) })) {
    if (!line.trim()) continue;
    const doc = JSON.parse(line);
    if (!/^ks_[a-f0-9]{32}$/.test(doc.id) || doc.bookingEnabled !== false || doc.source?.snapshot !== "202607") {
      throw Error("Unexpected facility export");
    }
    docs.push(doc);
  }
  if (new Set(docs.map(x => x.id)).size !== docs.length) throw Error("Duplicate IDs");
  console.log(JSON.stringify({ collection: "facilities", documents: docs.length, apply: args.includes("--apply") }));
  if (!args.includes("--apply")) return;
  if (!args.includes("--confirm-count") || Number(option("--confirm-count")) !== docs.length) throw Error("Confirm exact count");
  if (!args.includes("--config") || !path.isAbsolute(option("--config"))) throw Error("Absolute backend config path required");
  const db = require(option("--config"));
  if (db.projectId !== "project-ond" || db.databaseId !== "ond-db") throw Error("Unexpected Firebase target");
  let created = 0, skipped = 0;
  for (let offset = 0; offset < docs.length; offset += 200) {
    const chunk = docs.slice(offset, offset + 200);
    const batch = db.batch();
    for (const { id, ...data } of chunk) batch.create(db.collection("facilities").doc(id), data);
    try { await batch.commit(); created += chunk.length; }
    catch (error) {
      if (error.code !== 6) throw error;
      // A conflicting create aborts the entire batch; retry individually without overwriting.
      for (const { id, ...data } of chunk) {
        try { await db.collection("facilities").doc(id).create(data); created++; }
        catch (itemError) { if (itemError.code === 6) skipped++; else throw itemError; }
      }
    }
    console.log(JSON.stringify({ created, skipped }));
  }
  console.log(JSON.stringify({ created, skipped, completed: true }));
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
