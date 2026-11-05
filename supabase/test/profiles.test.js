import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

// Run the actual migrations in a fresh PostgreSQL database. Only the Supabase
// managed auth/storage schemas and request identity are supplied by this fixture.
test('approve follows, publish atomically to each profile, and enforce photo privacy', async t => {
  const db = await PGlite.create({ extensions: { pgcrypto } });
  t.after(() => db.close());
  await db.exec(`
    create role anon;
    create role authenticated;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb);
    create function auth.uid() returns uuid language sql stable as
      'select nullif(current_setting(''test.uid'', true), '''')::uuid';
    create table storage.buckets(id text primary key, name text, public boolean);
    create table storage.objects(bucket_id text, name text, primary key(bucket_id,name));
    alter table storage.objects enable row level security;
    create function storage.foldername(text) returns text[] language sql immutable as
      'select (string_to_array($1,''/''))[1:array_length(string_to_array($1,''/''),1)-1]';
    grant usage on schema auth, storage to authenticated,anon;
    grant select,insert on storage.objects to authenticated;
    alter default privileges in schema public grant select,insert,update,delete on tables to authenticated,anon;
  `);
  for (const file of ['001_memorygram.sql','002_auth_access.sql','003_social_profiles.sql','004_memory_feed.sql']) {
    await db.exec(await readFile(new URL('../migrations/' + file, import.meta.url), 'utf8'));
  }
  const [ada, ben, cy] = [randomUUID(), randomUUID(), randomUUID()];
  const mid = randomUUID();
  for (const [id, name] of [[ada,'Ada'], [ben,'Ben'], [cy,'Cy']]) {
    await db.query('insert into auth.users values ($1,$2)', [id, { full_name: name }]);
  }
  await db.exec('set role authenticated');
  const login = id => db.query("select set_config('test.uid',$1,false)", [id]);
  const follow = (id, action = 'follow') => db.query('select change_follow($1,$2)',[id,action]);
  const rows = async (sql, args = []) => (await db.query(sql,args)).rows;
  const publish = (friends, id = mid) => db.query(
    "select publish_memory($1,'Wrong turn','Coin walk','The walkers',$2::uuid[])", [id,friends]);
  const visible = async expected => {
    assert.equal((await rows('select id from memories where id=$1',[mid])).length, expected ? 1 : 0);
    assert.equal((await rows('select person_id from memory_people where memory_id=$1',[mid])).length, expected ? 2 : 0);
    assert.equal((await rows('select name from storage.objects where name=$1',[ada + '/' + mid])).length, expected ? 1 : 0);
  };

  await login(ada);
  assert.equal((await rows("select is_private from profile_people('profile',$1)", [ada]))[0].is_private, true);
  await db.query("insert into storage.objects values('memory-photos',$1)",[ada + '/' + mid]);
  await assert.rejects(publish([ben]), /follow you back/);
  await follow(ben);
  await follow(ben, 'approve'); // A requester cannot approve their own outbound request.
  assert.equal((await rows("select relation from profile_people('profile',$1)",[ben]))[0].relation, 'pending');
  await db.query('select set_profile_privacy(false)');
  await login(ben);
  assert.deepEqual(await rows("select id from profile_people('requests',$1)",[ben]), [{ id: ada }]);
  await follow(ada,'approve'); await follow(ada);
  await login(ada);
  assert.deepEqual(await rows("select id from profile_people('friends',$1)", [ada]), [{ id: ben }]);
  await publish([ben,ben,ada]); await publish([ben]);
  assert.equal((await rows('select id from groups')).length, 1);
  assert.deepEqual(new Set((await rows('select person_id from memory_people')).map(r => r.person_id)), new Set([ada,ben]));
  await visible(true);
  await login(ben); await visible(true);

  await login(cy); await visible(false); // Ada is public, Ben is private.
  await follow(ben); await visible(false);
  await follow(ben,'unfollow');
  await follow(ben);
  await login(ben); await follow(cy,'decline');
  await login(cy);
  assert.equal((await rows("select relation from profile_people('profile',$1)",[ben]))[0].relation, 'none');
  await follow(ben);
  await login(ben); await follow(cy,'approve');
  await login(cy); await visible(true);
  // An approved follower outside the group can interact once, even on retry.
  // Both direct reads and mutations must stop when the following edge is removed.
  const stats = () => rows('select likes,liked,comments from memory_activity(array[$1::uuid])',[mid]);
  const setLike = wanted => rows('select * from set_memory_like($1,$2)',[mid,wanted]);
  const commentId = randomUUID();
  const addComment = (body, id = commentId) => db.query(
    'insert into memory_comments(id,memory_id,body) values($1,$2,$3) on conflict(id) do nothing',[id,mid,body]);
  assert.deepEqual(await stats(), [{ likes: 0, liked: false, comments: 0 }]);
  await setLike(true); await setLike(true);
  await addComment('Love the photo!'); await addComment('Love the photo!');
  assert.deepEqual(await stats(), [{ likes: 1, liked: true, comments: 1 }]);
  await setLike(false); await setLike(false);
  assert.deepEqual(await stats(), [{ likes: 0, liked: false, comments: 1 }]);
  await setLike(true);
  await assert.rejects(addComment('   ',randomUUID()), /check constraint/);
  await assert.rejects(addComment('a'.repeat(501),randomUUID()), /check constraint/);
  await assert.rejects(db.query('insert into memory_comments(id,memory_id,author_id,body) values($1,$2,$3,$4)',
    [randomUUID(),mid,ada,'impersonation']), /permission denied/);
  await login(ada);
  assert.deepEqual(await stats(), [{ likes: 1, liked: false, comments: 1 }]);
  assert.deepEqual(await rows('select author_id,body from memory_comments where memory_id=$1',[mid]),
    [{ author_id: cy, body: 'Love the photo!' }]);
  await login(ben); await follow(cy,'remove');
  await login(cy); await visible(false);
  assert.deepEqual(await stats(), []);
  assert.deepEqual(await rows('select * from memory_comments'), []);
  assert.deepEqual(await rows('select * from memory_votes'), []);
  await assert.rejects(addComment('after revocation',randomUUID()), /row-level security/);
  await assert.rejects(setLike(false), /Memory unavailable/);
  await login(ben); await db.query('select set_profile_privacy(false)');
  await login(cy); await visible(true);
  await assert.rejects(db.query('insert into memory_people values ($1,$2)',[mid,cy]), /row-level security/);
  await login(ben); await db.query('select set_profile_privacy(true)');
  await login(cy); await visible(false);
  await login(ada);
  await assert.rejects(publish([],randomUUID()), /Upload the photo first/);
  assert.equal((await rows('select id from groups')).length, 1);
  await db.exec('reset role; set role anon');
  await assert.rejects(stats(), /permission denied/);
  await assert.rejects(rows("select * from profile_people('discover',$1)",[cy]), /permission denied/);
});
