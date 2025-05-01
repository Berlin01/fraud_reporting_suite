
/*****************************************************
Author:         Corey Smith
Purpose:        Bay Equity Fraud Committee: Appraiser Name (contact)
******************************************************
Modification History

Update		Version	Comments
08/01/2024	v1	Created script
08/19/2024	v6	Changed order of process
08/19/2024	V7	1ST place any appraiser contact name that IS NOT in the standardized table into temp table for processing
				2nd update any appraiser contact name that IS in the standardized table
09/04/2024	V8	Added two columns to source table [Lien Position] and [Collateral Review Reconsiderations Requested By]
******************************************************/

USE [ICReporting];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT OFF
GO

--CHANGE COMMON MISPELLINGS/COMMON SUBSTITUTIONS

UPDATE DBO.BayEquityFraudCommittee
SET [Appraisal Co Contact] = 'INVALID: APPRAISAL WAIVER NOTED'
WHERE isnull([AUS Comparison Appraisal Waiver],'1') IN ('FHLMC Appraisal Waiver', 'FNMA Appraisal Waiver')
AND [Appraisal Co Contact] != 'INVALID: APPRAISAL WAIVER NOTED'
AND date_input = (SELECT MAX(date_input) FROM DBO.BayEquityFraudCommittee)

UPDATE [dbo].[BayEquityFraudCommittee] 
SET [Appraisal Co Contact] = 'UNKNOWN'
WHERE [Appraisal Co Contact] = 'N'
	AND date_input = (SELECT MAX(date_input) FROM dbo.BayEquityFraudCommittee)
	AND [Appraisal Co Contact] != 'UNKNOWN'
PRINT 'REPLACED COMMON INPUT ERROR'
GO

UPDATE [dbo].[BayEquityFraudCommittee] 
SET [Appraisal Co Contact] = 'AVM'
WHERE [Appraisal Co Contact] = 'AMV'
	AND date_input = (SELECT MAX(date_input) FROM dbo.BayEquityFraudCommittee)
	AND [Appraisal Co Contact] != 'AVM'
PRINT 'REPLACED COMMON INPUT ERROR'
GO

--INTEGRITY CHECK FOR AVM LOANS
	--MAY NEED TO RESEARCH AND CHANGE TO INVALID (I.E. INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST OR INVALID: HELOC AVM)
SELECT b.[Loan Purpose],b.[Loan Number],b.[Loan Program],b.[Appraisal Co Contact], b.[Appraisal Company Name], b.[AUS Comparison Appraisal Waiver], b.[Interviewer Name], b.[Loan Info Channel], [Loan Type], LTV, CLTV, [Lien Position]
FROM DBO.BayEquityFraudCommittee B
WHERE [Appraisal Co Contact] LIKE '%AVM%' AND [Appraisal Co Contact] NOT LIKE '%INVALID%'

	--begin transaction
	--update dbo.BayEquityFraudCommittee
	--set [Appraisal Co Contact] = 'INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST',
	--[Appraisal Company Name] = 'INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST'
	--where [Loan Number] = '2407066497'
	--commit

--COMMIT
--ROLLBACK

--INTEGRITY CHECK FOR N/A AND VARIANCES: fix these, so they are not insert into the temp table for processing

SELECT b.[Loan Purpose],b.[Loan Number],b.[Loan Program],b.[Appraisal Co Contact], b.[Appraisal Company Name], b.[AUS Comparison Appraisal Waiver], b.[Interviewer Name], b.[Loan Info Channel], [Loan Type], LTV, CLTV, [Lien Position] 
FROM DBO.BayEquityFraudCommittee B
WHERE B.[Appraisal Co Contact] IN ('N/A','NA')


	--begin transaction
	--update dbo.BayEquityFraudCommittee
	--set [Appraisal Co Contact] = 'INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST',
	--[Appraisal Company Name] = 'INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST'
	--where [Loan Number] = '2408072134'
	--commit

/***************************************************************************************************************************************
CREATE NEW TABLE TO CAPTURE APPRAISERS NOT IN STANDARDIZED TABLE
***************************************************************************************************************************************/
--CHECK TO ENSURE NOT DUPLICATES IN STANDARDIZATION TABLE
SELECT a.AppraiserName
, a.AppraiserCompany
, a.AppraiserName_Standardized
, count(*) 
FROM dbo.AppraiserNameStandardizationList a
GROUP BY a.AppraiserName, a.AppraiserCompany, a.AppraiserName_Standardized
HAVING COUNT(*) > 1

--NOT IN STANDARDIZED LIST
--INSERT UNPROCESSED NAMES IN TEMP TABLE

--step 1: create temp table and add original appraiser name, company, new appraiser name, mark for processing AND UCASE EVERYTHING
--UPDATE dbo.AppraiserNameStandardizationList 
--SET AppraiserCompany = 'INTEGROUS APPRAISAL'
--WHERE AppraiserCompany = 'INTEGROUS APPRAISALS'
--AND AppraiserName_Standardized = 'ABEL CRUZ'

IF OBJECT_ID(N'tempdb..#AppraiserNameProcessing', N'U') IS NOT NULL   
DROP TABLE #AppraiserNameProcessing;  
GO

CREATE TABLE #AppraiserNameProcessing (
    OriginalAppraiserName NVARCHAR(255),
	Change NVARCHAR(255),
    CompanyName NVARCHAR(255),
    NewAppraiserFirstName NVARCHAR(255),
	NewAppraiserLastName NVARCHAR(255),
	NewAppraiserName NVARCHAR(255),
    MarkForProcessing NVARCHAR(255)
);
GO

--populate table only with appraisal company contact names not currently in the Standardization table
INSERT INTO #AppraiserNameProcessing
SELECT UPPER(a.[Appraisal Co Contact])
, UPPER(TRIM(a.[Appraisal Co Contact]))
, UPPER(a.[Appraisal Company Name])
, NULL
, NULL
, NULL
, NULL 
FROM dbo.BayEquityFraudCommittee a
LEFT JOIN dbo.AppraiserNameStandardizationList B
	ON A.[Appraisal Co Contact] = B.AppraiserName
WHERE 
	B.AppraiserName IS NULL
	AND a.date_input = (SELECT MAX(date_input) FROM dbo.BayEquityFraudCommittee)
	AND NOT EXISTS (SELECT * FROM #AppraiserNameProcessing) --TEMP FILE MUST BE EMPTY
	AND TRIM(A.[Appraisal Co Contact]) IS NOT NULL
	AND LEFT([Appraisal Company Name],7) != 'INVALID'
	AND TRIM([Appraisal Co Contact]) != ''
	AND [Appraisal Co Contact] != 'Appraisal Desk'
	AND isnull(A.[AUS Comparison Appraisal Waiver],'1') NOT IN 
				('FHLMC Appraisal Waiver', 'FNMA Appraisal Waiver')
ORDER BY UPPER(A.[Appraisal Co Contact])
--COMMIT
--select * from #AppraiserNameProcessing

--STEP: REMOVE TRIPLE SPACES
UPDATE #AppraiserNameProcessing
SET Change = REPLACE(Change,'   ', ' '),
MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED TRIPLE SPACES' ELSE concat(MarkForProcessing, ', REMOVED TRIPLE SPACES') END
WHERE PATINDEX('%   %',Change) > 0
GO

--STEP: REMOVE DOUBLE SPACES
UPDATE #AppraiserNameProcessing
SET Change = REPLACE(Change,'  ', ' '),
MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED DOUBLE SPACES' ELSE concat(MarkForProcessing, ', REMOVED DOUBLE SPACES') END
WHERE PATINDEX('%  %',Change) > 0
GO

--STEP: REMOVE BEGINNING/TRAILING SPACES
UPDATE #AppraiserNameProcessing
SET Change = TRIM(Change),
MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED BEGINNING/TRAILING SPACES' ELSE concat(MarkForProcessing, ', REMOVED BEGINNING/TRAILING SPACES') END
WHERE RIGHT(CHANGE, 1) = ' ' 
	OR LEFT(CHANGE, 1) = ' '
GO

--STEP: REMOVE COMMA AND HYPEN '-' CHARACTER AT END OF STRING
UPDATE #AppraiserNameProcessing
SET Change = CASE	WHEN RIGHT(CHANGE, 2) IN ('- ', ', ') THEN LEFT(CHANGE, LEN(CHANGE) - 2)
					WHEN RIGHT(CHANGE, 2) IN (' -', ' ,') THEN LEFT(CHANGE, LEN(CHANGE) - 2)
					WHEN RIGHT(CHANGE, 1) IN ('-', ',') THEN LEFT(CHANGE, LEN(CHANGE) - 1)
			END,
MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED - CHARACTER' ELSE concat(MarkForProcessing, ', REMOVED - CHARACTER') END
WHERE RIGHT(CHANGE, 2) IN ('- ', ', ') 
	OR RIGHT(CHANGE, 2) IN (' -', ' ,') 
	OR RIGHT(CHANGE, 1) IN ('-', ',') 
GO

--STEP REMOVE ANY COMMA AND LETTERS AFTER COMMA WHERE THERE ARE AT >=3 LETTERS
UPDATE #AppraiserNameProcessing
SET Change = LEFT(Change, CHARINDEX(',',Change) -1),
MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED ENDING COMMA,THREE+ LETTERS' ELSE concat(MarkForProcessing, ', REMOVED ENDING COMMA,THREE+ LETTERS') END
WHERE PATINDEX('%, [A-Z][A-Z][A-Z]%', Change) > 0
	AND (RIGHT(CHANGE,4) != ', JR.' OR RIGHT(CHANGE,4) != ', SR.')

--STEP REMOVE TRAILING COMMAS/SPACES
UPDATE #AppraiserNameProcessing
SET CHANGE = dbo.RemoveTrailingSpacesCommas(CHANGE)
WHERE RIGHT(CHANGE,1) IN (' ', ',','-')


--LOOP UNTIL NO RESULTS REMAIN: REMOVE SUFFIXES, THEN REMOVE SPACES OR COMMAS
DECLARE @RowsAffected INT;  -- variable to track the number of affected rows
SET @RowsAffected = 1;

-- Loop until no more rows are affected
WHILE @RowsAffected > 0
BEGIN
    -- Perform the update
    UPDATE #AppraiserNameProcessing
    SET Change = TRIM(LEFT(CHANGE, (LEN(CHANGE) - LEN(B.VARIANCE)))),
        MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED SUFFIX' ELSE CONCAT(MarkForProcessing, ', REMOVED SUFFIX') END
    FROM #AppraiserNameProcessing A
    LEFT JOIN NameVariationsSuffixesFixed B
        ON RIGHT(A.Change, LEN(B.VARIANCE)) = B.VARIANCE

--        ON RIGHT(A.Change, LEN(TRIM(B.VARIANCE))) = B.VARIANCE
    WHERE B.VARIANCE IS NOT NULL;

    -- Get the number of affected rows
    SET @RowsAffected = @@ROWCOUNT;

    -- Remove trailing commas/spaces
    UPDATE #AppraiserNameProcessing
    SET CHANGE = dbo.RemoveTrailingSpacesCommas(CHANGE)
    WHERE RIGHT(CHANGE, 1) IN (' ', ',','-');

	--REMOVE IF ONE LETTER AT THE END OF FIELD (I.E. COREY SMITH, L)
	UPDATE #AppraiserNameProcessing
	SET CHANGE = LEFT(CHANGE, LEN(CHANGE) -2)
	WHERE PATINDEX('% [A-Z]',CHANGE) > 0;

END;

--STEP: SPECIAL HANDLILNG FOR JR AND SR SUFFIXES DUE TO # OF VARIANCES
	--OUTCOME ALL JR AND SR END WITH COMMA, SPACE, SUFFIX WITHOUT A PERIOD (ALLOWS REMOVAL OF PERIOD FOR OTHER SUFFIXES)
UPDATE #AppraiserNameProcessing
SET		NewAppraiserLastName = CASE WHEN RIGHT(CHANGE,4) = ', JR' THEN ', JR'
						WHEN RIGHT(CHANGE,5) = ', JR.'	THEN ', JR'
						WHEN RIGHT(CHANGE,4) = ',JR.'	THEN  ', JR'
						WHEN RIGHT(CHANGE,4) = ' JR.'	THEN  ', JR'
						WHEN RIGHT(CHANGE,3) = ' JR'	THEN  ', JR'
						WHEN RIGHT(CHANGE,4) = ', SR'	THEN  ', SR'
						WHEN RIGHT(CHANGE,5) = ', SR.'	THEN ', SR'
						WHEN RIGHT(CHANGE,4) = ',SR.'	THEN ', SR'
						WHEN RIGHT(CHANGE,4) = ' SR.'	THEN ', SR'
						WHEN RIGHT(CHANGE,3) = ' SR'	THEN ', SR'
						WHEN RIGHT(CHANGE,4) = ' III'	THEN ' III'
						WHEN RIGHT(CHANGE,3) = ' II'	THEN ' II'
						WHEN RIGHT(CHANGE,3) = ' IV'	THEN ' IV'
					END,

		Change = 
					CASE 
						WHEN RIGHT(CHANGE,4) = ', JR'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,5) = ', JR.'	THEN LEFT(CHANGE,LEN(CHANGE)-5)
						WHEN RIGHT(CHANGE,4) = ',JR.'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,4) = ' JR.'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,3) = ' JR'	THEN LEFT(CHANGE,LEN(CHANGE)-3)
						WHEN RIGHT(CHANGE,4) = ', SR'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,5) = ', SR.'	THEN LEFT(CHANGE,LEN(CHANGE)-5)
						WHEN RIGHT(CHANGE,4) = ',SR.'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,4) = ' SR.'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,3) = ' SR'	THEN LEFT(CHANGE,LEN(CHANGE)-3)
						WHEN RIGHT(CHANGE,4) = ' III'	THEN LEFT(CHANGE,LEN(CHANGE)-4)
						WHEN RIGHT(CHANGE,3) = ' II'	THEN LEFT(CHANGE,LEN(CHANGE)-3)
						WHEN RIGHT(CHANGE,3) = ' IV'	THEN LEFT(CHANGE,LEN(CHANGE)-3)
			END,
		MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'JR/SR/II/III/IV' ELSE concat(MarkForProcessing, ', JR/SR/II/III/IV') END
--OUTPUT DELETED.CHANGE, INSERTED.CHANGE
WHERE	RIGHT(CHANGE,5) = ', JR.'	OR
		RIGHT(CHANGE,3) = ' JR'		OR
		RIGHT(CHANGE,4) = ' JR.'	OR
		RIGHT(CHANGE,4) = ',JR.'	OR
		RIGHT(CHANGE,5) = ', SR.'	OR
		RIGHT(CHANGE,3) = ' SR'		OR
		RIGHT(CHANGE,4) = ' SR.'	OR
		RIGHT(CHANGE,4) = ',SR.'	OR
		RIGHT(CHANGE,4) = ' III'	OR
		RIGHT(CHANGE,3) = ' II'		OR
		RIGHT(CHANGE,3) = ' IV'	

-- STEP: IF THERE IS ONE SPACE, POPULATE FIRST AND LAST NAMES
UPDATE #AppraiserNameProcessing
SET NewAppraiserFirstName = LEFT(Change, CHARINDEX(' ', Change) - 1),
    NewAppraiserLastName = CASE WHEN NewAppraiserLastName IS NULL THEN RIGHT(Change, LEN(Change) - CHARINDEX(' ', Change))
                                ELSE CONCAT(RIGHT(Change, LEN(Change) - CHARINDEX(' ', Change)), NewAppraiserLastName)
                           END,
    MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'FIRST/LAST NO MI' ELSE CONCAT(MarkForProcessing, ', FIRST/LAST NO MI') END
WHERE LEN(Change) - LEN(REPLACE(Change, ' ', '')) = 1
  AND NewAppraiserFirstName IS NULL
  AND Change NOT LIKE '%,%';
GO

-- MARK WILDCARD SUFFIXES SECOND 
UPDATE #AppraiserNameProcessing
SET MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'RESEARCH: WILDCARD' ELSE CONCAT(MarkForProcessing, ', RESEARCH: WILDCARD') END
FROM #AppraiserNameProcessing a
LEFT JOIN NameVariationsSuffixesWildcard b
    ON a.Change LIKE b.WC_VARIANCE
WHERE b.WC_VARIANCE IS NOT NULL
  AND a.MarkForProcessing IS NULL;
GO

SELECT * FROM #AppraiserNameProcessing WHERE MarkForProcessing LIKE '%RESEARCH%'

-- STEP: IF "CHANGE" FIELD HAS 2 SPACES, REMOVE MIDDLE NAME/INITIAL AND PLACE FIRST/LAST NAMES IN RESPECTIVE FIELDS
UPDATE #AppraiserNameProcessing
SET NewAppraiserFirstName = LEFT(Change, CHARINDEX(' ', Change) - 1),
    NewAppraiserLastName = CASE WHEN NewAppraiserLastName IS NULL THEN RIGHT(Change, LEN(Change) - CHARINDEX(' ', Change, CHARINDEX(' ', Change) + 1))
                                ELSE CONCAT(RIGHT(Change, LEN(Change) - CHARINDEX(' ', Change, CHARINDEX(' ', Change) + 1)), NewAppraiserLastName)
                           END,
    MarkForProcessing = CASE WHEN MarkForProcessing IS NULL THEN 'REMOVED MIDDLE NAME' ELSE CONCAT(MarkForProcessing, ', REMOVED MIDDLE NAME') END
WHERE LEN(Change) - LEN(REPLACE(Change, ' ', '')) = 2
  AND NewAppraiserFirstName IS NULL
  AND Change NOT LIKE '%,%';
GO
--REMOVE TRAILING COMMAS/SPACES
UPDATE #AppraiserNameProcessing
SET CHANGE = dbo.RemoveTrailingSpacesCommas(CHANGE)
WHERE RIGHT(CHANGE,1) IN (' ', ',','-')

--INTEGRITY CHECK

SELECT * FROM #AppraiserNameProcessing 
WHERE NewAppraiserLastName IS NULL


	--BEGIN TRANSACTION
	--UPDATE #AppraiserNameProcessing
	--SET Change = 'RHONDA DE LOS SANTOS',
	--NewAppraiserFirstName = 'RHONDA',
	--NewAppraiserLastName = 'DE LOS SANTOS',
	--MarkForProcessing = ''
	--WHERE OriginalAppraiserName = 'RHONDA DE LOS SANTOS'
	--COMMIT

	--BEGIN TRANSACTION
	--UPDATE #AppraiserNameProcessing
	--SET Change = 'TERRY VAN DIS',
	--NewAppraiserFirstName = 'TERRY',
	--NewAppraiserLastName = 'VAN DIS',
	--MarkForProcessing = 'REMOVED MIDDLE INITIAL'
	--WHERE OriginalAppraiserName = 'Terry W Van Dis'



	--SELECT [Loan Number],[Interviewer Name],[Appraisal Co Contact], [Appraisal Company Name] FROM DBO.BayEquityFraudCommittee WHERE [Appraisal Co Contact] = 'X'

	--SELECT b.[Loan Purpose],b.[Loan Number],b.[Loan Program],b.[Appraisal Co Contact], b.[Appraisal Company Name], b.[AUS Comparison Appraisal Waiver], b.[Interviewer Name], b.[Loan Info Channel], [Loan Type], LTV, CLTV, [Lien Position]
	--from dbo.BayEquityFraudCommittee b where b.[Appraisal Co Contact] = 'x' order by [Lien Position]

	--select [Appraisal Company Name]
	--from dbo.BayEquityFraudCommittee 
	--where [Appraisal Company Name] like '%2nd%'

	--begin transaction
	--update dbo.BayEquityFraudCommittee
	--set [Appraisal Co Contact] = 'INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST',
	--[Appraisal Company Name] = 'INVALID: 2ND MORTGAGE CONCURRENT WITH FIRST'
	--where [Appraisal Co Contact] = 'UNKNOWN' and [Lien Position] = 'Second Lien' 
	--commit

	--BEGIN TRANSACTION
	--DELETE FROM #AppraiserNameProcessing
	--WHERE OriginalAppraiserName = 'UNKNOWN'


	--begin transaction
	--update dbo.BayEquityFraudCommittee
	--set [Appraisal Co Contact] = 'SCOTT OLSON',
	--[Appraisal Company Name] = 'FIRGROVE APPRAISING'
	--where [Loan Number] = '2406060880' 
	--commit

	--select * from dbo.AppraisalCompanyStandardizationList where AppraiserCompany_Standardized like '%firgrove%'


SELECT * FROM #AppraiserNameProcessing 
WHERE MarkForProcessing IS NULL

SELECT * FROM #AppraiserNameProcessing 
WHERE LEN(NewAppraiserLastName) <= 2


	--BEGIN TRANSACTION
	--UPDATE #AppraiserNameProcessing
	--SET Change = 'CHRISTOPHER CHARLES',
	--NewAppraiserFirstName = 'CHRISTOPHER',
	--NewAppraiserLastName = 'CHARLES',
	--MarkForProcessing = 'REMOVED SUFFIXES'
	--WHERE OriginalAppraiserName = 'CHRISTOPHER CHARLES CA'
	--COMMIT

SELECT * FROM #AppraiserNameProcessing 
WHERE NewAppraiserFirstName IS NULL 

SELECT * FROM #AppraiserNameProcessing 
WHERE LEN(NewAppraiserFirstName) <= 2

--i have decided if the first name of the appraiser shows a letter and a period or a letter and a space (i.e. only the first initial) to let that be...no need to process it further.

--ENTER NewAppraiserName WHICH WILL BE TRANSFERRED TO [dbo].[AppraiserNameStandardizationList]
UPDATE #AppraiserNameProcessing 
SET NewAppraiserName = CONCAT(NewAppraiserFirstName,' ',NewAppraiserLastName)
WHERE NewAppraiserFirstName IS NOT NULL 
	AND NewAppraiserLastName IS NOT NULL


	--look to see duplicates...do nothing with this list...just a review...probably remove this script soon
		--STEVEN PIER	SJP APPRAISALS
	SELECT * FROM (
	SELECT 
		OriginalAppraiserName,
		NewAppraiserName,
		CompanyName,
		COUNT(NewAppraiserName) OVER (PARTITION BY NewAppraiserName) AS DuplicateCount
	FROM 
		#AppraiserNameProcessing
	)a
	WHERE DuplicateCount>1
	ORDER BY DuplicateCount DESC

--ENTER NAME INTO [dbo].[AppraiserNameStandardizationList]

-->>>>>>>>>>>>>>>MAKE SURE NAMES ARE NOT ALREADY IN DB<<<<<<<<<<<<----------------

-->>>>Run the SELECT statementS before inserting<<<< especially Look at N/A entries

	SELECT NewAppraiserName FROM #AppraiserNameProcessing WHERE NewAppraiserName LIKE '% NA %' OR NewAppraiserName LIKE '% N/A %'

	SELECT DISTINCT A.OriginalAppraiserName, A.CompanyName, a.NewAppraiserName
	FROM #AppraiserNameProcessing A
	LEFT JOIN [dbo].[AppraiserNameStandardizationList] B
		ON A.NewAppraiserName = B.AppraiserName_Standardized
		AND a.CompanyName = b.AppraiserCompany
	WHERE B.AppraiserName_Standardized IS NULL


BEGIN TRANSACTION

	INSERT INTO [dbo].[AppraiserNameStandardizationList] ([AppraiserName],[AppraiserCompany],[AppraiserName_Standardized])

	SELECT DISTINCT A.OriginalAppraiserName, A.CompanyName, a.NewAppraiserName
	FROM #AppraiserNameProcessing A
	LEFT JOIN [dbo].[AppraiserNameStandardizationList] B
		ON A.NewAppraiserName = B.AppraiserName_Standardized
		AND a.CompanyName = b.AppraiserCompany
	WHERE B.AppraiserName_Standardized IS NULL

--ROLLBACK / COMMIT

--INTEGRITY CHECK
SELECT AppraiserName, AppraiserCompany, AppraiserName_Standardized,  COUNT(*) 
FROM [dbo].[AppraiserNameStandardizationList]
GROUP BY AppraiserName, AppraiserCompany, AppraiserName_Standardized
HAVING COUNT(*) > 1

--CLEAN UP MANUAL WORK--REVIEW AND CHANGE WHAT DOES NOT MAKE SENSE (I.E. APPRAISER NAME = CLEAR CAPITOL AVM)
SELECT * FROM (
SELECT AppraiserName_Standardized, AppraiserName, COUNT(AppraiserName) OVER (PARTITION BY AppraiserName) AS DuplicateCount
FROM [dbo].[AppraiserNameStandardizationList]
)Z
ORDER BY Z.DuplicateCount DESC, z.AppraiserName_Standardized

SELECT AppraiserName_Standardized, AppraiserName
FROM [dbo].[AppraiserNameStandardizationList]
WHERE RIGHT(AppraiserName_Standardized, 1) = '.';


--BEGIN TRANSACTION;
--UPDATE [dbo].[AppraiserNameStandardizationList]
--SET AppraiserName_Standardized = 'BRENDA CLOUGH'
--WHERE AppraiserName_Standardized = 'BRENDA CLOUGH-CRT.RES.';
--COMMIT;


--here are some other checks to accompany the above
SELECT AppraiserName, AppraiserCompany, AppraiserName_Standardized, 
       COUNT(AppraiserName) OVER (PARTITION BY AppraiserName) AS DuplicateCount
FROM [dbo].[AppraiserNameStandardizationList] a 
WHERE a.AppraiserName_Standardized LIKE '%appra%';

SELECT AppraiserName, AppraiserCompany, AppraiserName_Standardized, 
       COUNT(AppraiserName) OVER (PARTITION BY AppraiserName) AS DuplicateCount
FROM [dbo].[AppraiserNameStandardizationList] a 
WHERE a.AppraiserName_Standardized LIKE '%unknown%';

SELECT b.[Loan Purpose], b.[Loan Number], b.[Loan Program], b.[Appraisal Co Contact], 
       b.[Appraisal Company Name], b.[AUS Comparison Appraisal Waiver], 
       b.[Interviewer Name], b.[Loan Info Channel], [Loan Type]
FROM dbo.BayEquityFraudCommittee b 
WHERE b.[Appraisal Co Contact] LIKE '%unknown%';

SELECT b.[Loan Purpose], b.[Loan Number], b.[Loan Program], b.LTV, b.[Appraisal Co Contact], 
       b.[Appraisal Company Name], b.[AUS Comparison Appraisal Waiver], 
       b.[Interviewer Name], b.[Loan Info Channel], [Loan Type]
FROM dbo.BayEquityFraudCommittee b 
WHERE b.[Appraisal Co Contact] LIKE '%n/a%' 
  AND b.[Appraisal Co Contact] != 'N/A: PIW' 
ORDER BY LTV;

 
/***************************************************************************************************************************************
UPDATE [BayEquityFraudCommittee] APPRAISER NAME BASED ON [dbo].[AppraiserNameStandardizationList] CURRENT RESULTS

--CHANGE SOURCE TABLE [BayEquityFraudCommittee] APPRAISAL NAMES TO STANDARDIZATION NAMES IF POSSIBLE
	--RAISE ERROR IF STANDAREIZED HAS NULL OR ['' = BLANK] FOR STANDARDIZED NAME OR IF STANDARDIZATION RECORDS ARE DUPLICATES (ALL THREE: ORIGINAL NAME, NEW NAME, AN COMPANY)
***************************************************************************************************************************************/

--CHANGE SOURCE TABLE APPRAISAL NAMES TO STANDARDIZED CHANGES WHEN MATCHING
BEGIN TRY
        BEGIN TRANSACTION
            IF EXISTS(SELECT * FROM [dbo].[AppraiserNameStandardizationList] WHERE ISNULL([AppraiserName_Standardized],'') = '')
			OR EXISTS(SELECT AppraiserName,AppraiserName_Standardized, AppraiserCompany,COUNT(*) FROM [dbo].[AppraiserNameStandardizationList] GROUP BY AppraiserName,AppraiserName_Standardized, AppraiserCompany HAVING COUNT(*) > 1)

                    BEGIN
                        RAISERROR('*****>>>>>CANCELLED: Cannot have NULL, BLANK, or DUPLICATE Record<<<<<*****',16,1)
                    END
                ELSE
                    BEGIN
						UPDATE [dbo].[BayEquityFraudCommittee]
						SET [Appraisal Co Contact] = TRIM(ANSL.AppraiserName_Standardized)
						FROM [dbo].[BayEquityFraudCommittee] BEFC
						LEFT JOIN dbo.AppraiserNameStandardizationList ANSL
							ON ISNULL(TRIM(BEFC.[Appraisal Co Contact]),1) = ISNULL(TRIM(ANSL.AppraiserName),1)
						WHERE ANSL.AppraiserName_Standardized IS NOT NULL
							AND BEFC.date_input = (SELECT MAX(date_input) FROM [dbo].[BayEquityFraudCommittee])
							--BELOW DOES NOT CHANGE FIELDS THAT ARE EXACTLY THE SAME AS STANDARDIZED LIST (INCL. UPPER CASE)
							AND BINARY_CHECKSUM(TRIM([Appraisal Co Contact])) != BINARY_CHECKSUM(UPPER(TRIM(ANSL.AppraiserName_Standardized)))
							AND LEFT(TRIM(BEFC.[Appraisal Company Name]),8) != 'INVALID:'
						IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION
                    END
END TRY

BEGIN CATCH
    DECLARE @msg VARCHAR(100) = error_message()
        IF @@trancount > 0
            BEGIN
                RAISERROR(@msg,16,1)
                ROLLBACK TRANSACTION
            END         
END CATCH


--INTEGRITY CHECK FOR PIW LOANS

--MANUAL PROCESS: IF LOANS SURFACE, MANUALLY CHECK TO SEE IF THEY HAVE A PROPERTY INSPECTION WAIVER VIA THE MOST RECENT AUS FINDINGS
	--IF SO, CHANGE THE [Appraisal Co Contact]

SELECT [Loan Number], [Appraisal Company Name], [Appraisal Co Contact], [AUS Comparison Appraisal Waiver], [Loan Info Channel], [Lien Position], [Loan Program]
FROM dbo.BayEquityFraudCommittee 
WHERE [Appraisal Company Name] = 'INVALID: APPRAISAL WAIVER NOTED' 
  AND [Appraisal Co Contact] != 'N/A: PIW' 
  AND [AUS Comparison Appraisal Waiver] NOT IN ('FNMA Appraisal Waiver', 'FHLMC Appraisal Waiver')
  AND date_input = (SELECT MAX(date_input) FROM dbo.BayEquityFraudCommittee)
  AND [Appraisal Co Contact] != 'INVALID: APPRAISAL WAIVER NOTED';

GO

	--BEGIN TRANSACTION
	--UPDATE DBO.BayEquityFraudCommittee
	--SET [Appraisal Co Contact] = 'INVALID: APPRAISAL WAIVER NOTED'
	--WHERE [Appraisal Company Name] = 'INVALID: APPRAISAL WAIVER NOTED'
	--AND [Loan Number] = '2407068096'
	--COMMIT


	--UPDATE dbo.BayEquityFraudCommittee
	--SET [Appraisal Company Name] = 'KENTUCKY APPRAISAL TEAM',
	--[Appraisal Co Contact] = 'MICHAEL MALLORY'
	--WHERE [Loan Number] = '2401042392'

/***************************************************************************************************************************************

UPDATE #AppraiserNameProcessing 
SET CHANGE = 'RON WYNN'
WHERE OriginalAppraiserName = 'RON DARIUS J WYNN'
 
--MANUAL ADD NAME SUFFIXES
	
	SELECT * FROM [dbo].[NameVariationsSuffixesFixed]

	INSERT INTO #NameVariationsSuffixesWildcard
	VALUES
	('% PA %')
	('%cert%')

--MANUAL ADDITIONS: ADD AND THEN DELETE FROM TEMP TABLE, SO THERE IS NO DOUBLE INPUT INTO AppraiserNameStandardizationList

INSERT INTO [dbo].[AppraiserNameStandardizationList]
VALUES
('AVM', 'N/A: AVM','CLEAR CAPITOL AVM')



begin transaction
delete from NameVariationsSuffixesFixed where variance IN ('III', 'II', 'IV')
commit
VALUES
('RAA')


BEGIN TRANSACTION
DELETE FROM #NameVariationsSuffixesFixed
WHERE VARIANCE= 'VA'

SELECT * FROM #NameVariationsSuffixesFixed
WHERE VARIANCE LIKE '%VA%'
COMMIT

***************************************************************************************************************************************/

