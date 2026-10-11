# Gloucester & Bristol Diocesan Association: tower register, 2025

*Recorded by Mark Ainsworth with Claude (Anthropic), 11 October 2026.*

## What it is

The Association's own list of its towers, with each tower's branch, its
number of bells, and the number of ringers on the register. Richard Heys, the
Association's treasurer, sent it to Mark on 11 October 2026 as a spreadsheet,
`G&B Towers 2025.xlsx`.

- 278 entries (towers, and one band) in 12 branches, plus 17 ringers in 6 branches registered as
  "Unattached" (with the branch, but no tower).
- 103 towers have no ringers on the register.
- Five towers are marked as sharing a band with a neighbour, such as
  Alderton "& Dumbleton". The count is the shared band's.
- Bells are every bell in the tower, so a ring of twelve with a flat counts
  as 13. Dove counts the ring (12).

## How it was compiled, and why it matters

As Richard described it: when he became treasurer, the register still listed
many people who had last paid years before. He pared it back to the ringers
actually in each band. The counts are therefore a recent, deliberate attempt
at the true size of each band. Lists kept for affiliation counts can run
higher than the bands themselves, which is one reason this register is so
useful.

## What it is for

- **Validating the settlement types.** Towers with no band of their own, such
  as the central Bristol ten-bell towers rung by a cluster band, test the
  tower-cluster flag directly.
- **Priors for the generative model.** Band size by ring size and place type,
  and the share of towers with no band, from a register kept for its own
  purposes.
- **A check on census returns** for the Association's towers.

## What it is not

- Not a census: one Association, kept by its treasurer, at one point in 2025.
- "Ringers on the register" is not the same as ringers who ring there. A
  ringer may ring at several towers but be registered at one.
- A zero means no registered ringers, not necessarily silent bells: a tower
  may be rung by visiting or shared bands.

## Where it lives

The register holds counts of ringers at named towers. It is the
Association's data, shared with the project, and this repository is public.
So:

| What | Where | Committed? |
| --- | --- | --- |
| The spreadsheet as received | `data/raw/gb_register/2026-10-11/` | No (gitignored); checksummed in `provenance/fetch_log.csv` |
| Tidy table with ringer counts | `data/curated/gb_register_gb_register_2025_2026-10-11.parquet` | No (gitignored) |
| Register names matched to Dove towers | `data/reference/gb_register_crosswalk.csv` | Yes: tower names and Dove ids only, no counts |

Built by `scripts/11_import_gb_register.R`. Publishing any counts, even in
aggregate, waits on the Association's agreement (decision register Q-025).

## The crosswalk

Matching follows the reference-data rule: the script proposes, a person
disposes. Each row has a `match_method`:

| Method | Meaning |
| --- | --- |
| `place` | The only Association ring in Dove at a place of that name |
| `place_bells` | One of several rings at that place, picked by its bells |
| `place_dedication` | Place and dedication together, such as "Bristol St James" |
| `unmatched` | Left for review; `candidates` lists likely Dove rings |
| `unattached` | Ringers with no tower; never matched |

`bells_differ` flags rows where the register and Dove disagree on bells,
usually because of extra semitone bells. To review: check each row, correct
`tower_id`, `ring_id` and `dove_label` where needed, and put your initials in
`reviewed`. Notes go in `notes`. Script 11 never overwrites a crosswalk that
exists.

"Bristol Central" is a band, not a tower: the central Bristol cluster band.
It should stay unmatched, with a note naming the towers it rings, once known.
