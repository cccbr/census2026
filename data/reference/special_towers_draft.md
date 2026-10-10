# special_towers_draft.csv — DRAFT, not yet reviewed

A hand-built list of towers whose band is unlikely to be explained by the
people living around them. For these towers, catchment and density measures
from `scripts/08` describe the wrong thing. Every row has `status = proposed`.
None has been reviewed by a person who knows the tower.

**What happens to these towers in the sample is Q-022 and is open.** The
options are a certainty stratum (chased with weight 1), or handling them
outside the chased sample through the societies. This file only says which
towers they are.

## Categories

| category | Rule | Rows |
| --- | --- | --- |
| `society_steeple_keeper` | A non-territorial society is responsible for the bells (ASCY, SRCY) | 11 |
| `society_service_band` | A named society or cathedral company is the band | 2 |
| `city_of_london_other` | Every other frame ring with Dove `County` = "City of London" | 8 |
| `central_london_major` | Central London cathedrals and major churches; band not established | 5 |
| `university_society` | Home tower of a student society (CCCBR university-ringing directory), or Dove lists a university society in `Affiliations` | 36 |
| `city_society_oxford` | Dove lists the Oxford Society in `Affiliations` | 7 |
| `no_resident_population` | Island or similar with essentially no resident population | 1 |
| `institutional` | Not a parish church: college, school, castle or civic chapel. Band, if any, is tied to the institution | 11 |

`city_of_london_other` is a rule, not a judgement. The Square Mile has a tiny
resident population. Any band there comes from elsewhere, whoever looks after
the bells.

## University societies: how the list was built

The main source is the CCCBR Young Ringers workgroup's directory,
https://universityringing.org/societies (75 entries, each with a Dove tower
link). Not every entry is a student society. Many are signposts: a local
tower that welcomes students. Every entry's page was read, and only towers
used by a named student society are listed. The signposts were left out
because they are ordinary local bands:

Aberdeen, Aberystwyth ("although not a university society"), Bath ("no
exclusively student ringing society"), Belfast, Chester, Cork, Dumfries,
Edinburgh ("no dedicated student practice"), Glasgow, Huddersfield ("no
student society"), Hull, Lancaster ("no dedicated student ringing society"),
Loughborough ("no student society"), Norwich ("There isn't a dedicated
university society practice"), Surrey ("no active resident students'
society"). The other entries named only by a place or county (Bedfordshire,
Bournemouth, Bradford, Buckingham, Cumbria, Derby, Dundee, Essex, Gloucester,
Hereford, Hertfordshire, Inverness, Lancashire, Limerick, Northampton,
Plymouth, Shropshire, Staffordshire, Stirling, Suffolk, Sunderland, Sussex,
Swansea, Teesside, Winchester, Wolverhampton, Worcester, Wrexham) look like
signposts too, but were not each opened.

The Welsh Colleges Society and the Open University Society have no home
tower.

**Strongest cases.** These are towers where the student society *is* the
Sunday band, or the tower belongs to the university:
- Brancepeth: Durham's society rings for Sunday service in term time and
  brings students out from the city.
- Liverpool SFX: the society is "primarily responsible for the ringing of the
  bells".
- Sheffield St Marie's: Sunday service ringing.
- St Andrews St Salvator's: rung for chapel services.
- Keele: campus church.
- The US university towers: Chicago, Seattle, Smith College, Sewanee.

**Weakest cases.** Towers marked `low` should probably be dropped:
- Reading: the society is "not currently active".
- Newcastle: a society is still "being formed".
- Walsgrave: reads as a signpost to a local band.
- Canterbury: the society joins an existing local practice.

**Disagreement.** Dove lists the Bristol society at Bristol S Michael. The
directory gives Kingsdown S Matthew. Both are kept, with S Michael at `low`.

## Known gaps and disagreements

- **ASCY at St Mary-le-Bow and St Sepulchre.** Wikipedia says the ASCY "is
  responsible for the bells at" both. Dove's `Affiliations` field does not list
  ASCY for either. Under D-022 Dove is not authoritative for affiliations, so
  log this rather than resolve it.
- **St Bride, Fleet Street** is not in `dove.csv` on this snapshot. `towers.csv`
  holds it as one bell. Its status needs checking before the list is final.
- **Cathedrals in general are not listed.** Many have their own appointed
  company, as at Lincoln. A rule is better than a list: Dove's `TowerStatus`
  field (97 ringable 4+ rings with a cathedral status) could become a frame
  flag. Lincoln is here only as an example of the type.
- **Not yet researched:** Society of Sherwood Youths (Nottingham), Southampton
  City Ringers, Birmingham St Martin and the cathedral, Liverpool Cathedral,
  York Minster, Bristol, Norwich St Peter Mancroft. These are all plausible
  city-centre cases.
- **Oxford and Cambridge rows** need checking by someone who knows who
  actually rings there in term time. Dove's affiliation is not evidence of the
  service band.

## Sources

- Ancient Society of College Youths, Wikipedia —
  https://en.wikipedia.org/wiki/Ancient_Society_of_College_Youths
- Society of Royal Cumberland Youths, Wikipedia —
  https://en.wikipedia.org/wiki/Society_of_Royal_Cumberland_Youths
- SRCY website, Service Ringing menu —
  https://srcy.org.uk/tower/st-martin-in-the-fields
- Great St Mary's Cambridge, bells page — https://www.greatstmarys.org/bells
- CCCBR university-ringing directory — https://universityringing.org/societies
  (one page per society, cited row by row)
- Southampton Universities Guild towers — https://sugcr.susu.org/towers/
- Imperial College, Use of the Queen's Tower —
  https://www.imperial.ac.uk/admin-services/secretariat/college-governance/charters/policies-regulations-and-codes-of-practice/use-of-the-queens-tower/
- Company of Ringers of the BVM of Lincoln, Wikipedia —
  https://en.wikipedia.org/wiki/Company_of_Ringers_of_the_Blessed_Virgin_Mary_of_Lincoln
- Dove's Guide `dove.csv`, snapshot `dove_2026-09-19` (CC BY-SA 4.0).

`dove_label` and `bells` are taken from Dove. Attribution:
`DOVE_ATTRIBUTION` in `scripts/00_setup.R`.
