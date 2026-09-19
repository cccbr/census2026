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
