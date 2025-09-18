-- ============================================
-- SQL SCRIPT: Clinical Data Demo
-- ============================================
-- Purpose:
--   This script demonstrates how clinical data 
--   (imported from CSV files into SQL Server Management Studio)
--   can be structured, cleaned, validated, and analyzed.
--
-- Workflow:
--   1. Initial data inspection
--   2. Enforce data integrity with keys & constraints
--   3. Fix datatype mismatches
--   4. Perform data quality checks
--   5. Run basic analysis queries
-- ============================================


-- 1. INITIAL DATA INSPECTION
-- --------------------------
-- After importing CSVs (Patients, Samples, Tests, Treatments),
-- we check whether the tables were loaded correctly.
SELECT * FROM Patients;
SELECT * FROM Samples;
SELECT * FROM Tests;
SELECT * FROM Treatments;


-- 2. ENFORCE DATA INTEGRITY
-- --------------------------
-- Ensure that each patient has a unique identifier.
ALTER TABLE Patients
ADD CONSTRAINT UQ_Patients_patient_code UNIQUE (patient_code);

-- Create foreign key relationships between tables:
-- Patient → Sample → Test
-- Patient → Treatment
ALTER TABLE Samples
ADD CONSTRAINT FK_Samples_Patients
FOREIGN KEY (patient_id) REFERENCES Patients(patient_id);

ALTER TABLE Tests
ADD CONSTRAINT FK_Tests_Samples
FOREIGN KEY (sample_id) REFERENCES Samples(sample_id);

ALTER TABLE Treatments
ADD CONSTRAINT FK_Treatments_Patients
FOREIGN KEY (patient_id) REFERENCES Patients(patient_id);


-- 3. FIX DATATYPE MISMATCHES
-- --------------------------
-- Sometimes CSV imports cause datatype mismatches.
-- In my case, the column "patient_id" in Treatments had a different datatype 
-- than in Patients, which caused a foreign key creation error. 
-- To fix this, we need to align both columns to the same datatype (INT).
-- This ensures referential integrity and prevents future join errors.
EXEC sp_columns 'Patients';
EXEC sp_columns 'Treatments';

-- Fix the column datatype (if required):
ALTER TABLE Treatments
ALTER COLUMN patient_id INT NOT NULL;

-- Re-add foreign key after fixing datatype:
ALTER TABLE Treatments
ADD CONSTRAINT FK_Treatments_Patients
FOREIGN KEY (patient_id) REFERENCES Patients(patient_id);


-- 4. DATA QUALITY CHECKS
-- ----------------------
-- Check for missing test results
SELECT COUNT(*) AS NullResults
FROM Tests
WHERE result IS NULL;

-- Check for invalid values in the "result" column
SELECT *
FROM Tests
WHERE result NOT IN ('Positive', 'Negative')
   OR result IS NULL;


-- 5. BASIC ANALYTICAL QUERIES
-- ---------------------------
-- Count how many tests were performed per patient
SELECT s.patient_id, COUNT(t.test_id) AS total_tests
FROM Tests t
JOIN Samples s ON t.sample_id = s.sample_id
GROUP BY s.patient_id;

-- Count positive and negative test results per patient
SELECT p.patient_id,
       SUM(CASE WHEN t.result = 'Positive' THEN 1 ELSE 0 END) AS positive_count,
       SUM(CASE WHEN t.result = 'Negative' THEN 1 ELSE 0 END) AS negative_count
FROM Tests t
JOIN Samples s ON t.sample_id = s.sample_id
JOIN Patients p ON s.patient_id = p.patient_id
GROUP BY p.patient_id;


-- 6. AGE GROUP ANALYSIS OF TREATMENT OUTCOMES
-- -------------------------------------------
-- Example: Evaluate treatment success rates by patient age groups
SELECT 
    CASE 
        WHEN DATEDIFF(YEAR, p.dob, GETDATE()) < 30 THEN '<30'
        WHEN DATEDIFF(YEAR, p.dob, GETDATE()) BETWEEN 30 AND 50 THEN '30-50'
        ELSE '>50'
    END AS age_group,
    COUNT(DISTINCT p.patient_id) AS total_patients,
    COUNT(*) AS total_treatments,
    SUM(CASE WHEN t.outcome = 'Successful' THEN 1 ELSE 0 END) AS successful_treatments,
    CAST(SUM(CASE WHEN t.outcome = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) 
         AS DECIMAL(5,2)) AS success_rate_percent
FROM Patients p
LEFT JOIN Treatments t ON p.patient_id = t.patient_id
GROUP BY 
    CASE 
        WHEN DATEDIFF(YEAR, p.dob, GETDATE()) < 30 THEN '<30'
        WHEN DATEDIFF(YEAR, p.dob, GETDATE()) BETWEEN 30 AND 50 THEN '30-50'
        ELSE '>50'
    END;
