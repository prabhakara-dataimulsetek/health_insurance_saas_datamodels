# NPPES NPI Data Model — Technical Reference

## Overview

This package contains the complete data model, DDL scripts, taxonomy reference data, and ERD diagram for loading and querying the **National Plan & Provider Enumeration System (NPPES)** NPI dataset.

The NPPES registry is maintained by CMS and contains over 8 million active healthcare provider records. This data model normalizes the raw flat-file format into a relational schema with full taxonomy mapping to human-readable specialty labels.

---

## Files in This Package

| File | Description |
|---|---|
| `nppes_ddl_updated.sql` | **Primary DDL** — full schema with taxonomy lookup, FK constraints, indexes, 4 views |
| `nppes_ddl_original.sql` | Original DDL without taxonomy mapping (reference only) |
| `nucc_taxonomy_250.csv` | NUCC Health Care Provider Taxonomy v25.0 — 879 codes (source: nucc.org) |
| `nppes_erd_diagram.html` | Interactive ERD diagram — open in browser |
| `README.md` | This file |

---

## Data Sources

| NPPES Flat File | Tables Populated |
|---|---|
| `npidata_pfile` | `provider`, `mailing_address`, `practice_location`, `taxonomy`, `other_identifier`, `authorized_official` |
| `pl_pfile` | `secondary_practice_location` |
| `othername_pfile` | `other_name` |
| `endpoint_pfile` | `endpoint` |

Download the latest NPPES data files from:
**https://download.cms.gov/nppes/NPI_Files.html**

---

## NPI Registry API

The CMS NPI Registry API provides real-time provider lookup. No API key required.

**Demo / Docs:** https://npiregistry.cms.hhs.gov/demo-api
**Base URL:** `https://npiregistry.cms.hhs.gov/api/`
**Version:** `2.1` (current)

### Parameters

| Parameter | Description | Example |
|---|---|---|
| `version` | Always use `2.1` | `2.1` |
| `number` | 10-digit NPI | `1234567893` |
| `enumeration_type` | `NPI-1` (individual) or `NPI-2` (organization) | `NPI-1` |
| `taxonomy_description` | Specialty keyword | `Cardiology` |
| `first_name` | Provider first name (append `*` for wildcard) | `John*` |
| `last_name` | Provider last name | `Smith` |
| `organization_name` | Organization name | `Mayo Clinic` |
| `city` | City | `Los Angeles` |
| `state` | 2-letter state code | `CA` |
| `postal_code` | ZIP (5 or 9 digit) | `90210` |
| `limit` | Results per page (max 200, default 10) | `50` |
| `skip` | Pagination offset | `0` |
| `pretty` | Pretty-print JSON | `true` |

### Example API Calls

**Look up by NPI:**
```
GET https://npiregistry.cms.hhs.gov/api/?version=2.1&number=1234567893&pretty=true
```

**Find cardiologists in California:**
```
GET https://npiregistry.cms.hhs.gov/api/?version=2.1&enumeration_type=NPI-1&taxonomy_description=Cardiology&state=CA&limit=50&pretty=true
```

**Find hospitals in Texas:**
```
GET https://npiregistry.cms.hhs.gov/api/?version=2.1&enumeration_type=NPI-2&taxonomy_description=Hospital&state=TX&limit=50&pretty=true
```

**Search by name:**
```
GET https://npiregistry.cms.hhs.gov/api/?version=2.1&first_name=John&last_name=Smith&state=NY&pretty=true
```

### Response Structure

```json
{
  "result_count": 1,
  "results": [
    {
      "number": "1234567893",
      "enumeration_type": "NPI-1",
      "basic": {
        "first_name": "JOHN",
        "last_name": "SMITH",
        "credential": "MD",
        "gender": "M",
        "enumeration_date": "2005-11-07",
        "last_updated": "2023-03-04",
        "status": "A"
      },
      "addresses": [
        {
          "address_1": "123 MAIN ST",
          "city": "LOS ANGELES",
          "state": "CA",
          "postal_code": "900101234",
          "telephone_number": "310-555-1234",
          "address_purpose": "LOCATION"
        }
      ],
      "taxonomies": [
        {
          "code": "207RC0000X",
          "desc": "Cardiovascular Disease Physician",
          "primary": true,
          "state": "CA",
          "license": "A12345"
        }
      ],
      "identifiers": [],
      "endpoints": []
    }
  ]
}
```

### API Notes

- No authentication required — publicly accessible
- Rate limit: CMS recommends no more than 20 requests/second
- Max 200 results per request; use `skip` for pagination
- Append `*` to name fields for partial/wildcard matching
- `taxonomies[].desc` in the API = `taxonomy_lookup.display_name` in local schema
- `basic.status = "A"` means Active

### Python Helper

```python
import requests

def lookup_npi(npi: str) -> dict:
    resp = requests.get(
        "https://npiregistry.cms.hhs.gov/api/",
        params={"version": "2.1", "number": npi, "pretty": "true"}
    )
    data = resp.json()
    if data["result_count"] == 0:
        return None
    r = data["results"][0]
    taxonomy = next((t for t in r["taxonomies"] if t["primary"]), {})
    location = next((a for a in r["addresses"] if a["address_purpose"] == "LOCATION"), {})
    return {
        "npi":           r["number"],
        "name":          f"{r['basic'].get('first_name','')} {r['basic'].get('last_name', r['basic'].get('organization_name',''))}".strip(),
        "credential":    r["basic"].get("credential"),
        "specialty":     taxonomy.get("desc"),       # human-readable
        "taxonomy_code": taxonomy.get("code"),
        "status":        r["basic"].get("status"),   # A=Active
        "city":          location.get("city"),
        "state":         location.get("state"),
        "phone":         location.get("telephone_number"),
    }

def search_providers(taxonomy_desc: str, state: str, limit: int = 50) -> list:
    resp = requests.get(
        "https://npiregistry.cms.hhs.gov/api/",
        params={
            "version":              "2.1",
            "enumeration_type":     "NPI-1",
            "taxonomy_description": taxonomy_desc,
            "state":                state,
            "limit":                limit,
        }
    )
    return resp.json().get("results", [])
```

---

## NUCC Health Care Provider Taxonomy

The **National Uniform Claim Committee (NUCC)** maintains the taxonomy code set that maps 10-character codes to human-readable specialty labels.

**CSV Downloads:** https://www.nucc.org/index.php/code-sets-mainmenu-41/provider-taxonomy-mainmenu-40/csv-mainmenu-57

### Release Schedule

NUCC releases taxonomy updates **twice per year**:

| Release Type | Effective Date |
|---|---|
| `.0` versions | January 1 |
| `.1` versions | July 1 |

### Version History (recent)

| Version | Effective | CSV URL |
|---|---|---|
| **v25.1** ← **Latest** | 7/1/2025 & 1/1/2026 | https://www.nucc.org/images/stories/CSV/nucc_taxonomy_251.csv |
| **v25.0** ← *included* | 1/1/2025 | https://www.nucc.org/images/stories/CSV/nucc_taxonomy_250.csv |
| v24.1 | 7/1/2024 | https://www.nucc.org/images/stories/CSV/nucc_taxonomy_241.csv |
| v24.0 | 1/1/2024 | https://www.nucc.org/images/stories/CSV/nucc_taxonomy_240.csv |
| v23.1 | 7/1/2023 | https://www.nucc.org/images/stories/CSV/nucc_taxonomy_231.csv |

> **Note:** The `nucc_taxonomy_250.csv` included is v25.0. The current release is **v25.1**. Download the latest before deploying to production.

### CSV Columns

| Column | Description | Example |
|---|---|---|
| `Code` | 10-character taxonomy code | `207RC0000X` |
| `Grouping` | Broad provider category | `Allopathic & Osteopathic Physicians` |
| `Classification` | Specialty | `Internal Medicine` |
| `Specialization` | Sub-specialty (blank for base codes) | `Cardiovascular Disease` |
| `Definition` | Full clinical definition | long text |
| `Notes` | Source/effective date notes | `[7/1/2007: added]` |
| `Display Name` | Short human-readable label | `Cardiovascular Disease Physician` |
| `Section` | `Individual` or `Non-Individual` | `Individual` |

### v25.0 Coverage

- **879 total codes**
- **694 Individual** provider types
- **185 Non-Individual** (hospitals, clinics, labs, agencies)
- **29 groupings**
- **240 base codes** (no sub-specialization)
- **639 codes** with sub-specialization

### Top Groupings

| Grouping | Codes |
|---|---|
| Allopathic & Osteopathic Physicians | 236 |
| Respiratory, Developmental, Rehabilitative and Restorative Service Providers | 82 |
| Technologists, Technicians & Other Technical Service Providers | 65 |
| Ambulatory Health Care Facilities | 63 |
| Nursing Service Providers | 59 |
| Physician Assistants & Advanced Practice Nursing Providers | 58 |
| Behavioral Health & Social Service Providers | 40 |

### Taxonomy Code Examples

| Code | Classification | Specialization | Display Name |
|---|---|---|---|
| `207Q00000X` | Family Medicine | — | Family Medicine Physician |
| `207QA0505X` | Family Medicine | Adult Medicine | Adult Medicine Physician |
| `207R00000X` | Internal Medicine | — | Internal Medicine Physician |
| `207RC0000X` | Internal Medicine | Cardiovascular Disease | Cardiovascular Disease Physician |
| `208000000X` | Pediatrics | — | Pediatrics Physician |
| `363L00000X` | Nurse Practitioner | — | Nurse Practitioner |
| `261QP2300X` | Ambulatory Health Care Facilities | Primary Care | Primary Care Clinic/Center |
| `282N00000X` | Hospitals | General Acute Care Hospital | General Acute Care Hospital |

---

## Schema Overview

```
taxonomy_lookup          ← NUCC v25.0 reference (879 codes, pre-seeded)
        ↑ FK
provider (NPI)           ← Central hub, one row per NPI
    ├── mailing_address                  1:1
    ├── practice_location                1:1
    ├── secondary_practice_location      1:many
    ├── taxonomy                         1:many (up to 15, FK → taxonomy_lookup)
    ├── other_identifier                 1:many (up to 50)
    ├── other_name                       1:many
    ├── authorized_official              1:0-or-1 (organizations only)
    └── endpoint                         1:many
```

---

## Table Definitions

### `taxonomy_lookup` (new in updated DDL)

Pre-seeded with all 879 NUCC v25.0 codes. Maps raw 10-character codes to human-readable labels.

| Column | Type | Description |
|---|---|---|
| `taxonomy_code` | VARCHAR(10) PK | 10-character NUCC code |
| `grouping` | VARCHAR(100) | Broad category |
| `classification` | VARCHAR(200) | Specialty |
| `specialization` | VARCHAR(200) | Sub-specialty (blank for base codes) |
| `display_name` | VARCHAR(300) | Human-readable label |
| `section` | VARCHAR(50) | `Individual` or `Non-Individual` |

### `provider`

Central entity — one row per NPI.

| Column | Type | Notes |
|---|---|---|
| `npi` | CHAR(10) PK | 10-digit NPI number |
| `entity_type_code` | SMALLINT | 1=Individual, 2=Organization |
| `org_name` | VARCHAR(300) | Legal business name (org) |
| `last_name` / `first_name` | VARCHAR(100) | Individual providers |
| `credential` | VARCHAR(50) | MD, DO, RN, PhD etc. |
| `enumeration_date` | DATE | NPI assignment date |
| `deactivation_date` | DATE | NULL = still active |

### `taxonomy`

Up to 15 codes per provider. FK to `taxonomy_lookup`.

| Column | Notes |
|---|---|
| `taxonomy_code` FK | References `taxonomy_lookup.taxonomy_code` |
| `primary_switch` | `Y` = primary taxonomy |
| `license_number` | State license number |
| `license_state` | Issuing state |

### Other Tables

| Table | Cardinality | Description |
|---|---|---|
| `practice_location` | 1:1 | Primary practice address |
| `mailing_address` | 1:1 | Business mailing address |
| `secondary_practice_location` | 1:many | Additional locations (pl_pfile) |
| `other_identifier` | 1:many (up to 50) | Medicare, Medicaid, DEA, state IDs |
| `other_name` | 1:many | Trade names, DBAs, former names |
| `authorized_official` | 1:0-or-1 | Organizations only |
| `endpoint` | 1:many | FHIR, Direct Trust, REST/SOAP |

---

## Views

### `v_individual_provider`
Individuals with practice location and primary taxonomy resolved.

```sql
SELECT npi, last_name, first_name, credential,
       specialty, specialty_classification, city, state, phone
FROM v_individual_provider
WHERE state = 'CA' AND specialty_classification = 'Family Medicine';
```

### `v_organization_provider`
Organizations with authorized official and primary specialty.

```sql
SELECT npi, org_name, specialty, city, state
FROM v_organization_provider
WHERE specialty_grouping = 'Hospitals';
```

### `v_provider_all_taxonomies`
All 15 taxonomy slots per provider with human-readable labels.

```sql
SELECT DISTINCT npi, provider_name
FROM v_provider_all_taxonomies
WHERE specialty_classification = 'Cardiology';
```

### `v_provider_search`
Optimized for search. Excludes deactivated providers.

```sql
SELECT npi, provider_name, credential, specialty,
       city, state, postal_code, phone
FROM v_provider_search
WHERE state = 'TX'
  AND specialty_classification ILIKE '%cardio%'
ORDER BY last_name;
```

---

## Loading NPPES Data

```bash
# 1. Create schema
psql -U postgres -d your_database -f nppes_ddl_updated.sql

# 2. Download NPPES (~9GB unzipped)
wget https://download.cms.gov/nppes/NPPES_Data_Dissemination_MMDDYYYY.zip
unzip NPPES_Data_Dissemination_*.zip

# 3. Load provider data
psql -U postgres -d your_database << 'SQL'
\COPY provider FROM 'npidata_pfile_YYYYMMDD.csv' CSV HEADER;
\COPY secondary_practice_location (npi, address_line_1, city, state, postal_code, phone)
  FROM 'pl_pfile_YYYYMMDD.csv' CSV HEADER;
\COPY endpoint (npi, endpoint_type, endpoint)
  FROM 'endpoint_pfile_YYYYMMDD.csv' CSV HEADER;
SQL

# 4. Verify taxonomy mapping (should be 0)
psql -U postgres -d your_database -c "
SELECT COUNT(*) AS unresolved
FROM taxonomy t
LEFT JOIN taxonomy_lookup tl ON t.taxonomy_code = tl.taxonomy_code
WHERE t.taxonomy_code IS NOT NULL AND tl.taxonomy_code IS NULL;"
```

---

## Updating Taxonomy Codes

NUCC releases updates every 6 months. Current latest: **v25.1** (effective 7/1/2025).

```bash
# Download latest
wget https://www.nucc.org/images/stories/CSV/nucc_taxonomy_251.csv

# Upsert
psql -U postgres -d your_database << 'SQL'
CREATE TEMP TABLE taxonomy_import (LIKE taxonomy_lookup);
\COPY taxonomy_import FROM 'nucc_taxonomy_251.csv' CSV HEADER;

INSERT INTO taxonomy_lookup
SELECT taxonomy_code, grouping, classification, specialization, display_name, section
FROM taxonomy_import
ON CONFLICT (taxonomy_code) DO UPDATE SET
    grouping         = EXCLUDED.grouping,
    classification   = EXCLUDED.classification,
    specialization   = EXCLUDED.specialization,
    display_name     = EXCLUDED.display_name,
    section          = EXCLUDED.section;
SQL
```

---

## Common Queries

```sql
-- Cardiologists in California
SELECT npi, provider_name, credential, city, postal_code, phone
FROM v_provider_search
WHERE state = 'CA' AND specialty_classification ILIKE '%cardiovascular%'
ORDER BY last_name;

-- Active hospitals in Texas
SELECT npi, org_name, specialty, city, postal_code, phone
FROM v_organization_provider
WHERE state = 'TX' AND specialty_grouping = 'Hospitals'
  AND deactivation_date IS NULL;

-- All specialties for a provider
SELECT slot, taxonomy_code, display_name, primary_switch, license_state
FROM v_provider_all_taxonomies
WHERE npi = '1234567890'
ORDER BY slot;

-- Top 20 specialties by provider count
SELECT tl.display_name, COUNT(*) AS provider_count
FROM taxonomy t
JOIN taxonomy_lookup tl ON t.taxonomy_code = tl.taxonomy_code
WHERE t.primary_switch = 'Y'
GROUP BY tl.display_name
ORDER BY provider_count DESC
LIMIT 20;
```

---

## References

| Resource | URL |
|---|---|
| NPI Registry API Demo | https://npiregistry.cms.hhs.gov/demo-api |
| NPPES Data Downloads | https://download.cms.gov/nppes/NPI_Files.html |
| NUCC Taxonomy CSV (v25.1 latest) | https://www.nucc.org/images/stories/CSV/nucc_taxonomy_251.csv |
| NUCC Taxonomy CSV page | https://www.nucc.org/index.php/code-sets-mainmenu-41/provider-taxonomy-mainmenu-40/csv-mainmenu-57 |
| NUCC Code Lookup | https://www.nucc.org/index.php/code-sets-mainmenu-41/provider-taxonomy-mainmenu-40/code-lookups |
| CMS NPI Standard | https://www.cms.gov/Regulations-and-Guidance/Administrative-Simplification/NationalProvIdentStand |

---

*Taxonomy: NUCC v25.0 (879 codes, included). Current release: v25.1 (7/1/2025). Schema: 2026-03-21.*
