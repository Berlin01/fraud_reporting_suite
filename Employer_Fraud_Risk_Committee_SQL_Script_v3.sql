/*****************************************************
Author:         Corey Smith
Written:        5/13/24
Purpose:        Bay Equity Fraud Committee: Employer
******************************************************
Modification History

Update		Version	Comments
05/13/24	1		Created Recurring Employer script
05/23/24	2		Added table name to stored procedure
09/10/2024	2		Added US Air Force one-off change (USAF)
09/10/2024	3		Enhanced script to show activity each month

******************************************************/

USE [ICReporting];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT OFF
GO

/***************************************************************************************************************************************
	EMPLOYER ANALYSIS
***************************************************************************************************************************************/
--Surface recurring employers for analysis
	--employers used by the same MLO >= 3x over a 4-month perior

IF OBJECT_ID('RiskCommittee_EmployerTable', 'U') IS NOT NULL 
DROP TABLE dbo.RiskCommittee_EmployerTable; 


CREATE TABLE RiskCommittee_EmployerTable(RowID int IDENTITY(1, 1), 
RE_Agent nvarchar(200), MLO nvarchar(200), Employer nvarchar(200), LoanNumber nvarchar(255), StatusDate DATE)
GO

--NEED ALL 4 MONTHS FOR PROCESSING AND REPORTING...DO NOT GO WITH JUST THE MOST RECENT MONTH

DECLARE @STARTDATE AS DATETIME, @ENDDATE AS DATETIME
SET @STARTDATE = DATEADD(MONTH, -4, dbo.GetFirstDayOfMonth(GETDATE())) --first day calendar date four months before the EndDate
SET @ENDDATE = DATEADD(DAY, -1, dbo.GetFirstDayOfMonth(GETDATE())) --last date of the previous momth
PRINT @STARTDATE
PRINT @ENDDATE


--Field, table, number of months processed
EXEC CreateBE_RiskCommittee_EmployerTable '[Borr Employer]', @STARTDATE, @ENDDATE
EXEC CreateBE_RiskCommittee_EmployerTable '[Borr Employer - 2nd]', @STARTDATE, @ENDDATE
EXEC CreateBE_RiskCommittee_EmployerTable '[Co-Borr Employer]', @STARTDATE, @ENDDATE
EXEC CreateBE_RiskCommittee_EmployerTable '[Co-Borr Employer - 2nd]', @STARTDATE, @ENDDATE

--VERIFY CORRECT DATE RANGE
--SELECT DISTINCT A.StatusDate FROM RiskCommittee_EmployerTable A ORDER BY A.StatusDate

/****************************************************
Data Integrity Processing for Employer Names
****************************************************/

-->>>>>>>>>>Remove Basic Punctuation<<<<<<<<<<

UPDATE dbo.RiskCommittee_EmployerTable
SET [Employer] =	REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
					[Employer]
					,',','') --remove commas
					,'.','') --remove periods
					,'&','and') --remove and
					,'  ',' ')--convert two spaces to one space
					,'-','') --remove hypens
FROM dbo.RiskCommittee_EmployerTable
GO
PRINT 'Removed common punctuation from employer names'

-->>>>>>>>>>Standardize Company Names<<<<<<<<<<
--remove common prefixes and entity identifiers
--(i.e. "Microsoft LLC", and "Microsoft International" = "Microsoft")

DECLARE @outsideCounter int, @insideCounter int, @outsideCount int, @insideCount int
DECLARE	@OUTSIDELOOP nvarchar(40), @INSIDELOOP nvarchar(40), @FindCount int

SET @outsideCount = (	SELECT COUNT(*) FROM dbo.RiskCommittee_EmployerTable)
SET @insideCount = (	SELECT COUNT(*) FROM [dbo].[BusinessEntityIndexes])

SET @outsideCounter = 1
SET @insideCounter = 1
SET @FindCount = 0
WHILE @outsideCounter <= @outsideCount --outside counter
BEGIN
	SET @OUTSIDELOOP = (SELECT Employer FROM dbo.RiskCommittee_EmployerTable WHERE RowID = @outsideCounter)
	SET @insideCounter = 1
	SET @FindCount = 0
	WHILE @insideCounter <= @insideCount
		BEGIN
			SET @INSIDELOOP = (SELECT [Business Entities] FROM [dbo].[BusinessEntityIndexes] WHERE RowID = @insideCounter)
			IF
				(SELECT CHARINDEX (@INSIDELOOP, UPPER(@OUTSIDELOOP), len(@OUTSIDELOOP) - len(@INSIDELOOP)+1)) > 0
				AND
				(SELECT SUBSTRING(@OUTSIDELOOP,len(@OUTSIDELOOP) - len(@INSIDELOOP) , 1)) = ' '
			BEGIN
				UPDATE dbo.RiskCommittee_EmployerTable
				SET [Employer]  = STUFF(@OUTSIDELOOP,len(@OUTSIDELOOP) - len(@INSIDELOOP),len(@INSIDELOOP)+1,'')
				FROM dbo.RiskCommittee_EmployerTable
				WHERE [Employer] = @OUTSIDELOOP
				SET @OUTSIDELOOP = STUFF(@OUTSIDELOOP,len(@OUTSIDELOOP) - len(@INSIDELOOP),len(@INSIDELOOP)+1,'')
				SET @insideCounter = 0
			END
			SET @insideCounter = @insideCounter + 1
		END
	SET @outsideCounter = @outsideCounter + 1
END

-->>>>>>>>>>Process Employer Name one-off Exceptions<<<<<<<<<<


   -- Update Amazon-related names
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'Amazon'
    WHERE Employer IN 
    (
        'Amazon Web',
        'Amazoncom',
        'Amazoncom inc and its affiliates',
        'Amazon (Ring)',
        'Amazon Advertising',
        'Amazon Dev Center US',
        'Amazon Dvlp Cnt',
        'Amazon Fulfillment Cen',
        'Amazon/Choice Delivery',
		'Amazon Retail'
    );
	GO

    -- Update Bay Equity
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'Bay Equity'
    WHERE Employer = 'Bay Equity Home Loans';
	GO
    -- Update Boeing
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'Boeing'
    WHERE Employer = 'The Boeing';
	GO
    -- Update Achieve Consulting Team
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'Achieve Consulting Team'
    WHERE Employer = 'Acheive Consulting Team';
	GO
    -- Update Chicago Public Schools
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'Chicago Public Schools'
    WHERE Employer = 'Chicago Public School';
	GO
    -- Update Costco Wholesale
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'Costco Wholesale'
    WHERE (Employer = 'Costco' 
		OR Employer LIKE 'COSTCO %')
		AND Employer != 'Costco Wholesale';
	GO
    -- Update COOK COUNTY GOVERNMENT
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'COOK COUNTY GOVERNMENT'
    WHERE Employer = 'COOK COUNTY GOVERMENT';
	GO
    -- Update US Army
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'US Army'
    WHERE Employer = 'Army';
	GO
	-- Update UPS
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'UPS'
    WHERE Employer = 'United Parcel';
	GO

	-- Update US Ai Force
    UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'US Air Force'
    WHERE Employer IN ('USAF','Air Force','United States Air Force');
	GO

	-- Update USPS
	UPDATE dbo.RiskCommittee_EmployerTable
    SET Employer = 'US Postal'
    WHERE Employer = 'USPS';
	GO




 --Integrity Script....visually review to see if any employers need to be a one-off exception below
 --future...create a script that estimates when there is a problem based on probability of matching names (i.e. boeing vs boeingg)
 
 SELECT trim(Employer), COUNT(*) as [Employer Name Input]
 FROM dbo.RiskCommittee_EmployerTable A
 WHERE TRIM(A.Employer) > ''
 GROUP BY Employer
 HAVING COUNT(*) >= 4
 ORDER BY Employer

 --SELECT * 
 --FROM dbo.RiskCommittee_EmployerTable A
 --WHERE Employer LIKE '%air force%'

 --begin transaction
 --update dbo.RiskCommittee_EmployerTable
 --set Employer = 'Walmart'
 --where Employer = 'Walmart Associates'
 --commit

 
 
--REPORT: SUMMARIZE by Employer
--Employer---count where count > 3x during past four months (same employer surfacing each month)
--must change script...hard coded
/*REPORTABLE******************************************************************/

IF OBJECT_ID(N'tempdb..#Recurring_Employers', N'U') IS NOT NULL   
DROP TABLE #Recurring_Employers

SELECT * INTO #Recurring_Employers FROM
(
SELECT * FROM
(
SELECT 
    Employer,
    
    [June 2024],
    [July 2024],
    [August 2024],
	[September 2024],
    ISNULL([June 2024], 0) + ISNULL([July 2024], 0) + ISNULL([August 2024], 0) + ISNULL([September 2024], 0)  AS Total
FROM 
    (SELECT 
         Employer, 
         FORMAT(StatusDate, 'MMMM yyyy') AS MonthYear
     FROM 
         dbo.RiskCommittee_EmployerTable) AS SourceTable
PIVOT
(
    COUNT(MonthYear)
    FOR MonthYear IN ([June 2024], [July 2024], [August 2024],[September 2024])
) AS PivotTable
	)z

	where z.Total >= 4
	--ORDER BY Total desc
)X

SELECT * FROM #Recurring_Employers

--get six-month data

SELECT Employer FROM #Recurring_Employers

--Research: script to generate additional details if needed for research
--SELECT * FROM [dbo].[BayEquityFraudCommittee] A
--WHERE A.[Borr Employer] LIKE '%broadcom%'
--OR A.[Co-Borr Employer] LIKE '%broadcom%'
--OR A.[Borr Employer - 2nd] LIKE '%broadcom%'
--OR A.[Borr Self Employed - 2nd] LIKE '%broadcom%'


 --REPORT: SUMMARIZE MLO-to-Employer
--MLO---Employer---count where count > 3x during past four months (same employer surfacing each month)

/*REPORTABLE******************************************************************/
	--oroginal reporting script
 --SELECT A.MLO, Employer, COUNT(*) as Units
 --FROM dbo.RiskCommittee_EmployerTable A
 --GROUP BY MLO, Employer
 --HAVING COUNT(*) >= 3
 --ORDER BY COUNT(*) DESC, A.MLO ASC


 SELECT * FROM
(
SELECT 
    MLO,
	Employer,
    [June 2024],
    [July 2024],
    [August 2024],
	[September 2024],
    ISNULL([June 2024], 0) + ISNULL([July 2024], 0) + ISNULL([August 2024], 0) + ISNULL([September 2024], 0) AS Total
FROM 
    (SELECT 
         MLO,
		 Employer, 
         FORMAT(StatusDate, 'MMMM yyyy') AS MonthYear
     FROM 
         dbo.RiskCommittee_EmployerTable) AS SourceTable
PIVOT
(
    COUNT(MonthYear)
    FOR MonthYear IN ([June 2024], [July 2024], [August 2024], [September 2024])
) AS PivotTable
	)z

	where z.Total >= 3
	ORDER BY 
    Total desc

 
--SUMMARIZE RE_Agent-to-Employer

/*REPORTABLE******************************************************************/
 --SELECT A.RE_Agent,a.Employer, COUNT(*) as Units
 --FROM dbo.RiskCommittee_EmployerTable A
 --GROUP BY a.RE_Agent, Employer
 --HAVING COUNT(*) >= 3
 --ORDER BY COUNT(*) DESC, RE_Agent ASC

  SELECT * FROM
(
SELECT 
    RE_Agent,
	Employer,
    [June 2024],
    [July 2024],
    [August 2024],
	[September 2024],
    ISNULL([June 2024], 0) + ISNULL([July 2024], 0) + ISNULL([August 2024], 0) + ISNULL([September 2024],0) AS Total
FROM 
    (SELECT 
         RE_Agent,
		 Employer, 
         FORMAT(StatusDate, 'MMMM yyyy') AS MonthYear
     FROM 
         dbo.RiskCommittee_EmployerTable) AS SourceTable
PIVOT
(
    COUNT(MonthYear)
    FOR MonthYear IN ([June 2024], [July 2024], [August 2024],[September 2024])
) AS PivotTable
	)z

	where z.Total >= 3
	ORDER BY 
    Total desc;


	--trying to troubleshoot blank realtors
	--select a.*, b.Purpose, b.Channel, b.LoanStatus
	--from  dbo.RiskCommittee_EmployerTable a
	--left join dbo.EncompassFundedLoans b
	--	 on a.LoanNumber = b.LoanNumber
	--where trim(RE_Agent) = ''
	--and LoanStatus = 'Loan Originated'
	--order by StatusDate desc