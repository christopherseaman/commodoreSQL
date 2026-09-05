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

## Sources

- `course_catalog_20251215`: BMG source rows; normalize fields/email and derive course, section, and term IDs. Keep duplicate/contact rows.
- `pricing_historical`: BMG bookstore observations; normalization and deduplication below.
- `ipeds_data`: institution attributes, joined by UNITID.
- `opt_out`: BVA exclusions, matched by cleaned email.
- `panel_email`: BVA history grouped by cleaned email; latest response year and source/variant counts.

### Lookups

`format_type_classification` maps FormatType to OER/IA. `supply_keywords.tsv` contains title
rules, not ISBN assignments. `state_region` maps catalog state codes to reporting regions at query time.

### Pending inputs

| Source | Intended destination |
|---|---|
| CMM Discipline | Department mapping in `comprehensive_data`; keys pending (#52). |
| CMM IA | Campus availability in `comprehensive_data`; distinct from FormatType IA; rules pending (#57). |
| CMM external pricing | `pricing_wide`; fields/grain pending (#23). |
| Bookstore-brand lookup | `pricing_wide`; key/scope pending (#72). |
| 25 institution list | Imported `sample_unit_25id`; sample outputs below (#60). |

Source refreshes reuse existing boxes. History retention is a separate pending decision (#76).

## Logic

### Materials

1. `recent_period` selects the newest 12 distinct non-NULL catalog terms. Materials and mailing share this window; older terms remain upstream.
2. `supply_isbn_classification` applies the title rules to recent catalog ISBN/title variants, producing one classified row per ISBN.
3. `section_enrollment` groups recent catalog sections, including those without materials. It takes maximum reported enrollment/seats and finds sibling availability; no IPEDS or supply dependency.
4. `comprehensive_data` enriches every source row with lookups, institution/contact history, section enrollment, and classification flags. Contact history does not filter materials.
5. `course_material` groups by term × section × ISBN. Require non-NULL term/section; retain `UNKNOWN` ID components and one NULL-ISBN group per section when present. Keep source counts and metadata/contact conflicts; choose a deterministic representative. Both tables remain: source-row and item grain serve different reports.

Enrollment assignment happens in `comprehensive_data`: own enrollment → own usable seats
(`<9999`) → course/term medians (enrollment, then seats) → control/level/term median →
level/term median → NULL. Reference medians use intro/intermediate/non-degree/uncategorized
courses at public, nonprofit, or for-profit two-/four-year institutions.
Carry `enrollment_assigned` and `enrollment_source` downstream.

`is_required_direct` means literal required, non-supply evidence. Within recent terms,
`is_required_inferred` selects required rows when their section has direct evidence;
otherwise it selects NULL-status rows. Item booleans combine source evidence with `BOOL_OR`;
conflict flags record disagreement.

`course_material_recent` applies the shared window. `course_material_use` keeps keys with
any source row that is non-Canada, ISBN-present, non-supply, and not `*No Book Details*`,
`*No Books Required*`, or supply category `placeholder_no_material`.
`course_material_no_use` is the remaining recent-term population. Exclusions
may overlap; both routing flags are false outside the window.

### Pricing

`pricing_historical` removes exact duplicates, combines instructor-only variants, then
keeps the latest observation per section × ISBN × option × condition × format × rental term.
It retains source status and identifiers; catalog-derived classifications do not feed back.

`pricing_wide` pivots to one section × ISBN row. Prices `>=9999` become NULL; each of the
18 offer cells uses `MAX(price)`. Preserve rental-term bounds, offered-format counts,
buy/rent availability, and bookstore URL. `price_avg = (price_min + price_max) / 2`, not mean offer price.

### Mailing

`master_mailing` selects one raw catalog row per nonblank email: newest term, largest
enrollment, then stable tie-breakers. It keeps separate co-instructor emails, independently
of material deduplication. `current_mailing` restricts those contacts to `recent_period`,
adds `panel_email` history, and excludes any matching `opt_out` email.

### Release

- `master_material`: LEFT-enrich every Use item from `pricing_wide` by exact section × ISBN; retain unmatched/unpriced items. [Encoding mismatch remains unresolved](PRICING-CATALOG-MATCHING.md).
- `master_section`: group `master_material` by section; count materials/classifications and sum per-item price bounds, split by inferred required/optional and all-offer/buy-only cost. NULL price/cost is not zero. Inherit enrollment and section audit values once, never sum their repeated copies.
- `master_isbn`: group `master_material` by term × ISBN; summarize adoptions, institutions, enrollment, metadata conflicts, and price-cell availability.
- Dashed `master_course`, `master_institution`: executable provisional section rollups by term × course/institution; final definitions remain pending (#87).

Section bookstore URL is the most frequent nonblank item URL; institution URL is the
most frequent section URL. Ties resolve lexically; NULL-institution URLs remain NULL.

## Samples & exports

| Sample | Selection |
|---|---|
| `sample_material_10pct` | Direct `master_material` sample: first 64 MD5 bits of section ID modulo 10 = 0; keep whole sections. |
| `sample_section_us_intro_fall2025` | `master_section`: Fall 2025, required-bearing, intro/intermediate, nonblank non-Canada state. |
| `sample_material_25id`, `sample_section_25id` | Pending: filter masters by imported `sample_unit_25id`. |

### Files

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
        materials_nouse --> canada_file
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

Canada files filter NoUse by `is_canada`. Geographic mailing files directly filter
`current_mailing`; NULL/blank/other states go to Other. The Texas Fall-series file is
a separate subset, not another partition. The 10% sample is not the random 10,000-row
`01_sample_records` export. Draft master exports remain executable; dashed 25-institution
outputs do not exist yet.

### Reports

| Reports | Tables / views |
|---|---|
| Release | `master_material`, `master_section`, `master_course`, `master_institution`, `master_isbn`, `current_mailing` |
| Samples | `sample_material_10pct`, `sample_section_us_intro_fall2025` |
| Populations | `course_material` and its routing views; `section_enrollment` |
| Source-row lineage/diagnostics | `comprehensive_data`, raw catalog, `pricing_historical`, DQ snapshots |

Geographic reports join `state_region` at query time.

The diagram describes staged SQL, not the live database. Deployment is held.
