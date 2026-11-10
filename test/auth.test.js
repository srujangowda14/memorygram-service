import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import test from 'node:test';

// Listen on an OS-assigned loopback port to exercise the real HTTP boundary.
// Close both local servers even when a credential assertion fails.
async function listen(server, t) {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  return 'http://127.0.0.1:' + server.address().port;
}

test('bearer verification and group authorization', async t => {
  const memberId = '85ba74fa-d99c-4b0b-877d-b07e363f5214';
  const groupId = '2abc1073-9452-41ff-aba9-05486a6d8041';
  let questReads = 0;
  const upstream = createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    res.setHeader('Content-Type', 'application/json');
    if (url.pathname === '/auth/v1/user') {
      if (req.headers.authorization === 'Bearer valid-session') {
        return res.end(JSON.stringify({ id: memberId, email: 'member@example.test' }));
      }
      res.writeHead(401);
      return res.end(JSON.stringify({ message: 'Expired or invalid token' }));
    }
    if (url.pathname === '/rest/v1/group_members') {
      const matches = url.searchParams.get('group_id') === 'eq.' + groupId
        && url.searchParams.get('user_id') === 'eq.' + memberId;
      return res.end(JSON.stringify(matches ? [{ group_id: groupId }] : []));
    }
    if (url.pathname === '/rest/v1/quests') {
      questReads++;
      return res.end(JSON.stringify([{ scope: url.searchParams.get('or') ?? url.searchParams.get('group_id') }]));
    }
    res.writeHead(404).end();
  });
  process.env.SUPABASE_URL = await listen(upstream, t);
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-server-key';
  const { default: app } = await import('../src/index.js');
  const base = await listen(createServer(app), t);
  const read = (path, authorization) => fetch(base + path, {
    headers: authorization ? { authorization } : {},
  });
  for (const credential of [undefined, 'Basic x', 'valid-session', 'Bearer expired']) {
    assert.equal((await read('/v1/me', credential)).status, 401);
    assert.equal((await read('/v1/nearby/spots', credential)).status, 401);
  }
  assert.deepEqual(await (await read('/v1/me', 'Bearer valid-session')).json(),
    { id: memberId, email: 'member@example.test' });
  assert.equal((await read('/v1/quests?groupId=invalid', 'Bearer valid-session')).status, 400);
  assert.equal((await read('/v1/quests?groupId=' + memberId, 'Bearer valid-session')).status, 403);
  assert.equal(questReads, 0);
  assert.deepEqual(await (await read('/v1/quests', 'Bearer valid-session')).json(),
    { quests: [{ scope: 'is.null' }] });
  assert.deepEqual(await (await read('/v1/quests?groupId=' + groupId, 'Bearer valid-session')).json(),
    { quests: [{ scope: '(group_id.is.null,group_id.eq.' + groupId + ')' }] });
});
