import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { nearbyRouter } from './nearby.js';

dotenv.config({ path: ['.env.local', '.env'] });

const app = express();
const origins = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
const admin = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    })
  : null;
app.use(helmet()); app.use(cors({ origin: origins.length ? origins : true })); app.use(express.json({ limit: '1mb' }));
app.get('/health', (_req,res) => res.json({ ok:true, service:'memorygram', time:new Date().toISOString() }));

// Resolve the caller with the same Supabase project that issued the token.
// Every protected route uses this identity, including group membership checks.
async function user(req, res, next) {
  const token = /^Bearer ([^\s,]+)$/i.exec(req.get('authorization') ?? '')?.[1];
  if (!token) return res.status(401).json({ error: 'A bearer token is required.' });
  if (!admin) return res.status(503).json({ error: 'Authentication is not configured.' });
  try {
    const { data, error } = await admin.auth.getUser(token);
    if (error && (!error.status || error.status >= 500 || error.status === 429)) {
      return res.status(503).json({ error: 'Authentication is temporarily unavailable.' });
    }
    if (error || !data.user) return res.status(401).json({ error: 'Invalid session.' });
    req.user = data.user;
    next();
  } catch {
    return res.status(503).json({ error: 'Authentication is temporarily unavailable.' });
  }
}
app.get('/v1/me', user, (req, res) => {
  res.set('Cache-Control', 'no-store').json({ id: req.user.id, email: req.user.email });
});
app.use('/v1/nearby', user, nearbyRouter(admin));
app.get('/v1/quests', user, async (req,res) => {
  const groupId = req.query.groupId;
  let query = admin.from('quests').select('*').eq('active', true);
  if (groupId !== undefined) {
    if (!z.string().uuid().safeParse(groupId).success) {
      return res.status(400).json({ error: 'Invalid group ID.' });
    }
    const member = await admin.from('group_members').select('group_id')
      .eq('group_id', groupId).eq('user_id', req.user.id).maybeSingle();
    if (member.error) return res.status(503).json({ error: 'Could not check membership.' });
    if (!member.data) return res.status(403).json({ error: 'Group membership required.' });
    query = query.or(`group_id.is.null,group_id.eq.${groupId}`);
  } else {
    query = query.is('group_id', null);
  }
  const { data, error } = await query.order('created_at');
  if (error) return res.status(400).json({ error:error.message }); res.json({ quests:data });
});
app.post('/v1/groups', user, async (req,res) => {
  const parsed=z.object({ name:z.string().min(2).max(50), emoji:z.string().max(8).default('✌️') }).safeParse(req.body);
  if(!parsed.success) return res.status(422).json({ error:'A group name is required.' });
  const {data,error}=await admin.from('groups').insert({ ...parsed.data, created_by:req.user.id }).select().single();
  if(error) return res.status(400).json({error:error.message});
  await admin.from('group_members').insert({group_id:data.id,user_id:req.user.id,role:'owner'}); res.status(201).json({group:data});
});
export default app;
