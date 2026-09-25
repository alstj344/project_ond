import express from 'express';
import { rateLimit } from 'express-rate-limit';

export function createApp({ verifyToken, users }) {
  const app = express();
  app.disable('x-powered-by');
  app.use((_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });
  app.get('/health', (_req, res) => res.json({ status: 'ok' }));
  app.use('/api', rateLimit({ windowMs: 60000, limit: 60,
    standardHeaders: 'draft-8', legacyHeaders: false,
    message: { error: { code: 'TOO_MANY_REQUESTS' } } }));

  const invalidTokens = new Set(['auth/argument-error', 'auth/invalid-id-token',
    'auth/id-token-expired', 'auth/id-token-revoked', 'auth/user-disabled', 'auth/user-not-found']);
  async function authMiddleware(req, res, next) {
    const header = req.get('authorization') ?? '';
    const match = /^Bearer ([^\s]+)$/i.exec(header);
    if (!match || match[1].length > 16384) {
      return res.status(401).json({ error: { code: 'UNAUTHENTICATED' } });
    }
    try {
      const identity = await verifyToken(match[1]);
      if (typeof identity.uid !== 'string' || !identity.uid || identity.uid.includes('/') ||
          identity.uid.length > 128) {
        return res.status(401).json({ error: { code: 'UNAUTHENTICATED' } });
      }
      if (typeof identity.email !== 'string' || !identity.email || identity.email.length > 254) {
        return res.status(403).json({ error: { code: 'EMAIL_REQUIRED' } });
      }
      req.identity = { uid: identity.uid, email: identity.email };
      next();
    } catch (error) {
      if (invalidTokens.has(error.code)) {
        return res.status(401).json({ error: { code: 'UNAUTHENTICATED' } });
      }
      next(error);
    }
  }
  app.use('/api', authMiddleware);
  app.get('/api/users/me', async (req, res) => {
    const user = await users.get(req.identity);
    if (!user) return res.status(404).json({ error: { code: 'USER_NOT_FOUND' } });
    res.json({ user });
  });
  // Idempotent initialization; identity never comes from request body or query.
  app.post('/api/users/me', async (req, res) => {
    res.json({ user: await users.ensure(req.identity) });
  });
  app.use((_req, res) => res.status(404).json({ error: { code: 'NOT_FOUND' } }));
  app.use((_error, _req, res, _next) => {
    res.status(503).json({ error: { code: 'SERVICE_UNAVAILABLE' } });
  });
  return app;
}
