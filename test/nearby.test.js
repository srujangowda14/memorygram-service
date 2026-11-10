import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import { miles, nearbyRouter, parseEvents, parseParks, shortlist, writePrompts } from '../src/nearby.js';

const rows = [
  {property_id:'1',property_name:'Meeting Park',propertytype:'Regional Park',address:'101 Test St',city:'San Francisco',latitude:'37.76',longitude:'-122.44'},
  {property_id:'2',property_name:'Garden',propertytype:'Community Garden',address:'1 Park St',city:'San Francisco',latitude:'37.761',longitude:'-122.44'},
  {property_id:'3',property_name:'Far park',propertytype:'Regional Park',address:'7 Far St',city:'San Francisco',latitude:'37.79',longitude:'-122.44'},
];
const rss = '<rss><channel><item><title>Mobile Rec at Garden</title><link>https://sfrecpark.org/Calendar.aspx?EID=1</link>'+
  '<calendarEvent:EventDates>November 7, 2026</calendarEvent:EventDates><calendarEvent:EventTimes>10:00 AM - 04:00 PM</calendarEvent:EventTimes>'+
  '<calendarEvent:Location>1 Park StreetSan Francisco, CA</calendarEvent:Location></item></channel></rss>';
const modelPicks = [{id:'0',title:'Two views',prompt:'Each pick a detail here and caption one photo together.'}];

// Substitute both OpenAI endpoints at the network boundary and inspect
// the model inputs to ensure meeting labels and personal data stay local.
function modelFetch(picks,flagged=false) {
  return async (url,init) => {
    const data = JSON.parse(init.body);
    if (url.endsWith('/moderations')) return Response.json({results:picks.map(() => ({flagged}))});
    assert.equal(url,'https://api.openai.com/v1/responses');
    assert.equal(data.store,false);
    assert.deepEqual(JSON.parse(data.input),{audience:'group',candidates:[{id:'0',category:'Community garden',listing:'Garden'}]});
    return Response.json({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({picks})}]}]});
  };
}

test('calendar requires an identifiable venue, future date and official link; radius precedes rounding', () => {
  const spots = parseParks(rows), meeting = spots.find(p=>p.id==='1');
  const now = Date.parse('2026-11-05T18:00Z');
  const events = parseEvents(rss,spots,now);
  assert.equal(events[0].date,'2026-11-07T18:00:00.000Z');
  assert.equal(parseEvents(rss.replace('sfrecpark.org','untrusted.test'),spots,now).length,0);
  assert.equal(parseEvents(rss,spots,Date.parse('2026-11-07T18:01Z')).length,0);
  assert.equal(parseEvents(rss.replace('at Garden','at Elsewhere').replace('1 Park Street','9999 Unknown'),spots,now).length,0);
  assert.deepEqual(shortlist(meeting,1,spots,events).map(c=>c.name),['Mobile Rec at Garden']);
  const garden = spots.find(p=>p.id==='2');
  assert.deepEqual(shortlist(meeting,miles(meeting,garden)-0.00001,spots,[]),[]);
});

test('OpenAI can return only in-radius IDs and approved creative text', async () => {
  const candidates=[{type:'Community garden',name:'Garden'}];
  assert.deepEqual(await writePrompts(candidates,'group',modelFetch(modelPicks),'test','fixture'),modelPicks);
  assert.deepEqual(await writePrompts(candidates,'group',modelFetch([{...modelPicks[0],id:'99'}]),'test','fixture'),[]);
  assert.deepEqual(await writePrompts(candidates,'group',modelFetch(modelPicks,true),'test','fixture'),[]);
});

test('service binds offers to the verified user and draft; AI outage falls back to city places',async t => {
  const original = process.env.OPENAI_API_KEY;
  process.env.OPENAI_API_KEY='test-key';
  t.after(() => { if (original===undefined) delete process.env.OPENAI_API_KEY; else process.env.OPENAI_API_KEY=original; });
  const previousPlacesKey = process.env.GOOGLE_PLACES_API_KEY;
  process.env.GOOGLE_PLACES_API_KEY = 'fixture';
  t.after(() => {
    if (previousPlacesKey === undefined) delete process.env.GOOGLE_PLACES_API_KEY;
    else process.env.GOOGLE_PLACES_API_KEY = previousPlacesKey;
  });
  const issued = [];
  let diningSearches = 0;
  let diningFailure = false;
  let failAI = false, parkLoads=0;
  const fetcher = async (url,init) => {
    if (String(url).startsWith('https://places.googleapis.com/')) {
      diningSearches++;
      if (diningFailure) return new Response(null, {status: 503});
      const query = JSON.parse(init.body);
      assert.deepEqual(query.priceLevels, ['PRICE_LEVEL_INEXPENSIVE','PRICE_LEVEL_MODERATE']);
      const base = {displayName:{text:'Fixture dining'}, location:{latitude:37.761,longitude:-122.44},
        priceLevel:'PRICE_LEVEL_MODERATE', rating:4.7, userRatingCount:42, businessStatus:'OPERATIONAL'};
      return Response.json({places:[
        {...base,id:'few',userRatingCount:3}, {...base,id:'best',rating:4.9}, {...base,id:'many'},
        {...base,id:'outside',location:{latitude:37.8,longitude:-122.44},rating:5},
        {...base,id:'expensive',priceLevel:'PRICE_LEVEL_EXPENSIVE'}, {...base,id:'unknown',priceLevel:undefined},
        {...base,id:'closed',businessStatus:'CLOSED_TEMPORARILY'},
      ]});
    }
    if (String(url).includes('data.sfgov.org')) { parkLoads++;return Response.json(rows); }
    if (String(url).includes('sfrecpark.org')) return new Response('<rss><channel><title>Current calendar</title></channel></rss>');
    if (failAI) throw new Error('simulated provider outage');
    return modelFetch(modelPicks)(String(url),init);
  };
  const userId=randomUUID(), draftId=randomUUID();
  const app=express();app.use(express.json());
  app.use((req,_res,next)=>{req.user={id:userId};next();});
  app.use(nearbyRouter({from(table){assert.equal(table,'nearby_offers');return {insert(items){issued.push(...items);return {error:null};}};}},{fetcher}));
  const server=createServer(app); server.listen(0,'127.0.0.1');await once(server,'listening');
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base='http://127.0.0.1:'+server.address().port;
  const search = args => fetch(base+'/suggestions',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({draftId,mode:'group',spotId:'1',radius:1,...args})});
  assert.equal((await (await fetch(base+'/spots')).json()).spots.length,3);
  assert.equal((await search({radius:999})).status,422);
  assert.equal((await search({spotId:'99'})).status,422);
  const first = await (await search({})).json();
  assert.equal(first.offers[0].nearby.origin,'OpenAI');
  assert.equal(first.offers[0].nearby.venue,'Garden');
  assert.equal(issued[0].owner_id,userId);assert.equal(issued[0].draft_id,draftId);
  failAI=true;
  assert.equal((await (await search({})).json()).offers[0].nearby.origin,'Curated');
  assert.equal(diningSearches,0);
  assert.equal((await search({restaurantBudget:5})).status,422);
  for (let attempt=0; attempt<2; attempt++) {
    const dining = await (await search({restaurantBudget:2})).json();
    assert.equal(dining.offers[0].nearby.origin,'Curated');
    assert.deepEqual(dining.offers.slice(1).map(o=>o.nearby.placeId),['best','many','few']);
    assert.equal(dining.offers[1].restaurant.rating,4.9);
    const stored = issued.find(row=>row.id===dining.offers[1].id);
    assert.equal(stored.owner_id,userId);
    assert.deepEqual(stored.nearby,{origin:'Google Maps',placeId:'best',budget:2,meeting:'Meeting Park',meetingAddress:'101 Test St',radius:1});
    assert.equal(stored.restaurant,undefined);
  }
  assert.equal(diningSearches,2);
  diningFailure=true;
  const partial = await (await search({restaurantBudget:2})).json();
  assert.equal(partial.restaurantStatus,'unavailable');
  assert.equal(partial.offers[0].nearby.origin,'Curated');
  assert.equal(parkLoads,1);
});
