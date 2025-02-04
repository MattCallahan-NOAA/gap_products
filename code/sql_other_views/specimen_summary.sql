-- DRAFT WORKING SUMMARY TABLE OF SAMPLED LENGTHS AND OTOLITHS. 
-- LONG VERSION OF TABLE.

WITH 
--TEMPORARY TABLE 1: SUMMARY BIOMASS
--THIS IS THE REGIONAL-LEVEL RECORDS FROM GAP_PRODUCTS.BIOMASS
--FOR THOSE SPECIES_CODES WHERE A LENGTH SAMPLE (OR SUBSAMPLE) WAS TAKEN
SUMMARY_BIOMASS AS (
SELECT SURVEY_DEFINITION_ID, YEAR, AREA_ID, SPECIES_CODE, N_HAUL, N_LENGTH 
FROM GAP_PRODUCTS.BIOMASS 
WHERE N_LENGTH > 0
AND YEAR > 2004 AND YEAR != 2025
AND SURVEY_DEFINITION_ID IN (47, 52, 78, 98, 143)
AND AREA_ID IN (99900, 99902, 99903, 99904, 99905)
),
--TEMPORARY TABLE 2: TEMP_OTOLITH
--FROM GAP_PRODUCTS.AKFIN_SPECIMEN WITH ADDED HAUL INFORMATION
--THIS TABLE ONLY HAS OTOLITHS FROM ABUNDANCE_HAUL = 'Y' HAULS
TEMP_OTOLITH AS (
SELECT HAULJOIN, SURVEY_DEFINITION_ID, YEAR, SPECIES_CODE, AGE, 
CASE WHEN AGE > 0 THEN 1 ELSE 0 END AS NULL_AGE
FROM GAP_PRODUCTS.AKFIN_SPECIMEN

JOIN (SELECT HAULJOIN, CRUISEJOIN FROM GAP_PRODUCTS.AKFIN_HAUL)
USING (HAULJOIN)
JOIN (SELECT CRUISEJOIN, YEAR, SURVEY_DEFINITION_ID FROM GAP_PRODUCTS.AKFIN_CRUISE)
USING (CRUISEJOIN)

WHERE GAP_PRODUCTS.AKFIN_SPECIMEN.SPECIMEN_SAMPLE_TYPE = 1
), 
--TEMPORARY TABLE 3: SUMMARY_OTOLITH
--TABULATION OF THE NUMBER OF COLLECTED OTOLITHS AND THE NUMBER OF READ OTOLITHS
SUMMARY_OTOLITH AS (
SELECT  
SURVEY_DEFINITION_ID, YEAR, SPECIES_CODE,
COUNT(DISTINCT HAULJOIN) AS N_SAMPLE, 
COUNT(NULL_AGE) AS COUNT_OTOLITH,
SUM(NULL_AGE) AS COUNT_AGE

FROM TEMP_OTOLITH
GROUP BY SPECIES_CODE, SURVEY_DEFINITION_ID, YEAR
),
--TEMPORARY TABLE 4: SUMMARY_LENGTH
--TABULATION OF THE NUMBER OF SAMPLED LENGTHS FROM RACE_DATA.LENGTHS
--RACE_DATA.LENGTHS ONLY GO BACK TO 2005 WHICH MAKES SENSE
--DOESN'T NECESSARILY REMOVE SAMPLED LENGTHS FROM HAULS WITH ABUNDANCE_HAUL != 'Y', I THINK..
SUMMARY_LENGTH AS (
SELECT  SD.SURVEY_DEFINITION_ID,
        A.CRUISE,
        FLOOR(A.CRUISE/100) YEAR,
        C.SPECIES_CODE SPECIES_CODE,
        SUM(C.FREQUENCY) COUNT_LENGTH
 FROM RACE_DATA.CRUISES A
 JOIN RACE_DATA.SURVEYS S
   ON (S.SURVEY_ID = A.SURVEY_ID)
 JOIN RACE_DATA.SURVEY_DEFINITIONS SD
   ON (SD.SURVEY_DEFINITION_ID = S.SURVEY_DEFINITION_ID)
 JOIN RACE_DATA.HAULS B
   ON (B.CRUISE_ID = A.CRUISE_ID)
 JOIN RACE_DATA.LENGTHS C
   ON (C.HAUL_ID = B.HAUL_ID)
 GROUP BY SD.SURVEY_DEFINITION_ID,
          A.CRUISE,
          C.SPECIES_CODE
)

-- FINALLY, UNITE THE LENGTH, OTOLITH, AND READ OTOLITH DATA
-- Wrangle Length Data
SELECT SUMMARY_BIOMASS.SURVEY_DEFINITION_ID, SUMMARY_BIOMASS.SPECIES_CODE, 
SUMMARY_BIOMASS.YEAR, 'LENGTH' AS SPECIMEN_SAMPLE_TYPES, 
SUMMARY_BIOMASS.N_LENGTH AS N_SAMPLE, SUMMARY_LENGTH.COUNT_LENGTH AS COUNT
FROM SUMMARY_BIOMASS 
JOIN SUMMARY_LENGTH 
ON SUMMARY_BIOMASS.SURVEY_DEFINITION_ID = SUMMARY_LENGTH.SURVEY_DEFINITION_ID
AND SUMMARY_BIOMASS.SPECIES_CODE = SUMMARY_LENGTH.SPECIES_CODE
AND SUMMARY_BIOMASS.YEAR = SUMMARY_LENGTH.YEAR

UNION

-- Wrangle Otolith Data
SELECT SUMMARY_BIOMASS.SURVEY_DEFINITION_ID, SUMMARY_BIOMASS.SPECIES_CODE, 
SUMMARY_BIOMASS.YEAR, 'OTOLITH' AS SPECIMEN_SAMPLE_TYPES,
SUMMARY_OTOLITH.N_SAMPLE, SUMMARY_OTOLITH.COUNT_OTOLITH AS COUNT
FROM SUMMARY_BIOMASS 
JOIN SUMMARY_OTOLITH
ON SUMMARY_BIOMASS.SURVEY_DEFINITION_ID = SUMMARY_OTOLITH.SURVEY_DEFINITION_ID
AND SUMMARY_BIOMASS.SPECIES_CODE = SUMMARY_OTOLITH.SPECIES_CODE
AND SUMMARY_BIOMASS.YEAR = SUMMARY_OTOLITH.YEAR

UNION

-- Wrangle Read Otolith Data
SELECT SUMMARY_BIOMASS.SURVEY_DEFINITION_ID, SUMMARY_BIOMASS.SPECIES_CODE, 
SUMMARY_BIOMASS.YEAR, 'AGE' AS SPECIMEN_SAMPLE_TYPES,
SUMMARY_OTOLITH.N_SAMPLE, SUMMARY_OTOLITH.COUNT_AGE AS COUNT
FROM SUMMARY_BIOMASS 
JOIN SUMMARY_OTOLITH
ON SUMMARY_BIOMASS.SURVEY_DEFINITION_ID = SUMMARY_OTOLITH.SURVEY_DEFINITION_ID
AND SUMMARY_BIOMASS.SPECIES_CODE = SUMMARY_OTOLITH.SPECIES_CODE
AND SUMMARY_BIOMASS.YEAR = SUMMARY_OTOLITH.YEAR

ORDER BY YEAR, SURVEY_DEFINITION_ID, SPECIES_CODE
