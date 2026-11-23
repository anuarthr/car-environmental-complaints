# ADR 0006: Model the complaints as a star schema

- Status: accepted
- Date: 2026-11-23

## Context

The dashboard and the analyses ask the same questions of every complaint: when it was filed,
where, about which resource, through which office and channel, and how its answer compares
with the recorded deadline and with the legal term. Staging and the intermediate models hold
those facts in two places, and two of them need a lookup the source does not provide.

- **Municipality.** CAR writes 126 names without a department. DIVIPOLA repeats names across
  departments (four BUENAVISTA), spells three of them differently (BOGOTÁ, D.C., VILLA DE SAN
  DIEGO DE UBATÉ, VILLAGÓMEZ), and does not divide Bogotá into the 21 districts CAR names.
  Every name is handled by a single CAR regional office.
- **Resource.** The resource marks are missing on three in four complaints (ADR 0004), so the
  theme is the only complete source. Of its 50 values, some name one resource, one says there
  are several, and the rest are requests and procedures. Noise, odors and seizures are not
  named as a resource at all.

Looker Studio reads BigQuery tables and computes its own aggregates, including medians.

## Decision

- **A star schema with one fact table.** `fct_complaints` has one row per complaint. Three
  dimensions have attributes of their own: `dim_date` (calendar parts, holidays, business
  days), `dim_municipality` (department and coordinates, every DIVIPOLA municipality) and
  `dim_theme` (the resource).
- **No dimension for office, channel or filer type.** They have no attribute beyond their
  name, so a dimension each would add joins and nothing else. They stay in the fact table as
  text (degenerate dimensions).
- **Curated seeds for both lookups, listing every value.**
  - `car_municipality_codes` maps each of the 126 names to a code and says how it was found:
    the only DIVIPOLA match once accents and case are ignored, the only namesake in the
    department of the CAR office that handles it, DANE's spelling, or a district of Bogotá. The
    result is 98 municipalities of Cundinamarca, 6 of Boyacá and Bogotá, the jurisdiction CAR
    describes.
  - `car_theme_resources` gives each theme the resource it names. CAR's marks back the choices
    where they exist: it marked air on 246 of 262 marked noise complaints and on 148 of 206
    marked odor complaints. Seizures get no resource: CAR marked flora on 386 of 535 and fauna
    on 123.
  - Listing every value, rather than matching names in SQL and curating only the exceptions,
    means a value a new release brings is reviewed by a person: `fct_complaints` fails its
    tests until the seed has a row for it.
- **Aggregate marts hold counts, not rates.** `mart_monthly_compliance` (filing month and
  regional office) and `mart_municipality_summary` (municipality and resource) hold counts
  that add up across any grouping. A rate is a ratio of sums. Medians and percentiles are not
  additive, so they are computed from the fact table.
- **Nothing is dropped.** A complaint with no municipality keeps a null code and, in the
  municipality mart, a row with no coordinates. An answer dated before filing is left out of
  the complaints judged against the legal term, not counted as on time. Tests check that the
  fact table has one row per staged complaint and that each mart adds up to it.
- **Marts are tables.** Each chart scans a table of at most a few megabytes instead of
  rerunning the views down to raw.

## Consequences

- A new municipality name or theme in a release stops the build of the fact table and the
  marts until the seed is curated. The rest of the project still builds.
- The map places 84.3% of complaints in the release of 2026-11-10: 11,780 have no recorded or
  verified municipality. Complaints in Bogotá sit on one point, though CAR named the district
  in most of them; the fact table keeps CAR's name.
- 5,371 complaints (7.1%) have a theme that names no resource, and 30,097 (40.0%) a theme that
  names several. The resource question can be answered for the rest only.
- Matching within CAR's jurisdiction confirms only that every name falls in Cundinamarca,
  Boyacá or Bogotá. It is not a check against CAR's official list of municipalities.
