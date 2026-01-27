# OER and IA Identification from FormatType

## Discovery: FormatType Column Contains Explicit OER and IA Labels

**Date:** 2026-01-20 (OER), 2026-01-21 (IA)
**Source:** `DiscoveryExtract.20251215.csv` - `FormatType` column

## Key Finding

Both OER (Open Educational Resources) and IA (Inclusive Access) materials are **explicitly labeled** in the `FormatType` column, not derived from publisher names or heuristics.

### FormatType Values Containing OER:

```
Open Educational Resource
Book/ Open Educational Resource
eBook/ Open Educational Resource
Digital/ Open Educational Resource
Bundle/ Open Educational Resource
Courseware/ Homework/ Open Educational Resource/ Subscription
Loose Leaf/ Open Educational Resource
Courseware/ Open Educational Resource
... and more
```

### FormatType Values Containing Inclusive Access:

```
Digital/ Inclusive Access/ Subscription
Bundle/ Inclusive Access
Inclusive Access
Book/ Inclusive Access
Courseware/ Inclusive Access
eBook/ Inclusive Access/ Subscription
eBook/ Inclusive Access
Inclusive Access/ Loose Leaf
Inclusive Access/ Subscription
Courseware/ Digital/ Inclusive Access
... and more
```

## Identification Method

### OER - Correct Method (FormatType-based):

```sql
SELECT *
FROM course_catalog_20251215
WHERE FormatType LIKE '%Open Educational Resource%';
```

**Result:** 354,809 OER records (0.34% of total records)

### IA - Correct Method (FormatType-based):

```sql
SELECT *
FROM course_catalog_20251215
WHERE FormatType LIKE '%Inclusive Access%';
```

**Result:** 956,868 IA records (0.93% of total records)

### Incorrect Method (Publisher-based):

```sql
-- DO NOT USE: Inaccurate
SELECT *
FROM course_catalog_20251215
WHERE Publisher IN ('OER', 'OpenStax', 'OpenIntro/ Inc.', 'OpenIntro', 'OERCommons');
```

**Result:** 89,311 records (only 25% of actual OER)

## Statistics (2025.12.15 Data)

### OER Statistics - Total: 354,809 (0.34%)

| Format Type | Count | Percentage of OER |
|------------|--------|------------|
| Book/ Open Educational Resource | 248,698 | 70.1% |
| Open Educational Resource (pure) | 38,917 | 11.0% |
| eBook/ Open Educational Resource | 16,303 | 4.6% |
| Digital/ Open Educational Resource | 15,199 | 4.3% |
| Bundle/ Open Educational Resource | 14,539 | 4.1% |
| Courseware OER (various) | 11,605 | 3.3% |
| Loose Leaf/ Open Educational Resource | 8,190 | 2.3% |
| Other OER combinations | 1,358 | 0.4% |

### IA Statistics - Total: 956,868 (0.93%)

| Format Type | Count | Percentage of IA |
|------------|--------|------------|
| Digital/ Inclusive Access/ Subscription | 822,058 | 85.9% |
| Bundle/ Inclusive Access | 46,637 | 4.9% |
| Inclusive Access (pure) | 21,084 | 2.2% |
| Book/ Inclusive Access | 14,484 | 1.5% |
| Courseware/ Inclusive Access | 12,778 | 1.3% |
| eBook/ Inclusive Access (various) | 20,514 | 2.1% |
| Inclusive Access/ Loose Leaf | 6,319 | 0.7% |
| Other IA combinations | 12,994 | 1.4% |

## Categories in Database

### OER Categories

The `oer_category` field categorizes OER by primary format:

- `book_oer` - Physical books labeled as OER
- `ebook_oer` - Electronic books labeled as OER
- `digital_oer` - Digital materials (may include courseware, videos, etc.)
- `courseware_oer` - Interactive courseware/learning platforms
- `bundle_oer` - Bundled materials (multiple formats)
- `homework_oer` - Homework platforms/systems
- `loose_leaf_oer` - Unbound printed materials
- `pure_oer` - Simply labeled "Open Educational Resource"
- `other_oer` - Other OER combinations
- `non_oer` - Not OER

### IA Categories

The `ia_category` field categorizes IA by primary format:

- `digital_ia` - Digital materials with Inclusive Access
- `bundle_ia` - Bundled materials with Inclusive Access
- `pure_ia` - Simply labeled "Inclusive Access"
- `book_ia` - Physical books with Inclusive Access
- `courseware_ia` - Courseware with Inclusive Access
- `ebook_ia` - Electronic books with Inclusive Access
- `loose_leaf_ia` - Loose leaf materials with Inclusive Access
- `subscription_ia` - Subscription-based Inclusive Access
- `homework_ia` - Homework systems with Inclusive Access
- `other_ia` - Other IA combinations
- `non_ia` - Not Inclusive Access

## Implementation

### Lookup Table Approach

**File:** `data/2025.12.15/format_type_lookup.tsv`

Classification uses a **lookup table** (69 unique FormatType values) rather than hardcoded LIKE patterns:

```tsv
format_type	is_oer	oer_category	is_ia	ia_category
Book/ Open Educational Resource	true	book_oer	false	non_ia
Digital/ Inclusive Access/ Subscription	false	non_oer	true	digital_ia
Bundle/ Inclusive Access/ Open Educational Resource	true	bundle_oer	true	bundle_ia
```

**Benefits:**
- Easy to update classifications without SQL changes
- Version controlled alongside data
- Clear audit trail of classification logic
- Handles edge cases (2 formats are both OER and IA)

### Database Fields

#### OER Fields: `is_oer` and `oer_category`
- Joined from `format_type_classification` table via FormatType
- Defaults to `false` and `'non_oer'` for NULL/missing values

#### IA Fields: `is_ia` and `ia_category`
- Joined from `format_type_classification` table via FormatType
- Defaults to `false` and `'non_ia'` for NULL/missing values

### Tables Using OER/IA Classification:

1. **`format_type_classification`** - Lookup table (69 rows) mapping FormatType to OER and IA status
2. **`comprehensive_data`** - Main table with `is_oer`, `oer_category`, `is_ia`, and `ia_category` fields
3. **`master_section`** - (Future) Section-level OER/IA metrics
4. **`master_course`** - (Future) Course-level OER/IA adoption metrics

### OER + IA Overlap

**2 FormatType values** are classified as BOTH OER and IA:
- `Bundle/ Inclusive Access/ Open Educational Resource`
- `Courseware/ Inclusive Access/ Open Educational Resource`

## Why This Matters

### Accuracy:
- ✅ **354,809 OER records** identified (FormatType method)
- ❌ **89,311 records** found (Publisher guessing method)
- **4x more accurate** than publisher-based heuristics
- ✅ **956,868 IA records** identified (FormatType method)
- Cannot derive IA from publisher data at all

### Data Quality:
- Explicit labels from source system (not guessed)
- Captures all OER/IA regardless of publisher
- Includes institutional materials (not just major publishers)

### Analysis Implications:

**OER:**
- Adoption rate: 0.34% of course materials
- Most common format: Physical books (70% of OER)
- Growing digital/courseware OER presence (11% combined)

**Inclusive Access:**
- Adoption rate: 0.93% of course materials (nearly 3x OER)
- Heavily digital-focused: 86% are Digital/Subscription format
- Modern distribution model gaining traction
- Often combined with subscriptions (85.9%)

## Historical Note

**Initial Approach (Incorrect):**
- Attempted to derive OER from `Publisher` field
- Used pattern matching: "OpenStax", "OER", "OpenIntro", etc.
- Only captured 25% of actual OER materials
- Missed all OER from traditional publishers (Pearson, Cengage, etc.)

**Corrected Approach:**
- Use explicit `FormatType` field labels
- Simple `LIKE '%Open Educational Resource%'` check
- Captures all OER regardless of publisher
- Aligns with source system's OER definition

## References

- Source Data: `data/2025.12.15/2025_12/DiscoveryExtract.20251215.csv`
- Lookup Table: `data/2025.12.15/format_type_lookup.tsv` (69 unique FormatTypes)
- Import Script: `scripts/sql/0_setup.sql`
- OER/IA Classification: `scripts/sql/2_oer_classification.sql`
- Implementation Date: 2026-01-20 (OER), 2026-01-21 (IA + lookup table)

## Future Enhancements

1. Add OER/IA metrics to `master_section` view (per-section usage)
2. Add OER/IA metrics to `master_course` view (per-course adoption)
3. Track OER/IA adoption trends over time (by period)
4. Analyze OER/IA usage by institution type/size
5. Compare OER vs. IA vs. traditional material costs (if pricing data available)
6. Analyze overlap between OER and IA (some materials are both)
