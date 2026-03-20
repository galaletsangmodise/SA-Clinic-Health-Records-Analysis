
-- SA CLINIC HEALTH RECORDS — DATA ANALYTICS PROJECT
-- Author: Galaletsang Modise
-- Tool: Microsoft SQL Server (SSMS)


-- STEP 1: CREATE DATABASE

USE master; IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SA_Clinic_Project')
CREATE DATABASE SA_Clinic_Project; USE SA_Clinic_Project;

-- STEP 2: CREATE TABLES

-- Clinics IF OBJECT_ID('Clinics', 'U') IS NOT NULL DROP TABLE Clinics;
CREATE TABLE
Clinics
( clinic_id NVARCHAR(20),
clinic_name NVARCHAR(100),
province NVARCHAR(50),
district NVARCHAR(20), staff_count INT NULL,
has_digital_system NVARCHAR(5),
total_capacity_per_day INT NULL,
year_established INT NULL );
-- Patients IF OBJECT_ID('Patients', 'U') IS NOT NULL DROP TABLE Patients;
CREATE TABLE
Patients
( patient_id NVARCHAR(20),
first_name NVARCHAR(50),
last_name NVARCHAR(50),
id_number NVARCHAR(20) NULL,
date_of_birth NVARCHAR(50) NULL,
gender NVARCHAR(10) NULL,
province NVARCHAR(50),
has_file NVARCHAR(5),
file_type NVARCHAR(20) NULL );
-- Visits IF OBJECT_ID('Visits', 'U') IS NOT NULL DROP TABLE Visits;
CREATE TABLE
Visits
( visit_id NVARCHAR(20),
patient_id NVARCHAR(20),
clinic_id NVARCHAR(20),
visit_date NVARCHAR(50),
visit_reason NVARCHAR(50) NULL,
file_found NVARCHAR(10),
visit_outcome NVARCHAR(50) );
-- Wait Times IF OBJECT_ID('Wait_Times', 'U') IS NOT NULL DROP TABLE Wait_Times;
CREATE TABLE
Wait_Times
( wait_id NVARCHAR(20),
visit_id NVARCHAR(20),
clinic_id NVARCHAR(20),
time_to_file_minutes FLOAT NULL,
time_to_triage_minutes FLOAT NULL,
time_to_assist_minutes FLOAT NULL,
visit_date NVARCHAR(50) NULL );
-- Files IF OBJECT_ID('Files', 'U') IS NOT NULL DROP TABLE Files;
CREATE TABLE
Files
( file_id NVARCHAR(20),
patient_id NVARCHAR(20),
clinic_id NVARCHAR(20),
file_type NVARCHAR(20),
file_status NVARCHAR(20),
date_created NVARCHAR(50),
last_accessed NVARCHAR(50) NULL ); 

-- STEP 3: IMPORT DATA

BULK INSERT Clinics
FROM 'C:\clinics.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT Patients FROM 'C:\patients.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT Visits FROM 'C:\visits.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT Wait_Times FROM 'C:\wait_times.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT Files FROM 'C:\files.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);
-- Verify row counts
SELECT 'Clinics' AS table_name, COUNT(*) AS row_count
FROM Clinics UNION ALL
SELECT 'Patients', COUNT(*)
FROM Patients
UNION ALL
SELECT 'Visits', COUNT(*) FROM Visits UNION ALL
SELECT 'Wait_Times', COUNT(*)
FROM Wait_Times UNION ALL
SELECT 'Files', COUNT(*)
FROM Files;

-- STEP 4: DATA CLEANING

-- 4.1 Audit NULL values
SELECT COUNT(*) AS total_rows,
SUM(CASE WHEN id_number IS NULL THEN 1 ELSE 0 END) AS null_id_numbers,
SUM(CASE WHEN date_of_birth IS NULL THEN 1 ELSE 0 END) AS null_dob,
SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) AS null_gender
FROM Patients;
-- 4.2 Standardise gender entries
UPDATE Patients SET gender = CASE WHEN LOWER(gender) IN ('male', 'm') THEN 'Male'
WHEN LOWER(gender) IN ('female', 'f') THEN 'Female' ELSE gender END;
-- 4.3 Replace NULL wait times with average
UPDATE Wait_Times SET time_to_file_minutes = ( SELECT AVG(time_to_file_minutes)
FROM Wait_Times
WHERE time_to_file_minutes IS NOT NULL )
WHERE time_to_file_minutes IS NULL;
-- 4.4 Detect duplicate patients
SELECT id_number, COUNT(*) AS occurrences
FROM Patients
WHERE id_number IS NOT NULL
GROUP BY id_number HAVING COUNT(*) > 1
ORDER BY occurrences DESC;
-- 4.5 Flag outlier wait times
SELECT *, CASE WHEN time_to_file_minutes > 300 THEN 'Outlier - Review'
ELSE 'Normal' END AS data_quality_flag
FROM Wait_Times
ORDER BY time_to_file_minutes DESC;

-- STEP 5: ANALYSIS QUERIES

-- 5.1 Average wait time by clinic (CTE)
WITH AvgWaits AS (
SELECT clinic_id, AVG(time_to_file_minutes) AS avg_file_wait,
AVG(time_to_assist_minutes) AS avg_assist_wait
FROM Wait_Times GROUP BY clinic_id )
SELECT
c.clinic_name,
c.province,
c.has_digital_system,
c.staff_count,
a.avg_file_wait,
a.avg_assist_wait,
a.avg_file_wait + a.avg_assist_wait AS total_avg_wait_minutes
FROM AvgWaits a
JOIN Clinics c ON a.clinic_id = c.clinic_id
ORDER BY total_avg_wait_minutes DESC;
-- 5.2 Rank clinics within province (Window Function)
SELECT
c.clinic_name,
c.province,
c.staff_count,
AVG(w.time_to_file_minutes) AS avg_file_wait,
RANK() OVER ( PARTITION BY c.province
ORDER BY AVG(w.time_to_file_minutes) DESC ) AS rank_in_province
FROM Wait_Times w
JOIN Clinics c ON w.clinic_id = c.clinic_id
GROUP BY c.clinic_name, c.province, c.staff_count;
-- 5.3 Monthly patient volume with running total (Window Function)
SELECT
clinic_id,
visit_month,
monthly_patients,
SUM(monthly_patients) OVER ( PARTITION BY clinic_id
ORDER BY CONVERT(VARCHAR(7), visit_month) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS running_total
FROM (
SELECT clinic_id, FORMAT(visit_date, 'yyyy-MM') AS visit_month, COUNT(*) AS monthly_patients
FROM Visits GROUP BY clinic_id, FORMAT(visit_date, 'yyyy-MM') ) monthly_data
ORDER BY clinic_id, visit_month;
-- 5.4 Critical clinics: high wait + low staff (Subquery)
SELECT clinic_name, province, staff_count, avg_wait_time
FROM ( SELECT c.clinic_name, c.province, c.staff_count,
AVG(w.time_to_file_minutes) AS avg_wait_time
FROM Clinics c
JOIN Wait_Times w ON c.clinic_id = w.clinic_id
GROUP BY c.clinic_name, c.province, c.staff_count ) clinic_summary
WHERE avg_wait_time > (SELECT AVG(time_to_file_minutes) FROM Wait_Times) AND staff_count < (SELECT AVG(staff_count) FROM Clinics)
ORDER BY avg_wait_time DESC;
-- 5.5 File found rate by clinic
SELECT c.clinic_name, c.province, COUNT(*) AS total_visits,
SUM(CASE WHEN v.file_found = 1 THEN 1 ELSE 0 END) AS files_found,
ROUND(100.0 * SUM(CASE WHEN v.file_found = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS file_found_rate_pct
FROM Visits v
JOIN Clinics c ON v.clinic_id = c.clinic_id
GROUP BY c.clinic_name, c.province
ORDER BY file_found_rate_pct ASC;
-- 5.6 Digital vs physical file missing rate
SELECT file_type,
COUNT(*) AS total_files, SUM(CASE WHEN file_status = 'Missing' THEN 1 ELSE 0 END) AS missing_count,
ROUND(100.0 * SUM(CASE WHEN file_status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_rate_pct
FROM Files GROUP BY file_type;
-- 5.7 Patient hours lost to paper-based filing
SELECT ROUND(SUM(time_to_file_minutes - 5) / 60.0, 0) AS hours_lost_monthly
FROM Wait_Times
WHERE time_to_file_minutes > 5;

-- STEP 6: CREATE VIEWS FOR POWER BI 
CREATE VIEW vw_AvgWaitByClinic AS WITH AvgWaits
AS ( SELECT clinic_id, AVG(time_to_file_minutes) AS avg_file_wait, AVG(time_to_assist_minutes) AS avg_assist_wait
FROM Wait_Times
GROUP BY clinic_id )
SELECT
c.clinic_name,
c.province,
c.has_digital_system,
c.staff_count,
a.avg_file_wait,
a.avg_assist_wait,
a.avg_file_wait + a.avg_assist_wait AS total_avg_wait_minutes
FROM AvgWaits a
JOIN Clinics c ON a.clinic_id = c.clinic_id;

 CREATE VIEW vw_CriticalClinics AS
SELECT clinic_name,
province,
staff_count,
avg_wait_time
FROM (
SELECT
c.clinic_name,
c.province,
c.staff_count,
AVG(w.time_to_file_minutes) AS avg_wait_time
FROM Clinics c JOIN Wait_Times w ON c.clinic_id = w.clinic_id
GROUP BY c.clinic_name, c.province, c.staff_count ) s
WHERE avg_wait_time > (SELECT AVG(time_to_file_minutes)
FROM Wait_Times) AND staff_count < (SELECT AVG(staff_count)
FROM Clinics);GO
CREATE VIEW vw_FileFoundRate AS
SELECT
c.clinic_name,
c.province,
COUNT(*) AS total_visits,
SUM(CASE WHEN v.file_found = 1 THEN 1 ELSE 0 END) AS files_found,
ROUND(100.0 * SUM(CASE WHEN v.file_found = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS file_found_rate_pct
FROM Visits v
JOIN Clinics c ON v.clinic_id = c.clinic_id
GROUP BY c.clinic_name, c.province; GO
CREATE VIEW vw_DigitalVsPhysical AS
SELECT file_type, COUNT(*) AS total_files,
SUM(CASE WHEN file_status = 'Missing' THEN 1 ELSE 0 END) AS missing_count,
ROUND(100.0 * SUM(CASE WHEN file_status = 'Missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS missing_rate_pct
FROM Files
GROUP BY file_type; GO
CREATE VIEW vw_FileTypeByProvince AS
SELECT c.province, f.file_type, COUNT(*) AS total_files
FROM Files f JOIN Clinics c ON f.clinic_id = c.clinic_id
GROUP BY c.province, f.file_type; GO
-- Verify all views
SELECT name AS view_name
FROM sys.views
WHERE name LIKE 'vw_%'
ORDER BY name;