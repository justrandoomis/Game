/**
 * Standalone dev/production server.
 *
 * Inside the Levonis platform this file is not used — `createGameRouter()` is
 * mounted on the platform's own Express app instead. It exists so the game
 * backend can be run on its own, and so the exported Godot Web build in
 * `client/web/` can be served for testing.
 */

import express from 'express';
import path from 'path';
import { createGameRouter } from './game/router';
import { hasD1 } from './store';

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.use('/api/game', createGameRouter());

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', storage: hasD1() ? 'd1' : 'file' });
});

async function start() {
  // Godot's Web export needs cross-origin isolation for its threaded build.
  const clientDir = path.join(process.cwd(), 'client', 'web');
  app.use(
    express.static(clientDir, {
      setHeaders(res) {
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
      },
    }),
  );

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`LEVO Printer Farm on :${PORT} (storage: ${hasD1() ? 'D1' : 'file'})`);
  });
}

start();
