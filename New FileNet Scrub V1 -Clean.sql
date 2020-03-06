SET NOCOUNT ON
--BASE--
SELECT
A.[LOAN NUMBER]
/*
,CASE
WHEN E.DOCUMENT IN ('Trust - HACG','Trust') THEN A.[Loan Number]+'TRUST1'
WHEN E.DOCUMENT IN ('Current OCC Cert') THEN A.[Loan Number]+'OCCERT1'
WHEN E.DOCUMENT IN ('HOA') THEN A.[Loan Number]+'HOADOCS1'
WHEN E.DOCUMENT IN ('Death Cert HACG','Death Cert') THEN A.[Loan Number]+'C.DEATH1'
WHEN E.DOCUMENT IN ('Proof of Repair') THEN A.[Loan Number]+'REPAIRS1'
END AS 'Concat'

,NUll AS 'GUID'
,NULL AS 'Invalid Check'
,NULL AS 'Date Created'*/
,GETDATE() AS 'Refreshed'
,case
	when E.Document is null then 'No Issue'
	when E.[Document] IN ('Trust','Trust - HACG') THEN 'Trust'
	when E.[Document] IN ('Death Cert','Death Cert HACG') THEN 'Death Cert'
	when e.[Document] is not null AND E.[Document] NOT IN ('Trust','Trust - HACG') AND E.[Document] NOT IN ('Death Cert','Death Cert HACG') then e.[Document]
	ELSE E.[Document]
	end as 'Document'
/*,NULL AS 'DateDiff'
,NULL AS 'DateCheck'*/
,E.Issue
,Cast(E.[Exception Request Date] AS Date) AS 'Exception Request Date'
,DATEDIFF(day,E.[Exception Request Date],Getdate()) AS 'Aged'
,a.[tag 2]
,a.[incurable flag]
,a.[loan status]
,a.Stage
,a.[mca %]
,CASE
	WHEN a.[MCA %] >= 97.5 THEN '>= 97.5'
	WHEN a.[MCA %] < 97.5 THEN '< 97.5'
		ELSE 'Error'
	END AS 'MCA Flag'
,e.[Exception ID]
,b.[final review assigned to]
,c.[hud assigned to]
,r.mgr_nm
,r.st_loc
,t.[Open Exceptions]
,T.OpenCurative
,T.OpenHACG
,case
	when C.[HUD Status] IN ('Pkg Submitted to HUD','resubmitted to hud','rebuttal to hud') then 'Submitted'
	when c.[hud status] in ('hud approved') then 'HUD Approved'
	else 'Not Submitted'
	end as 'Status'
 ,CASE 
	WHEN E.[Document] = 'Current OCC Cert' THEN 'OCCERT'
	WHEN E.[Document] = 'TRUST' THEN 'Trust'
	WHEN E.[Document] = 'HOA' THEN 'HOADOCS'
	WHEN E.[Document] = 'Death Cert' THEN 'C.DEATH'
	WHEN E.[Document] = 'Proof of Repair' THEN 'REPAIRS'
END AS 'Excp_FN_Code'
,CASE
WHEN E.[Document] = 'Proof of Repair' THEN 'REPAIRINS' 
END AS 'Por_FN_Code_2'
,[Final Review Status]
,[HUD Preliminary Title Approval]
--,CASE
	--WHEN b.[Final Review Status Date] > C.[HUD Status Date] THEN CONVERT(NVARCHAR(10),b.[Final Review Status Date],101)
	--WHEN b.[Final Review Status Date] < C.[HUD Status Date] THEN CONVERT(NVARCHAR(10),C.[HUD Status Date],101)
	--ELSE CONVERT(NVARCHAR(10),b.[Final Review Status Date],101) END AS 'Last Updated'

--,CASE
	--WHEN B.[Final Review Comment] > C.[HUD Status Comment] THEN B.[Final Review Comment]
	--WHEN B.[Final Review Comment] < C.[HUD Status Comment] THEN C.[HUD Status Comment]
	--ELSE B.[Final Review Comment]  END AS 'Last Comment'
,E.[Exception Status]
,E.[Exception Status Updated By]
,Cast(E.[Exception Status Date] AS Date) AS 'Exception Status Date'
--INTO #Exceptions
,CASE
WHEN [Document] IN ('HOA')
THEN (SELECT CAST(MIN(V) AS DATE) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3]),([Ledger Letter Sent 1]),	([Ledger Letter Sent 2]),	([Ledger Letter Sent 3]),	([Non GC Letter Sent 1]),	([Non GC Letter Sent 2]),	([Non GC Letter Sent 3])) AS VALUE (V)) 
WHEN [Document] IN ('Current OCC Cert') 
THEN (SELECT CAST(MIN(V) AS DATE) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3]),([Non GC Letter Sent 1]),	([Non GC Letter Sent 2]),	([Non GC Letter Sent 3])) AS VALUE (V)) 
ELSE (SELECT CAST(MIN(V) AS DATE) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3])) AS VALUE (V)) 
END AS 'Min Letter Date'
INTO #BASE
FROM Proprietary_Loan_Status A
LEFT JOIN Proprietary_Workable_Table B
ON a.[LOAN NUMBER]=b.[LOAN NUMBER]
LEFT JOIN (SELECT [LOAN NUMBER],[EXCEPTION ID],[DOCUMENT],[ISSUE], [EXCEPTION ASSIGNED TO],[EXCEPTION REQUEST DATE],[EXCEPTION STATUS],[EXCEPTION STATUS DATE],[Exception Status Updated By],[Gift Card Letter Sent],[Gift Card Letter Sent 2],	[Gift Card Letter Sent 3],[Ledger Letter Sent 1],[Ledger Letter Sent 2],[Ledger Letter Sent 3],[Non GC Letter Sent 1],[Non GC Letter Sent 2],[Non GC Letter Sent 3] FROM Proprietary_Exception_Table WHERE [Document] IN ('Trust - HACG','Trust','Current OCC Cert','HOA','Death Cert HACG','Death Cert','Proof of Repair') AND [EXCEPTION STATUS] NOT IN ('RESOLVED','CLOSED','NOT VALID','CLOSED WITH VENDOR')) E
ON A.[LOAN NUMBER]=E.[Loan Number]
LEFT JOIN Proprietary_Assignment_Table C
ON a.[LOAN NUMBER]=c.[LOAN NUMBER]
LEFT JOIN Proprietary_Exception_Total_Table  T
on a.[Loan Number]=T.[Loan Number]
left join Proprietary_Employ_Roster_Total_Table r
on c.[HUD Assigned To]=r.agnt_nm

WHERE a.[Loan Status] in ('Active') AND A.[Tag 2] is NULL AND A.[Incurable Flag] in ('0') AND (a.[Group] in ('Grp 1 NSM Balance Sheet','Grp 2 FNMA','Grp 3 GNMA excl BofA','Grp 4 Trust / Private exlc BofA','Grp 4 Trust / Private exlc BofA') or
a.[Group] is null) and	c.[HUD Status] not in ('HUD Approved','Pkg Submitted to HUD','Resubmitted to HUD','Rebuttal to HUD')
AND E.[Document] IS NOT NULL
--AND [Final Review Status] IN ('Pending QC')
 ORDER BY E.Document,'MCA Flag' DESC

 --Invalid Scrub--
 SELECT B.*
 ,D.[OBJ_ID],
  CASE 
	WHEN D.[UA878_ORGNL_DOC_NM] = 'OCCERT' THEN 'Current OCC Cert'
	WHEN D.[UA878_ORGNL_DOC_NM] = 'TRUST' THEN 'Trust'
	WHEN D.[UA878_ORGNL_DOC_NM] = 'HOADOCS' THEN 'HOA'
	WHEN D.[UA878_ORGNL_DOC_NM] = 'C.DEATH' THEN 'Death Cert'
	WHEN D.[UA878_ORGNL_DOC_NM] IN ('REPAIRINS','REPAIRS') THEN 'Proof of Repair'
	END AS 'Invalid_Excp_Type'
,[CRE_DT]
,CASE WHEN '{' + D.[OBJ_ID] + '}' = C.[GUID] THEN 'Invalid'
ELSE 'Valid'
END AS 'Invalid_Flag'

INTO #INVALID
 FROM #BASE B
 LEFT JOIN Proprietary_InvalidFileNet C
	ON B.[Loan Number] = C.Loan_Nbr
 LEFT JOIN Proprietary_FileNet_Table
	ON B.[Loan Number] = Replace(ltrim(replace(D.[U03D8_NSM_LOAN_NBR],'0',' ')),' ','0') 

WHERE  D.[U3FC8_DOC_TYPE_CD] = Excp_FN_Code OR ISNULL(Por_FN_Code_2 ,'NOTPOREXCEPTION') = D.[U3FC8_DOC_TYPE_CD]
AND ABS(DATEDIFF(M,CAST(GETDATE() AS DATE),CAST([CRE_DT] AS DATE))) <= 10

--Final--
SELECT A.[LOAN NUMBER],A.Refreshed,A.[MCA %],A.[MCA Flag],'{' + B.[OBJ_ID] + '}' AS 'GUID',B.CRE_DT AS 'Date Created',A.[Document],A.[Issue],A.[Exception Request Date]

FROM #BASE A
	LEFT JOIN #INVALID B
ON A.[Loan Number] = B.[Loan Number]
	LEFT JOIN (SELECT [Exception ID],MAX([CRE_DT]) AS 'Invalid_DT' FROM #INVALID WHERE Invalid_Flag = 'Invalid' GROUP BY [Exception ID]) C
ON A.[Exception ID] = C.[Exception ID]
	LEFT JOIN (SELECT [Exception ID],MAX([CRE_DT]) AS 'Valid_DT' FROM #INVALID WHERE Invalid_Flag = 'Valid' GROUP BY [Exception ID]) D
ON A.[Exception ID] = D.[Exception ID]
WHERE B.CRE_DT = Valid_DT AND B.CRE_DT > ISNULL(Invalid_DT,CAST('1/1/1900' AS DATE))

ORDER BY [Document],[MCA %] DESC


DROP TABLE #BASE,#INVALID

