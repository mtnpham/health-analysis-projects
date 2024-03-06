/*Set Up Code */

libname hca202in "/courses/d70e69e5ba27fe300"
access=readonly;
libname hca202 "~/hca202";

data hca202.frmgham;
	set hca202in.frmgham;
run;


/*Data Transformation*/

data baseline; 
  set hca202in.frmgham; 
  if period=1 and diabetes=1 
  then DELETE;
run;

data frmg2;
set baseline;
keep sex period time randid hichol totchol diabetes bmi age;
if totchol>=240 then do hichol=1;
end;
else do; hichol=0;
end;
run;

data frmg8; 
  set baseline; 
  if hdlc=. then DELETE;
run;

data frmg8;
set frmg8;
keep sex period time randid hdlc ldlc hiLDLC lowHDLC diabetes bmi age;
	if ldlc>=160 then do hiLDLC=1;
end;
	else do; hiLDLC=0;
end;
if sex=1 then do;
	if hdlc<40 then lowHDLC=1; 
	else lowHDLC=0; 
end;
if sex=2 then do;
	if hdlc<50 then lowHDLC=1; 
	else lowHDLC=0; 
end;
run;

/*Create TIMECHOL variable*/

data frmg3(keep=randid timechol censrchol);
set frmg2;
by randid time;
retain timechol;
	if first.randid then timechol=.;
	if (hichol=1) and timechol=. then 
	timechol=time;
	if last.randid then do;
	if timechol=. then do;
	timechol=time;
	censrchol=0; end;
else censrchol=1; end;
	if last.randid then output;
run;

proc sql; 
create table frmg4 as
select * from frmg2
full join frmg3
on frmg2.randid=frmg3.randid;
quit;

proc sort data=frmg4; 
  by randid period;
run;

/*Create TIMEDIAB variable*/

data frmg5(keep=randid timediab censrdiab);
set frmg4;
by randid time;
retain timediab;
	if first.randid then timediab=.;
	if (diabetes=1) and timediab=. then 
	timediab=time;
	if last.randid then do;
	if timediab=. then do;
	timediab=time;
	censrdiab=0; end;
else censrdiab=1; end;
	if last.randid then output;
run;

proc sql; 
create table frmg6 as
select * from frmg4
full join frmg5
on frmg4.randid=frmg5.randid;
quit;

proc sort data=frmg6; 
  by randid period;
run;

/*Create EXPOSURE variable*/
data frmg6;
set frmg6;
by randid;
keep sex period time randid hichol diabetes bmi age timechol timediab exposure;
retain exposure;
if timechol < timediab then do;
	exposure=1; end;
else do; exposure=0; end;
run;

/*Create NEWEVNT variable*/
proc sort data=frmg6; 
  by randid descending period;
run;

data frmg6; 
  set frmg6; 
  by randid; 
 retain exmtime;
 if first.randid then do;
 	newevnt=diabetes;
    endtime=timediab; 
    exmtime=time; 
  end;
  else do;
     newevnt=0; 
     endtime=exmtime;
     exmtime=time; 
  end;
run;

proc sort data=frmg6; 
  by randid period;
run;

data frmg7; 
  set frmg6;
  by randid;
  if last.randid then output;
run;

/*Statistics and Results*/

proc corr data=baseline;
	title ‘Population Summary’;
	var sex age BMI totchol LDLC HDLC;
run;

proc corr data=frmg7;
	title 'Population Summary';
	var sex age BMI;
run;

proc freq data=frmg7;
title 'Diabetes Frequency'; 
table diabetes/chisq;
table hichol/chisq;
table newevnt*exposure/cmh chisq norow nopercent;
run;
 
proc logistic data=frmg7 descending;
	title 'Aim 1 Total Cholesterol'; 
	class sex exposure; 
	model newevnt = age sex bmi exposure; 
run;  

proc logistic data=frmg8 descending;
	title 'Aim 2 LDLC HDLC'; 
	class sex hiLDLC lowHDLC;
	model diabetes = age sex bmi hiLDLC lowHDLC; 
run;  

