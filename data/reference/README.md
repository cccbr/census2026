# Reference data

Small, hand-curated lookups that are **part of the method**, not build
artefacts. These are committed so they are reviewable and diffable.

Expected contents:

- `societies.csv` — CCCBR affiliated/associated/small societies as listed in
  the Council's annual membership return, with membership counts and rep
  numbers.
- `society_crosswalk.csv` — the mapping from Dove affiliation codes to CCCBR
  society names.
- `tower_territorial_society.csv` — the single territorial society assigned to
  each tower, for association-level reporting.

## The crosswalk rule

Fuzzy matching **proposes**; a human **disposes**; the accepted mapping is
committed. No mapping enters these files because a string distance was below a
threshold. Every row carries a `match_method` and a `notes` column, and every
row has been looked at.

This matters because society display names ("Bath & Wells Diocesan",
"Gloucester & Bristol") will not string-match Dove's affiliation codes, and a
silently fuzzy-matched association total is exactly the kind of number that
cannot be defended when a delegate queries it.

## Known complications, to be handled explicitly

- **Affiliation is many-to-many.** Towers affiliate to multiple societies.
  ASCY, the Royal Cumberland, the university societies and the Guild of Railway
  Ringers are non-territorial and cut across geography. Association-level
  reporting therefore needs a curated single *territorial* assignment per
  tower, held separately from non-territorial membership.
- **Society membership is not a person count.** A ringer may belong to several
  societies. The Council's "total ringers represented" figure is a sum of
  memberships and the census must say so.
- **Branch / district does not exist in Dove.** If drill-down by branch is
  required, that attribute must be sourced from associations directly. Do not
  collect it as free text from tower representatives.

## known_towers.csv — towers people on the team know well

A sense check for the settlement classification. Each row is a tower that a
named person knows well enough to say what sort of place it feels like. The
analysis chapter *Choosing a classification* lists every known tower with its
class, the measures behind it, and whether the class matches the feel.

| Column | Meaning |
| --- | --- |
| `tower_id`, `ring_id` | Dove keys. Join on `tower_id` |
| `dove_label` | Dove's place and dedication, for reading the file |
| `known_by` | Who knows it |
| `relationship` | A few words on how they know it |
| `feels_like` | What sort of place it feels like, in the classification's own words: `Small village or hamlet`, `Village`, `Town`, `City or large town`, `Suburban`, `Inner city`. Use the nearest; do not add new words |
| `why` | Optional: a few words on why it feels that way |
| `added_on` | Date the row was added |

`feels_like` is the person's judgement, recorded **before** seeing the class
the rules give. Change it only if your view of the place changes, never to
match the rules: a disagreement is the useful part.

The classification now splits cities and conurbations into centre and suburb
(D-036). Keep using the simpler words above: the chapter counts "City or
large town" as agreeing with either kind of centre, "Suburban" with either
kind of suburb, and "Inner city" with a conurbation's centre.

To add your own: append rows, one per tower, keeping the relationship short
and impersonal. **This repository is public.** Do not add anything about
other people, or anything you would not want published.

## gb_register_crosswalk.csv — the Gloucester & Bristol register matched to Dove

The Association's 2025 tower register (towers, branches, bells, ringers on
the register) matched to Dove's `tower_id` and `ring_id`. Only tower names
and Dove keys are here; the ringer counts stay out of this public
repository. Built and explained by `scripts/11_import_gb_register.R` and
`gb_register.md`. Proposed matches have `reviewed` blank until a person has
checked them.
