-- ================== DATA CLEANING PROJECT SCRIPT ================== --
-- Database: clean

USE clean;

-- Create a stored procedure to display all records from 'limpieza'
DELIMITER //
CREATE PROCEDURE limp()
BEGIN
	SELECT * FROM limpieza;
END //
DELIMITER ;

-- Call the procedure to view data
CALL limp();

-- ================== COLUMN RENAMING ================== --
-- Rename columns with encoding issues and set appropriate data types
ALTER TABLE limpieza CHANGE COLUMN `ï»¿Id?empleado` Id_emp VARCHAR(20) NULL; 
ALTER TABLE limpieza CHANGE COLUMN `gÃ©nero` Gender VARCHAR(20) NULL; 
ALTER TABLE limpieza CHANGE COLUMN `Apellido` Last_name VARCHAR(50) NULL; 
ALTER TABLE limpieza CHANGE COLUMN `star_date` Start_date VARCHAR(20) NULL; 

-- ================== DUPLICATE DETECTION ================== --
-- Count duplicate records based on employee ID
SELECT count(*) AS cantidad_duplicados
FROM (
	SELECT id_emp, count(*) AS cantidad_duplicados
	FROM limpieza
	GROUP BY id_emp
	HAVING count(*) > 1
) AS subquery;

-- Rename original table for backup
RENAME TABLE limpieza TO conduplicados;

-- Create a temporary table without duplicates
CREATE TEMPORARY TABLE temp_limpieza AS 
SELECT DISTINCT * FROM conduplicados; 

-- Compare row counts before and after duplicate removal
SELECT COUNT(*) AS original FROM conduplicados;
SELECT COUNT(*) AS cleaned FROM temp_limpieza;

-- Replace old table with the cleaned one
CREATE TABLE limpieza AS SELECT * FROM temp_limpieza;
DROP TABLE conduplicados;

-- Disable safe updates for unrestricted modifications
SET sql_safe_updates = 0;

-- Inspect table structure
DESCRIBE limpieza;

-- ================== TRIMMING SPACES ================== --
-- Detect names with leading/trailing spaces
SELECT name FROM limpieza
WHERE length(name) - length(trim(name)) > 0;

-- Preview cleaned names
SELECT name, trim(name) AS trimmed_name
FROM limpieza
WHERE length(name) - length(trim(name)) > 0;

-- Apply trimming to 'name' field
UPDATE limpieza SET name = trim(name)
WHERE length(name) - length(trim(name)) > 0;

-- Repeat trimming process for last names
SELECT last_name, trim(last_name) AS trimmed_last_name
FROM limpieza
WHERE length(last_name) - length(trim(last_name)) > 0;

UPDATE limpieza SET last_name = trim(last_name)
WHERE length(last_name) - length(trim(last_name)) > 0;

-- Replace multiple spaces within 'area'
UPDATE limpieza SET area = REPLACE(area, ' ', '       ');
CALL limp();

-- Detect multiple spaces using regex
SELECT area FROM limpieza WHERE area REGEXP '\\s{2,}';

-- Preview replacement of multiple spaces with a single one
SELECT area, trim(regexp_replace(area, '\\s+', ' ')) AS cleaned_area FROM limpieza;

-- Apply regex-based cleanup to 'area'
UPDATE limpieza SET area = trim(regexp_replace(area, '\\s+', ' '));
CALL limp();

-- ================== STANDARDIZING GENDER ================== --
-- Preview gender translation
SELECT gender,
CASE
	WHEN gender = 'hombre' THEN 'male'
	WHEN gender = 'mujer' THEN 'female'
	ELSE 'other'
END AS gender_standardized
FROM limpieza;

-- Apply gender normalization
UPDATE limpieza SET gender = CASE
	WHEN gender = 'hombre' THEN 'male'
	WHEN gender = 'mujer' THEN 'female'
	ELSE 'other'
END;
CALL limp();

-- ================== TYPE COLUMN CLEANUP ================== --
DESCRIBE limpieza;

-- Change column type to text for flexibility
ALTER TABLE limpieza MODIFY COLUMN type TEXT;

-- Preview work type conversion
SELECT TYPE,
CASE
	WHEN TYPE = 1 THEN 'remote'
	WHEN TYPE = 0 THEN 'hybrid'
	ELSE 'other'
END AS work_type
FROM limpieza;

-- Apply updates to 'type' column
UPDATE limpieza SET TYPE = CASE
	WHEN TYPE = 1 THEN 'remote'
	WHEN TYPE = 0 THEN 'hybrid'
	ELSE 'other'
END;

-- ================== SALARY CLEANING ================== --
-- Remove '$' and ',' symbols and convert salary to numeric
SELECT salary, 
	cast(trim(REPLACE(REPLACE(salary, '$', ''), ',','')) AS DECIMAL(15, 2)) AS cleaned_salary 
FROM limpieza;

UPDATE limpieza 
SET salary = cast(trim(REPLACE(REPLACE(salary, '$', ''), ',','')) AS DECIMAL(15, 2));

CALL limp();

-- Convert salary column to integer
ALTER TABLE limpieza MODIFY COLUMN salary INT NULL;
DESCRIBE limpieza;

-- ================== DATE CLEANUP: BIRTH DATE ================== --
-- Standardize multiple date formats to YYYY-MM-DD
SELECT birth_date, CASE
	WHEN birth_date LIKE '%/%' THEN date_format(str_to_date(birth_date, '%m/%d/%Y'), '%Y-%m-%d')
	WHEN birth_date LIKE '%-%' THEN date_format(str_to_date(birth_date, '%m-%d-%Y'), '%Y-%m-%d')
	ELSE NULL
END AS new_birth_date
FROM limpieza;

UPDATE limpieza
SET birth_date = CASE
	WHEN birth_date LIKE '%/%' THEN date_format(str_to_date(birth_date, '%m/%d/%Y'), '%Y-%m-%d')
	WHEN birth_date LIKE '%-%' THEN date_format(str_to_date(birth_date, '%m-%d-%Y'), '%Y-%m-%d')
	ELSE NULL
END;

CALL limp();
ALTER TABLE limpieza MODIFY COLUMN birth_date DATE;
DESCRIBE limpieza;

-- ================== DATE CLEANUP: START DATE ================== --
-- Convert start date formats to ISO format
SELECT Start_date, CASE
	WHEN Start_date LIKE '%/%' THEN date_format(str_to_date(Start_date, '%m/%d/%Y'), '%Y-%m-%d')
	WHEN Start_date LIKE '%-%' THEN date_format(str_to_date(Start_date, '%m-%d-%Y'), '%Y-%m-%d')
	ELSE NULL
END AS new_start_date
FROM limpieza;

UPDATE limpieza
SET Start_date = CASE
	WHEN Start_date LIKE '%/%' THEN date_format(str_to_date(Start_date, '%m/%d/%Y'), '%Y-%m-%d')
	WHEN Start_date LIKE '%-%' THEN date_format(str_to_date(Start_date, '%m-%d-%Y'), '%Y-%m-%d')
	ELSE NULL
END;

CALL limp();
ALTER TABLE limpieza MODIFY COLUMN Start_date DATE;
DESCRIBE limpieza;

-- ================== FINISH DATE CLEANUP ================== --
SELECT finish_date FROM limpieza;
CALL limp();

-- Convert finish_date strings into proper DATETIME values
ALTER TABLE limpieza ADD COLUMN date_backup TEXT;
UPDATE limpieza SET date_backup = finish_date; -- Create a backup copy

UPDATE limpieza
	SET finish_date = str_to_date(finish_date, '%Y-%m-%d %H:%i:%s UTC') 
	WHERE finish_date <> '';
    
CALL limp();

-- Split finish_date into separate date and time columns
ALTER TABLE limpieza
	ADD COLUMN fecha DATE,
	ADD COLUMN hora TIME;

UPDATE limpieza
SET fecha = DATE(finish_date),
    hora = TIME(finish_date)
WHERE finish_date IS NOT NULL AND finish_date <> '';

-- Replace empty finish_date values with NULL
UPDATE limpieza SET finish_date = NULL WHERE finish_date = '';

-- Change finish_date type to DATETIME
ALTER TABLE limpieza MODIFY COLUMN finish_date DATETIME;

-- ================== AGE CALCULATION ================== --
ALTER TABLE limpieza ADD COLUMN age INT;
CALL limp();

-- Calculate employee age based on current date
UPDATE limpieza
SET age = timestampdiff(YEAR, birth_date, CURDATE()); 

CALL limp();

-- ================== EMAIL CREATION ================== --
-- Generate company email based on name, last name, and type
ALTER TABLE limpieza ADD COLUMN email VARCHAR(100);
CALL limp();

UPDATE limpieza 
SET email = CONCAT(
	SUBSTRING_INDEX(Name, ' ', 1), '_', 
	SUBSTRING(Last_name, 1, 2), '.', 
	SUBSTRING(Type, 1, 1), 
	'@consulting.com'
); 

CALL limp();

-- ================== FINAL CLEAN DATASET ================== --
-- Export ready-to-use dataset for analysis
SELECT Id_emp, Name, Last_name, age, Gender, area, salary, email, finish_date 
FROM limpieza
WHERE finish_date <= CURDATE() OR finish_date IS NULL
ORDER BY area, Name;

-- Count employees per department for validation
SELECT area, COUNT(*) AS cantidad_empleados 
FROM limpieza
GROUP BY area
ORDER BY cantidad_empleados DESC;





