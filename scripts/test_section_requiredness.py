#!/usr/bin/env python3
"""Execute the changed section and enrichment SQL against an isolated fixture."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
DUCKDB = shutil.which("duckdb")

FIXTURE = r'''
CREATE TABLE catalog AS SELECT * FROM (VALUES
 ('100','Own','optional',1,'D','100','A','1::D::100','1::D::100::A::2025-4','2025-4',DATE '2025-10-01',10,NULL,'Introductory or general undergraduate'),
 ('101','Seats',NULL,1,'D','101','A','1::D::101','1::D::101::A::2025-4','2025-4',DATE '2025-10-01',NULL,20,'Introductory or general undergraduate'),
 ('102','Sibling A',NULL,1,'D','102','A','1::D::102','1::D::102::A::2025-4','2025-4',DATE '2025-10-01',30,NULL,'Introductory or general undergraduate'),
 ('103','Sibling B',NULL,1,'D','102','B','1::D::102','1::D::102::B::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 ('104','Class ref',NULL,2,'D','104','A','2::D::104','2::D::104::A::2025-4','2025-4',DATE '2025-10-01',40,NULL,'Introductory or general undergraduate'),
 ('105','Class target',NULL,2,'E','105','A','2::E::105','2::E::105::A::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 ('106','Level ref',NULL,3,'D','106','A','3::D::106','3::D::106::A::2025-4','2025-4',DATE '2025-10-01',50,NULL,'Introductory or general undergraduate'),
 ('107','Level target',NULL,4,'E','107','A','4::E::107','4::E::107::A::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 ('111','Supply','required',1,'S','111','A','1::S::111','1::S::111::A::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 (NULL,'Blank fallback',NULL,1,'S','111','A','1::S::111','1::S::111::A::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 ('108','Mixed required','required',1,'M','108','A','1::M::108','1::M::108::A::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 ('109','Mixed optional','option',1,'M','108','A','1::M::108','1::M::108::A::2025-4','2025-4',DATE '2025-10-01',NULL,NULL,'Introductory or general undergraduate'),
 ('110','Old','required',1,'O','110','A','1::O::110','1::O::110::A::2023-4','2023-4',DATE '2023-10-01',NULL,NULL,'Introductory or general undergraduate')) AS t("ISBN13","Title",book_status,unit_id,dept_code,course_number,section,course_id,section_id,period_sortable,period_date,enrollments,seats_taken,course_level);
ALTER TABLE catalog ADD COLUMN "Author" VARCHAR; ALTER TABLE catalog ADD COLUMN "Publisher" VARCHAR; ALTER TABLE catalog ADD COLUMN "Imprint" VARCHAR; ALTER TABLE catalog ADD COLUMN "Format" VARCHAR; ALTER TABLE catalog ADD COLUMN "FormatType" VARCHAR; ALTER TABLE catalog ADD COLUMN school VARCHAR; ALTER TABLE catalog ADD COLUMN state VARCHAR; ALTER TABLE catalog ADD COLUMN department VARCHAR; ALTER TABLE catalog ADD COLUMN dept_description VARCHAR; ALTER TABLE catalog ADD COLUMN course_title VARCHAR; ALTER TABLE catalog ADD COLUMN course_subject VARCHAR; ALTER TABLE catalog ADD COLUMN period VARCHAR; ALTER TABLE catalog ADD COLUMN instructor VARCHAR; ALTER TABLE catalog ADD COLUMN first_name VARCHAR; ALTER TABLE catalog ADD COLUMN last_name VARCHAR; ALTER TABLE catalog ADD COLUMN email VARCHAR;
ALTER TABLE catalog ALTER COLUMN "ISBN13" SET DATA TYPE BIGINT USING TRY_CAST("ISBN13" AS BIGINT);
UPDATE catalog SET "FormatType"='Book', period='Fall 2025', school='S', state='CA', department='D', dept_description='D', course_title='T', course_subject='X', instructor='I', first_name='F', last_name='L', email='e';
CREATE TABLE ipeds_data AS SELECT * FROM (VALUES (1,'s','Public, 4-year or above','Four or more years','Public','1',100,10,'College'),(2,'s','Public, 4-year or above','Four or more years','Public','1',100,10,'College'),(3,'s','Public, 4-year or above','Four or more years','Public','1',100,10,'College'),(4,'s','Private not-for-profit, 4-year or above','Four or more years','Private','1',100,10,'College')) t(unitid,instnm,sector,iclevel,control,instsize,enroll_24,dist_enroll_24,inst_type);
 CREATE TABLE panel(email VARCHAR,response_year INTEGER); CREATE TABLE panel_email(email VARCHAR,panel_response_year INTEGER,panel_source_row_count INTEGER,panel_response_year_variant_count INTEGER); CREATE TABLE opt_out(email VARCHAR,source VARCHAR); CREATE TABLE supply_isbn_classification(isbn13 VARCHAR,category VARCHAR); INSERT INTO supply_isbn_classification VALUES ('111','science_lab');
'''

class SectionRequirednessTest(unittest.TestCase):
    def test_actual_scripts_and_assignment_ladder(self):
        self.assertIsNotNone(DUCKDB, "duckdb CLI is required")
        config = "SET memory_limit='1GB'; SET threads=1; SET preserve_insertion_order=false;"
        one_b = (ROOT/'scripts/sql/1b_section_enrollment.sql').read_text().replace('${CONFIG}',config).replace('${SURVEY_TABLE}','catalog').replace('${IPEDS_TABLE}','ipeds_data')
        oer = (ROOT/'scripts/sql/2_oer_classification.sql').read_text()
        for key, value in {'${LOOKUP_DIR}':str(ROOT/'data/2025.12.15'),'${SURVEY_TABLE}':'catalog','${IPEDS_TABLE}':'ipeds_data','${PANEL_TABLE}':'panel','${OPTOUT_TABLE}':'opt_out'}.items(): oer=oer.replace(key,value)
        checks = r'''
SELECT CASE WHEN
 (SELECT enrollment_source FROM section_enrollment WHERE section_id='1::D::100::A::2025-4')='own' AND
 (SELECT enrollment_source FROM section_enrollment WHERE section_id='1::D::101::A::2025-4')='own_seats' AND
 (SELECT enrollment_source FROM section_enrollment WHERE section_id='1::D::102::B::2025-4')='sibling_enroll' AND
 (SELECT enrollment_source FROM section_enrollment WHERE section_id='2::E::105::A::2025-4')='class_median' AND
 (SELECT enrollment_source FROM section_enrollment WHERE section_id='4::E::107::A::2025-4')='level_median' AND
 (SELECT is_section_required_direct FROM comprehensive_data WHERE section_id='1::S::111::A::2025-4' AND "ISBN13" IS NULL LIMIT 1)=FALSE AND
 (SELECT is_required_inferred FROM comprehensive_data WHERE section_id='1::S::111::A::2025-4' AND "ISBN13" IS NULL)=TRUE AND
 (SELECT is_section_required_direct FROM comprehensive_data WHERE section_id='1::M::108::A::2025-4' LIMIT 1)=TRUE AND
 (SELECT is_required_inferred FROM comprehensive_data WHERE section_id='1::M::108::A::2025-4' AND book_status='option')=FALSE AND
 (SELECT COUNT(*) FROM comprehensive_data)=13 AND
 (SELECT COUNT(*) FROM comprehensive_data WHERE section_id='1::O::110::A::2023-4' AND is_required_inferred)=0
 THEN 1 ELSE error('actual SQL regression') END AS contract_ok;
'''
        with tempfile.TemporaryDirectory() as td:
            r = subprocess.run([DUCKDB,'-bail',str(Path(td)/'t.duckdb'),'-c',FIXTURE+one_b+oer+checks],text=True,capture_output=True)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr); self.assertIn('1',r.stdout)

    def test_helper_has_no_supply_requiredness(self):
        s=(ROOT/'scripts/sql/1b_section_enrollment.sql').read_text()
        self.assertNotIn('supply_isbn_classification',s); self.assertNotIn('AS is_required_direct',s); self.assertNotIn('is_required_direct_legacy',s)

if __name__ == '__main__': unittest.main()
