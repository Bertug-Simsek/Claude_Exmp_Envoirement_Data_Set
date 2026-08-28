--- Checking the Tables if the number are equal with the excel report.---

SELECT COUNT(*) FROM facilities;
SELECT COUNT(*) FROM departments;
SELECT COUNT(*) FROM energy_emission_records;

--- Everthing seem fine, lets continue.---
--- Now we will check the null values or off values---

SELECT COUNT(*) FROM energy_emission_records 
WHERE consumption_amount IS NULL;

--- We have (455) null values on cansumption_amount. ---
---Now lets check the city names if everything fine---
SELECT DISTINCT city, TRIM(UPPER(city)) AS city_standard
FROM facilities;
---As we see, most of the city names typed randomly withour following---
---any upper/lower case rules---

--- 1. Cleaning facilities information.---

CREATE VIEW clean_facilities AS
SELECT 
   facility_code,
   TRIM(facility_name) AS facility_name,
   CASE UPPER(TRIM(city))
   WHEN 'AMSTERDAM' THEN 'Amsterdam' WHEN 'ROTTERDAM' THEN 'Rotterdam'
    WHEN 'BERLIN' THEN 'Berlin' WHEN 'PARIS' THEN 'Paris'
    WHEN 'BRUSSELS' THEN 'Brussels' WHEN 'WARSAW' THEN 'Warsaw'
    WHEN 'MILAN' THEN 'Milan' WHEN 'BARCELONA' THEN 'Barcelona'
    ELSE TRIM(city)
    END AS city,
    COALESCE (sector, 'Not Specified') AS sector

FROM facilities;


---Now we created a view, lets check it.---

SELECT * FROM clean_facilities;

---Perfect, lets continue.---


---2. Cleaning departments information."

CREATE VIEW clean_departments AS
SELECT
department_id,
CASE
    WHEN LOWER(department_name) LIKE '%production%' THEN 'Production'
    WHEN LOWER(department_name) LIKE '%logistic%' THEN 'Logistics'
    WHEN LOWER(department_name) LIKE '%human resources%' THEN 'Human Resources'
    ELSE TRIM(department_name)
END AS department_name,
facility_code,
COALESCE( NULLIF( TRIM(manager_name)  , ''  )   ,  'Not Assigned'   ) AS manager_name
FROM departments;

---3. Cleaning Emission Records information.---

SELECT * FROM energy_emission_records
LIMIT 60 ;

---3.1---

CREATE VIEW clean_energy_step1 AS
SELECT
record_id, facility_code,department_id,date,

CASE UPPER(TRIM(energy_type))
WHEN 'ELECTRICITY' THEN 'Electricity'
WHEN 'DIESEL' THEN 'Diesel'
WHEN 'NATURAL GAS' THEN 'Natural Gas'
WHEN 'PETROL' THEN 'Petrol'
WHEN 'LPG' THEN 'Lpg'
ELSE TRIM(energy_type)
END AS energy_type,

CASE UPPER(TRIM(scope))
WHEN 'SCOPE 1' THEN 'Scope 1' WHEN 'SCOPE 2' THEN 'Scope 2'
ELSE NULL 
END AS scope,

CASE
WHEN TRIM(consumption_amount) IN ('NULL','N/A','-','#N/A','unknown','none','') THEN NULL
ELSE CAST(consumption_amount AS REAL)
END AS consumption_amount,

CASE 
WHEN TRIM(co2_emission_tons) IN ('NULL','N/A','-','#N/A','unknown','none','') THEN NULL
ELSE CAST(co2_emission_tons AS REAL)
END AS co2_emission_tons

FROM energy_emission_records;

---3.2---
CREATE VIEW clean_energy_step2 AS
SELECT *,
  CASE WHEN consumption_amount < 0 THEN NULL ELSE consumption_amount END AS consumption_fixed
FROM clean_energy_step1;
---
---4. Fixing date formats.---

CREATE VIEW clean_energy_step3 AS
SELECT
   record_id, facility_code, department_id, energy_type, scope, consumption_amount, co2_emission_tons,
   CASE
     WHEN date LIKE '____-__-__' THEN date
     WHEN date LIKE '__/__/____' THEN

       printf('%04d-%02d-%02d',
               CAST (substr(date, 7, 4) AS INTEGER),
               CAST (substr(date, 4, 2) AS INTEGER),
               CAST (substr(date, 1, 2) AS INTEGER)
              )


        WHEN date LIKE '__.__.____' THEN
        printf( '%04d-%02d-%02d',
                CAST(substr (date,7,4) AS INTEGER),
                CAST(substr (date,4,2) AS INTEGER),
                CAST(substr (date,1,2) AS INTEGER)
               )

        WHEN date LIKE '__-__-____' THEN
        printf( '%04d-%02d-%02d',
                CAST(substr (date,7,4) AS INTEGER),
                CAST(substr (date,1,2) AS INTEGER),
                CAST(substr (date,4,2) AS INTEGER)
               )

        ELSE NULL
        END AS date_iso
FROM clean_energy_step2;

--- 5. Eliminating Duplicate Lines.---
CREATE VIEW clean_energy_final AS
SELECT
  MIN(record_id) AS record_id,
  facility_code, department_id, date_iso, energy_type, scope,
  consumption_amount, co2_emission_tons
FROM clean_energy_step3
GROUP BY facility_code, department_id, date_iso, energy_type, scope, consumption_amount, co2_emission_tons;

SELECT * FROM clean_energy_final;


---6. Joining tables. Now, we have 3 cleaned table view.---

SELECT * FROM clean_energy_final ;

SELECT * FROM  clean_departments;

SELECT * FROM  clean_facilities;
---  ((facility code to facility code)this have departmant id) to departmant id.--- 

DROP VIEW IF EXISTS v_pre_audit;
CREATE VIEW v_pre_audit AS
SELECT
cf.facility_name, cf.city, cf.sector,
  cd.department_name,
  ce.date_iso, ce.energy_type, ce.scope, ce.consumption_amount, ce.co2_emission_tons
FROM clean_energy_final ce
      LEFT JOIN clean_facilities cf ON ce.facility_code = cf.facility_code 
      LEFT JOIN clean_departments cd ON cf.facility_code = cd.facility_code;


SELECT * FROM v_pre_audit;

---7. Data Quality Score KPI---

CREATE VIEW kpi_data_quality AS
SELECT
facility_name, 
COUNT(*) AS total_record,
SUM(CASE WHEN consumption_amount IS NULL THEN 1.0 ELSE 0.0 END) AS total_null,
ROUND(((SUM(CASE WHEN consumption_amount IS NULL THEN 1.0 ELSE 0.0 END)) * 100)/ COUNT(*), 2) AS null_percentage

FROM v_pre_audit
GROUP BY facility_name;

SELECT * FROM kpi_data_quality;

---8.Total Emission KPI by Scope---

CREATE VIEW kpi_emission_by_scope AS
SELECT facility_name, scope, ROUND(SUM(co2_emission_tons), 2) AS total_co2_ton
FROM v_pre_audit
WHERE scope IS NOT NULL
GROUP BY facility_name, scope
ORDER BY total_co2_ton DESC
; 

SELECT * FROM kpi_emission_by_scope;

---9. Monthly Emission trend KPI.---

SELECT * FROM v_pre_audit;

CREATE VIEW kpi_monthly_trend AS
SELECT
  strftime('%Y-%m', date_iso) AS month,
  ROUND(SUM(co2_emission_tons), 2) AS monthly_total_co2
FROM v_pre_audit
WHERE date_iso IS NOT NULL
GROUP BY month
ORDER BY month;

---10. Last step and Finish.---
SELECT
  (SELECT COUNT(*) FROM energy_emission_records) AS raw_row_count,
  (SELECT COUNT(*) FROM v_pre_audit)             AS clean_row_count,
  (SELECT COUNT(*) FROM energy_emission_records) - (SELECT COUNT(*) FROM v_pre_audit) AS subtraction;