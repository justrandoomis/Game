import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

/**
 * The client and the server meet at the error code. The server invents a
 * refusal, the client has to turn it into a sentence — and when it cannot, the
 * player is told something untrue (the fallback used to claim the connection
 * was down). This is the one test that can see both sides.
 */
const ROOT = path.join(__dirname, '..');

function serverErrorCodes(): Set<string> {
  const codes = new Set<string>();
  const dirs = ['shared/engines', 'server/game'];
  for (const dir of dirs) {
    for (const file of fs.readdirSync(path.join(ROOT, dir))) {
      if (!file.endsWith('.ts')) continue;
      const src = fs.readFileSync(path.join(ROOT, dir, file), 'utf8');
      for (const m of src.matchAll(/fail\('([a-z_]+)'\)/g)) codes.add(m[1]);
      for (const m of src.matchAll(/error: '([a-z_]+)'/g)) codes.add(m[1]);
    }
  }
  return codes;
}

function stringsFor(lang: string): Set<string> {
  const src = fs.readFileSync(path.join(ROOT, 'godot/autoload/I18n.gd'), 'utf8');
  const table = src.split(`"${lang}": {`)[1].split('\n\t},')[0];
  return new Set([...table.matchAll(/"([a-z_0-9]+)":/g)].map((m) => m[1]));
}

describe('error codes reach the player as words', () => {
  it('every refusal the server can send has an English sentence', () => {
    const en = stringsFor('en');
    const unmapped = [...serverErrorCodes()].filter((c) => !en.has(c));
    // The unknown_* family means the client sent an id the server does not
    // have. A player can do nothing about it and should never see it, so they
    // share the generic sentence rather than each carrying their own.
    expect(unmapped.filter((c) => !c.startsWith('unknown_'))).toEqual([]);
  });

  it('has the same keys in all three languages', () => {
    const en = stringsFor('en');
    for (const lang of ['ar', 'ku']) {
      const other = stringsFor(lang);
      expect([...en].filter((k) => !other.has(k))).toEqual([]);
      expect([...other].filter((k) => !en.has(k))).toEqual([]);
    }
  });
});
