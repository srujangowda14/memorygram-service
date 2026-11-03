import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';

const app = express();
const port = process.env.PORT || 3000;
const origins = (process.env.ALLOWED_ORIGINS || '').split(',').filter(Boolean);
const admin = createClient(process.env.SUPABASE_URL || '', process.env.SUPABASE_SERVICE_ROLE_KEY || '');
app.use(helmet()); app.use(cors({ origin: origins.length ? origins : true })); app.use(express.json({ limit: '1mb' }));
app.get('/health', (_req,res) => res.json({ ok:true, service:'memorygram', time:new Date().toISOString() }));

async function user(req, res, next) {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error:'Missing authorization token' });
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return res.status(401).json({ error:'Invalid session' });
  req.user = data.user; next();
}
app.get('/v1/quests', user, async (req,res) => {
  const { data, error } = await admin.from('quests').select('*').or(`group_id.is.null,group_id.eq.${req.query.groupId || ''}`).eq('active',true).order('created_at');
  if (error) return res.status(400).json({ error:error.message }); res.json({ quests:data });
});
app.post('/v1/groups', user, async (req,res) => {
  const parsed=z.object({ name:z.string().min(2).max(50), emoji:z.string().max(8).default('✌️') }).safeParse(req.body);
  if(!parsed.success) return res.status(422).json({ error:'A group name is required.' });
  const {data,error}=await admin.from('groups').insert({ ...parsed.data, created_by:req.user.id }).select().single();
  if(error) return res.status(400).json({error:error.message});
  await admin.from('group_members').insert({group_id:data.id,user_id:req.user.id,role:'owner'}); res.status(201).json({group:data});
});
app.listen(port, () => console.log(`Memorygram service listening on ${port}`));
