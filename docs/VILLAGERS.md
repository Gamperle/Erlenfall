# The villagers of Erlenfall

Status: draft for review, like the rest of the story (see issue #20). Every name and backstory here is a proposal. The five villagers already in the game keep everything their dialogue says about them, and the rest is built around that.

The design asks for 10-15 named characters. This document describes 20 so there is room to choose: the five in the game, the ones their dialogue already mentions, and others who fit later crafts, quests, and the town's growth. Only the first five are in the world for now.

## How to use this document

- **Ages** match the MakeHuman `age` slider used in `tools/character_pipeline/villagers.json`: 0.5 is 25 years, 1.0 is 90, and between 0.1875 (11 years) and 0.5 it rises evenly. The appearance notes name the slider value and the build, so a recipe can be written from them.
- **Clothes** are described in the pipeline's terms where an asset already exists (`toigo_fisherman_sweater`, `toigo_long_full_skirt`, `toigo_wool_pants`, `rehmanpolanski_viking_*`, `donitz_monk_robe`, `shoes03`). Anything else is a wish for a future asset.
- **Offers** say what the character could give the player: quests, trade, lore, or help with a craft. They are ideas for later milestones, not promises.

## The village's history

| When | What happened |
| --- | --- |
| About 200 years ago | Miners settle where an alder grove grows on an old rockfall below the iron seams, and the place takes its name from it: *Erlenfall*. The village holds its spring assembly under an alder on the hill at the northeast edge. |
| About 90 years ago | A goblin winter. The village raises a wooden palisade on the steep mound to the southwest, and it holds. Only the ditch is left of it now. |
| Since then | The mine pays well. Ore goes down the north road over the pass to the lowland market town of Talbrück, and grain and cloth come back. |
| 11 years ago | Brandt becomes mayor. |
| 7 years ago, autumn | Oswin, the mine's foreman, finds fresh cracks in the slope above the mine and asks to close the upper galleries and shore the slope. Brandt puts it off until spring: the Talbrück contract has to be met, timber costs money, and the village needs its winter grain. |
| 6 years ago, spring thaw | The mountain comes down at night. It buries the mine entrance and the north road. Two men on the night shift die: Jorin, Hedda's younger son, and Matthis, Konrad's younger brother. |
| The years after | With no road and no ore, families leave over the goat path across the pass. Houses stand empty. Goblins move into the woods east of the landslide. A fever the first winter kills Konrad's wife, because no healer can get through. |
| Last winter | Anselm, the player's grandfather, who kept half the village's roofs and doors mended, dies. Without him the repairs stop. |
| The game begins | The player arrives to live in Anselm's house and help Hedda and Mira. |

Only Brandt and Oswin know that the slope was reported the autumn before. That secret is the core of the mayor's arc: he is not afraid of the newcomer's work, he is afraid of what reopening the mine will dig up.

### The mayor's arc (proposal)

1. **Suspicion** (in the game). Brandt insists repairs go through him, because he guards what little the village can afford and because he wants to control what changes.
2. **Pressure.** As the village recovers, people start talking about reopening the mine. Brandt blocks it with good-sounding reasons: no money, no road, too dangerous.
3. **The truth.** Oswin, or Lene going through her father's old ledgers, tells the player about the cracks and the delayed shoring. The player chooses how to handle it: let Brandt tell the village himself, tell it for him, or keep it between them.
4. **Coming around.** Whatever the choice, Brandt finally stands up at the assembly, owns his decision, and backs the reopening, with the slope shored this time. His relationship with the player decides whether he stays mayor or hands the office to Lene.

## The villagers

### 1. Hedda, the grandmother (in the game)

- **Age and role:** 83. The player's grandmother, Anselm's widow, and the village's memory.
- **Appearance:** Woman, age 0.95, soft heavy build (weight 0.55, muscle 0.3). Silver hair in a long braid. Long brown skirt and a cream fisherman sweater, worn shoes. Stoops a little, but walks the village every day.
- **Personality:** Warm, practical, and sharp. Feeds people instead of comforting them with words. Never complains about her own losses, and notices everyone else's.
- **Backstory:** Born in Erlenfall, married Anselm at nineteen. Raised two sons: Lukas, the player's parent, who went to Talbrück long before the landslide, and Jorin, Mira's father, who stayed and became a miner. She lost Jorin to the slide and Anselm last winter, and took Mira in when Mira's mother left. She has watched the road every day since writing to Lukas's child.
- **Relationships:** Raised Mira, and loves her fiercely. Old friend of Greta, Agnes, and Veit. Respects Bertram, who was Anselm's closest friend. Suspects Brandt carries something about the slide, but has never asked him.
- **Offers:** Lore about the village and the family. Hot soup as a small heal. Later, the family quest to find Anselm's lost toolbox, and a recipe book of home remedies for alchemy.

### 2. Mira, the cousin (in the game)

- **Age and role:** 25. The player's cousin. Gathers wood, walks the hills, and knows every path in the valley.
- **Appearance:** Woman, age 0.5, lean and strong (weight 0.4, muscle 0.5). Short chestnut hair, often messy. Green-grey fisherman sweater, brown wool trousers, boots. A hatchet on her belt.
- **Personality:** Restless, quick, and funny. Covers worry with jokes. Brave to the point of carelessness, and hates being told to be careful.
- **Backstory:** Grew up around the mine, where her father Jorin worked. She was nineteen when the slide killed him. Her mother Liese went to Talbrück for work and asked Mira to come, but Mira stayed with Hedda and refuses to leave the valley that took her father. She roams the landslide and the woods, and was the first to see the goblins move in.
- **Relationships:** Hedda's granddaughter and her shadow. Works for Wendel, cutting wood. Friends with Rudi and Falk, who taught her to track. Tobi follows her around, and she pretends to mind.
- **Offers:** Directions and gathering hints, warnings about goblins, and later a scouting quest to the far side of the landslide. A source of rumors from the inn.

### 3. Bertram, the smith (in the game)

- **Age and role:** 44. The village's smith, with more work than hands.
- **Appearance:** Man, age 0.65, broad and heavily muscled (muscle 0.8, weight 0.6). Short dark hair, full brown beard, burn scars on his forearms. Brown tunic and trousers with a leather apron, heavy boots.
- **Personality:** Gruff, patient, and honest. Says little, praises rarely, and means it when he does. Measures people by the quality of their work.
- **Backstory:** Came to Erlenfall at fourteen as an apprentice to the old smith, and took over the forge at twenty-five. His work was mine tools: picks, wedges, rails, and hinges. Anselm took him in his first winter and taught him to fix more than iron. Since the slide he forges nails, hinges, and ploughshares from scrap, and he refuses to let the forge go cold. His apprentice left two winters ago.
- **Relationships:** Anselm was like a father to him, and he feels he owes the family. Drinks one cup at Greta's every evening. Knew Oswin from the mine days. Trades with Marek for coal when the landslide's seams run thin. Argues with Brandt, but respects him.
- **Offers:** Teaches smithing, the first quest, and later recipes and better tools. Buys nails and tools. A quest to reforge the mine's old rails once the mine opens.

### 4. Greta, the innkeeper (in the game)

- **Age and role:** 38. Runs the inn, *The Alder Bough* (*Zum Erlenzweig*), on the village square.
- **Appearance:** Woman, age 0.6, sturdy (weight 0.6, muscle 0.4). Dark blond hair in a ponytail, rosy cheeks. Rust-red sweater over a long ochre skirt, sleeves pushed up.
- **Personality:** Brisk, dry, and kind. Jokes about her troubles so no one pities her. Knows everything that is said in the village and repeats only the good parts.
- **Backstory:** Inherited the inn from her parents. Before the slide it was full of miners and carters from Talbrück. Her husband Peter left to find work in the lowlands four years ago and stopped writing. She kept the inn open, because the village needs one warm room where people meet, even after the roof began to leak.
- **Relationships:** Mother of Jakob, the young carpenter, whose broken leg is why nobody could climb onto her roof. Friend of Hedda and Hanne. Bertram's evening cup is a habit she counts on. Brews the village's beer with Veit's honey.
- **Offers:** Rumors and lore. Food and a bed. Later, quests to bring the inn back: tables and chairs (carpentry), a new sign, and rooms for travelers once the road reopens. The inn is where new villagers would first appear (issue #40).

### 5. Brandt, the mayor (in the game)

- **Age and role:** 70. Mayor for eleven years, and the last member of the old village council.
- **Appearance:** Man, age 0.85, average build (weight 0.6, muscle 0.4). Short grey hair, clean-shaven, deep frown lines. A long dark red robe, the mayor's chain on feast days.
- **Personality:** Proud, careful, and stubborn. Values order because he has seen what happens without it. Feels threatened by anyone who acts without asking, and hides guilt behind rules.
- **Backstory:** Once ran the ore trade with Talbrück. As mayor he steered the village through good years, and then decided to keep the mine open one more winter despite Oswin's warning. Since the slide he has spent everything he had on keeping people fed, and he blames himself for every family that left. He has never told anyone about the warning.
- **Relationships:** Father of Lene, his clerk. Oswin's silence binds the two of them. Distant with Hedda, whose son died in his mine. Respects Bertram's work, distrusts Mira's wandering, and fears the player's energy.
- **Offers:** Permission and building contracts, the village's taxes and treasury later, and the main story's arc. Rewards depend on whether the player respected or annoyed him.

### 6. Oswin, the old foreman

- **Age and role:** 63. Former foreman of the mine, now a broken-down man who mends baskets.
- **Appearance:** Man, age 0.79, wiry and bent (weight 0.4, muscle 0.5). Thin white hair, a short grey beard, a cough. A miner's leather cap he never takes off, a faded tunic, a cane.
- **Personality:** Quiet, bitter, and gentle with children. Talks about the mine as if it were a person. Speaks the truth when asked directly, and avoids being asked.
- **Backstory:** Worked in the mine for forty years. He reported the cracks, was overruled, and was not on shift the night it came down. He has never forgiven himself for not closing the galleries on his own, and has never told the village, because blame would not bring anyone back.
- **Relationships:** Brandt's unwilling secret-keeper. Taught Jorin and Matthis. Avoids Hedda and Konrad because he cannot look at them. Plays draughts with Veit and Albrecht.
- **Offers:** Mine lore, the map of the old galleries, and the truth about the slide. Later, the main quest to reopen the mine safely: timber for shoring, a cleared entrance, and lamps.

### 7. Konrad, the north farmer

- **Age and role:** 42. Farms the north farm, the largest of the three.
- **Appearance:** Man, age 0.63, big and solid (weight 0.65, muscle 0.7). Shaggy brown hair, a beard, sunburnt face. Wool trousers, a brown sweater, a straw hat in good weather.
- **Personality:** Hard-working and blunt. Grief turned him serious. Distrusts talk and plans, and trusts dirt under the fingernails.
- **Backstory:** Lost his brother Matthis in the slide and his wife Ilse to fever the winter after. Raises his son Tobi alone and feeds a good part of the village from his fields. He wants the mine left buried, where his brother lies.
- **Relationships:** Tobi's father. Sells grain to Greta. Leans on Agnes for help with Tobi. Grudging respect for Brandt, who kept the village fed. Will oppose reopening the mine until he hears the whole story.
- **Offers:** Grain, vegetables, and farm work. Later, quests to mend his fence and plough (smithing), and a choice-heavy moment in the mine arc.

### 8. Tobi, the farmer's boy

- **Age and role:** 10. Konrad's son.
- **Appearance:** Boy, age 0.17, small and skinny. Tousled light brown hair, a gap in his teeth, scraped knees. An oversized sweater that was his uncle's, trousers rolled up.
- **Personality:** Curious, loud, and fearless. Asks everything. Collects shiny stones and wants to be a smith, or a goblin hunter, or both.
- **Backstory:** Was four when his uncle died and five when his mother did, and remembers little of either. He has grown up in a village where everyone talks about how things used to be, and he wants to see some of it.
- **Relationships:** Follows Mira and the player everywhere. Hangs around Bertram's forge until he is chased away. Oswin is the only adult who has time for his questions.
- **Offers:** Small fetch quests, finding lost things, and gossip no adult would share. Reacts to everything the player builds.

### 9. Wendel, the woodcutter

- **Age and role:** 55. Woodcutter and forester of the west woods.
- **Appearance:** Man, age 0.73, tall and rangy (weight 0.45, muscle 0.65). Grey-streaked dark hair tied back, a thick moustache. Green-brown tunic, leather leggings, a woollen hood, an axe always within reach.
- **Personality:** Slow-spoken and calm. Loves the forest, and would rather plant two trees than cut one. Hums while he works.
- **Backstory:** Grew up in the forest's edge cottage his family has held for generations. Since the mine closed, wood is the only thing Erlenfall still sells, carried over the pass a few bundles at a time. He keeps the felling sustainable, and worries that the village will strip the woods if it gets hungry enough.
- **Relationships:** Mira works for him, and he trusts her more than she knows. Supplies Bertram with charcoal wood and Jakob with timber. Old friends with Falk.
- **Offers:** Wood and timber. Teaches felling once the player has an axe. Later, quests to replant, and timber for the mine's shoring and the town wall.

### 10. Agnes, the goatherd

- **Age and role:** 66. Keeps goats and sheep on the south farm.
- **Appearance:** Woman, age 0.82, small and tough (weight 0.4, muscle 0.45). White hair under a headscarf, weathered face, laugh lines. Long grey-blue skirt, a sheepskin vest, a crook.
- **Personality:** Cheerful, superstitious, and tireless. Talks to her goats more than to people. Believes in signs and the old stories, and is sometimes right.
- **Backstory:** A widow for twenty years. She raised her grandson Rudi after his parents moved to Talbrück for work. She knows the high pastures and the goat path over the pass better than anyone except Marek.
- **Relationships:** Rudi's grandmother. Hedda's oldest friend; the two of them argue about everything. Helps Konrad with Tobi. Sells cheese and wool to Greta and Hanne.
- **Offers:** Cheese, milk, and wool. Folk tales and the old stories about the mountain. Later, a quest to find lost goats near the goblin woods.

### 11. Rudi, the restless youth

- **Age and role:** 19. Agnes's grandson, a shepherd who wants to be anything else.
- **Appearance:** Young man, age 0.37, lanky (weight 0.35, muscle 0.4). Messy blond hair, the start of a beard. A patched sweater, wool trousers, a pack he keeps half-packed.
- **Personality:** Bored, honest, and kind underneath. Thinks Erlenfall is dying and that staying is foolish. Hates hurting his grandmother.
- **Backstory:** Has planned to leave over the pass every spring for three years and never gone, because Agnes would be alone. He listens to Marek's stories of Talbrück the way Tobi listens to Oswin.
- **Relationships:** Agnes's grandson. Mira's friend; she teases him about leaving. Marek's best listener.
- **Offers:** A personal story shaped by the player: as the village grows, he decides whether to stay. He could become Jakob's partner, the town's first guard, or Marek's trading partner.

### 12. Runa, the herbalist

- **Age and role:** 34. Herbalist and the village's only healer. The first to practise alchemy here.
- **Appearance:** Woman, age 0.57, slight (weight 0.4, muscle 0.4). Long black hair in two braids, dark eyes, ink and herb stains on her fingers. A grey-green dress with a leather apron full of pockets, a satchel.
- **Personality:** Thoughtful, private, and dry. Precise about her work. Says plainly that her craft is no magic, only knowledge, and that it cannot fix everything.
- **Backstory:** Came over the pass four years ago, alone, after hearing that Erlenfall had lost people to a fever no one could treat. She does not talk about where she came from. She lives in a cottage at the forest's edge and is still treated as a newcomer.
- **Relationships:** Konrad has never forgiven the fever, and avoids her though she came too late to blame. Hedda trades remedies with her. Tends Jakob's leg and Oswin's cough. Wary of Falk's traps, which catch the wrong animals.
- **Offers:** Healing, herbs, and potions. Teaches alchemy (a launch craft) and thrown potions. Later, a quest to gather rare herbs on the landslide.

### 13. Jakob, the young carpenter

- **Age and role:** 21. Greta's son, the village's carpenter since the old one left.
- **Appearance:** Young man, age 0.41, slim but strong in the arms (weight 0.4, muscle 0.55). Dark blond hair like his mother, freckles. Brown wool trousers, a rolled-up linen shirt, a leather tool belt. A splinted leg and a crutch for now.
- **Personality:** Eager, proud, and impatient. Embarrassed to be laid up. Has big ideas about building and little patience for being careful.
- **Backstory:** Learned carpentry from Anselm, more than from the old carpenter who left. He fell from the inn's own roof in autumn while trying to fix it, which is why it stayed broken.
- **Relationships:** Greta's son, and protective of her. Misses his father but won't say so. Thinks of Anselm as his real teacher, so he is curious and a little jealous of the player. Gets his timber from Wendel.
- **Offers:** Teaches carpentry (a launch craft) once his leg heals. Furniture for the inn and house repairs. A partner for building quests, including the assembly building and the fort.

### 14. Falk, the hunter

- **Age and role:** 41. Hunter and trapper. Keeps the goblins in the east woods watched.
- **Appearance:** Man, age 0.62, lean and quiet-moving (weight 0.4, muscle 0.65). Close-cropped black hair, stubble, a scar through one eyebrow. A dark brown hooded jerkin, leather leggings, a bow.
- **Personality:** Watchful, patient, and few-worded. Respects the goblins as opponents and does not hate them. Wants to be left alone, and helps anyone who asks.
- **Backstory:** A soldier in the lowland wars in his youth, and came home to Erlenfall, where he was born, to forget them. Since the slide he hunts for the village's meat. He has watched the goblin camp for years and thinks they came down because the slide drove them out of their own caves.
- **Relationships:** Taught Mira to track. Friends with Wendel. Gerold served with him and they share the watch. Runa dislikes his traps.
- **Offers:** Meat, hides, and leather. Combat tips, goblin lore, and later the bow. Quests to scout or deal with the goblins, with talking as a possible way (issue #30).

### 15. Lene, the clerk

- **Age and role:** 31. The mayor's daughter and the village's clerk.
- **Appearance:** Woman, age 0.55, slender (weight 0.45, muscle 0.35). Light brown hair pinned up, ink on her fingers, sharp grey eyes. A dark red dress like her father's robe, a ledger under her arm.
- **Personality:** Organised, fair, and frank. Loves her father, and sees his faults clearly. Believes in fixing things with numbers and plans.
- **Backstory:** Was sent to Talbrück to learn reckoning and letters, and came back when the slide cut the road, to help her father hold the village together. She keeps the ledgers of food, wood, and debts, and has noticed gaps in the mine's records from the autumn before the slide.
- **Relationships:** Brandt's daughter, and the person who can soften him. Admires Hanne's patience. Grows to trust the player, and to rely on them.
- **Offers:** Taxes, the economy, and contracts later. A bridge between the player and the mayor. Finds the ledger page that starts the mine arc's reveal, and could become mayor at the end.

### 16. Albrecht, the old teacher

- **Age and role:** 79. Retired schoolmaster and keeper of the village chronicle.
- **Appearance:** Man, age 0.92, thin and frail (weight 0.35, muscle 0.25). Wispy white hair, a white beard, spectacles. A long brown robe with ink stains, a shawl.
- **Personality:** Talkative, curious, and gentle. Loves history and puns, and remembers dates better than names.
- **Backstory:** Taught three generations of Erlenfall's children, including Brandt, Hedda's sons, and Bertram. The school closed when the last families with children left. He still writes down everything that happens in the village chronicle, and thinks the player belongs in it.
- **Relationships:** Plays draughts with Oswin and Veit. Teaches Tobi to read on his own time. Calls Brandt "young man", which Brandt hates.
- **Offers:** Lore about the alder grove, the goblin winter, and the old palisade on the mound. A quest to restore the school. The chronicle as an in-game record of the player's choices.

### 17. Marek, the peddler

- **Age and role:** 46. A travelling peddler who crosses the goat path over the pass about once a month.
- **Appearance:** Man, age 0.66, wiry and weather-beaten (weight 0.45, muscle 0.5). Curly dark hair going grey, a gold earring, a big grin. A colorful patched coat, a wide hat, an enormous pack.
- **Personality:** Charming, talkative, and shrewd. Exaggerates everything, but always pays fair. Likes Erlenfall more than he admits.
- **Backstory:** Was a carter on the north road before the slide. Now he carries what fits on his back: salt, cloth, needles, and news. He is the only regular link between Erlenfall and Talbrück, and he carries letters both ways.
- **Relationships:** Rudi's idol. Trades coal and iron with Bertram and wood with Wendel. Greta gives him a free bed. Brings Mira letters from her mother.
- **Offers:** Trade in goods the valley can't make. News of the outside world. Later, word that the village is recovering brings new settlers (issue #40), and clearing the road turns him into a proper merchant.

### 18. Hanne, the weaver

- **Age and role:** 52. Weaver and tailor.
- **Appearance:** Woman, age 0.71, round and soft (weight 0.65, muscle 0.3). Grey-brown hair in a bun, round spectacles. A blue-dyed dress she made herself, a knitted shawl, measuring tape around her neck.
- **Personality:** Patient, observant, and sly. Listens more than she talks, and remembers everything. Hums old songs at her loom.
- **Backstory:** Has woven Erlenfall's cloth for thirty years. Her loom stands in the front room of a house she shares with her late sister's things. She mends more than she makes now, and dreams of dyeing cloth in colors the valley has never seen.
- **Relationships:** Greta's confidant. Buys wool from Agnes. Lene visits her to think. Knows more about the village's secrets than anyone suspects.
- **Offers:** Clothes and cloth. Tailoring and leatherwork later. Gossip that hints at hidden stories.

### 19. Veit, the beekeeper

- **Age and role:** 74. Beekeeper and candle-maker.
- **Appearance:** Man, age 0.88, small and round (weight 0.6, muscle 0.3). Bald with a fringe of white hair, bushy eyebrows, red cheeks. A straw hat with a net, a cream smock, wooden clogs.
- **Personality:** Sunny, slow, and wise. Finds a lesson in every hive. Never in a hurry, and never worried.
- **Backstory:** Has kept bees on the slopes above the village all his life. He lost hives in the slide and rebuilt them, and likes to say that bees always rebuild. His honey and wax are among the few things the village still sells.
- **Relationships:** Plays draughts with Oswin and Albrecht. Old friend of Hedda. Supplies Greta's brewing and Runa's salves.
- **Offers:** Honey, wax, and candles. Gentle advice about patience. Later, a quest to find a wild swarm, and ingredients for alchemy and cooking.

### 20. Gerold, the watchman

- **Age and role:** 57. The village's only watchman.
- **Appearance:** Man, age 0.75, heavy and strong (weight 0.7, muscle 0.6). A shaved head, a grey beard, a broken nose. A battered padded gambeson over a tunic, a spear, a horn on his belt.
- **Personality:** Loyal, loud, and old-fashioned. Takes his job very seriously, though there is little to guard. Tells war stories nobody believes.
- **Backstory:** Served in the lowland wars with Falk, and came to Erlenfall as the mine's guard when the ore carts needed protecting. He stayed after the slide, because the village took him in. He walks the old palisade's ditch on the mound every evening and dreams of rebuilding it.
- **Relationships:** Falk's old comrade. Brandt's loyal man. Respects Bertram, who sharpens his spear. Lets Tobi blow his horn.
- **Offers:** Guard duties and the night watch. Later, the quest line for the wooden fort on the mound and the town wall, and training for combat.

## Who knows whom

| Bond | Characters |
| --- | --- |
| Family | Hedda, Mira, and the player. Konrad and Tobi. Agnes and Rudi. Greta and Jakob. Brandt and Lene. |
| The slide's losses | Hedda and Mira lost Jorin, Konrad lost Matthis, and Oswin taught them both. |
| The secret | Brandt and Oswin. Lene is close to finding it. Hedda suspects. |
| Anselm's circle | Bertram, Jakob, Hedda, and Veit. |
| The draughts table | Oswin, Veit, and Albrecht. |
| The old soldiers | Falk and Gerold. |
| The forest | Wendel, Mira, Falk, and Runa. |
| The link to the outside | Marek, with Rudi, Greta, and Mira's letters. |

## In the game now

The world has Hedda, Mira, Bertram, Greta, and Brandt (`data/village_layout.json`). Their dialogue is in `data/dialogue.json`. It mentions Konrad, Agnes, Wendel, Oswin, Albrecht, Jakob, Falk, Marek, and Lene as people the player will meet later, and uses the draft names Anselm, Jorin, Talbrück, and The Alder Bough. Changing any of these names means changing those lines in `localization/strings.csv` too. Adding the other fifteen villagers to the world is a separate step.

### What each villager says, and when

A villager plays the first conversation in their list whose conditions hold, so the later quest steps come first and a plain fallback comes last.

| Villager | Arrival | Making nails | Telling the mayor | Repairing the roof | After the repair |
| --- | --- | --- | --- | --- | --- |
| Hedda | Welcome, can ask about Anselm; then repeats where the forge is | Encouragement | Hints at Brandt's burden | Sends the player up the ladder | Proud, then questions about Mira's parents, the villagers, and Anselm |
| Mira | Greets the player, then points to the forge | Ore hint, can ask about goblins | Explains Brandt | Warns about Jakob's fall | Questions about her work, why she stayed, and her father |
| Bertram | Gives the first quest | Reminder, can ask about ore again | Speaks up for Brandt | Points to the ladder | Questions about forging, Anselm, and the mine |
| Greta | Her leaking roof, and the inn | Thanks the player for the nails | Same | Warns about the roof | Grateful, then questions about guests, Jakob, and the inn |
| Brandt | Introduces himself, can ask how long he has been mayor | Same | Confrontation and choice | Warm or cold, by that choice | Respected: questions about the mine and his rules. Annoyed: cold, with an apology or the mine |
