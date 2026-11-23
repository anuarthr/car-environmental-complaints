# Findings

What the release CAR published on 2026-11-10 says about the questions in the README. Every
figure comes from a query in [`transform/analyses/`](../transform/analyses) run against that
release; a new release can change them, so rerun the queries before quoting them:

```bash
cd transform
uv run dbt show --select q1_answer_time --limit 50
```

Time is counted in Colombian business days from the day after filing, as legal terms are
(ADR 0005). "Within the legal term" means answered by the end of the general term of a
petition: 15 business days, or 30 for complaints filed while the pandemic decree was in force.
It is the strictest reading, since the law lets an authority extend the term when it tells the
filer, which the data does not record.

## Before reading the numbers

- **Only answered complaints are published.** Every complaint in the release has a final
  answer date, the latest on 2026-09-08. A complaint still open when CAR extracted the release
  is missing, so the most recent months can look faster than they were. The second half of 2025
  has as many complaints as the second half of 2024 (3,223 and 3,282), so few are missing, but
  its slowest answers may be.
- **198 answers and 30 deadlines are dated before their filing date.** They are left out of the
  measures they would distort.
- **One date per answer.** A partial answer is followed by no second date, so the data cannot
  say whether, or when, a complaint answered partially got a full answer.

## 1. How long does CAR take to answer?

[`q1_answer_time.sql`](../transform/analyses/q1_answer_time.sql), by half-year of filing.

| Filed | Complaints | Median | p90 | Mean | On time, CAR's label | Within the legal term |
|---|---:|---:|---:|---:|---:|---:|
| 2009-H1 | 1,683 | 34 | 306 | 127.4 | 56.5% | 32.4% |
| 2011-H2 | 1,324 | 40.5 | 529 | 143.1 | 79.3% | 36.2% |
| 2015-H1 | 1,953 | 52 | 276 | 101.8 | 78.8% | 30.0% |
| 2017-H2 | 2,176 | 26 | 58 | 31.2 | 88.8% | 43.4% |
| 2019-H1 | 2,236 | 15 | 55 | 27.3 | 91.9% | 54.4% |
| 2020-H2 | 2,188 | 30 | 89 | 45.4 | 90.4% | 53.3% |
| 2021-H2 | 2,137 | 30 | 90 | 45.3 | 89.7% | 55.1% |
| 2022-H2 | 2,609 | 15 | 50 | 26.6 | 88.7% | 51.5% |
| 2024-H1 | 3,024 | 37 | 70 | 35.6 | 87.7% | 34.3% |
| 2025-H1 | 3,064 | 35 | 59 | 33.4 | 88.7% | 35.0% |
| 2025-H2 | 3,223 | 15 | 45 | 21.9 | 93.9% | 57.8% |

Medians and p90 in business days; the query returns all 34 half-years.

- **The slow tail is what changed most.** Until 2015, one complaint in ten took more than 200
  business days, a year or more, and the mean ran at 1.7 to 3.7 times the median. From 2017 the
  p90 stays between 45 and 98 business days.
- **The median follows the legal term.** It sat at 29 to 30 business days while the pandemic
  decree allowed 30, dropped to 15 in the half-year after its repeal, and is 15 again in the
  second half of 2025, which suggests answers are timed by the deadline (see question 3).
- **CAR's label and the law tell different stories.** CAR's label reads above 70% in every
  half-year since 2010 and above 82% since 2017; within the legal term, the share has never
  passed 60%.

## 2. Where does CAR miss the legal term most often?

[`q2_legal_term_by_group.sql`](../transform/analyses/q2_legal_term_by_group.sql). Share of
answers that came after the legal term, for all years and for 2023 to 2025 alone, since a group
with more old complaints would otherwise look worse only because of its age.

| Regional office | Complaints | Missed | Missed, 2023–2025 |
|---|---:|---:|---:|
| Tequendama | 7,576 | 72.1% | 69.9% |
| Rionegro | 4,452 | 68.7% | 66.5% |
| Sumapaz | 7,537 | 68.4% | 62.5% |
| Bajo Magdalena | 4,088 | 67.6% | 64.3% |
| Ubaté | 3,820 | 65.9% | 63.1% |
| Sabana Centro | 8,340 | 61.3% | 63.8% |
| Almeidas y Guatavita | 4,270 | 60.9% | 69.1% |
| Sabana Occidente | 4,655 | 60.6% | 60.6% |
| Soacha | 3,345 | 59.1% | 62.5% |
| Bogotá - La Calera | 5,224 | 56.9% | 53.7% |
| Chiquinquirá | 3,169 | 56.4% | 69.6% |
| Magdalena Centro | 3,643 | 52.2% | 46.6% |
| Gualivá | 8,064 | 45.7% | 48.0% |
| Alto Magdalena | 6,859 | 37.6% | 37.1% |

- **Offices differ by a factor of two.** Alto Magdalena misses about one in three; Tequendama
  more than two in three, in every period.
- **Two offices got worse lately.** Chiquinquirá and Almeidas y Guatavita miss about 70% of
  recent terms, against 56% and 61% over all years.
- **Channel matters more than who files.** Complaints filed in person (67.9% missed), by letter
  (62.2%) or by phone (60.9%) are answered late more often than those filed by email (52.1%).
  People and organizations fare alike (59.9% and 57.1%).
- **Fauna is answered fastest** (44.1% missed), the only resource well below the rest
  (55% to 63%).

## 3. Do partial answers inflate the on-time rate?

[`q3_partial_answers.sql`](../transform/analyses/q3_partial_answers.sql).

| Answer type | Complaints | Share | Median | On time, CAR's label | Within the legal term | On the recorded deadline day |
|---|---:|---:|---:|---:|---:|---:|
| De Fondo (full) | 51,501 | 68.6% | 39 | 80.8% | 31.5% | 12.2% |
| Parcial | 19,731 | 26.3% | 16 | 90.8% | 57.1% | 2.4% |
| Otra | 3,757 | 5.0% | 12 | 93.0% | 83.6% | 9.1% |
| Requerimiento | 53 | 0.1% | 69 | 100.0% | 13.2% | 0.0% |

- **Yes, by about three points.** Partial answers come early and nearly always on time, so they
  lift CAR's label from 80.8% for full answers alone to 84.1% overall.
- **Full answers meet the legal term less than a third of the time** (31.5%).
- **Full answers bunch on the deadline.** 6,262 are dated on the day of the recorded deadline,
  against 3,537 the day before and 1,144 the day after. Those deadlines are the legal term only
  somewhat less often than the rest (29% against 35% to 44% in the days before), so they are
  not mainly deadlines written to match the answer: answers are sent on the last day.

## 4. Do the recorded deadlines match the legal term?

[`q4_recorded_deadlines.sql`](../transform/analyses/q4_recorded_deadlines.sql), by filing year.

| Filed | At 15 business days | At the legal term | At 41–48 | Beyond the legal term | Most common |
|---|---:|---:|---:|---:|---:|
| 2009 | 54.2% | 54.2% | 2.8% | 45.3% | 15 |
| 2013 | 28.5% | 28.5% | 2.5% | 71.1% | 15 |
| 2016 | 21.4% | 21.4% | 25.2% | 78.1% | 15 |
| 2017 | 23.1% | 23.1% | 46.2% | 76.9% | 15 |
| 2019 | 23.5% | 23.5% | 47.3% | 76.1% | 15 |
| 2020 | 5.9% | 31.6% | 7.1% | 67.3% | 30 |
| 2021 | 0.0% | 35.9% | 0.8% | 63.5% | 30 |
| 2023 | 29.0% | 29.0% | 47.5% | 71.0% | 15 |
| 2025 | 41.4% | 41.4% | 32.2% | 58.5% | 15 |

- **Mostly not.** In every year since 2010, most recorded deadlines fall after the legal term.
- **The cluster at 41 to 48 business days grew from 2014 to a quarter of deadlines in 2016**,
  held near half of them in 2017 to 2019 and 2023, and vanished while the pandemic decree set 30 days. Its rule is not in
  the data: it is neither a doubled term (30) nor a count in calendar days or months.
- **CAR applied the pandemic decree**: 30 business days was the most common deadline in 2020
  and 2021, and almost no 2021 deadline was set at 15.
- CAR's on-time label measures against these recorded deadlines, which is why it reads 84%
  while the legal reading gives 41% (52% if every term had been doubled).

## 5. Where are complaints concentrated, and about which resource?

[`q5_place_and_resource.sql`](../transform/analyses/q5_place_and_resource.sql). 63,460
complaints (84.3%) have a municipality; the rest have none recorded or verified.

| Rank | Municipality | Complaints | Share | Running share | Leading resource named |
|---:|---|---:|---:|---:|---|
| 1 | Girardot | 4,112 | 6.5% | 6.5% | fauna (1,891) |
| 2 | Bogotá, D.C. | 3,817 | 6.0% | 12.5% | flora (568) |
| 3 | Fusagasugá | 3,777 | 6.0% | 18.4% | water (628) |
| 4 | Guaduas | 2,770 | 4.4% | 22.8% | flora (630) |
| 5 | La Mesa | 2,299 | 3.6% | 26.4% | fauna (357) |
| 6 | Pacho | 2,266 | 3.6% | 30.0% | water (548) |
| 7 | Soacha | 2,164 | 3.4% | 33.4% | air (336) |
| 8 | Villeta | 1,936 | 3.1% | 36.5% | water (361) |
| 9 | Facatativá | 1,572 | 2.5% | 38.9% | water (388) |
| 10 | Chiquinquirá | 1,524 | 2.4% | 41.3% | water (423) |

"Leading resource named" leaves out themes that name several resources, which lead in eight
of these ten municipalities.

- **Half of the placed complaints come from 15 of 105 municipalities.**
- **By resource**, over all 75,240 complaints: several resources 30,097 (40.0%), water 12,461
  (16.6%), flora 11,474 (15.2%), fauna 5,958 (7.9%), air 5,217 (6.9%), soil 4,662 (6.2%) and
  none named 5,371 (7.1%). Air includes noise and odors, as CAR marks them.
- **Girardot stands apart**: 46% of its complaints concern fauna, and 1,690 of those 1,891 are
  voluntary surrenders of wild animals. No other municipality with 100 complaints or more
  passes 19%.

## 6. Data quality

[`q6_data_quality.sql`](../transform/analyses/q6_data_quality.sql).

| Issue | Complaints | Share |
|---|---:|---:|
| Theme names several resources | 30,097 | 40.0% |
| Health risk not assessed (N.A) | 23,937 | 31.8% |
| Site visit not recorded | 23,486 | 31.2% |
| No municipality recorded or verified | 11,780 | 15.7% |
| Theme names no resource | 5,371 | 7.1% |
| Channel `APLICAR`, a value whose meaning CAR does not document | 1,416 | 1.9% |
| A district of Bogotá in place of the municipality | 544 | 0.7% |
| Answer dated before filing | 198 | 0.3% |
| Deadline dated before filing | 30 | 0.04% |
| Deadline after the release date (complaint 63277, due 2026-12-01) | 1 | 0.001% |

- **Every municipality name falls in Cundinamarca, Boyacá or Bogotá**: 98, 6 and 1, the counts
  CAR gives for its jurisdiction, though not checked name by name against its official list.
  The gap is the 15.7% with no municipality, not names from elsewhere.
- **Resource marks cannot stand in for the theme**: three in four complaints have none marked,
  so the resource comes from the theme (ADR 0006).
- `APLICAR` appears every year from 2017 to 2025, about 200 complaints a year, so it is a
  steady category rather than a typo.

## Open questions for CAR

- What rule sets the recorded deadlines of 41 to 48 business days, and the others beyond the
  legal term?
- Did complaints answered partially get a full answer later, and when?
- What changed in the second half of 2025, when the median answer fell from 35 to 15 business
  days?
- What is the `APLICAR` channel?
