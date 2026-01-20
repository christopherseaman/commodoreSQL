-- Aggregate and transform records by faculty, course sections, and courses

${CONFIG}

-- Generate faculty records with aggregated metrics
DROP VIEW IF EXISTS faculty_records;
CREATE VIEW faculty_records AS
WITH faculty_counts AS (
    SELECT
        CASE
            WHEN email IS NOT NULL AND email != ''
            THEN email
            ELSE CONCAT(instructor, '_', school)
        END AS faculty_id,
        instructor,
        school,
        email,
        department,
        period_sortable,
        COUNT(*) AS record_count,
        COUNT(DISTINCT section_id) AS section_count
    FROM comprehensive_data
    WHERE
        instructor IS NOT NULL AND
        course_number IS NOT NULL AND
        section IS NOT NULL AND
        course_title IS NOT NULL
    GROUP BY
        faculty_id,
        instructor,
        school,
        email,
        department,
        period_sortable
)
SELECT
    faculty_id,
    instructor,
    school,
    email,
    department,
    LIST(CONCAT(period_sortable, ':', record_count)) AS record_counts_by_period,
    LIST(CONCAT(period_sortable, ':', section_count)) AS section_counts_by_period
FROM faculty_counts
GROUP BY
    faculty_id,
    instructor,
    school,
    email,
    department;

-- Create master_section: one row per section per period
DROP VIEW IF EXISTS master_section;
CREATE VIEW master_section AS
SELECT
    section_id,
    course_id,
    period,
    period_sortable,
    school,
    department,
    course_number,
    section,
    course_title,
    course_level,
    course_subject,
    COUNT(*) AS material_count,
    SUM(CASE WHEN LOWER(book_status) = 'required' THEN 1 ELSE 0 END) AS required_count,
    SUM(CASE WHEN LOWER(book_status) != 'required' THEN 1 ELSE 0 END) AS optional_count,
    LIST(DISTINCT publisher) FILTER (WHERE publisher IS NOT NULL) AS publishers,
    LIST(DISTINCT publisher) FILTER (WHERE publisher IS NOT NULL AND LOWER(book_status) = 'required') AS required_publishers,
    COUNT(DISTINCT CASE WHEN LOWER(book_status) = 'required' THEN publisher END) AS required_publisher_count,
    COUNT(DISTINCT CASE WHEN LOWER(book_status) != 'required' THEN publisher END) AS optional_publisher_count,
    MAX(enrollments) AS enrollments,
    MAX(seats_taken) AS seats_taken
FROM comprehensive_data
WHERE
    section_id IS NOT NULL AND
    period_sortable IS NOT NULL
GROUP BY
    section_id,
    course_id,
    period,
    period_sortable,
    school,
    department,
    course_number,
    section,
    course_title,
    course_level,
    course_subject;

-- Create master_course: one row per course per period
DROP VIEW IF EXISTS master_course;
CREATE VIEW master_course AS
SELECT
    course_id,
    period,
    period_sortable,
    school,
    department,
    course_number,
    course_title,
    course_level,
    course_subject,
    COUNT(DISTINCT section_id) AS section_count,
    SUM(enrollments) AS enrollment_total,
    SUM(seats_taken) AS seats_taken_total,
    SUM(material_count) AS total_materials,
    SUM(required_count) AS total_required,
    SUM(optional_count) AS total_optional,
    LIST(publishers) FILTER (WHERE publishers IS NOT NULL) AS all_publishers,
    SUM(required_publisher_count) AS unique_required_publishers
FROM master_section
GROUP BY
    course_id,
    period,
    period_sortable,
    school,
    department,
    course_number,
    course_title,
    course_level,
    course_subject;

-- Create master_course_material: material distribution by course
DROP VIEW IF EXISTS master_course_material;
CREATE VIEW master_course_material AS
SELECT
    course_id,
    period,
    period_sortable,
    school,
    department,
    course_number,
    course_title,
    publisher,
    book_status,
    COUNT(*) AS material_instances,
    COUNT(DISTINCT section_id) AS sections_using,
    SUM(seats_taken) AS total_seats_affected
FROM comprehensive_data
WHERE
    course_id IS NOT NULL AND
    publisher IS NOT NULL AND
    period_sortable IS NOT NULL
GROUP BY
    course_id,
    period,
    period_sortable,
    school,
    department,
    course_number,
    course_title,
    publisher,
    book_status;

-- Create course section records with period-based metrics (legacy compatibility)
DROP VIEW IF EXISTS course_section_records;
CREATE VIEW course_section_records AS
SELECT
    section_id,
    course_id,
    course_number,
    section,
    course_title,
    school,
    period_sortable,
    material_count AS records_in_period,
    publishers
FROM master_section;

-- Generate course records with aggregated enrollment and section data (legacy compatibility)
DROP VIEW IF EXISTS course_records;
CREATE VIEW course_records AS
SELECT
    course_id,
    course_number,
    course_title,
    school,
    period_sortable,
    section_count AS sections_in_period,
    enrollment_total AS total_enrollment,
    all_publishers AS publishers
FROM master_course;
