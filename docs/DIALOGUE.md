# Dialogue data

Conversations live in [`data/dialogue.json`](../data/dialogue.json) and are played by `DialogueRunner` (`scripts/story/dialogue_runner.gd`). All text is a key in `localization/strings.csv`, in English and German.

## Structure

The file maps a character id to a list of conversations. When the player talks to the character, the **first conversation whose `when` holds** plays. A conversation without `when` always holds, so put it last as the everyday fallback. Because the first match wins, make neighbouring conversations exclusive (with `not_flag`) rather than relying on their order.

A conversation has a `start` node id and a `nodes` map. A node has:

- `text`: the line, as a translation key.
- `next`: the node to go to when the player continues. Without it the conversation ends.
- `choices`: the player's replies. Each has `text`, an optional `next`, an optional `when` (the reply is hidden unless it holds), and optionally `chance` with `fail_next` for replies that only sometimes work.
- `choices_of`: the id of another node in the same conversation whose `choices` this node uses. Use it for an "anything else?" node instead of repeating the list.
- `effects`: `start_quest`, `advance_quest`, `set_flag`, `give_item`, `take_item`, and for enemies `calm_enemy` and `provoke_enemy`.
- `must_answer`: if true, the player cannot walk away from the line.

## Conditions

A `when` can hold several conditions, and all of them must hold.

| Condition | Value | Holds when |
|---|---|---|
| `objective` | `["quest", "objective"]` | The quest's current objective is that one |
| `quest_done` | `"quest"` | The quest is finished |
| `flag` | `"flag"` | The flag has been set (by a `set_flag` effect or a world event) |
| `not_flag` | `"flag"` | The flag has not been set |
| `has_item` | `["item", count]` | The player carries at least that many |

## One-time lines

To say something once and then give way to an everyday greeting, set a flag in the first conversation and exclude it with `not_flag`:

```json
{ "when": { "quest_done": "first_nails", "not_flag": "hedda_proud_told" }, "start": "proud",
  "nodes": { "proud": { "text": "DLG_HEDDA_PROUD", "effects": [{ "type": "set_flag", "flag": "hedda_proud_told" }] } } },
{ "when": { "quest_done": "first_nails" }, "start": "hello", "nodes": { "hello": { "text": "DLG_HEDDA_GREETING" } } }
```

`DataValidator` checks the condition names and that `choices_of` points at a node that exists.
