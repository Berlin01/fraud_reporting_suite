/*****************************************************
Author:         Corey Smith
Purpose:        Bay Equity Fraud Committee: MAIN SCRIPT
******************************************************
Modification History

Update		Version	Comments
05/13/2024	1		Created script
09/13/2024	2		Added Top 10 RE Agent Script
09/16/2024	3		Added General RE Agent Script
09/17/2024	4		Streamlining Appraisal Scripts
******************************************************/


		/*********************VERY IMPORTANT******************

		FIRST RUN COMPANY NAME STANDARIZATION SCRIPT
		THEN RUN APPRAISER NAME STANDARDIZATION SCRIPT
		THE RUN EMPLOYER SCRIPT
		THEN RUN BELOW TO GET REPORTS

		*********************VERY IMPORTANT******************/


USE [ICReporting];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT OFF
GO


--integrity...change all redfin to Redfin Corporation
BEGIN TRANSACTION
UPDATE [dbo].BayEquityFraudCommittee 
SET [Buyers Agent Name] = 'Redfin Corporation' 
WHERE ([Buyers Agent Name] = 'Redfn' OR [Buyers Agent Name] LIKE '%REDFIN%')
	AND [Buyers Agent Name] != 'Redfin Corporation'
	AND  date_input = (SELECT MAX(date_input) FROM [dbo].BayEquityFraudCommittee)
COMMIT



---Review AVM records
SELECT FD.[Loan Number],FD.[Appraisal Co Contact], FD.[Appraisal Company Name], FD.[Loan Type], FD.[Loan Purpose], FD.[Loan Program], [Current Status Date]
FROM [dbo].BayEquityFraudCommittee FD
WHERE FD.[Loan Type] LIKE 'HELOC'
AND ([Appraisal Co Contact] != 'INVALID: HELOC AVM' OR [Appraisal Company Name] != 'INVALID: HELOC AVM' )
AND  date_input = (SELECT MAX(date_input) FROM [dbo].BayEquityFraudCommittee)
ORDER BY [Current Status Date] DESC

	--BEGIN TRANSACTION
	--UPDATE DBO.BayEquityFraudCommittee
	--SET [Appraisal Co Contact] = 'INVALID: HELOC AVM',
	--[Appraisal Company Name] = 'INVALID: HELOC AVM'
	--	WHERE [Loan Type] LIKE 'HELOC'
	--	AND ([Appraisal Co Contact] != 'INVALID: HELOC AVM' OR [Appraisal Company Name] != 'INVALID: HELOC AVM' )
	--	AND  date_input = (SELECT MAX(date_input) FROM [dbo].BayEquityFraudCommittee)
	--	and trim([Appraisal Co Contact]) = ''

	--COMMIT
	--ROLLBACK

/***************************************************************************************************************************************
	CAPTURE TOP 10 MLO'S FOR REPORTING SUITE
***************************************************************************************************************************************/


--TEMP TABLE HOLDING TOP 10 MLO'S DURING THE PAST 4 MONTHS
		IF OBJECT_ID(N'tempdb..#Top_10_MLOs', N'U') IS NOT NULL   
		DROP TABLE #Top_10_MLOs

		SELECT *
		INTO #Top_10_MLOs
		FROM(
				SELECT MLO 
				FROM
					(
					SELECT DISTINCT TOP 10 [Interviewer Name] MLO, COUNT(*) AS UNITS
						FROM DBO.BayEquityFraudCommittee
						WHERE [Lien Position] = 'First lien'
						AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
						AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
						GROUP BY [Interviewer Name]
						ORDER BY COUNT(*) DESC
					)AA
			)BB



/***************************************************************************************************************************************
	RE Agent Reporting
***************************************************************************************************************************************/
----------TOP 10 MLO'S: VERIFIED CORRECT VIA EXCEL PIVOT

--TEMP TABLE HOLDING DATA SO CAN IDENTIFY TO SAME RE AGENTS FOR 6-MONTH COMPARISON
IF OBJECT_ID(N'tempdb..#Top_10_MLO_RE_AGENT', N'U') IS NOT NULL   
DROP TABLE #Top_10_MLO_RE_AGENT


SELECT * INTO #Top_10_MLO_RE_AGENT
FROM
(
	SELECT *,
	ROUND(CAST([AGENT TRANSACTIONS] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) AS [% AGENT USAGE]
	FROM
	(
		SELECT DISTINCT
			[Interviewer Name]
			,[Buyers Agent Contact Name]
			,[Buyers Agent Name]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name],[Buyers Agent Contact Name]) AS [AGENT TRANSACTIONS]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
		FROM dbo.BayEquityFraudCommittee
		WHERE [Loan Purpose] = 'Purchase'
			AND [Lien Position] = 'First Lien'
			AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
			AND [Interviewer Name] IN (SELECT * FROM #Top_10_MLOs)
		GROUP BY [Interviewer Name]
			,[Buyers Agent Contact Name]
			,[Buyers Agent Name]
			,[Loan Number]
	)Z
	WHERE (ROUND(CAST([AGENT TRANSACTIONS] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4)) >= .05
)Z
ORDER BY Z.[Interviewer Name]

/******************************************** REPORTABLE **********************************************/

SELECT * FROM #Top_10_MLO_RE_AGENT

/******************************************** REPORTABLE **********************************************/
--integrity update

--select [Buyers Agent Name] from dbo.BayEquityFraudCommittee where [Buyers Agent Name] like 'Keller Williams%'

--begin transaction
--update dbo.BayEquityFraudCommittee 
--set [Buyers Agent Name] = 'Keller Williams'
--where [Buyers Agent Name] like 'Keller Williams%'
--commit

----------TOP 10 MLO'S PREVIOUS SIX MONTHS

/******************************************** REPORTABLE **********************************************/	
SELECT *,
	ROUND(CAST([AGENT TRANSACTIONS] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) AS [% AGENT USAGE]
	FROM
	(
		SELECT DISTINCT
			[Interviewer Name]
			,CASE WHEN [Buyers Agent Contact Name] IN (SELECT [Buyers Agent Contact Name] FROM #Top_10_MLO_RE_AGENT) THEN CONCAT('>>>',[Buyers Agent Contact Name])
				ELSE [Buyers Agent Contact Name]
			END AS [Buyers Agent Contact Name]
			, CONCAT([Interviewer Name], [Buyers Agent Contact Name]) as [VLookup Text]
			,[Buyers Agent Name]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name],[Buyers Agent Contact Name]) AS [AGENT TRANSACTIONS]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
		FROM dbo.BayEquityFraudCommittee
		WHERE [Loan Purpose] = 'Purchase'
			AND [Lien Position] = 'First Lien'
			AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Interviewer Name] IN (SELECT * FROM #Top_10_MLOs)
			--AND [Buyers Agent Contact Name] IN (SELECT [Buyers Agent Contact Name] FROM #Top_10_MLO_RE_AGENT)
		GROUP BY [Interviewer Name]
			,[Buyers Agent Contact Name]
			,[Buyers Agent Name]
			,[Loan Number]
	)Z
	WHERE LEFT([Buyers Agent Contact Name],3) = '>>>'
	ORDER BY [Interviewer Name], [% AGENT USAGE]

/******************************************** REPORTABLE **********************************************/

----------GENERAL MLO RE AGENT TREND: VERIFIED CORRECT VIA EXCEL PIVOT

--TEMP TABLE HOLDING DATA SO CAN IDENTIFY TO SAME RE AGENTS FOR 6-MONTH COMPARISON
IF OBJECT_ID(N'tempdb..#MLO_General_MLO_RE_AGENT', N'U') IS NOT NULL   
DROP TABLE #MLO_General_MLO_RE_AGENT


SELECT * INTO #MLO_General_MLO_RE_AGENT
FROM
(
	SELECT *,
	ROUND(CAST([AGENT TRANSACTIONS] AS FLOAT) / CAST(MLO_Count AS float) * 1.0, 4) AS [% AGENT USAGE]
	FROM
	(
		SELECT DISTINCT
			[Interviewer Name]
			,[Buyers Agent Contact Name]
			,[Buyers Agent Name]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name],[Buyers Agent Contact Name]) AS [AGENT TRANSACTIONS]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
		FROM dbo.BayEquityFraudCommittee
		WHERE [Loan Purpose] = 'Purchase'
			AND [Lien Position] = 'First Lien'
			AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
		GROUP BY [Interviewer Name]
			,[Buyers Agent Contact Name]
			,[Buyers Agent Name]
			,[Loan Number]
	)Z
		WHERE [AGENT TRANSACTIONS] >= 4
		AND MLO_Count >= 4
)Z
WHERE Z.[% AGENT USAGE] >= .3
ORDER BY Z.[Interviewer Name]

/******************************************** REPORTABLE **********************************************/

SELECT * FROM #MLO_General_MLO_RE_AGENT

/******************************************** REPORTABLE **********************************************/

--GENERAL MLO RE AGENT TREND: SIX-MONTH TREND (COPY/PASTE RESULTS TO MLO to RE Agent Help tab)

/******************************************** REPORTABLE **********************************************/

	SELECT *,
	ROUND(CAST([AGENT TRANSACTIONS] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) AS [% AGENT USAGE]
	FROM
	(
		SELECT DISTINCT
			[Interviewer Name]
			,CASE WHEN [Buyers Agent Contact Name] IN (SELECT [Buyers Agent Contact Name] FROM #MLO_General_MLO_RE_AGENT) THEN CONCAT('>>>',[Buyers Agent Contact Name])
				ELSE [Buyers Agent Contact Name]
			END AS [Buyers Agent Contact Name]
			, CONCAT([Interviewer Name], [Buyers Agent Contact Name]) as [VLookup Text]
			,[Buyers Agent Name]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name],[Buyers Agent Contact Name]) AS [AGENT TRANSACTIONS]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
		FROM dbo.BayEquityFraudCommittee
		WHERE [Loan Purpose] = 'Purchase'
			AND [Lien Position] = 'First Lien'
			AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Interviewer Name] IN (SELECT [Interviewer Name] FROM #MLO_General_MLO_RE_AGENT)
		GROUP BY [Interviewer Name]
			,[Buyers Agent Contact Name]
			,[Buyers Agent Name]
			,[Loan Number]
	)Z
	WHERE LEFT([Buyers Agent Contact Name],3) = '>>>'
	ORDER BY [Interviewer Name], [% AGENT USAGE]

/******************************************** REPORTABLE **********************************************/


/***************************************************************************************************************************************
	APPRAISAL ANALYSIS Reporting
***************************************************************************************************************************************/
--first run appraisal script to standardize appraiser company names

--MLO to Appraisal Reporting

/*>>MUST RUN ENTIRE INDENTED TEXT TO CATCH DATE VARIABLES */


		DECLARE @startdate date , @enddate as date
			SET @startdate = '5-1-2024'
			SET @enddate = '8-31-2024'

		IF OBJECT_ID(N'tempdb..#DateSpecificTable', N'U') IS NOT NULL   
		DROP TABLE #DateSpecificTable  

		SELECT *
		INTO #DateSpecificTable
		FROM [dbo].[BayEquityFraudCommittee] A
		WHERE A.[Current Status Date] BETWEEN @startdate AND @enddate  --<<<<<CHANGE DATE FOR THE PAST FOUR MONTHS
		AND LEFT(A.[Appraisal Company Name],7) != 'INVALID'


/***************************
Top 10 MLO's:  Appraiser Relationships: Surfaces details for Appraiser companies used >= 10% (shows appraiser names, counts, etc.) 
***************************/

IF OBJECT_ID(N'tempdb..#Top_10_MLOs_APPRAISALS', N'U') IS NOT NULL   
DROP TABLE #Top_10_MLOs_APPRAISALS


SELECT * INTO #Top_10_MLOs_APPRAISALS
FROM
(
	SELECT *,
	--ROUND(CAST([Appraisal Company Count] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) AS [% AGENT USAGE],
	ROUND(CAST([Appraiser Count] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) AS [% AGENT USAGE]
	FROM
	(
		SELECT DISTINCT
			[Interviewer Name] AS MLO
			, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
			,A.[Appraisal Company Name]
			,A.[Appraisal Co Contact]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name],[Appraisal Co Contact]) AS [Appraiser Count]
		FROM dbo.BayEquityFraudCommittee A
		WHERE [Lien Position] = 'First Lien'
			AND LEFT(A.[Appraisal Company Name],7) != 'INVALID'
			AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
			AND [Interviewer Name] IN (SELECT * FROM #Top_10_MLOs)
		GROUP BY [Interviewer Name]
			,A.[Appraisal Company Name]
			,A.[Appraisal Co Contact]
			,A.[Loan Number]
			
	)Z
	where ROUND(CAST([Appraiser Count] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) >= .1
)ZZ
ORDER BY ZZ.MLO

/******************************************** REPORTABLE **********************************************/
SELECT * FROM #Top_10_MLOs_APPRAISALS
/******************************************** REPORTABLE **********************************************/

--PREVIOUS SIX MONTHS

/******************************************** REPORTABLE **********************************************/

	SELECT MLO
	,[Appraisal Co Contact]
	,[VLookup Text]
	,[Appraiser Count]
	,ROUND(CAST([Appraiser Count] AS FLOAT) / CAST(MLO_Count AS float) * 1.0,4) AS [% Appraiser Usage]
	,MLO_Count AS [(Funded Units)]
	FROM
	(
		SELECT DISTINCT
			[Interviewer Name] AS MLO
			,CASE WHEN [Appraisal Co Contact] IN (SELECT DISTINCT [Appraisal Co Contact] FROM #Top_10_MLOs_APPRAISALS) THEN CONCAT('>>>',[Appraisal Co Contact])
			ELSE [Appraisal Co Contact]
			END AS [Appraisal Co Contact]
			, CONCAT([Interviewer Name], [Appraisal Co Contact]) as [VLookup Text]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name],[Appraisal Co Contact]) AS [Appraiser Count]
			, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
		FROM dbo.BayEquityFraudCommittee A
		WHERE [Lien Position] = 'First Lien'
			AND LEFT(A.[Appraisal Company Name],7) != 'INVALID'
			AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Interviewer Name] IN (SELECT DISTINCT MLO FROM #Top_10_MLOs_APPRAISALS)

		GROUP BY [Interviewer Name]
			,A.[Appraisal Company Name]
			,A.[Appraisal Co Contact]
			,A.[Loan Number]
	)Z
	WHERE LEFT(Z.[Appraisal Co Contact],3) = '>>>'

/******************************************** REPORTABLE **********************************************/


-------VISIBILITY INTO INVALID APPRAISAL COMPANY NAMES

DECLARE @startdate date , @enddate as date
	SET @startdate = '5-1-2024'
	SET @enddate = '8-31-2024'

SELECT A.[Interviewer Name]
, A.[Appraisal Company Name]
, A.[Appraisal Co Contact]
, A.[Loan Info Channel]
,A.[Loan Type]
, A.[Loan Program]
, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count 
FROM [dbo].[BayEquityFraudCommittee] A
LEFT JOIN
			(SELECT top 10 [Interviewer Name] AS MLO
			FROM [dbo].[BayEquityFraudCommittee]
			WHERE [Current Status Date] BETWEEN @startdate AND @enddate
			GROUP BY [Interviewer Name]
			ORDER BY count(*) desc) B
ON A.[Interviewer Name] = B.MLO
WHERE B.MLO IS NOT NULL
AND LEFT([Appraisal Company Name],7) = 'INVALID'
AND A.[Current Status Date] BETWEEN @startdate AND @enddate
ORDER BY COUNT(*) OVER (PARTITION BY [Interviewer Name]) DESC, A.[Appraisal Company Name], A.[Appraisal Co Contact]

/***************************
Highest MLO-to-Appraiser Relationships: Surfaces details for Appraiser companies used >= 30% going to same appraiser
***************************/
--High % of MLO-to-Appraiser usage >= 30% going to same appraiser
--Minimum of 1 transactions going to the same appraiser per month (4 for this report)

-- Drop the temporary table if it exists
IF OBJECT_ID(N'tempdb..#MLO_General_MLO_APPRAISER', N'U') IS NOT NULL
    DROP TABLE #MLO_General_MLO_APPRAISER;

-- Create and populate the temporary table
SELECT *
INTO #MLO_General_MLO_APPRAISER
FROM (
    SELECT *
    FROM (
        SELECT *,
               ROUND(CAST([Appraiser Count] AS FLOAT) / CAST([MLO Count] AS FLOAT) * 1.0, 4) AS [% Appraiser Usage]
        FROM (
            SELECT DISTINCT
                   [Interviewer Name] AS MLO,
                   COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS [MLO Count],
                   A.[Appraisal Company Name],
                   A.[Appraisal Co Contact],
                   COUNT(*) OVER (PARTITION BY [Interviewer Name], [Appraisal Co Contact]) AS [Appraiser Count]
            FROM dbo.BayEquityFraudCommittee A
            WHERE [Lien Position] = 'First Lien'
              AND LEFT(A.[Appraisal Company Name], 7) != 'INVALID'
              AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
              AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
			  AND [Interviewer Name] NOT IN (SELECT DISTINCT MLO FROM #Top_10_MLOs_APPRAISALS) 
            GROUP BY [Interviewer Name],
                     A.[Appraisal Company Name],
                     A.[Appraisal Co Contact],
                     A.[Loan Number]
        ) A
        WHERE A.[MLO Count] >= 4
          AND ROUND(CAST([Appraiser Count] AS FLOAT) / CAST([MLO Count] AS FLOAT) * 1.0, 4) >= 0.3
    ) Z
    WHERE [Appraiser Count] >= 4
      AND [MLO Count] >= 4
) ZZ
ORDER BY ZZ.MLO

/******************************************** REPORTABLE **********************************************/	

SELECT * FROM #MLO_General_MLO_APPRAISER

/******************************************** REPORTABLE **********************************************/	

--GENERAL MLO APPRAISER SIX-MONTH TREND (COPY/PASTE RESULTS TO MLO to APPRAISER HELP tab)

--GENERAL MLO APPRAISER SIX-MONTH TREND (COPY/PASTE RESULTS TO MLO to APPRAISER HELP tab)

        SELECT	MLO
				, Z.[Appraisal Co Contact]
				, Z.[VLookup Text]
                , ROUND(CAST([Appraiser Count] AS FLOAT) / CAST(MLO_Count AS FLOAT) * 1.0, 4) AS [% Appraiser Usage]
				, Z.MLO_Count
        FROM (
            SELECT DISTINCT
                   [Interviewer Name] AS MLO
				   , CASE WHEN [Appraisal Co Contact] IN (SELECT DISTINCT [Appraisal Co Contact] FROM #MLO_General_MLO_APPRAISER) THEN CONCAT('>>>',[Appraisal Co Contact])
					 ELSE [Appraisal Co Contact]
					 END AS [Appraisal Co Contact]
					, CONCAT([Interviewer Name], [Appraisal Co Contact]) as [VLookup Text]
					, COUNT(*) OVER (PARTITION BY [Interviewer Name]) AS MLO_Count
                    , COUNT(*) OVER (PARTITION BY [Interviewer Name], [Appraisal Co Contact]) AS [Appraiser Count]
            FROM dbo.BayEquityFraudCommittee A
            WHERE [Lien Position] = 'First Lien'
              AND LEFT(A.[Appraisal Company Name], 7) != 'INVALID'
              AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
              AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			  AND [Interviewer Name] IN (SELECT DISTINCT MLO FROM #MLO_General_MLO_APPRAISER)
			  AND [Interviewer Name] NOT IN (SELECT DISTINCT MLO FROM #Top_10_MLOs_APPRAISALS) 
            GROUP BY [Interviewer Name],
                     A.[Appraisal Company Name],
                     A.[Appraisal Co Contact],
                     A.[Loan Number]
        ) Z
		WHERE LEFT(Z.[Appraisal Co Contact],3) = '>>>'

/********************************************************************
% BY CHANNEL FOR REPORT AND BLANK ISSUES WITH BROKERED APPRAISALS

RUN ENTIRE SECTION
*********************************************************************/

/******************************************** REPORTABLE **********************************************/	

DECLARE @StartDate DATE;
DECLARE @EndDate DATE;

-- Set the start date to the beginning of the month four months ago
SET @StartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0);

-- Set the end date to the beginning of the current month
SET @EndDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);

SELECT 'START DATE' AS Label, @StartDate AS DateValue
UNION ALL
SELECT 'END DATE', @EndDate;

SELECT 
    [Loan Info Channel],
    COUNT(*) AS Count,
    ROUND(CAST(COUNT(*) * 1.0 / (SELECT COUNT(*) 
							FROM dbo.BayEquityFraudCommittee 
							WHERE [Current Status Date] >= @StartDate 
								AND [Current Status Date] < @EndDate 
								AND [Lien Position] = 'First Lien') AS FLOAT),4) AS PercentageOfTotal
FROM 
    dbo.BayEquityFraudCommittee
WHERE 
    [Current Status Date] >= @StartDate
    AND [Current Status Date] < @EndDate
    AND [Lien Position] = 'First Lien'
GROUP BY 
    [Loan Info Channel]
ORDER BY 
    Count DESC;

--COUNT OF BROKERED LOANS WITH FAULTY APPRAISAL INFORMATION
SELECT [Appraisal Co Contact], [Appraisal Company Name], [Current Status Date], [Loan Info Channel], [Lien Position]
FROM DBO.BayEquityFraudCommittee
WHERE [Loan Info Channel] = 'Brokered'
AND ([Appraisal Co Contact] LIKE '%BLANK%' OR TRIM([Appraisal Co Contact]) = '')
AND [Lien Position] = 'FIRST LIEN'
AND [Current Status Date] >= @StartDate
AND [Current Status Date] < @EndDate
ORDER BY [Current Status Date] DESC

/******************************************** REPORTABLE **********************************************/	

/***************************************************************************************************************************************
	SELF EMPLOYED REPORTING
***************************************************************************************************************************************/

--TOP 10
--last 4 months

--TOP 10 MLO'S self employment MAIN REPORT

/******************************************** REPORTABLE **********************************************/	

SELECT * FROM 
(
SELECT 
	[Interviewer Name],
	[Yes],
	[No],
	ISNULL([Yes],0) + ISNULL([No], 0) AS TOTAL,
	ROUND(CAST([YES] * 1.0 / (NULLIF(ISNULL([Yes], 0) + ISNULL([No], 0), 0)) AS FLOAT), 2) AS [YES PERCENTAGE]
	FROM
		(SELECT [Interviewer Name], Z.[Self Employed Status]
		FROM DBO.BayEquityFraudCommittee Z
		WHERE [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
		AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
		AND [Lien Position] = 'First Lien'
		AND [Interviewer Name] IN
		(
			SELECT * FROM #Top_10_MLOs
		)
	) AS SOURCETABLE
PIVOT
(
	COUNT([Self Employed Status])
	FOR [Self Employed Status] IN ([Yes],[No])
) AS PivotTable
)ZZ
ORDER BY [Interviewer Name]

/******************************************** REPORTABLE **********************************************/	

----TOP 10 MLO'S self employment MAIN REPORT PREVIOUS 6 MONTHS yes percentage (only for last column)

/******************************************** REPORTABLE **********************************************/	

SELECT * FROM 
(
SELECT 
	[Interviewer Name],
--	[Yes],
--	[No],
--	ISNULL([Yes],0) + ISNULL([No], 0) AS TOTAL,
	ROUND(CAST([YES] * 1.0 / (NULLIF(ISNULL([Yes], 0) + ISNULL([No], 0), 0)) AS FLOAT), 2) AS [YES PERCENTAGE]
	FROM
		(SELECT [Interviewer Name], Z.[Self Employed Status]
		FROM DBO.BayEquityFraudCommittee Z
		WHERE  [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
				AND [Current Status Date] <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) -4, 0)
		AND [Lien Position] = 'First Lien'
		AND [Interviewer Name] IN
		(
			SELECT * FROM #Top_10_MLOs
		)
	) AS SOURCETABLE
PIVOT
(
	COUNT([Self Employed Status])
	FOR [Self Employed Status] IN ([Yes],[No])
) AS PivotTable
)ZZ
ORDER BY [Interviewer Name]

/******************************************** REPORTABLE **********************************************/	

--DETERMINING THE AVERAGE SELF-EMPLOYED % TO SET OUTLIER THRESHOLD

/******************************************** REPORTABLE **********************************************/	

DECLARE @YES_PERCENTAGE_OVERAL_SELF_EMPLOYED FLOAT;

SET @YES_PERCENTAGE_OVERAL_SELF_EMPLOYED = (

												SELECT Percentage FROM
												(
												SELECT 
													[Self Employed Status], 
													--COUNT(*) AS Count,
													COUNT(*) * 100.0 / (SELECT COUNT(*) FROM DBO.BayEquityFraudCommittee WHERE [Lien Position] = 'First Lien') AS Percentage
												FROM 
													DBO.BayEquityFraudCommittee
												WHERE 
													[Lien Position] = 'First Lien'
												GROUP BY 
													[Self Employed Status]
												)C
												WHERE [Self Employed Status] = 'Yes'
											) * 2
SELECT @YES_PERCENTAGE_OVERAL_SELF_EMPLOYED 

/******************************************** REPORTABLE **********************************************/	

--SELF-EMPLOYED HIGH % FOR MLO'S
--TEMP TABLE HOLDING TOP 10 MLO'S DURING THE PAST 4 MONTHS

/******************************************** REPORTABLE **********************************************/	

IF OBJECT_ID(N'tempdb..#MLO_HIGH_Self_Employed', N'U') IS NOT NULL   
DROP TABLE #MLO_HIGH_Self_Employed

SELECT * INTO #MLO_HIGH_Self_Employed
FROM
(

	SELECT * FROM 
	(
	SELECT 
		[Interviewer Name],
		[Yes],
		[No],
		ISNULL([Yes],0) + ISNULL([No], 0) AS TOTAL,
		ROUND(CAST([YES] * 1.0 / (NULLIF(ISNULL([Yes], 0) + ISNULL([No], 0), 0)) AS FLOAT), 2) AS [YES PERCENTAGE]
		FROM
			(SELECT [Interviewer Name], Z.[Self Employed Status]
			FROM DBO.BayEquityFraudCommittee Z
			WHERE [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
			AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
			AND [Lien Position] = 'First Lien'
		) AS SOURCETABLE
	PIVOT
	(
		COUNT([Self Employed Status])
		FOR [Self Employed Status] IN ([Yes],[No])
	) AS PivotTable
	)ZZ
	WHERE [YES PERCENTAGE] >= @YES_PERCENTAGE_OVERAL_SELF_EMPLOYED * .01
	AND Yes >= 4
)DD
ORDER BY [Interviewer Name]

/******************************************** REPORTABLE **********************************************/	

SELECT * FROM #MLO_HIGH_Self_Employed

/******************************************** REPORTABLE **********************************************/	

----MLO'S SELF EMPLOYMENT OVER THE PAST 6 MONTHS yes percentage (only for last column)

SELECT * FROM 
(
SELECT 
	[Interviewer Name],
	--[Yes],
	--[No],
	--ISNULL([Yes],0) + ISNULL([No], 0) AS TOTAL,
	ROUND(CAST([YES] * 1.0 / (NULLIF(ISNULL([Yes], 0) + ISNULL([No], 0), 0)) AS FLOAT), 2) AS [YES PERCENTAGE]
	FROM
		(SELECT [Interviewer Name], Z.[Self Employed Status]
		FROM DBO.BayEquityFraudCommittee Z
		WHERE  [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
				AND [Current Status Date] <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) -4, 0)
		AND [Lien Position] = 'First Lien'
		AND [Interviewer Name] IN
		(
			SELECT DISTINCT [Interviewer Name] FROM #MLO_HIGH_Self_Employed
		)
	) AS SOURCETABLE
PIVOT
(
	COUNT([Self Employed Status])
	FOR [Self Employed Status] IN ([Yes],[No])
) AS PivotTable
)ZZ
ORDER BY [Interviewer Name]

/******************************************** REPORTABLE **********************************************/	

/***************************************************************************************************************************************
	RATIOS TRENDING
***************************************************************************************************************************************/

--TOP 10 mlo'S
--last 4 months

/******************************************** REPORTABLE **********************************************/	

	SELECT 
		[Interviewer Name],
		COUNT(*) [Funded Units],
		ROUND(AVG([Debt to Income Ratio]), 2) AS AVG_DTI
	FROM 
		DBO.BayEquityFraudCommittee
	WHERE
		[Lien Position] = 'First Lien' 
		AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
		AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
		AND [Debt to Income Ratio] < 100
		AND [Interviewer Name] IN (SELECT * FROM #Top_10_MLOs)
		AND [Loan Info Channel] = 'Banked - RetaiL'
	GROUP BY 
		[Interviewer Name]

/******************************************** REPORTABLE **********************************************/	

	--top MLO's during the past 6 months

/******************************************** REPORTABLE **********************************************/	

	SELECT 
		[Interviewer Name],
		COUNT(*) [Funded Units],
		ROUND(AVG([Debt to Income Ratio]), 2) AS AVG_DTI
	FROM 
		DBO.BayEquityFraudCommittee
	WHERE
		[Lien Position] = 'First Lien' 
		AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
		AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-4, 0)
		AND [Debt to Income Ratio] < 100
		AND [Interviewer Name] IN (SELECT * FROM #Top_10_MLOs)
		AND [Loan Info Channel] = 'Banked - RetaiL'
	GROUP BY 
		[Interviewer Name]
	ORDER BY
		[Interviewer Name]

/******************************************** REPORTABLE **********************************************/	

--high ratios for MLO General Population
--last 4 months, over 4 laons, over 48%, 1st lien, retail channel

/******************************************** REPORTABLE **********************************************/	

--TEMP TABLE HOLDING TOP 10 MLO'S DURING THE PAST 4 MONTHS
		IF OBJECT_ID(N'tempdb..#MLO_HIGH_Ratios', N'U') IS NOT NULL   
		DROP TABLE #MLO_HIGH_Ratios

SELECT * INTO #MLO_HIGH_Ratios
FROM
(
	SELECT 
		[Interviewer Name],
		ROUND(AVG([Debt to Income Ratio]), 2) AS AVG_DTI,
		COUNT(*) [Funded Units]

	FROM 
		DBO.BayEquityFraudCommittee
	WHERE
		[Lien Position] = 'First Lien' 
		AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 4, 0)
		AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
		AND [Debt to Income Ratio] < 100
		AND [Loan Info Channel] = 'Banked - RetaiL'
	GROUP BY
		[Interviewer Name]
	HAVING AVG([Debt to Income Ratio]) > 45
	AND COUNT(*) > 4
)Z

/******************************************** REPORTABLE **********************************************/	

SELECT * FROM #MLO_HIGH_Ratios ORDER BY [Interviewer Name]


--Above high ratios General MLO's during the previous 6 months

/******************************************** REPORTABLE **********************************************/	

SELECT 
	[Interviewer Name],
    ROUND(AVG([Debt to Income Ratio]), 2) AS AVG_DTI,
	COUNT(*) [Funded Units]
FROM 
    DBO.BayEquityFraudCommittee
WHERE
    [Lien Position] = 'First Lien' 
    AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 10, 0)
    AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-4, 0)
    --AND [Debt to Income Ratio] < 100
    AND [Loan Info Channel] = 'Banked - RetaiL'
	AND [Interviewer Name] IN (SELECT [Interviewer Name] FROM #MLO_HIGH_Ratios)
GROUP BY
	[Interviewer Name]
ORDER BY [Interviewer Name]

/******************************************** REPORTABLE **********************************************/	


/***************************************************************************************************************************************
	CREDIT SCORE TRENDING
***************************************************************************************************************************************/

--WHAT PERCENTAGE OF UNITS ARE BELOW 650 CREDIT SCORE

--TEMP TABLE HOLDING TOP 10 MLO'S DURING THE PAST 4 MONTHS
		IF OBJECT_ID(N'tempdb..#MLO_LOW_CREDIT_SCORE', N'U') IS NOT NULL   
		DROP TABLE #MLO_LOW_CREDIT_SCORE

/******************************************** REPORTABLE **********************************************/	

WITH InterviewerCreditScoreCounts AS (
    SELECT 
        [Interviewer Name],
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN [Lock Request Credit Score for Decision Making] < 650 THEN 1 ELSE 0 END) AS UnitsBelow650
    FROM dbo.BayEquityFraudCommittee
	WHERE [Lien Position] = 'First Lien' 
    AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) -4, 0)
    AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()),0)
    --AND [Debt to Income Ratio] < 100
    AND [Loan Info Channel] = 'Banked - RetaiL'

    GROUP BY [Interviewer Name]
    HAVING COUNT(*) > 4
)
SELECT * INTO #MLO_LOW_CREDIT_SCORE
FROM
(
	SELECT 
		[Interviewer Name],
		TotalRecords,
		UnitsBelow650,
		CAST(ROUND((CAST(UnitsBelow650 AS DECIMAL(10,2)) / TotalRecords) * 1.0, 2) AS DECIMAL(5,2)) AS PercentBelow650
	FROM InterviewerCreditScoreCounts
	WHERE ((CAST(UnitsBelow650 AS DECIMAL(10,2)) / TotalRecords) * 1.0) > .30
)Z

/******************************************** REPORTABLE **********************************************/	

SELECT * FROM #MLO_LOW_CREDIT_SCORE

----Above MLO's LOW FICO during the previous 6 months

/******************************************** REPORTABLE **********************************************/	

WITH InterviewerCreditScoreCounts AS (
    SELECT 
        [Interviewer Name],
        COUNT(*) AS TotalRecords,
        SUM(CASE WHEN [Lock Request Credit Score for Decision Making] < 650 THEN 1 ELSE 0 END) AS UnitsBelow650
    FROM dbo.BayEquityFraudCommittee
	WHERE [Lien Position] = 'First Lien' 
    AND [Current Status Date] >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) -10, 0)
    AND [Current Status Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-4, 0)
    AND [Interviewer Name] IN (SELECT [Interviewer Name] FROM #MLO_LOW_CREDIT_SCORE)
    AND [Loan Info Channel] = 'Banked - RetaiL'
    GROUP BY [Interviewer Name]
)

	SELECT 
		[Interviewer Name],
		TotalRecords,
		UnitsBelow650,
		CAST(ROUND((CAST(UnitsBelow650 AS DECIMAL(10,2)) / TotalRecords) * 1.0, 2) AS DECIMAL(5,2)) AS PercentBelow650
	FROM InterviewerCreditScoreCounts

/******************************************** REPORTABLE **********************************************/