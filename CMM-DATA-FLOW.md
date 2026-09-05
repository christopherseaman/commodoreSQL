---
notion-id: 3ced9fdd-1a1a-81ae-9e11-cf36cf96e96e
notion-url: https://app.notion.com/p/CMM-Data-Flow-3ced9fdd1a1a81ae9e11cf36cf96e96e
notion-sync: push
---

# Data flow

```mermaid
flowchart LR
    subgraph sources["Sources"]
        direction TB
        catalog("course_catalog_20251215<br/>(DiscoveryExtract.20251215.csv)")
        pricing_historical("pricing_historical<br/>(BookPricing.Historical_20260224.csv)")
        ipeds("ipeds_data<br/>(IPEDS_2024.csv)")
        optout("opt_out<br/>(OptOut_20251215.csv)")
        panel_email("panel_email<br/>(panel_20260108.csv)")
        subgraph lookup_sources["Lookups"]
            direction TB
            format_lookup("format_type_classification<br/>(format_type_lookup.tsv)")
            supply_rules["supply_keywords.tsv"]
            region_lookup("state_region<br/>(0b_state_region.sql)")
        end
        subgraph expected_sources["Pending"]
            direction TB
            cmm_discipline_source["CMM Discipline"]
            cmm_ia_source["CMM IA"]
            external_pricing_source["CMM external pricing"]
            brand_source["Bookstore-brand lookup"]
            sample_unit_25id["sample_unit_25id<br/>(25 institution list)"]
        end
    end

    subgraph helpers["Helpers"]
        direction TB
        supply("supply_isbn_classification")
        section_enrollment("section_enrollment")
        recent_period{{"recent_period"}}
    end

    subgraph catalog_flow["Materials"]
        direction TB
        comprehensive("comprehensive_data")
        course_material("course_material")
        materials_recent{{"course_material_recent"}}
        materials_use{{"course_material_use"}}
        materials_nouse{{"course_material_no_use"}}
    end

    subgraph pricing_flow["Pricing"]
        direction TB
        pricing_wide("pricing_wide")
    end

    subgraph release["Release"]
        direction TB
        master_material("master_material")
        master_section("master_section")
        master_course{{"master_course"}}
        master_institution("master_institution")
        master_isbn("master_isbn")
        current_mailing{{"current_mailing"}}
    end

    subgraph samples["Samples"]
        direction TB
        fall_scope{{"sample_section_us_intro_fall2025"}}
        sample10_materials("sample_material_10pct")
        sample25_material("sample_material_25id")
        sample25_section("sample_section_25id")
    end

    subgraph mailing["Mailing"]
        direction TB
        master_mailing("master_mailing")
    end

    catalog --> supply
    supply_rules --> supply
    recent_period --> supply
    catalog --> section_enrollment
    recent_period --> section_enrollment
    catalog --> comprehensive
    ipeds --> comprehensive
    optout --> comprehensive
    panel_email --> comprehensive
    format_lookup --> comprehensive
    supply --> comprehensive
    section_enrollment --> comprehensive
    recent_period --> comprehensive

    comprehensive --> course_material
    course_material --> materials_recent
    recent_period --> materials_recent

    materials_recent --> materials_use
    materials_recent --> materials_nouse

    pricing_historical --> pricing_wide
    materials_use --> master_material
    pricing_wide --> master_material
    master_material --> master_section
    master_section -.-> master_course
    master_section -.-> master_institution
    master_material --> master_isbn
    master_material --> sample10_materials
    master_section --> fall_scope

    catalog --> master_mailing
    catalog --> recent_period
    master_mailing --> current_mailing
    recent_period --> current_mailing
    panel_email --> current_mailing
    optout --> current_mailing

    cmm_discipline_source -.-> comprehensive
    cmm_ia_source -.-> comprehensive
    external_pricing_source -.-> pricing_wide
    brand_source -.-> pricing_wide
    sample_unit_25id -.-> sample25_material
    sample_unit_25id -.-> sample25_section
    master_material -.-> sample25_material
    master_section -.-> sample25_section

    classDef imported fill:#d9ead3,stroke:#38761d,stroke-width:2px,color:#274e13;
    classDef expected fill:#f3f3f3,stroke:#777,stroke-width:2px,stroke-dasharray:6 4,color:#444;
    class catalog,pricing_historical,ipeds,optout,panel_email,format_lookup,supply_rules,region_lookup imported;
    class cmm_discipline_source,cmm_ia_source,external_pricing_source,brand_source,sample_unit_25id,sample25_material,sample25_section,master_course,master_institution expected;
    style expected_sources fill:#fafafa,stroke:#777,stroke-width:2px,stroke-dasharray:8 4
```

## Exports

```mermaid
flowchart TB
    subgraph course_exports["Materials"]
        direction LR
        course_material("course_material")
        materials_recent{{"course_material_recent"}}
        materials_use{{"course_material_use"}}
        materials_nouse{{"course_material_no_use"}}
        course_file["course_material[_&lt;YYYY_N&gt;]_&lt;YYYYMMDD&gt;.csv"]
        recent_file["course_material_recent[_&lt;YYYY_N&gt;]_&lt;YYYYMMDD&gt;.csv"]
        use_file["course_material_use_recent[_&lt;YYYY_N&gt;]_&lt;YYYYMMDD&gt;.csv"]
        nouse_file["course_material_no_use_recent[_&lt;YYYY_N&gt;]_&lt;YYYYMMDD&gt;.csv"]
        canada_file["course_material_can_recent[_&lt;YYYY_N&gt;]_&lt;YYYYMMDD&gt;.csv"]
        course_material --> course_file
        materials_recent --> recent_file
        materials_use --> use_file
        materials_nouse --> nouse_file
        materials_nouse -->|is_canada| canada_file
    end

    subgraph release_exports["Release"]
        direction LR
        master_material("master_material")
        master_section("master_section")
        master_course{{"master_course"}}
        master_institution("master_institution")
        master_isbn("master_isbn")
        cost_files["40_master_material_by_term.csv<br/>master_material_&lt;YYYY_N&gt;_&lt;YYYYMMDD&gt;.csv"]
        section_files["31_master_section.csv<br/>master_section_&lt;YYYY_N&gt;_&lt;YYYYMMDD&gt;.csv"]
        institution_files["35_master_institution_by_term.csv<br/>master_institution_&lt;YYYY_N&gt;_&lt;YYYYMMDD&gt;.csv"]
        isbn_files["36_master_isbn_by_term.csv<br/>master_isbn_&lt;YYYY_N&gt;_&lt;YYYYMMDD&gt;.csv"]
        course_files["32_master_course.csv"]
        master_material --> cost_files
        master_section --> section_files
        master_institution -.-> institution_files
        master_course -.-> course_files
        master_isbn --> isbn_files
    end

    subgraph mailing_exports["Mailing"]
        direction LR
        master_mailing("master_mailing")
        current_mailing{{"current_mailing"}}
        master_file["10_master_mailing.csv"]
        mailing_files["11_current_mailing.csv<br/>11_recent_mailing.csv"]
        geography_files["20_california_mailing.csv<br/>21_texas_mailing.csv<br/>22_florida_mailing.csv<br/>23_newyork_mailing.csv<br/>24_texas_fall_series.csv<br/>25_pennsylvania_mailing.csv<br/>26_canada_mailing.csv<br/>27_other_mailing.csv"]
        master_mailing --> master_file
        current_mailing --> mailing_files
        current_mailing --> geography_files
    end

    subgraph analysis_exports["Analysis"]
        direction LR
        comprehensive("comprehensive_data")
        master_section_analysis("master_section")
        sample10_materials("sample_material_10pct")
        random_file["01_sample_records.csv"]
        faculty_file["30_faculty_records.csv"]
        sample_file["34_sample_material_10pct.csv<br/>sample_material_10pct.parquet"]
        subset_files["fall2025_setA_required.parquet<br/>fall2025_setB_no_required.parquet"]
        comprehensive --> random_file
        comprehensive --> faculty_file
        sample10_materials --> sample_file
        master_section_analysis --> subset_files
    end

    subgraph pending_sample_exports["Pending 25-institution samples"]
        direction LR
        sample_unit_25id["sample_unit_25id<br/>(25 institution list)"]
        sample25_material("sample_material_25id")
        sample25_section("sample_section_25id")
        sample25_material_file["sample_material_25id.csv"]
        sample25_section_file["sample_section_25id.csv"]
        master_material -.-> sample25_material
        sample_unit_25id -.-> sample25_material
        sample_unit_25id -.-> sample25_section
        master_section -.-> sample25_section
        sample25_section -.-> sample25_section_file
        sample25_material -.-> sample25_material_file
    end

    classDef file fill:#fff2cc,stroke:#9c7227,color:#222;
    class course_file,recent_file,use_file,nouse_file,canada_file,cost_files,section_files,course_files,institution_files,isbn_files,master_file,mailing_files,geography_files,random_file,faculty_file,sample_file,subset_files file;
    classDef expected fill:#f3f3f3,stroke:#777,stroke-width:2px,stroke-dasharray:6 4,color:#444;
    class sample_unit_25id,sample25_material,sample25_section,sample25_material_file,sample25_section_file,master_course,master_institution,course_files,institution_files expected;
```

`YYYY_N` is the term; `YYYYMMDD` is the export date. Brackets mark an optional term suffix.

## Table logic

Arrows above identify inputs. “Section” includes term; grain means one row per key.

| Table / view | Grain | Logic / filter |
|---|---|---|
| `course_catalog_20251215` | Source row | Normalize fields; derive course, section, term IDs. |
| `ipeds_data` | Institution | Import institution attributes. |
| `opt_out` | Source row | Normalize email; retain duplicates. |
| `panel_email` | Email | Import history; latest response year; duplicate/year-variant counts. |
| `format_type_classification` | FormatType | Map OER/IA. |
| `state_region` | State/province | Map reporting region; query-time only. |
| `supply_isbn_classification` | ISBN | Apply CMM-owned title rules to recent-term ISBNs. |
| `section_enrollment` | Section | Catalog-only enrollment, seats, and sibling availability. |
| `comprehensive_data` | Source row | Add lookups, IPEDS-scoped enrollment assignment, requiredness, population flags. |
| `course_material` | Section × ISBN | Deduplicate; retain conflicts, section audit counts, NULL-ISBN groups. |
| `course_material_recent` | Section × ISBN | Shared recent-term export/report boundary. |
| `course_material_use` | Section × ISBN | Use filter below. |
| `course_material_no_use` | Section × ISBN | Remaining recent-term rows. |
| `pricing_historical` | Section × ISBN × option × condition × format × rental term | Remove exact/instructor-only duplicates; latest dated offer. |
| `pricing_wide` | Section × ISBN | Pivot offers; no catalog enrichment. |
| `master_material` | Use section × ISBN | Exact LEFT join; retain unmatched/unpriced items. |
| `master_section` | Material-bearing section | Roll up `master_material`; inherit audits; select modal bookstore URL. |
| `master_course` | Course × term | Draft section/cost rollup; definition pending. |
| `master_institution` | Institution × term | Draft section rollup and modal section URL; definition pending. |
| `master_isbn` | ISBN × term | Roll up material rows. |
| `sample_material_10pct` | Section × ISBN | Selected section clusters from `master_material`. |
| `sample_section_us_intro_fall2025` | Section | Fall 2025; required-bearing; introductory/intermediate; nonblank, non-Canada state. |
| `master_mailing` | Email | Nonblank; newest term, largest enrollment, stable tie-breakers. |
| `recent_period` | Term | Lookup view of newest 12 terms from `course_catalog_20251215`. |
| `current_mailing` | Email | Recent terms; add history; exclude opt-outs. |

The supply TSV contains 123 title rules, not ISBN assignments. Catalog titles are
needed to build `supply_isbn_classification`. Section requiredness is computed inside
`comprehensive_data`; it is independent of the enrollment helper.

### Use filter

Recent terms, non-Canada, ISBN present; exclude supplies, `*No Book Details*`,
`*No Books Required*`, and other no-material placeholders. Any qualifying source row admits
the key; conflicts remain recorded. Older terms stay upstream. Exclusion reasons may overlap.

Materials and mailing share `recent_period`: the newest 12 distinct catalog terms,
including pre-2024 terms while they remain in that window.

### Reading results

- `section_enrollment` includes sections without materials; `master_section` does not.
- Exact section × ISBN matching only; no normalization or broader-key fallback.
- Match ≠ valid price. NULL price/cost ≠ zero.
- `price_avg = (price_min + price_max) / 2`, not mean offer price.
- Enrollment-weighted results must report `enrollment_source`.
- Section audit values repeat on material rows; never sum those copies.
- URL selection ignores blank values; most frequent wins, lexical tie-break.

## Metabase

| Reports | Tables / views |
|---|---|
| Release | `master_material`, `master_section`, `master_course`, `master_institution`, `master_isbn`, `current_mailing` |
| Samples | `sample_material_10pct`, `sample_section_us_intro_fall2025` |
| Populations | `course_material` and its routing views; `section_enrollment` |

Geographic reports join `state_region` at query time.

## Pending

| Item | Boundary |
|---|---|
| `master_course`, `master_institution` | Dashed: draft SQL exists; final definitions pending (#87). |
| CMM Discipline | Department mapping; keys/normalization await lookup. |
| CMM IA | Campus availability, distinct from FormatType IA; grain/dates/precedence unresolved. |
| CMM external pricing | Feed the pricing-wide stage; fields/grain await source. |
| Bookstore-brand lookup | Enrich `pricing_wide`; key and file scope await lookup. |
| 25 institution list | `sample_unit_25id` feeds `sample_material_25id` and `sample_section_25id`; #60. |
Refreshes reuse existing source boxes. Missing arrows mean destination undecided.
“Keep History” is a pending retention decision, not a source.

The diagram describes staged SQL, not the live database. Deployment is held.
Combining `comprehensive_data` and `course_material` remains implementation work (#86),
not an unresolved requirement.
