import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

test('identity comes only from a verified token; failures never expose internals', async t => {
  let touched = 0;
  const app = createApp({
    async verifyToken(token) {
      if (token === 'valid') return { uid: 'alice', email: 'alice@example.test' };
      if (token === 'outage') throw new Error('private credential detail');
      throw Object.assign(new Error('private token detail'), { code: 'auth/id-token-expired' });
    },
    users: {
      async get(identity) { touched++; return identity; },
      async ensure(identity) { touched++; return identity; }
    }
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const authorization of ['', 'Basic valid', 'Bearer expired', 'Bearer valid extra']) {
    const result = await fetch(`${base}/api/users/me`, { headers: { authorization } });
    assert.equal(result.status, 401);
    assert.deepEqual(await result.json(), { error: { code: 'UNAUTHENTICATED' } });
  }
  assert.equal(touched, 0);
  const result = await fetch(`${base}/api/users/me?uid=bob`, {
    method: 'POST', headers: { authorization: 'Bearer valid', 'content-type': 'application/json' },
    body: JSON.stringify({ uid: 'bob', email: 'bob@example.test', role: 'admin' })
  });
  assert.equal(result.status, 200);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await result.json(), { user: { uid: 'alice', email: 'alice@example.test' } });
  const outage = await fetch(`${base}/api/users/me`, { headers: { authorization: 'Bearer outage' } });
  assert.equal(outage.status, 503);
  assert.deepEqual(await outage.json(), { error: { code: 'SERVICE_UNAVAILABLE' } });
});
