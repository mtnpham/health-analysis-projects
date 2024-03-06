USE OMOP_TEST;

-- PART I DATA INTEGRATION --

SELECT * FROM person;

SELECT * FROM location;

SELECT o.condition_concept_id, c.concept_name
FROM condition_occurrence o
INNER JOIN concept c 
	ON o.condition_concept_id = c.concept_id
	WHERE c.concept_name LIKE '%malig%'
;

SELECT * FROM condition_occurrence;

SELECT * FROM death;

SELECT * FROM concept;

SELECT DISTINCT state FROM location;

SELECT * FROM procedure_occurrence;

SELECT DISTINCT pr.procedure_source_concept_id, c.concept_name, c.domain_id, c.vocabulary_id, c.concept_class_id
FROM procedure_occurrence pr
LEFT JOIN concept c 
ON pr.procedure_source_concept_id = c.concept_id
WHERE c.concept_name LIKE '%chemother%'
OR c.concept_name LIKE '%immunother%';


SELECT d.drug_source_concept_id, c.concept_name, c.domain_id, c.vocabulary_id, c.concept_class_id
FROM drug_exposure d
LEFT JOIN concept c
ON d.drug_source_concept_id = c.concept_id
WHERE c.concept_name LIKE '%anti%';


SELECT DISTINCT 	p.person_id				AS person_id, 
					g.concept_name			AS gender,
					(year(curdate()) - year_of_birth)  AS Age,
					p.year_of_birth			AS birth_year,
					YEAR(death_date) 		AS death_year,
					l.state					AS state,
					c.concept_name			AS condition_name,
					co.condition_start_date	AS date_onset,
					co.condition_end_date 	AS date_remission,
					po.procedure_concept_id AS procedure_id,
					pr.concept_name			AS procedure_name,
					po.procedure_date		AS procedure_date
FROM person p
	LEFT JOIN 	location l 
		ON 		p.location_id = l.location_id
	LEFT JOIN 	condition_occurrence co 
		ON 		p.person_id = co.person_id
	LEFT JOIN 	concept c 	
		ON 		co.condition_concept_id = c.concept_id
	LEFT JOIN 	concept g 
		ON 		p.gender_concept_id = g.concept_id
	LEFT JOIN 	death d 
		ON 		p.person_id = d.person_id 
	LEFT JOIN 	procedure_occurrence po 
		ON 		po.visit_occurrence_id = co.visit_occurrence_id 
	LEFT JOIN 	concept pr
		ON 		po.procedure_concept_id = pr.concept_id
WHERE c.concept_name LIKE '%malig%'
AND NOT c.concept_name LIKE '%hypertens%'
AND NOT c.concept_name LIKE '%otitis%'
	LIMIT 500;


-- PART II: DATA QUALITY --


SELECT * FROM person 
WHERE month_of_birth > 12
AND month_of_birth < 1;

SELECT * FROM measurement;

SELECT * FROM visit_occurrence;

SELECT * FROM drug_exposure;

SELECT * FROM procedure_occurrence;

SELECT * FROM measurement 
WHERE value_as_numBER IS NOT NULL;


SELECT d.person_id,
       YEAR(death_date) AS  year_of_death,
       p.year_of_birth
FROM death d
JOIN person p ON p.person_id = d.person_id
WHERE 
	(SELECT YEAR(death_date) AS  year_of_death) < year_of_birth;


SELECT  DISTINCT 	c.concept_name,
        			g.concept_name AS gender,
        			co.person_id
FROM condition_occurrence co 
    INNER JOIN  person p
		ON 	co.person_id = p.person_id
	LEFT JOIN 	concept c 
	    ON 	co.condition_concept_id  = c.concept_id
	LEFT JOIN 	concept g   
	    ON 	p.gender_concept_id  = g.concept_id 
WHERE g.concept_name = 'MALE'
AND (
	c.concept_name LIKE '%fallopian%' OR	
	c.concept_name LIKE '%UTER%' OR 	
	c.concept_name LIKE '%OVAR%'OR
	c.concept_name LIKE '%cervix%'
);


SELECT  DISTINCT 	c.concept_name,
        			g.concept_name AS gender,
        			co.person_id
FROM condition_occurrence co 
    INNER JOIN  person p
		ON 	co.person_id = p.person_id
	LEFT JOIN 	concept c 
	    ON 	co.condition_concept_id  = c.concept_id
	LEFT JOIN 	concept g   
	    ON 	p.gender_concept_id  = g.concept_id 
WHERE g.concept_name = 'FEMALE'
AND (
	c.concept_name LIKE '%testic%' OR	
	c.concept_name LIKE '%penis%' OR
	c.concept_name LIKE '%penile%' OR
	c.concept_name LIKE '%prostat%'OR
	c.concept_name LIKE '%seminal%' OR 
	c.concept_name LIKE '%sperm%'
);


SELECT 	p.person_id, l.state, l.county, 
		l.location_source_value
FROM person p
INNER JOIN location l 
	ON p.location_id = l.location_id 
	WHERE l.state BETWEEN 1 AND 100;


SELECT 	DISTINCT 	
	p.person_id,
	co.condition_concept_id, 
	c.concept_name,
	YEAR(condition_start_date) 
		AS  year_onset,
	(YEAR(condition_start_date) - year_of_birth) 
		AS age_onset
FROM condition_occurrence co
	INNER JOIN person p 
		ON p.person_id = co.person_id
	INNER JOIN concept c 
		ON co.condition_concept_id = c.concept_id
ORDER BY age_onset DESC;


SELECT 	p.person_id, 
		co.condition_concept_id, 
		co.condition_source_concept_id,
		c.concept_name,
		c.domain_id,
		c.vocabulary_id, 
		c.concept_class_id
FROM condition_occurrence co
INNER JOIN concept c 
	ON co.condition_source_concept_id = c.concept_id
INNER JOIN person p 
	ON co.person_id = p.person_id
WHERE condition_concept_id = 0;


SELECT 	po.procedure_concept_id, 
		po.procedure_source_concept_id,
		c.concept_name,
		c.domain_id,
		c.vocabulary_id, 
		c.concept_class_id 
FROM procedure_occurrence po
LEFT JOIN concept c 
ON po.procedure_source_concept_id = c.concept_id
WHERE po.procedure_concept_id = 0
AND c.concept_name = ('');


SELECT 	po.procedure_concept_id, 
		po.procedure_source_concept_id,
		c.concept_name,
		COUNT(procedure_occurrence_id) 
			AS count_not_mapped
FROM procedure_occurrence po
LEFT JOIN concept c 
ON po.procedure_source_concept_id = c.concept_id
WHERE po.procedure_concept_id = 0
AND c.concept_name = ('')
GROUP BY procedure_source_concept_id;


SELECT 	po.procedure_concept_id, 
		po.procedure_source_concept_id,
		c.concept_name,
		COUNT(procedure_occurrence_id) 
			AS count_mapped
FROM procedure_occurrence po
LEFT JOIN concept c 
ON po.procedure_source_concept_id = c.concept_id
WHERE po.procedure_concept_id = 0
AND NOT c.concept_name = ('')
GROUP BY procedure_source_concept_id;


-- PART III: CREATING ANALYTICAL COHORTS -- 

DROP TABLE CANCER;

CREATE TEMPORARY TABLE CANCER
   (
   condition_concept_id INTEGER,
   condition_concept_name VARCHAR(250),
   condition_concept_code VARCHAR(50),
   condition_concept_class VARCHAR(20),
   condition_concept_vocab_id VARCHAR(20),
   is_disease_concept_flag CHAR(10)
   );

INSERT INTO CANCER 	 
	 SELECT
  c.concept_id       AS condition_concept_id,
  c.concept_name     AS condition_concept_name,
  c.concept_code     AS condition_concept_code,
  c.concept_class_id AS condition_concept_class,
  c.vocabulary_id    AS condition_concept_vocab_id,
  CASE c.vocabulary_id
  WHEN 'SNOMED'
    THEN CASE lower(c.concept_class_id)
         WHEN 'clinical finding'
           THEN 'Yes'
         ELSE 'No' END
  WHEN 'MedDRA'
    THEN 'Yes'
  ELSE 'No'
  END                AS is_disease_concept_flag
FROM concept AS c
WHERE	c.concept_name LIKE '%malig%'
AND NOT c.concept_name LIKE '%hypertens%'
AND NOT c.concept_name LIKE '%otitis%';

SELECT * FROM CANCER;

DROP TABLE cancer_cohort;

CREATE TEMPORARY TABLE cancer_cohort  
SELECT DISTINCT 
	co.person_id,
	co.condition_start_date,
    co.condition_concept_id, 
    c.concept_name
FROM condition_occurrence co
LEFT JOIN concept c 
	ON co.condition_concept_id = c.concept_id
WHERE condition_concept_id IN 
    (SELECT DISTINCT condition_concept_id 
          FROM CANCER)
ORDER BY person_id;

SELECT * FROM cancer_cohort; 

DROP TABLE cancer_procedure;

CREATE TEMPORARY TABLE cancer_procedure
SELECT DISTINCT 
	po.person_id,
    po.procedure_date, 
    c.concept_name
FROM procedure_occurrence po
LEFT JOIN concept c 
	ON po.procedure_source_concept_id = c.concept_id
WHERE person_id IN 
    (SELECT DISTINCT person_id 
          FROM cancer_cohort);
         
SELECT * FROM cancer_procedure
WHERE NOT concept_name = ('');

DROP TABLE cancer_mortality;

CREATE TEMPORARY TABLE cancer_mortality
SELECT DISTINCT
    d.person_id,
    d.death_date
FROM death d
WHERE person_id IN 
    (SELECT DISTINCT person_id 
          FROM cancer_cohort);

SELECT * FROM cancer_mortality;

CREATE TEMPORARY TABLE cancer_registry
SELECT 	cc.person_id,
		p.year_of_birth,
		cc.condition_start_date,
		cc.concept_name AS condition_name, 
		cm.death_date,
		(
		CASE WHEN death_date IS NULL THEN 'alive'
		ELSE 'dead'
		END) AS vital_status
FROM cancer_cohort cc
LEFT JOIN cancer_mortality cm
	ON cc.person_id = cm.person_id
LEFT JOIN person p 
	ON cc.person_id = p.person_id;

SELECT * FROM cancer_registry;

SELECT 	re.*, cp.procedure_date, 
		cp.concept_name AS treatme
FROM cancer_registry re
	INNER JOIN cancer_procedure cp 
	ON re.person_id = cp.person_id
WHERE cp.concept_name LIKE '%chemother%'
OR cp.concept_name LIKE '%immunother%';


SELECT
      re.vital_status,     
      COUNT(person_id) AS num_persons
FROM cancer_registry re 
  GROUP BY 
      re.vital_status;
