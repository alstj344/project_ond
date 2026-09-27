import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

test('production endpoints require HTTPS; localhost is development-only', () => {
  const source = readFileSync(new URL('../CalmIOS/APIService.swift', import.meta.url), 'utf8');
  const start = source.indexOf('enum APIEndpoint {');
  const end = source.indexOf('// MARK: - Program', start);
  assert.ok(start >= 0 && end > start);
  const directory = mkdtempSync(join(tmpdir(), 'ond-endpoint-'));
  try {
    const file = join(directory, 'main.swift');
    writeFileSync(file, `import Foundation\n${source.slice(start, end)}
func reject(_ value: String?, fallback: String? = nil, path: String = "/api/users/me") {
    do {
        _ = try APIEndpoint.resolve(configured: value, fallback: fallback, path: path)
        fatalError("Unsafe endpoint accepted")
    } catch {}
}
let valid = try APIEndpoint.resolve(configured: "https://api.example.com/", fallback: nil, path: "/api/users/me")
precondition(valid.absoluteString == "https://api.example.com/api/users/me")
let local = try APIEndpoint.resolve(configured: nil, fallback: "http://localhost:3000", path: "/api/programs")
precondition(local.absoluteString == "http://localhost:3000/api/programs")
reject(nil)
reject("")
reject("http://api.example.com")
reject("https://localhost")
reject("http://localhost:3000")
reject("https://user:pass@api.example.com")
reject("https://api.example.com?redirect=bad")
reject("https://api.example.com#fragment")
reject("https://api.example.com/prefix")
reject("$(OND_API_BASE_URL)")
reject("https://api.example.com", path: "//evil.example.com")
reject("https://api.example.com", path: "/api/../admin")
reject("https://api.example.com", path: "/api/%2e%2e/admin")
reject("http://evil.example.com", fallback: "http://localhost:3000")
print("Endpoint checks passed")
`);
    const result = spawnSync('xcrun', ['swift', file], {
      encoding: 'utf8', timeout: 120000,
      env: { ...process.env, DEVELOPER_DIR: '/Applications/Xcode.app/Contents/Developer' }
    });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    assert.match(result.stdout, /Endpoint checks passed/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
