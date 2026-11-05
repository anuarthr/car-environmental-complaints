# CAR Environmental Complaints

End-to-end ELT pipeline and analysis of the **68,948 environmental complaints** filed with the
Corporación Autónoma Regional de Cundinamarca (CAR), Colombia, between 2009 and 2024.

> Work in progress. The project is being built in public, one milestone at a time.

## Questions this project answers

1. How long does CAR take to answer a complaint, and how has that changed since 2009?
2. Where does it miss the legal deadline most often: by regional office, channel, theme or type of filer?
3. Do partial answers inflate the on-time rate?
4. Do the recorded deadlines match the legal term of 15 business days?
5. Where are complaints concentrated, and which natural resource do they concern?

## Stack

| Layer | Tool |
|---|---|
| Extract and load | [dlt](https://dlthub.com/) from the Socrata API of datos.gov.co |
| Warehouse | Google BigQuery |
| Transform and test | dbt |
| Orchestration and CI | GitHub Actions |
| Dashboard | Looker Studio |

## Data source and license

- **Quejas Ambientales CAR Cundinamarca**, published by CAR on
  [datos.gov.co](https://www.datos.gov.co/d/5ddb-j9e9) under
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The source is anonymized.
- **DIVIPOLA municipality codes**, published by DANE on
  [datos.gov.co](https://www.datos.gov.co/d/gdxc-w37w).

Derived datasets are shared under the same CC BY-SA 4.0 license. The code is under the
[MIT license](LICENSE).
