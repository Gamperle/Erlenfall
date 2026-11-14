# Erlenfall lore bible

**Status: DRAFT for the maintainer to review.** Like the rest of the story (issue [#20](https://github.com/Gamperle/Erlenfall/issues/20)), every name, date, and rule here is a proposal. Nothing in the game reads this file. It exists so dialogue, item descriptions, signs, and books (and mod authors) stay consistent. Part of [#266](https://github.com/Gamperle/Erlenfall/issues/266).

It builds on what the game already says: [the design document](GAME_DESIGN.md), [the villager document](VILLAGERS.md) (whose history table this extends, not replaces), and the dialogue in `localization/strings.csv`. If this file and an in-game line disagree, the game line wins until the maintainer decides otherwise (see "Facts that must stay true").

Dates are "years before the game begins", as in the villager document, because the game has no calendar and no seasons yet.

## Timeline

| When | What happened | Source |
| --- | --- | --- |
| Long ago | The mountains rise over a valley whose iron seams run under an old rockfall. The rock is slightly "bright" (see Magic). Nobody lives here. | Proposal |
| About 200 years | Miners settle below the seams, where an alder grove grows on the rockfall, and name the place *Erlenfall*. The first beer is poured at what becomes *The Alder Bough*. The spring assembly meets under an alder on the northeast hill. | Villager doc, Greta |
| About 150 years | The north road over the pass to Talbrück is built to carry ore down and grain up. | Proposal |
| About 90 years | The goblin winter. The village raises a wooden palisade on the southwest mound, and it holds. Only the ditch remains. | Villager doc |
| About 64 years | Hedda marries Anselm at 19 (she is 83 now). | Derived |
| 11 years | Brandt becomes mayor. The mine pays well. | Game (Brandt) |
| 7 years, autumn | Oswin finds fresh cracks above the upper galleries and asks to close them. Brandt delays until spring. | Villager doc (secret) |
| 6 years, spring thaw, at night | The slope comes down and buries the mine entrance and the north road. Jorin and Matthis, on the night shift, die. | Game; details in villager doc |
| 6 years and after | Families leave over the goat path. A fever the first winter kills Konrad's wife. Goblins move into the east woods. | Game (goblins); villager doc |
| 4 years | Runa arrives over the pass. Greta's husband leaves. | Villager doc |
| Last winter | Anselm dies and repairs stop. | Game |
| Now | The player arrives. | Game |

## Places

Names must read in both English and German, as *Erlenfall* does (*Erle* = alder, *Fall* = rockfall). Proposed pairs are English / German.

| Place | What it is | Source |
| --- | --- | --- |
| Erlenfall / Erlenfall | The village at the valley's centre, with outlying farms. | Game |
| The Alder Bough / Zum Erlenzweig | Greta's inn on the square. | Game |
| The mine / Die Mine | The buried mine north of the village. | Game |
| The Slide / Der Erdrutsch | The landslide site up the north road, where ore and coal can be gathered. | Game |
| The north road / Die Nordstraße | Village to the Slide, formerly on over the pass. | Game |
| The pass / Der Pass | The mountain crossing to Talbrück. Only a goat path is left. | Game |
| Talbrück / Talbrück | The lowland market town (*Brücke* = bridge) that bought the ore. | Game, villager doc |
| The west woods / Der Westwald | Wendel's forest, where trees can be felled. | Design doc |
| The goblin woods / Der Goblinwald | East of the Slide. | Game (Mira) |
| The mound / Der Hügel | The steep southwest mound with the old palisade ditch, kept free for the fort. | `building_sites` |
| Assembly hill / Der Versammlungshügel | The northeast hill with the old alder, kept free for the assembly building. | `building_sites` |

"The mine" and "the Slide" are working names for the glossary. The game only says "the mine" and "the landslide".

## Peoples and factions

There is no villain, only interests (design document).

- **The mayor and clerk.** Brandt and Lene. They want order and food on the table, and Brandt hides a secret about the slide.
- **The miners' families.** Hedda and Mira, Konrad and Tobi. They lost people to the slide and disagree about the mine: Konrad wants it left buried.
- **The craftspeople.** Bertram, Jakob, Hanne, Wendel. They want trade and materials.
- **Leavers and returners.** Those who crossed the pass, and Talbrück's people who may come back once the road opens. Marek links the two.
- **The goblins.** Grey-green, quick, spear-carrying, and not evil. They were probably driven out of their caves by the slide (Falk's theory) and carry scrap iron. Talking to them may become a way out of fights (issue [#30](https://github.com/Gamperle/Erlenfall/issues/30)).

## The mine

- **What it was.** An iron mine with coal nearby, worked for about 200 years. Oswin ran it for forty years, and Bertram made tools for forty miners. Carts ran every hour. Ore went down the north road to Talbrück, and grain and cloth came back.
- **Shape (proposal).** Upper galleries along the iron seams, lower galleries toward the old rockfall, shored with timber from the west woods.
- **Now.** The entrance is buried. Ore and coal can still be gathered at the Slide.
- **Future.** A main-story quest to reopen it safely: timber for shoring, a cleared entrance, and lamps. Whether to reopen it is a player choice that changes the town (the mayor's arc in the villager doc).

## The landslide

- **What happened.** On a spring-thaw night six years ago, the slope above the upper galleries came down. It buried the mine entrance and the north road. Two night-shift miners died: Jorin (Hedda's younger son, Mira's father) and Matthis (Konrad's younger brother).
- **Cause (proposal).** Meltwater in cracks that Oswin had already reported, shoring put off until spring, and weak old rockfall under the seams. No monster, sabotage, or spell.
- **What it still does.** The slope shifts after heavy rain (Mira). Shoring and drainage are part of reopening the mine.
- **Who knows what.** Everyone knows it happened. Only Brandt and Oswin know it was reported, Hedda suspects, and Lene is close to finding the ledger page.

## Magic

The design says: high fantasy, but magic is limited and solves no problem by itself. Milestone 10 plans it ([#230](https://github.com/Gamperle/Erlenfall/issues/230)), so this section sets the world's rules, not the gameplay. It must not make the other crafts pointless.

**Proposal: "glimmer" / *Schimmer*.** A faint, bright quality in some old stone, most of all the rock under the iron seams. Iron from the mine carries a trace of it. Glimmer is not a force anyone commands. It is a property of materials that skilled hands can bring out.

**Rules**

1. Magic comes from materials, never from the caster alone. No glimmer-bearing material, no spell.
2. It works through a craft: enchanting, alchemy, or smithing. A bare-handed effect is at most a small bolt or a light.
3. It is small and local: a lamp that stays warm, a sharper edge, a short bolt, a salve that works a little better.
4. Each use spends the material (a charge, a shard, a reagent), so supply depends on the mine.
5. Quality matters as in every craft: the same recipe made badly does less, or nothing.

**Limits (it never solves a problem alone)**

- It cannot raise the dead or undo the slide's losses.
- It cannot move mountains, clear the road, or feed the village. Those take people, timber, and time.
- It cannot heal what rest and care could not.
- It cannot make anyone obey, or replace a hard conversation.
- Magic items and users are rare, and a skill, not a gift.

**Learned how (proposal for #230).** By practice with a teacher or a book, and by working glimmer-bearing materials.

**Magic in the game now.** None. Agnes believes in signs and old stories, Albrecht keeps the chronicle, and Runa (in the villager doc) says her craft is knowledge, not magic. Players first meet magic as rumor.

## What the player may learn, and what stays a mystery

| The player learns | Stays a mystery |
| --- | --- |
| The slide's real cause (the reported cracks and the delay), through Oswin or Lene's ledger | Whether glimmer in the rock made the slope weaker |
| That the mine can be reopened with shoring | What lies in the lowest galleries |
| That the slide drove the goblins out | Why the goblins carry scrap iron, and what their caves held |
| The founding and the goblin winter, from Albrecht and Agnes | The exact origin of glimmer |
| That magic is small, costly, and craft-based | Whether it was once stronger |
| | What Mira hears when she listens at the slide |

## Names and language

- Prefer names that are the same word or an obvious cognate in English and German (*Erlenfall*, *Talbrück*). Place names are not translated, but their meaning in a sign or book should be.
- Villagers' given names (Hedda, Mira, Bertram, Brandt) are drafts ([#20](https://github.com/Gamperle/Erlenfall/issues/20)). If one changes, update this file and the villager document together.
- German text is unreviewed by a native speaker ([#19](https://github.com/Gamperle/Erlenfall/issues/19)), so the glossary's German names are proposals too.

## Facts that must stay true

These are already in the game (`localization/strings.csv`, `data/`) unless marked. Change them only on purpose.

1. The landslide destroyed the road and buried the mine, the village's main income, and only wood and farming remain (Hedda).
2. Brandt has been mayor eleven years: five good, six since the mountain came down, and nobody has starved in those six (Brandt).
3. Jorin was on the night shift when it came down. Mira's mother went to Talbrück, and Mira stayed (Hedda, Mira).
4. Some say the mountain gave warnings before it fell, and Hedda never asked Brandt (Hedda).
5. Ore is rust-red stone and coal is black, both at the Slide up the north road (Mira, Bertram).
6. Goblins moved into the woods east of the Slide. They are grey-green, quick, and carry scrap iron, and Falk says the slide drove them from their caves (Mira, Bertram).
7. The slide still shifts after heavy rain (Mira).
8. Oswin ran the mine for forty years and will not talk about it yet (Oswin). Bertram made tools for forty miners (Bertram).
9. The inn is *The Alder Bough*. Greta's grandmother's grandmother poured the first beer there for the miners, and the fire has never gone out (Greta).
10. Marek crosses the pass about once a month and is the link to Talbrück (Greta, Marek).
11. Jakob fell from the inn roof last autumn and is on crutches (Mira).
12. Anselm, the grandfather, mended half the village's roofs and doors and died last winter (design doc, villager doc).
13. Magic is limited and solves no problem by itself (design doc).
14. The valley has the north road, a river under the road bridge, the west woods, the mound, and the northeast hill (design doc, `data/village_layout.json`).

## Open questions for the maintainer

1. Are "glimmer" and *Schimmer* the right name and idea for magic, or should magic come from somewhere else?
2. Should magic users exist in the story, or only enchanted items?
3. Is the landslide purely human error (my proposal), or does the mountain play a part?
4. Is the 200-year founding right? Do you want real calendar dates, or years-ago only?
5. What lies in the mine's lowest galleries: only a place to explore, or where a larger mystery leads?
6. Do the goblins have their own story, and can the player make peace with them (#30)?
7. Should Talbrück become a place the player can visit (world expansion, milestone 10)?
8. Should the mayor's secret be the main revelation, or something larger?

See also the open questions in the villager document, and issues [#192](https://github.com/Gamperle/Erlenfall/issues/192) (villager dialogue) and [#230](https://github.com/Gamperle/Erlenfall/issues/230) (magic).
