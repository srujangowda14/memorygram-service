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
    create publication supabase_realtime;
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
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
  for (const file of ['001_memorygram.sql','002_auth_access.sql','003_social_profiles.sql','004_memory_feed.sql','005_memory_spaces.sql','006_nearby_tasks.sql','007_age_quests.sql','008_realtime_chat.sql','009_profile_age.sql']) {
    await db.exec(await readFile(new URL('../migrations/' + file, import.meta.url), 'utf8'));
  }
  assert.deepEqual((await db.query("select tablename from pg_publication_tables where pubname='supabase_realtime'")).rows,
    [{ tablename: 'space_messages' }]);
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
  const range = async ids => (await rows('select group_profile_range($1::uuid[]) band',[ids]))[0].band;
  assert.equal(await range([ben]), 'All ages');
  await assert.rejects(range([cy]), /mutual friends/);
  await db.query("insert into profile_birthdays values ($1,current_date-interval '71 years')",[ada]);
  await login(ben);
  assert.deepEqual(await rows('select * from profile_birthdays'),[]);
  await db.query("insert into profile_birthdays values ($1,current_date-interval '68 years')",[ben]);
  assert.equal(await range([ada]),'65+');
  await login(ada);
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

  // Create solo and group spaces using the same entry point as the app.
  // Failure must roll back the room; response retries must reuse its tasks.
  const gid = randomUUID(), solo = randomUUID(), denied = randomUUID();
  const start = (id, mode, friends, context = 'anywhere') => db.query(
    'select start_memory_space($1,$2,$3,$4::uuid[],$5)',[id,mode,'Autumn memories',friends,context]);
  const tasks = id => rows('select id,title,active from quests where group_id=$1 order by id',[id]);
  await assert.rejects(start(denied,'group',[cy]), /follow you back/);
  await assert.rejects(start(denied,'group',[]), /Choose a name/);
  await assert.rejects(start(denied,'solo',[ben]), /Choose a name/);
  assert.deepEqual(await rows('select id from groups where id=$1',[denied]), []);
  await start(solo,'solo',[]); await start(gid,'group',[ben,ben],'cubbon');
  const cityRoom = randomUUID();
  await db.query("select start_memory_space($1,'solo','My neighborhood',array[]::uuid[],'locality','Paris')",[cityRoom]);
  assert.equal((await rows("select prompt from quests where group_id=$1 and prompt like '%Paris%'",[cityRoom])).length,1);
  for (const band of ['Under 30','30–49','50–64','65+']) {
    const roomId=randomUUID();
    await db.query("select start_age_space($1,'Age test',$2::uuid[],$3,'anywhere',null,null)",[roomId,[ben],band]);
    const titles=(await tasks(roomId)).map(q=>q.title);
    await db.exec('reset role');
    const pool=await rows('select key,title from memory_prompt_catalog where age_band=$1',[band]);
    assert.equal(pool.length,25);
    assert.equal(titles.length,3);
    assert.ok(titles.every(title=>pool.some(q=>q.title===title)));
    await db.exec('set role authenticated');
    const extra=pool.find(q=>!titles.includes(q.title));
    const add=()=>db.query('select add_friend_quest($1,$2)',[roomId,extra.key]);
    await login(cy); await assert.rejects(add(),/Group unavailable/);
    const changeRange=()=>db.query("select set_group_quest_range($1,null)",[roomId]);
    await assert.rejects(changeRange(),/Group unavailable/);
    await login(ben); await add(); await add();
    assert.equal((await tasks(roomId)).length,4);
    await changeRange();
    assert.deepEqual(await rows('select quest_age from groups where id=$1',[roomId]),[{quest_age:null}]);
    await login(ada);
  }
  const assigned = await tasks(gid);
  assert.equal(assigned.length,3);
  assert.ok(assigned.some(q => q.title === 'Cubbon Park in miniature'));
  assert.equal((await tasks(solo)).length,3);
  await start(gid,'group',[ben],'evening');
  assert.deepEqual(await tasks(gid),assigned);

  const msg = randomUUID(), saved = randomUUID(), task = assigned[0].id;
  const send = (group, id, body) => db.query(
    'insert into space_messages(group_id,id,body) values($1,$2,$3) on conflict(id) do nothing',[group,id,body]);
  const finish = (tid, id) => db.query('select finish_memory_task($1,$2,$3)', [tid,id,'Our little time capsule']);
  await assert.rejects(send(solo,randomUUID(),'Test'), /row-level security/);
  await send(gid,msg,'Shall we try the postcard?'); await send(gid,msg,'Shall we try the postcard?');
  await login(ben);
  assert.deepEqual(await tasks(gid),assigned);
  assert.deepEqual(await tasks(solo),[]);
  assert.deepEqual(await rows('select author_id,body from space_messages'), [{ author_id:ada, body:'Shall we try the postcard?' }]);
  await send(gid,randomUUID(),'Yes!');
  await assert.rejects(db.query('insert into space_messages(group_id,id,author_id,body) values($1,$2,$3,$4)',
    [gid,randomUUID(),ada,'forged']), /permission denied/);
  await assert.rejects(finish(task,saved), /Upload the photo first/);
  await db.query("insert into storage.objects values('memory-photos',$1)",[ben + '/' + saved]);
  await finish(task,saved); await finish(task,saved);
  await login(ada);
  await assert.rejects(finish(task,randomUUID()), /already has a memory/);
  assert.equal((await tasks(gid)).filter(q => !q.active).length,1);
  assert.deepEqual(await rows('select group_id,profile_post from memories where id=$1',[saved]),[{ group_id:gid,profile_post:false }]);
  assert.equal((await rows('select * from memory_people where memory_id=$1',[saved])).length,2);
  assert.equal((await rows('select id from space_messages')).length,2);
  await login(ben); await db.query('select set_profile_privacy(false)');
  await login(cy);
  assert.deepEqual(await rows('select id from groups where memory_mode is not null'),[]);
  assert.deepEqual(await tasks(gid),[]); assert.deepEqual(await rows('select id from space_messages'),[]);
  assert.deepEqual(await rows('select id from memories where id=$1',[saved]),[]);
  assert.deepEqual(await rows('select name from storage.objects where name=$1',[ben + '/' + saved]),[]);
  await assert.rejects(send(gid,randomUUID(),'outsider'), /row-level security/);
  await assert.rejects(finish(task,randomUUID()), /Task unavailable/);
  // Mint a suggestion through the service role, then redeem it as its owner.
  // Other users, drafts, direct writes and expired offers must be rejected.
  const draft = randomUUID(), offer = randomUUID(), expired = randomUUID();
  const metadata = {meeting:'Alamo Square',venue:'Duboce Park',radius:1};
  const issue = (id,expiry) => db.query(`insert into nearby_offers
    (id,owner_id,draft_id,mode,title,prompt,nearby,expires_at)
    values($1,$2,$3,'group','Two views','Save two views of this park.',$4,$5)`,
    [id,ada,draft,metadata,expiry]);
  const redeem = (g,id,mode='group') => db.query('select start_nearby_memory_space($1,$2,$3,$4::uuid[],$5)',
    [g,mode,'Our SF walk',[ben],id]);
  await assert.rejects(issue(offer,new Date()),/permission denied/);
  await db.exec('reset role; set role service_role');
  await issue(expired,new Date(Date.now()-1000));
  await issue(offer,new Date(Date.now()+60000));
  await db.exec('reset role; set role authenticated');
  await login(cy); await assert.rejects(redeem(draft,offer),/expired/);
  await login(ada); await assert.rejects(redeem(draft,expired),/expired/);
  await assert.rejects(redeem(randomUUID(),offer),/expired/);
  await assert.rejects(redeem(draft,offer,'solo'),/expired/);
  await redeem(draft,offer); await redeem(draft,offer);
  await login(ben);
  assert.equal((await tasks(draft)).length,3);
  assert.deepEqual(await rows('select title,nearby from quests where group_id=$1 and nearby is not null',[draft]),
    [{title:'Two views',nearby:metadata}]);
  await login(cy); assert.deepEqual(await tasks(draft),[]);
  await db.exec('reset role; set role anon');
  await assert.rejects(start(randomUUID(),'solo',[]), /permission denied/);
  await assert.rejects(stats(), /permission denied/);
  await assert.rejects(rows("select * from profile_people('discover',$1)",[cy]), /permission denied/);
});
