LIBNAME CMS "/courses/dd667415ba27fe300/MEDICARE_DESYNPUF" access=readonly ;

LIBNAME GRP "/courses/dd667415ba27fe300/GROUPERS" access=readonly ;


proc contents data=cms.inpatient_elx_grp details; run;

proc contents data=cms.bene_09_10 details; run;


/* PART I: IDENTIFYING SUPER-UTILIZERS */

/* SUM TOTAL AMOUNTS PER PATIENT NO NEGATIVES*/

PROC SQL;
	CREATE TABLE superusers AS
	SELECT DESYNPUF_ID,
	SUM(CLM_PMT_AMT) AS TOTAL_AMT
	FROM CMS.INPATIENT_ELX_GRP
	WHERE CLM_PMT_AMT > 0
	GROUP BY DESYNPUF_ID
	ORDER BY TOTAL_AMT DESC;
QUIT;

PROC FREQ DATA = superusers;
	TABLE TOTAL_AMT;
RUN;

proc univariate data= superusers;
	var TOTAL_AMT;
	histogram total_amt;
run;

/* SELECT TOP 5 PERCENT */

PROC SQL;
	CREATE TABLE TOP_5 AS 
	SELECT A.*, B.*
	FROM CMS.INPATIENT_ELX_GRP A
	INNER JOIN superusers B 
	ON A.DESYNPUF_ID = B.DESYNPUF_ID
	WHERE total_amt > 56000;
QUIT;

PROC SQL;
	SELECT COUNT(DISTINCT DESYNPUF_ID) AS CNT_REC
	FROM top_5;
QUIT;	/*3596*/

PROC SQL;
	CREATE TABLE top_beneficiary AS 
	SELECT DISTINCT A.BENE_BIRTH_DT AS BIRTHDATE,
			 		A.BENE_RACE_CD AS RACE,
			 		A.BENE_SEX_IDENT_CD AS SEX,
			 		A.SP_STATE_CODE AS STATE,
			 		B.*
	FROM cms.bene_09_10 A
	INNER JOIN top_5 B 
	ON A.DESYNPUF_ID = B.DESYNPUF_ID;
QUIT;

DATA top_beneficiary;
	SET top_beneficiary;
	AGE_AT_DSCHRG= (NCH_BENE_DSCHRG_DT - birthdate) / 365.25;
run;

proc univariate data= top_beneficiary;
	var age_at_dschrg;
	histogram age_at_dschrg;
run;

/* CREATE HYPERTENSION COHORT USING ELIXHAUSER GROUPER*/

proc freq data=top_beneficiary;
tables 	elx_grp_1 elx_grp_2 elx_grp_3 elx_grp_4 elx_grp_5 elx_grp_6 elx_grp_7 elx_grp_8 elx_grp_9 elx_grp_10 
		elx_grp_11 elx_grp_12 elx_grp_13 elx_grp_14 elx_grp_15 elx_grp_16 elx_grp_17 elx_grp_18 elx_grp_19 elx_grp_20
		elx_grp_21 elx_grp_22 elx_grp_23 elx_grp_24 elx_grp_25 elx_grp_26 elx_grp_27 elx_grp_28 elx_grp_29 elx_grp_30 elx_grp_31;
run;

data study_disease;
	set top_beneficiary;
	hypertension = 0;
	if elx_grp_6 = 1 or elx_grp_7 = 1 
	then hypertension = 1;
run;

PROC SQL;
	CREATE TABLE HYPERTENSION AS
	SELECT 	DESYNPUF_ID, AGE_AT_DSCHRG, CLM_PMT_AMT, RACE, SEX, STATE, TOTAL_AMT, TOT_GRP, HYPERTENSION,
			elx_grp_1, elx_grp_2, elx_grp_3, elx_grp_4, elx_grp_5, elx_grp_6, elx_grp_7, elx_grp_8, elx_grp_9, elx_grp_10, 
			elx_grp_11, elx_grp_12, elx_grp_13, elx_grp_14, elx_grp_15, elx_grp_16, elx_grp_17, elx_grp_18, elx_grp_19, elx_grp_20,
			elx_grp_21, elx_grp_22, elx_grp_23, elx_grp_24, elx_grp_25, elx_grp_26, elx_grp_27, elx_grp_28, elx_grp_29, elx_grp_30, elx_grp_31
	FROM STUDY_DISEASE
	WHERE HYPERTENSION = 1
	ORDER BY DESYNPUF_ID, CLM_PMT_AMT DESC;
QUIT;

PROC SQL;
	SELECT COUNT(DISTINCT DESYNPUF_ID) AS CNT_REC
	FROM HYPERTENSION;
QUIT;	/*2899*/

data hyper_single; 
	set hypertension;
  	by desynpuf_id;
  	if first.desynpuf_id then output;
run;

/*DESCRIPTIVE STATISTICS FOR SUPER-UTILIZER HYPERTENSION COHORT */

proc univariate data= hyper_single;
	var age_at_dschrg;
	histogram age_at_dschrg / midpoints=25 to 105 by 10
							barlabel=percent;
run;

proc freq data=hyper_single;
tables state race sex tot_grp;
table sex/chisq; 
proc sort data=hyper_single;
by state;
run;

proc means data=hyper_single N Mean Median Std Min Max;
var total_amt;
class state;
ods output Summary=meansdata;
run;

proc sort data= meansdata;
by descending total_amt_median;
proc print data=meansdata;
run;

proc sgplot data=hyper_single;
series y=total_amt x=state / markers;
yaxis label='Total Cost';
run;

/*TRANSPOSING TABLE TO "TRANSACTION" FORMAT FOR ENTERPRISE MINER*/

proc sort data=hyper_single
(keep= 	desynpuf_ID elx_grp_1 elx_grp_2 elx_grp_3 elx_grp_4 elx_grp_5 elx_grp_6 elx_grp_7 elx_grp_8 elx_grp_9 elx_grp_10 
		elx_grp_11 elx_grp_12 elx_grp_13 elx_grp_14 elx_grp_15 elx_grp_16 elx_grp_17 elx_grp_18 elx_grp_19 elx_grp_20
		elx_grp_21 elx_grp_22 elx_grp_23 elx_grp_24 elx_grp_25 elx_grp_26 elx_grp_27 elx_grp_28 elx_grp_29 elx_grp_30 elx_grp_31
);
by desynpuf_ID;
run;

proc transpose data=hyper_single
 out=hyper_trans (rename=(COL1=status _NAME_=disease));
 by desynpuf_ID;
run;

data hyper_final;
	set hyper_trans;
	where status = 1;
run;

PROC SQL;
	SELECT COUNT(DISTINCT DESYNPUF_ID) AS CNT_REC
	FROM hyper_final;
QUIT;

/* PERMANENT TABLE FOR USE IN ENTERPRISE MINER */
libname super '/home/u61852647/hca203/SuperUtilizers';
data super.top_beneficiary;
set work.top_beneficiary;
run;
proc contents data=super.top_beneficiary details; run;
data super.hyper_single;
set work.hyper_single;
run;
data super.hyper_final;
set work.hyper_final;
run;
/* END OF MINER PREP
RESULTS: COMPLICATED HYPERTENSION (ELX_GRP_7) AND RENAL FAILURE (ELX_GRP_14) */

/*---------------------------------------------------------*/
/* PART II: HOSPITAL READMISSIONS OF TOP 5% SUPER-UTILIZERS */

/* REMOVE BLANK ROWS FROM ADMISSIONS */

data admission;
set top_beneficiary;
if clm_id ne .;
run;	/*15,422*/

proc sort data = admission;
by desynpuf_id clm_from_dt; 
run;	

/* COUNT NUMBER OF ADMISSIONS PER PATIENT */ 
 	
data admit_count;
retain SEQ;
set admission;
SEQ + 1;
by desynpuf_id clm_from_dt;
if first.desynpuf_id then SEQ = 1;
run;

/* CALCULATE CUMULATIVE READMISSIONS WITHIN 30 DAYS */

data readmit;
set admit_count;
by desynpuf_id SEQ;

Ref_date = LAG(CLM_THRU_DT); /*Retrieve the value of the previous discharge date*/
Format Ref_Date YYMMDD10.;
Label Ref_Date = 'Reference Date';

Gap = CLM_FROM_DT - Ref_Date; 

If First.DESYNPUF_ID then do; 
Ref_date = .;
Gap = .;
Tag = .;
Readmissions = .;
End;

If 0 <= Gap <= 30 then Tag = 1; 
Readmissions + Tag; 
Run;

proc freq data = readmit;
table readmissions;
run;

/*-----------------------------------------------------*/
/* PART III: RISK STRATIFICATION MODEL OF READMISSIONS */

PROC SQL;
SELECT COUNT(DISTINCT DESYNPUF_ID) AS CNT_REC
FROM TOP_BENEFICIARY
QUIT;	/*3596*/

/* CREATE ONE ROW PER DESYNPUF_ID FOR ADMISSIONS */

PROC SQL;
	CREATE TABLE admit_sum AS
	SELECT 	DESYNPUF_ID, AGE_AT_DSCHRG, CLM_PMT_AMT, RACE, SEX, STATE, TOTAL_AMT, TOT_GRP, READMISSIONS,
			elx_grp_1, elx_grp_2, elx_grp_3, elx_grp_4, elx_grp_5, elx_grp_6, elx_grp_7, elx_grp_8, elx_grp_9, elx_grp_10, 
			elx_grp_11, elx_grp_12, elx_grp_13, elx_grp_14, elx_grp_15, elx_grp_16, elx_grp_17, elx_grp_18, elx_grp_19, elx_grp_20,
			elx_grp_21, elx_grp_22, elx_grp_23, elx_grp_24, elx_grp_25, elx_grp_26, elx_grp_27, elx_grp_28, elx_grp_29, elx_grp_30, elx_grp_31
	FROM READMIT
	ORDER BY DESYNPUF_ID, READMISSIONS DESC;
QUIT;

data top_readmit; 
	set admit_sum;
	by desynpuf_id;
  		if readmissions = "." then sum_admit = 0;
  		else sum_admit = readmissions;
  	if first.desynpuf_id then output;
run;

proc contents data = top_readmit; run;

data admit_fit;
retain admit_outcome;
set top_readmit;
	if sum_admit > 0 then admit_outcome = 1;
	else admit_outcome = 0;

/* CREATE TRAINING AND VALIDATION SAMPLES */

PROC SURVEYSELECT DATA= ADMIT_FIT OUT= ADMIT_TRAIN METHOD=srs SAMPRATE=0.7;
RUN;

PROC SURVEYSELECT DATA= ADMIT_FIT OUT= ADMIT_VALIDATE METHOD=srs SAMPRATE=0.3;
RUN;

/* FIT MODEL TO TRAINING SET AND SCORE VALIDATION SET */

proc logistic data= ADMIT_TRAIN OUTMODEL=ADMIT_TRAIN_OUT;
CLASS SEX RACE;
model admit_outcome (EVENT='1') = AGE_AT_DSCHRG RACE SEX TOTAL_AMT TOT_GRP elx_grp_6 elx_grp_30 
;	/* BACKWARDS SELECTION REMOVED CONDITIONS NOT MEETING THE 95% CI */

output out=SCORE1 P=PRED;
score data= ADMIT_VALIDATE out=SCORE2;
run;

/* LOOK AT THE PREDICTED PROBABILITIES BY SORTING THEM */
PROC SORT DATA= SCORE1;
BY DESCENDING PRED; RUN;

/* STRATIFY PATIENTS INTO RISK GROUPS */
DATA RISK;
SET SCORE1;

IF PRED < .3 THEN RISK_TRAIN = 'LOW ';
ELSE IF PRED >= .3 AND PRED < .7 THEN RISK_TRAIN = 'MEDIUM';
ELSE IF PRED >= .7 THEN RISK_TRAIN = 'HIGH';
RUN;

/* COUNT NUMBER OF PATIENTS IN BINS */
PROC FREQ DATA=RISK;
TABLE RISK_TRAIN;
RUN;

/* Score the validation data set using saved model information*/

proc logistic inmodel=ADMIT_TRAIN_OUT;
score data= ADMIT_VALIDATE out=Score2;
run;

DATA RISK2;
SET SCORE2;

IF P_1 < .3 THEN RISK_VALIDATE = 'LOW ';
ELSE IF P_1 >= .3 AND P_1 < .7 THEN RISK_VALIDATE = 'MEDIUM';
ELSE IF P_1 >= .7 THEN RISK_VALIDATE = 'HIGH';
RUN;

/* COUNT NUMBER OF PATIENTS IN BINS */
PROC FREQ DATA=RISK2;
TABLE RISK_VALIDATE;
RUN;

/* CONCLUSION: Patients can be stratified into risk groups using a logistic model 
that predicts risk of readmission from presence of hypertension and psychoses.
Based on this predictive model, patients with hypertension and psychoses 
are 1.2 and 2.0 times more likely to have a readmission within 30 days, respectively. 
Though renal failure has high likelihood of co-occurring with hypertension, 
it was not significant in the predictive model. */

