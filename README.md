# ESG Data Backbone — CSRD Pre-Audit Pipeline

## Project Overview

This project simulates a real-world consulting scenario in the context of the **EU Corporate Sustainability Reporting Directive (CSRD)**: an external Data Engineer is given fragmented, uncleaned CSV exports from a client's disconnected corporate systems.

The goal is to turn that "Excel chaos" into a clean, relational, audit-ready **data backbone**, and to surface that data in an interactive **Pre-Audit Dashboard** that shows leadership exactly which facilities are — and are not — ready for a formal CSRD audit.

## Business Problem

Environmental data required for CSRD reporting (Scope 1 / Scope 2 emissions) typically arrives as disconnected exports from multiple facilities, each with its own data entry habits. Before any meaningful emissions analysis is possible, the data has to be:

- Validated against the source system's row counts
- Standardized (text casing, date formats, units)
- De-duplicated
- Checked for missing or invalid values

## Tech Stack

| **Excel** | (Checking Data and first hand cleaning)
| **SQLite** | Data backbone (staging + transformation layer) |
| **DB Browser for SQLite** | CSV import, SQL execution, CSV export |
| **SQL** | Staging, cleaning (CASE/TRIM/COALESCE), JOINs, analytical VIEWs |
| **VS Code** | SQL script authoring, Git version control |
| **Power BI** | Interactive Pre-Audit Dashboard |

## Repository Structure

```
00_original_data_sets/     Raw, untouched CSV exports (facilities, departments, energy records)
01_cleaned_raw_data/       Cleaned CSVs exported from the SQL views
02_sql_scripts/            All .sql scripts — staging, cleaning, joins, KPI views
03_powerbi_dashboard/      .pbix file + exported KPI CSVs + dashboard screenshot
```

## Data Model

Three relationally-linked tables simulate a facility → department → transaction hierarchy:

| `facilities` | Dimension | `facility_code` (PK) | — |
| `departments` | Dimension | `department_id` (PK) | `facility_code` (FK) |
| `energy_emission_records` | Fact (Environmental) | `record_id` (PK) | `facility_code` + `department_id` (FK) |

## Data Cleaning Highlights

The source data was intentionally messy, simulating common real-world ERP export issues:

- **Inconsistent text casing** — `Electricity` / `ELECTRICITY` / `electricity` standardized via `TRIM(UPPER(...))` + `CASE` mapping
- **5 mixed date formats in a single column** (`DD/MM/YYYY`, `YYYY-MM-DD`, `MM-DD-YYYY`, `DD.MM.YYYY`, `DD/MM/YY`) parsed and normalized to ISO 8601 using pattern detection (`LIKE`) + string manipulation (`substr`, `printf`)
- **Real NULLs *and* "fake-null" text** (`N/A`, `-`, `unknown`) — required dual detection logic, since `COALESCE` alone doesn't catch string placeholders
- **Negative / erroneous meter readings** — flagged as invalid and nulled (not deleted), preserving the row's other context for the audit trail
- **~0.5% exact duplicate records** — removed via `GROUP BY` on business-key columns rather than the surrogate `record_id`, since ERP systems typically re-export the same transaction under a new ID

## Dashboard KPIs

The Power BI dashboard answers four audit-readiness questions:

1. **Total CO₂ Emissions** (Scope 1 + Scope 2)
2. **Emissions by Facility & Scope** — where is the emissions footprint concentrated?
3. **Monthly Emission Trend** — is consumption rising or falling over time?
4. **Data Quality / Audit-Readiness Score** — % of missing consumption data per facility, the single most important pre-audit signal

## Author

**Andaç Bertuğ Şimşek**
Data Analyst in training | ESG / CSRD Data Engineering
[https://www.linkedin.com/in/bertu%C4%9F-%C5%9Fim%C5%9Fek-5a1489242/] · [https://github.com/Bertug-Simsek]
