SA Clinic Health Records — Data Analytics Project
By Galaletsang Modise | LinkedIn

Project Overview
Every day, across thousands of public clinics in South Africa, patients arrive seeking care 
and wait. Not because there are no doctors. Not because there are no beds. But because
their file cannot be found.

In a system still heavily dependent on physical paper records, a single missing or misfiled
folder can mean hours of waiting  for the elderly, for mothers with sick children, for people
who travelled far to be there. In some cases, that delay is the difference between life and
death.

This project uses data analytics to quantify that problem and make the case for
digitisation aligned with South Africa’s National Health Normative Standards Framework
(HNSF) and NHI rollout strategy.

Key Finding

1,472 patient hours are lost every single month to paper-based file retrieval. That’s
time spent waiting for a folder — not time spent with a doctor.

Tools Used

Tool Purpose
Microsoft SQL Server (SSMS) Data cleaning, transformation & analysis
Power BI Desktop Data modelling & dashboard visualisation
Python Simulated dataset generation
GitHub Version control & portfolio publishing

Dashboard Pages

Page 1 — The Problem
Map of South Africa showing average wait times by province
Top 10 worst-performing clinics by average wait time
KPI card: Average file retrieval time (49 minutes)
Page 2 — Root Causes
Scatter plot: Staff count vs average wait time
Stacked bar: Physical vs Digital files by province
Critical clinics table: High wait time + low staff count
Page 3 — Patient Impact
Line chart: Cumulative clinic visits over time (2023–2024)
Bar chart: Reasons for clinic visits
Donut chart: Visit outcomes breakdown
Page 4 — The Case for Change
1,472 patient hours lost monthly to paper-based filing
Side by side KPI: Digital vs Physical average wait times
Bar chart: File missing rate — Digital vs Physical

Dataset
This project uses a realistic simulated dataset modelled on South African public clinic
operations. The data was generated in Python and intentionally includes real-world data
quality issues such as NULL values, duplicates, inconsistent entries and outliers — to
demonstrate data cleaning skills.

File Table Rows Description
clinics.csv Clinics 20 SA clinics across all 9 provinces
patients.csv Patients 505 Patient records with nulls & duplicates
visits.csv Visits 2,000 Clinic visit records
wait_times.csv Wait_Times 2,000 Wait time records including outliers
files.csv Files 600 Physical vs digital file records

SQL — Data Cleaning

Key cleaning steps performed in SSMS:
-- 1. Audit NULL values
SELECT
COUNT(*) AS total_rows,
SUM(CASE WHEN id_number IS NULL THEN 1 ELSE 0 END) AS null_id_numbers,
SUM(CASE WHEN date_of_birth IS NULL THEN 1 ELSE 0 END) AS null_dob
FROM Patients;
-- 2. Standardise inconsistent gender entries
UPDATE Patients
SET gender = CASE
WHEN LOWER(gender) IN ('male', 'm') THEN 'Male'
WHEN LOWER(gender) IN ('female', 'f') THEN 'Female'
ELSE gender
END;
-- 3. Replace NULL wait times with column average
UPDATE Wait_Times
SET time_to_file_minutes = (
SELECT AVG(time_to_file_minutes)
FROM Wait_Times
WHERE time_to_file_minutes IS NOT NULL
)
WHERE time_to_file_minutes IS NULL;
-- 4. Detect duplicate patients
SELECT id_number, COUNT(*) AS occurrences
FROM Patients
WHERE id_number IS NOT NULL
GROUP BY id_number
HAVING COUNT(*) > 1;
-- 5. Flag outlier wait times

SELECT *,
CASE
WHEN time_to_file_minutes > 300 THEN 'Outlier - Review'
ELSE 'Normal'
END AS data_quality_flag
FROM Wait_Times;

SQL — Analysis Queries
CTE — Average Wait Time by Clinic
WITH AvgWaits AS (
SELECT
clinic_id,
AVG(time_to_file_minutes) AS avg_file_wait,
AVG(time_to_assist_minutes) AS avg_assist_wait
FROM Wait_Times
GROUP BY clinic_id
)
SELECT
c.clinic_name,
c.province,
c.has_digital_system,
a.avg_file_wait,
a.avg_assist_wait,
a.avg_file_wait + a.avg_assist_wait AS total_avg_wait_minutes
FROM AvgWaits a
JOIN Clinics c ON a.clinic_id = c.clinic_id
ORDER BY total_avg_wait_minutes DESC;

Window Function — Rank Clinics Within Province

SELECT
c.clinic_name,
c.province,
c.staff_count,
AVG(w.time_to_file_minutes) AS avg_file_wait,
RANK() OVER (
PARTITION BY c.province
ORDER BY AVG(w.time_to_file_minutes) DESC
) AS rank_in_province
FROM Wait_Times w

JOIN Clinics c ON w.clinic_id = c.clinic_id
GROUP BY c.clinic_name, c.province, c.staff_count;

Subquery — Critical Clinics (High Wait + Low Staff)
SELECT clinic_name, province, staff_count, avg_wait_time
FROM (
SELECT
c.clinic_name,
c.province,
c.staff_count,
AVG(w.time_to_file_minutes) AS avg_wait_time
FROM Clinics c
JOIN Wait_Times w ON c.clinic_id = w.clinic_id
GROUP BY c.clinic_name, c.province, c.staff_count
) clinic_summary
WHERE avg_wait_time > (SELECT AVG(time_to_file_minutes) FROM Wait_Times)
AND staff_count < (SELECT AVG(staff_count) FROM Clinics)
ORDER BY avg_wait_time DESC;

The “So What” Query — Patient Hours Lost
SELECT
ROUND(SUM(time_to_file_minutes - 5) / 60.0, 0) AS hours_saved_if_digitised
FROM Wait_Times
WHERE time_to_file_minutes > 5;

Results & Insights

49 minutes is the average time a patient waits just for their file to be retrieved
Physical clinics have a significantly higher file missing rate than digital clinics
Clinics with fewer than 8 staff members consistently show the worst wait times
1,472 patient hours are lost monthly to paper-based filing across the dataset
The data directly supports South Africa’s NHI digitisation strategy

How to Use This Project

1. Clone or download this repository
2. Import the 5 CSV files into SQL Server using BULK INSERT
3. Run SA_Clinic_Project.sql to clean and analyse the data
4. Open GaliProject.pbix in Power BI Desktop
5. Connect to your local SQL Server instance
6. Refresh the data and explore the dashboard

About Me

I’m Galaletsang Modise, a data analyst in the making — transitioning into tech with a passion
for using data to solve real problems in the communities I grew up in.

Certifications:
Microsoft Azure Fundamentals (AZ-900)
Microsoft Power BI Data Analyst (PL-300) — in progress
Skills: SQL · Power BI · Data Cleaning · Data Visualisation · Storytelling with Data
Connect with me on LinkedIn

Built with purpose. Rooted in South Africa. Powered by data.
