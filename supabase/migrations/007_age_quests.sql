begin;
alter table public.groups add column quest_age text check(quest_age in ('Under 30','30–49','50–64','65+'));
alter table public.memory_prompt_catalog add column age_band text;
insert into public.memory_prompt_catalog(key,family,mode,context,minutes,setting,title,prompt,age_band) values
  ('group-chat-patch-notes', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Group chat patch notes', 'Write three changes a fictional update would make to your hangout. Photograph the object that inspired the funniest fix.', 'Under 30'),
  ('the-dinner-we-could-improvise', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The dinner we could improvise', 'Pick three ingredients people already have. Sketch a meal you could make together and write who would tackle each part.', '30–49'),
  ('skills-worth-stealing', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Skills worth stealing', 'Demonstrate a trick you learned through practice. Let a friend draw its crucial step and photograph their illustrated instructions.', '50–64'),
  ('two-witnesses-one-afternoon', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Two witnesses, one afternoon', 'Recall an outing two friends attended. Draw the scene separately and photograph the details that both drawings share.', '65+'),
  ('silent-trailer', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Silent trailer', 'Stage three stills for a film about the last ten minutes. Save the middle frame and let a friend write the tagline.', 'Under 30'),
  ('calendar-archaeology', 'place', 'group', 'anywhere', '10', 'anywhere', 'Calendar archaeology', 'Think of a day everyone somehow made time to meet. Draw its unofficial invitation and save the detail that made it happen.', '30–49'),
  ('before-the-shortcut', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Before the shortcut', 'Compare two ways you learned to do the same job. Sketch the old and new tools and caption the trade-off you remember.', '50–64'),
  ('an-accent-worth-keeping', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'An accent worth keeping', 'Trade local sayings you love. Illustrate one literally and add the meaning a visitor would need.', '65+'),
  ('low-budget-boss-fight', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Low-budget boss fight', 'Turn a cushion or mug into the final boss of a game. Photograph its arena and invent its one ridiculous weakness.', 'Under 30'),
  ('ten-minute-skill-share', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Ten-minute skill share', 'Teach a friend one small skill, such as a paper fold or a drawing shortcut. Photograph their first attempt and their advice for the next learner.', '30–49'),
  ('three-eras-of-a-street', 'place', 'group', 'anywhere', '5', 'anywhere', 'Three eras of a street', 'Choose a street two people remember. Draw its remembered past, its present and a possible future on one strip.', '50–64'),
  ('the-public-bench-dedication', 'place', 'group', 'anywhere', '5', 'anywhere', 'The public bench dedication', 'Choose a real or imaginary bench and dedicate it to a friendship moment. Photograph a paper plaque and explain the choice.', '65+'),
  ('the-lost-reaction-image', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The lost reaction image', 'Make a reaction image using only objects. Let someone guess the message it answers before you caption it.', 'Under 30'),
  ('the-corner-shop-window', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'The corner shop window', 'Arrange ordinary items as a shop display for a shop your group would run. Photograph the window and invent opening-day specials.', '30–49'),
  ('second-act-prospectus', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Second-act prospectus', 'Invent a one-day apprenticeship each friend would enjoy trying. Photograph the course list with a first lesson for each.', '50–64'),
  ('mystery-tune-in-pictures', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Mystery tune in pictures', 'Draw clues to a tune without using letters. Have friends guess, then record what the melody brings back for each person.', '65+'),
  ('pocket-festival', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Pocket festival', 'Give each friend a stage name and an everyday object as an instrument. Draw the lineup on paper and photograph the poster.', 'Under 30'),
  ('friendship-commute-map', 'place', 'group', 'anywhere', '10', 'anywhere', 'Friendship commute map', 'Draw the routes that first brought you together. Mark the place where two paths crossed and caption the coincidence.', '30–49'),
  ('record-sleeve-reunion', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Record sleeve reunion', 'Pick a song linked to an earlier chapter of life. Design new sleeve art inspired by where you are together now.', '50–64'),
  ('a-recipe-in-someone-s-hands', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'A recipe in someone''s hands', 'Recall a cook''s gesture that a recipe never captured. Demonstrate it with an empty bowl and caption the missing instruction.', '65+'),
  ('three-frame-speedrun', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Three-frame speedrun', 'Invent a tiny challenge you can finish from a chair. Photograph its finish line and record the most creative solution.', 'Under 30'),
  ('spare-room-supper-club', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Spare-room supper club', 'Design a place setting from things within reach. Photograph it and decide which shared story would open dinner.', '30–49'),
  ('the-object-that-stayed', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'The object that stayed', 'Describe something that followed you through several moves. Draw or photograph its stand-in and mark its most surprising stop.', '50–64'),
  ('the-long-running-joke', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'The long-running joke', 'Tell the origin stories of a phrase the group still uses. Photograph a prop with two versions of how it began.', '65+'),
  ('side-character-diaries', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Side character diaries', 'Choose a background object. Take its portrait and co-write the diary entry it would make about your group.', 'Under 30'),
  ('break-time-expedition', 'place', 'group', 'anywhere', '10', 'anywhere', 'Break-time expedition', 'Spend a short break inspecting a familiar corner. Each find one detail everyone else missed and photograph a group favorite.', '30–49'),
  ('friendly-pub-quiz', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Friendly pub quiz', 'Write three questions whose answers come from the group''s own stories. Photograph the answer sheet after everyone guesses.', '50–64'),
  ('teach-me-your-opening', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Teach me your opening', 'Invent or demonstrate the first move of a tabletop game. Let a friend counter it and save a diagram of the position.', '65+'),
  ('bad-pitch-night', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Bad pitch night', 'Pitch an absurd use for an ordinary object in twenty seconds each. Photograph the prototype and quote the best pitch.', 'Under 30'),
  ('tiny-repair-clinic', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Tiny repair clinic', 'Pick an object with an annoying flaw. Draw two possible fixes together and photograph the one you would actually try.', '30–49'),
  ('what-i-changed-my-mind-about', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'What I changed my mind about', 'Choose an everyday taste or hobby you warmed to over time. Make a before-and-after sketch and compare turning points.', '50–64'),
  ('neighborhood-oral-history', 'place', 'group', 'anywhere', '10', 'anywhere', 'Neighborhood oral history', 'Choose a nearby landmark or one you remember. Invite each person to contribute one sentence and photograph the illustrated account.', '65+'),
  ('outfit-from-another-planet', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Outfit from another planet', 'Arrange scraps or leaves as a tiny outfit for a visitor from space. Photograph it and explain the local dress code.', 'Under 30'),
  ('house-rules-exchange', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'House rules exchange', 'Each share one unwritten rule from a household you know. Write an illustrated rulebook page for a fictional shared house.', '30–49'),
  ('an-argument-for-keeping-it', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'An argument for keeping it', 'Find an object someone might discard. Take turns arguing for a second use, then stage and photograph the winning design.', '50–64'),
  ('an-invitation-from-the-past', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'An invitation from the past', 'Recreate an invitation to a gathering you remember fondly. Add one guest''s recollection of what actually happened.', '65+'),
  ('fake-season-finale', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Fake season finale', 'Pose objects for the cliffhanger ending of today''s hangout. Caption the photo with the question viewers would argue about.', 'Under 30'),
  ('the-recurring-appointment', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'The recurring appointment', 'Design a repeatable five-minute ritual for the next time you meet. Photograph its cue and write how to start it.', '30–49'),
  ('first-paycheck-museum', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'First paycheck museum', 'Recall something you bought, saved for or borrowed early on. Draw a museum label for it and compare why it mattered.', '50–64'),
  ('the-pocket-puzzle-exchange', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The pocket puzzle exchange', 'Arrange five objects in a pattern with one hidden rule. Let a friend solve it and photograph their explanation.', '65+'),
  ('reverse-scavenger-hunt', 'place', 'group', 'anywhere', '10', 'anywhere', 'Reverse scavenger hunt', 'Start with a photo of something nearby. Give increasingly strange clues until a friend finds the subject.', 'Under 30'),
  ('kitchen-relay-on-paper', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Kitchen relay on paper', 'Start a recipe with one step. Each friend adds the next from imagination. Photograph the result and name the dish.', '30–49'),
  ('the-reluctant-expert', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The reluctant expert', 'Ask a friend what people often seek their help with. Stage a photo for the cover of their imaginary handbook.', '50–64'),
  ('a-duet-of-descriptions', 'place', 'group', 'anywhere', '10', 'anywhere', 'A duet of descriptions', 'Describe the same familiar view using only sound, then only color. Save a photo or drawing with both descriptions.', '65+'),
  ('soundtrack-draft', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Soundtrack draft', 'Take turns drafting song titles for the opening, plot twist and credits of today. Photograph the handwritten track list.', 'Under 30'),
  ('after-hours-field-notes', 'place', 'group', 'anywhere', '5', 'anywhere', 'After-hours field notes', 'Choose a familiar place and imagine its evening shift. Sketch a page of observations and add one detail from real life.', '30–49'),
  ('two-versions-of-the-recipe', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Two versions of the recipe', 'Compare two ways of preparing a familiar dish. Sketch the point where the methods diverge and record both explanations.', '50–64'),
  ('museum-of-first-names', 'place', 'group', 'anywhere', '5', 'anywhere', 'Museum of first names', 'Recall the first name or nickname of a memorable place. Design a sign for it and tell a friend why the name stuck.', '65+'),
  ('emoji-translation-desk', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Emoji translation desk', 'Describe a shared incident with three drawn symbols. Photograph the puzzle and add the group''s best translation.', 'Under 30'),
  ('the-hobby-we-nearly-started', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The hobby we nearly started', 'Pick an activity two friends have always meant to try. Make a paper invitation and sketch the very first practice exercise.', '30–49'),
  ('hometown-radio-hour', 'place', 'group', 'anywhere', '10', 'anywhere', 'Hometown radio hour', 'Make a running order for a five-minute radio show about a place you know. Include one local sound and one personal story.', '50–64'),
  ('one-tool-many-teachers', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'One tool, many teachers', 'Choose a skill passed between people. Draw the chain of teachers and photograph the step you would pass on next.', '65+'),
  ('forced-perspective-lab', 'place', 'group', 'anywhere', '10', 'anywhere', 'Forced perspective lab', 'Use distance to make a tiny object look enormous beside another. Save the illusion and its behind-the-scenes secret.', 'Under 30'),
  ('a-table-for-old-neighbors', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'A table for old neighbors', 'Design a seating plan for memorable people from past neighborhoods. Share one reason two of the guests should meet.', '30–49'),
  ('challenge-the-house-champion', 'place', 'group', 'anywhere', '10', 'anywhere', 'Challenge the house champion', 'Design a tabletop accuracy game with folded paper. Play a round, then photograph the rule change that made it more interesting.', '50–64'),
  ('the-encore-nobody-planned', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'The encore nobody planned', 'Tell a story about something unexpected that improved a gathering. Stage the turning point with objects and title the scene.', '65+'),
  ('micro-zine-exchange', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Micro-zine exchange', 'Fold one sheet into four panels. Each person adds a line or doodle about today, then photograph the cover.', 'Under 30'),
  ('lost-weekend-souvenir', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Lost weekend souvenir', 'Make a souvenir for a trip you never took together. Photograph it with the imaginary mishap that made the trip memorable.', '30–49'),
  ('the-road-you-almost-took', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'The road you almost took', 'Choose a harmless fork in the road from years ago. Sketch two alternate postcards and share the story behind one.', '50–64'),
  ('a-map-drawn-from-voices', 'place', 'group', 'anywhere', '5', 'anywhere', 'A map drawn from voices', 'Draw a remembered route while another friend supplies landmarks aloud. Save the map with one place you pictured differently.', '65+'),
  ('invent-a-fandom', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Invent a fandom', 'Choose an overlooked object to become obsessed with for five minutes. Design its fan badge and photograph the first edition.', 'Under 30'),
  ('the-good-shortcut', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The good shortcut', 'Each teach a tiny shortcut that makes ordinary days easier. Photograph a demonstration and credit the person who taught it.', '30–49'),
  ('borrowed-wisdom-audit', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Borrowed wisdom audit', 'Each recall advice you once received. Rewrite one piece for a friend facing the same situation today and photograph both versions.', '50–64'),
  ('a-new-rule-for-an-old-game', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'A new rule for an old game', 'Pick a familiar word or paper game. Each propose a new rule, try one round and photograph the winning rulebook.', '65+'),
  ('wrong-answers-tour', 'place', 'group', 'anywhere', '10', 'anywhere', 'Wrong answers tour', 'Point out three ordinary features nearby and invent extravagant fictional explanations. Save a photo with the favorite tall tale.', 'Under 30'),
  ('borrow-my-eyes', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Borrow my eyes', 'Take turns framing the same workaday object as if it belonged to another profession. Save the most unexpected interpretation.', '30–49'),
  ('neighborhood-texture-atlas', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Neighborhood texture atlas', 'Look for two textures that suggest different chapters of a place. Photograph one and sketch a map key for both.', '50–64'),
  ('the-neighborhood-editor', 'place', 'group', 'anywhere', '10', 'anywhere', 'The neighborhood editor', 'Imagine editing a one-page paper about today. Assign a headline, sketch a picture and save the story someone else would have missed.', '65+'),
  ('one-take-storyboard', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'One-take storyboard', 'Draw a scene one panel at a time without planning its ending. Photograph the twist and title the episode.', 'Under 30'),
  ('five-minute-reunion', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Five-minute reunion', 'Recreate the first few minutes of a memorable reunion using objects as stand-ins. Photograph the scene before the first greeting.', '30–49'),
  ('unlikely-doubles-team', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Unlikely doubles team', 'Pair two unrelated skills from the group into an imaginary team event. Draw its emblem and demonstrate its opening move.', '50–64'),
  ('small-pleasures-tasting-notes', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Small pleasures tasting notes', 'Compare a familiar drink, sound or texture in the style of expert reviewers. Photograph the subject and the group''s most precise description.', '65+'),
  ('mystery-inventory', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Mystery inventory', 'Empty three harmless objects onto a table. Design a fictional character who owns them all and photograph the clues.', 'Under 30'),
  ('the-unfinished-project-fair', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The unfinished project fair', 'Sketch a project each friend once abandoned. Pair two sketches into a new invention and photograph the mash-up.', '30–49'),
  ('your-first-day-again', 'place', 'group', 'anywhere', '10', 'anywhere', 'Your first day again', 'Trade stories of starting something unfamiliar. Arrange objects as a first-day survival kit and caption its strangest item.', '50–64'),
  ('postcards-across-decades', 'place', 'group', 'anywhere', '10', 'anywhere', 'Postcards across decades', 'Pick one place and write two postcard greetings set decades apart. Photograph them and describe what both visitors would recognize.', '65+'),
  ('lobby-screen', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Lobby screen', 'Draw the loading screen for your group''s next adventure. Everyone adds a useful or wildly unhelpful tip.', 'Under 30'),
  ('our-neighborhood-ballot', 'place', 'group', 'anywhere', '10', 'anywhere', 'Our neighborhood ballot', 'Nominate nearby details for playful awards, like best-shaped shadow. Make a paper ballot and save the winning detail.', '30–49'),
  ('the-changing-skyline', 'place', 'group', 'anywhere', '10', 'anywhere', 'The changing skyline', 'Outline a view you remember, then outline the view in front of you. Photograph the two shapes and name what anchors each.', '50–64'),
  ('a-portrait-in-possessions', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'A portrait in possessions', 'Build a portrait of a friend from three objects they choose. Photograph it and let them write the caption.', '65+'),
  ('parallel-universe-lunch', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Parallel universe lunch', 'Design an imaginary menu where every dish is named after an inside joke. Photograph the special of the day.', 'Under 30'),
  ('dinner-party-question-deck', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'Dinner-party question deck', 'Everyone writes one question they would genuinely like to be asked. Photograph the deck and answer one together.', '30–49'),
  ('the-lost-instruction-sheet', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'The lost instruction sheet', 'Pick a familiar tool and draw instructions for someone seeing it for the first time. Let a friend test the drawings.', '50–64'),
  ('the-celebration-we-invented', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'The celebration we invented', 'Design a holiday for an overlooked pleasure your friends share. Draw its emblem and agree on a first annual custom.', '65+'),
  ('cover-art-swap', 'place', 'group', 'anywhere', '10', 'anywhere', 'Cover art swap', 'Everyone sketches a cover for the same invented song. Put the covers side by side and caption their different moods.', 'Under 30'),
  ('parallel-tuesdays', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Parallel Tuesdays', 'Compare what each person usually does at the same time on a Tuesday. Draw a split-screen scene and caption the contrast.', '30–49'),
  ('one-good-conversation', 'place', 'group', 'anywhere', '10', 'anywhere', 'One good conversation', 'Recall a conversation that nudged you toward something new. Photograph a symbolic object and save the question that helped.', '50–64'),
  ('a-question-for-the-next-visit', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'A question for the next visit', 'Ask each friend for a story they have always wanted to hear. Photograph one question and spend a few minutes on its answer.', '65+'),
  ('glitch-portrait', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Glitch portrait', 'Arrange strips of colored paper into a deliberately glitched face. Photograph it and name its current emotion.', 'Under 30'),
  ('the-thank-you-prototype', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'The thank-you prototype', 'Think of a favor a friend once did. Design a tiny monument to the favor using nearby objects and photograph the dedication.', '30–49'),
  ('an-exhibition-in-three-labels', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'An exhibition in three labels', 'Curate three objects around an interest you share. Write labels from different viewpoints and photograph the entrance piece.', '50–64'),
  ('committee-for-beautiful-mistakes', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'Committee for beautiful mistakes', 'Recall a harmless mistake that turned into a good story. Make a ribbon for it and photograph the citation.', '65+'),
  ('friendship-achievement', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Friendship achievement', 'Design a game achievement for something a friend did today. Photograph the badge with its unlock condition.', 'Under 30'),
  ('a-spare-hour-itinerary', 'place', 'group', 'anywhere', '5', 'anywhere', 'A spare hour itinerary', 'Build an outing that fits into a spare hour with zero spending. Photograph your hand-drawn map and its optional detour.', '30–49'),
  ('small-rebellions-anthology', 'keepsake', 'group', 'anywhere', '5', 'anywhere', 'Small rebellions anthology', 'Share a time you quietly did something your own way. Illustrate one story as a single comic panel with a friend''s caption.', '50–64'),
  ('the-apprentice-takes-over', 'discovery', 'group', 'anywhere', '5', 'anywhere', 'The apprentice takes over', 'Invite someone to teach a new paper fold, rhythm or sketch. Switch teacher and learner, then save the two attempts together.', '65+'),
  ('one-star-review-club', 'place', 'group', 'anywhere', '10', 'anywhere', 'One-star review club', 'Write an affectionate one-star review of an imaginary inconvenience, like gravity for a dropped pencil. Photograph the evidence.', 'Under 30'),
  ('postcard-from-next-year', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Postcard from next year', 'Each write one ordinary thing you hope the group is still doing next year. Photograph the cards as a set.', '30–49'),
  ('the-next-first', 'discovery', 'group', 'anywhere', '10', 'anywhere', 'The next first', 'Choose a small first you would like to experience together. Invent a ticket for it and photograph the stub.', '50–64'),
  ('tomorrow-s-correspondence', 'keepsake', 'group', 'anywhere', '10', 'anywhere', 'Tomorrow''s correspondence', 'Write a short invitation to something new your group could try. Illustrate it together and photograph the detail everyone wants to remember.', '65+');

create or replace function public.start_memory_space(gid uuid, mode text, space_name text, companions uuid[], place_context text, locality_name text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); friends uuid[]; assigned integer; band text := nullif(current_setting('memorygram.quest_age',true),'');
begin
  if me is null or gid is null then raise exception 'Sign in to start a memory.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(gid::text,0));
  if exists(select 1 from public.groups g where g.id=gid and g.created_by=me and g.memory_mode is not null) then return gid; end if;
  if place_context='locality' and (locality_name is null or length(trim(locality_name)) not between 1 and 80
    or locality_name ~ '[[:cntrl:]]') then raise exception 'Choose a valid locality.'; end if;
  select array(select distinct x from unnest(companions) x) into friends;
  if mode is null or mode not in ('solo','group') or space_name is null or length(trim(space_name)) not between 2 and 50
    or (mode='solo' and cardinality(friends)<>0) or (mode='group' and cardinality(friends) not between 1 and 19)
    then raise exception 'Choose a name and the people for this space.'; end if;
  if exists(select 1 from unnest(friends) x where x is null or x=me or not exists (
    select 1 from public.follows a join public.follows b on b.follower=a.target and b.target=a.follower
    where a.follower=me and a.target=x and a.status='accepted' and b.status='accepted'
  )) then raise exception 'Choose friends who follow you back.'; end if;
  insert into public.groups(id,name,created_by,memory_mode,quest_age) values(gid,trim(space_name),me,mode,band);
  insert into public.group_members(group_id,user_id,role) values(gid,me,'owner');
  insert into public.group_members(group_id,user_id) select gid,x from unnest(friends) x;
  insert into public.quests(group_id,title,prompt,minutes,setting,people)
    select gid,p.title,replace(p.prompt,'{place}',coalesce(trim(locality_name),'')),p.minutes,p.setting,$2 from (
      select distinct on (c.family) c.* from public.memory_prompt_catalog c
      where c.mode in ($2,'any') and c.context in ('anywhere',place_context)
      and (band is null or c.age_band is null or c.age_band=band)
      order by c.family,(c.context=place_context) desc,coalesce(c.age_band=band,false) desc,random()
    ) p;
  get diagnostics assigned=row_count;
  if assigned<>3 then raise exception 'Could not assign three tasks.'; end if;
  return gid;
end $$;

-- Carry the selected group range through either existing atomic creation path.
-- Individual ages never leave the creator's device.
create function public.start_age_space(gid uuid, space_name text, companions uuid[], age_range text,
  place_context text, locality_name text, offer_id uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
begin
  if age_range is null or age_range not in ('Under 30','30–49','50–64','65+') then raise exception 'Invalid age range'; end if;
  perform set_config('memorygram.quest_age',age_range,true);
  if offer_id is not null then
    return public.start_nearby_memory_space(gid,'group',space_name,companions,offer_id);
  end if;
  return public.start_memory_space(gid,'group',space_name,companions,place_context,locality_name);
end $$;
revoke all on function public.start_age_space(uuid,text,uuid[],text,text,text,uuid) from public,anon;
grant execute on function public.start_age_space(uuid,text,uuid[],text,text,text,uuid) to authenticated;

-- Serialize additions per room so two friends choosing the same quest
-- receive one shared assignment, including retries of a completed task.
create function public.add_friend_quest(gid uuid, prompt_key text) returns void
language plpgsql security definer set search_path='' as $$
declare band text; chosen public.memory_prompt_catalog;
begin
  select g.quest_age into band from public.groups g where g.id=gid and g.memory_mode='group'
    and public.is_member(gid) for update;
  if not found then raise exception 'Group unavailable'; end if;
  select c.* into chosen from public.memory_prompt_catalog c where c.key=prompt_key
    and c.age_band is not null and (band is null or c.age_band=band);
  if not found then raise exception 'Quest unavailable'; end if;
  if exists(select 1 from public.quests q where q.group_id=gid and q.title=chosen.title) then return; end if;
  insert into public.quests(group_id,title,prompt,minutes,setting,people)
    values(gid,chosen.title,chosen.prompt,chosen.minutes,chosen.setting,'group');
end $$;
revoke all on function public.add_friend_quest(uuid,text) from public,anon;
grant execute on function public.add_friend_quest(uuid,text) to authenticated;
-- Members can change future library choices in an existing friendship group.
-- Assigned quests and completed memories keep their original prompts.
create function public.set_group_quest_range(gid uuid, age_range text) returns void
language plpgsql security definer set search_path='' as $$
begin
  update public.groups g set quest_age=age_range where g.id=gid and g.memory_mode='group' and public.is_member(gid);
  if not found then raise exception 'Group unavailable'; end if;
end $$;
revoke all on function public.set_group_quest_range(uuid,text) from public,anon;
grant execute on function public.set_group_quest_range(uuid,text) to authenticated;
commit;
