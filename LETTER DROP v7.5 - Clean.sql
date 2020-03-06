Set NoCount ON
SET ANSI_WARNINGS OFF 
--Base Population--
SELECT A.[Loan Number],A.[Loan Status],A.[TAG 2],A.[Incurable Flag],CAST(D.[MCA_PERCENT] AS Float(2)) AS 'MCA %'
,CASE
WHEN D.[MCA_PERCENT] < 95 THEN '< 95'
WHEN D.[MCA_PERCENT] BETWEEN 95 AND 96.49 THEN '95 < 96.5'
WHEN D.[MCA_PERCENT] BETWEEN 96.5 AND 97.49 THEN '96.5 < 97.5'
WHEN D.[MCA_PERCENT] BETWEEN 97.5 AND 99.99 THEN '97.5 < 100'
WHEN D.[MCA_PERCENT] >= 100 THEN '>= 100'
ELSE 'Error'
END AS 'MCA Flag'
,B.[HUD Status],C.[Final Review Status],B.[HUD Assigned To],C.[Final Review Assigned To],A.[Group]
,D.[Current Year Anniversary of Loan Closing Date],D.[Next Year Anniversary of Loan Closing Date]
,ABS(DATEDIFF(Month,GETDATE(),D.[Current Year Anniversary of Loan Closing Date])) AS 'Curr_Anni'
,ABS(DATEDIFF(Month,GETDATE(),D.[Next Year Anniversary of Loan Closing Date])) AS 'Next_Anni'
INTO #LoanStatus
FROM Proprietary_Loan_Status A
LEFT JOIN Proprietary_HUD_Status_Table B
ON A.[Loan Number] = B.[Loan Number]
LEFT JOIN Proprietary_Workable_Table C
ON A.[Loan Number] = C.[Loan Number]
LEFT JOIN Tact_Rev.[dbo].[champbase] D
ON A.[Loan Number] = D.Loan_Nbr
WHERE A.[Loan Status] IN ('Active') AND  A.[TAG 2] IS NULL AND A.[Incurable Flag] IN ('0')
AND (A.[GROUP] IN ('Grp 1 NSM Balance Sheet',	'Grp 3 GNMA excl BofA',	'Grp 2 FNMA',	'Grp 4 Trust / Private exlc BofA') OR A.[GROUP] IS NULL)
AND B.[HUD Status] IN ('Not Started','HUD Denied')

--Exception Scrub--
SELECT B.*
,CASE
WHEN B.[Document] IN ('HOA')
THEN (SELECT MAX(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3]),([Ledger Letter Sent 1]),	([Ledger Letter Sent 2]),	([Ledger Letter Sent 3]),	([Non GC Letter Sent 1]),	([Non GC Letter Sent 2]),	([Non GC Letter Sent 3])) AS VALUE (V)) 
WHEN B.[Document] IN ('Current OCC Cert') 
THEN (SELECT MAX(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3]),([Non GC Letter Sent 1]),	([Non GC Letter Sent 2]),	([Non GC Letter Sent 3])) AS VALUE (V)) 
ELSE (SELECT MAX(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3])) AS VALUE (V)) 
END AS 'Max Date'

,(SELECT COUNT(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),([Gift Card Letter Sent 3]),([Non GC Letter Sent 1]),([Non GC Letter Sent 2]),([Non GC Letter Sent 3])) AS VALUE (V)) AS 'LTR Count'
--,C.END_DTTM AS 'Exception Last Resolved'
INTO #Exceptions
FROM #LoanStatus A
	LEFT JOIN Proprietary_Exception_Table B
		ON A.[Loan Number] = B.[Loan Number]

/*EXCEPTION Reopen SCRUB		LEFT JOIN (SELECT [Excp_ID], MAX([END_DTTM]) AS 'END_DTTM' FROM [VRSQLRODS\RODS_PROD].Reverse_DW.[dbo].[HUD_ASGN_EXCP_EDW] WHERE [Doc_Desc] IN ('Current OCC Cert') AND [EXCP_STS_DESC] IN ('CLOSED','RESOLVED','NOT VALID','INCURABLE','CLOSED WITH VENDOR') AND Curr_Ind NOT IN ('Y') GROUP BY [EXCP_ID]) C
		ON B.[Exception ID] = C.[Excp_ID]*/

WHERE (Document IN ('Current Occ Cert') AND A.[MCA %] >= 95 AND [EXCEPTION STATUS] NOT IN ('CLOSED','RESOLVED','NOT VALID','INCURABLE','CLOSED WITH VENDOR')) OR (Document IN ('Death Cert HACG','Trust - HACG') AND A.[MCA %] >= 95 AND [EXCEPTION STATUS] NOT IN ('CLOSED','RESOLVED','NOT VALID','INCURABLE','CLOSED WITH VENDOR'))
OR (A.[MCA %] >= 95 AND ISNULL(B.[Proof of Repairs Status],'No Status') NOT IN ('Report/Inspection complete repairs are not complete') AND Document IN ('Proof of Repair') AND [EXCEPTION STATUS] NOT IN ('CLOSED','RESOLVED','NOT VALID','INCURABLE','CLOSED WITH VENDOR'))
OR (Document IN ('HOA') AND A.[MCA %] >=96 AND B.Issue IN ('Missing','Missing Contact Info','Authorization Received - Invalid','BCR- Authorization required','BCR- Missing Contact information','BCR- No HOA required','BCR- Uncooperative-Unresponsive','BCR- Authorization Received') AND [EXCEPTION STATUS] NOT IN ('CLOSED','RESOLVED','NOT VALID','INCURABLE','CLOSED WITH VENDOR')) 

/*
--Max Letter Date--
SELECT ,(SELECT MAX(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3]),([Ledger Letter Sent 1]),	([Ledger Letter Sent 2]),	([Ledger Letter Sent 3]),	([Non GC Letter Sent 1]),	([Non GC Letter Sent 2]),	([Non GC Letter Sent 3])) AS VALUE (V)) AS 'Max Date'
	,(SELECT COUNT(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),	([Gift Card Letter Sent 3]),([Ledger Letter Sent 1]),	([Ledger Letter Sent 2]),	([Ledger Letter Sent 3]),	([Non GC Letter Sent 1]),	([Non GC Letter Sent 2]),	([Non GC Letter Sent 3])) AS VALUE (V)) AS 'LTR Count'
INTO #MAXDATE
FROM #Exceptions
WHERE [Document] IN ('HOA')

INSERT INTO #MAXDATE
SELECT #Exceptions.*,(SELECT MAX(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),([Gift Card Letter Sent 3]),([Non GC Letter Sent 1]),([Non GC Letter Sent 2]),([Non GC Letter Sent 3])) AS VALUE (V)) AS 'Max Date'
	,(SELECT COUNT(V) FROM (VALUES ([Gift Card Letter Sent]),([Gift Card Letter Sent 2]),([Gift Card Letter Sent 3]),([Non GC Letter Sent 1]),([Non GC Letter Sent 2]),([Non GC Letter Sent 3])) AS VALUE (V)) AS 'LTR Count'
FROM #Exceptions
WHERE [Document] IN ('CURRENT OCC CERT')
*/

--HOA--
SELECT A.[Loan Number] ,CAST(GETDATE() AS DATE) AS 'TODAY',A.[Loan Status],A.[TAG 2],A.[Incurable Flag],CAST(A.[MCA %] AS Float(2)) AS 'MCA %'
,CASE 
WHEN A.[MCA %] < 95.5 THEN 'DO_NOT_SEND'
WHEN ABS(DATEDIFF(DAY,GETDATE(),B.[MAX DATE])) < 30 THEN 'DO_NOT_SEND'
WHEN [Sent For Gift Card Processing] IS NOT NULL AND B.[Ledger Sent for Gift Card Processing] IS NOT NULL THEN 'DO_NOT_SEND'
WHEN [Sent For Gift Card Processing] IS NOT NULL and A.[MCA %] < 97 AND [ISSUE] IN ('Authorization Received - Valid') THEN 'DO_NOT_SEND'
WHEN [Non GC Letter Document Returned] IS NOT NULL and A.[MCA %] < 97 AND [ISSUE] IN ('Authorization Received - Valid') THEN 'DO_NOT_SEND'
WHEN DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) <= 20 THEN  'DO_NOT_SEND'
--WHEN [Sent For Gift Card Processing] IS NOT NULL AND [ISSUE] IN ('Missing Contact Info','Missing') THEN 'Review Issue - Doc Received'
--WHEN [Non GC Letter Document Returned] IS NOT NULL AND [ISSUE] IN ('Missing Contact Info','Missing') THEN 'Review Issue - Doc Received'
WHEN A.[MCA %] >= 96 AND [Non GC Letter Sent 1] IS NULL AND ISSUE IN ('Missing Contact Info','Authorization Received - Invalid') THEN 'Send Non GC 1'
WHEN A.[MCA %] >=96 AND [Non GC Letter Sent 2] IS NULL AND ISSUE IN ('Missing Contact Info','Authorization Received - Invalid') THEN 'Send Non GC 2'
WHEN A.[MCA %] >=96 AND [Non GC Letter Sent 3] IS NULL AND ISSUE IN ('Missing Contact Info','Authorization Received - Invalid') THEN 'Send Non GC 3'
WHEN A.[MCA %] >=96 AND [Non GC Letter Sent 3] IS NOT NULL AND ISSUE IN ('Missing Contact Info','Authorization Received - Invalid') THEN 'Incurable Review - Send Non GC 3'
WHEN A.[MCA %] >=97 AND B.[Ledger Letter Sent 1] IS NULL THEN 'Send Ledger 1'
WHEN A.[MCA %] >=97 AND B.[Ledger Letter Sent 2] IS NULL THEN 'Send Ledger 2'
WHEN A.[MCA %] >=97 AND B.[Ledger Letter Sent 3] IS NULL THEN 'Send Ledger 3'
WHEN A.[MCA %] >=97 AND B.[Ledger Letter Sent 3] IS NOT NULL THEN 'Send Ledger 3 - Incurable Review'
WHEN (A.[MCA %] >= 96.5 AND A.[MCA %] < 97) AND [Sent For Gift Card Processing] IS NOT NULL THEN 'DO_NOT_SEND'
/*WHEN (A.[MCA %] >= 96.5 AND A.[MCA %] < 97) AND [Gift Card Letter Sent] IS NULL THEN 'Send GC 1'
WHEN (A.[MCA %] >= 96.5 AND A.[MCA %] < 97) AND [Gift Card Letter Sent 2] IS NULL THEN 'Send GC 2'
WHEN (A.[MCA %] >= 96.5 AND A.[MCA %] < 97) AND [Gift Card Letter Sent 3] IS NULL THEN 'Send GC 3'*/
ELSE 'DO_NOT_SEND'
END AS 'Send Flag'
,[Exception ID],[Document],[Exception Status],[Issue],CAST([Gift Card Letter Sent] AS DATE) AS 'Gift Card Letter Sent',	CAST([Gift Card Letter Sent 2] AS DATE) AS 'Gift Card Letter Sent 2',	CAST([Gift Card Letter Sent 3] AS DATE) AS 'Gift Card Letter Sent 3',	CAST([Sent For Gift Card Processing] AS DATE) AS 'Sent For Gift Card Processing',	CAST([Document Returned] AS DATE) AS 'Document Returned',	CAST([Ledger Letter Document Returned] AS DATE) AS 'Ledger Letter Document Returned',	CAST([Ledger Letter Sent 1] AS DATE) AS 'Ledger Letter Sent 1',	CAST([Ledger Letter Sent 2] AS DATE) AS 'Ledger Letter Sent 2',	CAST([Ledger Letter Sent 3] AS DATE) AS 'Ledger Letter Sent 3',	CAST([Ledger Sent for Gift Card Processing] AS DATE) AS 'Ledger Sent for Gift Card Processing',	CAST([Non GC Letter Sent 1] AS DATE) AS 'Non GC Letter Sent 1',	CAST([Non GC Letter Sent 2] AS DATE) AS 'Non GC Letter Sent 2',	CAST([Non GC Letter Sent 3] AS DATE) AS 'Non GC Letter Sent 3',	CAST([Non GC Letter Document Returned] AS DATE) AS 'Non GC Letter Document Returned',CAST([Max Date] AS DATE) AS 'Max Date',
DATEDIFF(DAY,CAST(GETDATE() AS DATE),CAST([Max Date] AS DATE))
[LTR Count]
INTO #HOA
FROM #LoanStatus A
LEFT JOIN #Exceptions B
ON A.[Loan Number] = B.[Loan Number]
WHERE B.[Document] IN ('HOA') AND A.[MCA %] >= 96

--OCC--
SELECT A.[Loan Number],CAST(GETDATE() AS DATE) AS 'TODAY',A.[Loan Status],A.[TAG 2],A.[Incurable Flag],CAST(A.[MCA %] AS Float(2)) AS 'MCA %'
,CASE 
WHEN A.[MCA %] >= 96.5 AND DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) <= 20 THEN  'DO_NOT_SEND'
WHEN A.[MCA %] < 96.5 AND DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) <= 30 THEN  'DO_NOT_SEND'
WHEN A.[MCA %] >= 96.5 AND [Sent For Gift Card Processing] IS NOT NULL THEN 'Review to Reopen'
--WHEN A.[MCA %] >= 96.5 AND [Sent For Gift Card Processing] IS NOT NULL AND CAST([Sent For Gift Card Processing] AS DATE) <= CAST([OCC Last Resolved] AS DATE) THEN 'Send GC 1 - Confirm Reopen with TS Team - Clear GC Dates - Restart Treament'
WHEN A.[MCA %] >= 96.5 AND [Gift Card Letter Sent] IS NULL THEN 'Send GC 1'
WHEN A.[MCA %] >= 96.5 AND [Gift Card Letter Sent 2] IS NULL THEN 'Send GC 2'
WHEN A.[MCA %] >= 96.5 AND [Gift Card Letter Sent 3] IS NULL THEN 'Send GC 3'
WHEN A.[MCA %] >= 96.5 AND [Gift Card Letter Sent 3] IS NOT NULL AND ([Sent to Inspection Vendor] IS NOT NULL OR [Ledger Letter Sent 1] IS NOT NULL) THEN 'DO_NOT_SEND'
WHEN A.[MCA %] >= 96.5 AND [Gift Card Letter Sent 3] IS NOT NULL AND [Sent to Inspection Vendor] IS NOT NULL AND [Ledger Letter Document Returned] IS NOT NULL THEN 'Send GC 3 - Incurable Review'
WHEN A.[MCA %] < 96.5 AND (Curr_Anni IN (0,1) OR Next_Anni IN (0,1)) THEN 'DO_NOT_SEND'
WHEN A.[MCA %] < 96.5 AND [Non GC Letter Sent 1] IS NULL AND DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) >= 30 THEN 'Send Non GC 1'
WHEN A.[MCA %] < 96.5 AND [Non GC Letter Sent 2] IS NULL AND DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) >= 30 THEN 'Send Non GC 2'
WHEN A.[MCA %] < 96.5 AND [Non GC Letter Sent 3] IS NULL AND DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) >= 30 THEN 'Send Non GC 3'
WHEN A.[MCA %] < 96.5 AND DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) >= 30 AND [Non GC Letter Sent 3] IS NOT NULL THEN 'DO_NOT_SEND'
ELSE 'DO_NOT_SEND'
END AS 'Send Flag'
,[Exception ID],[Document],[Exception Status],[Issue],CAST([Gift Card Letter Sent] AS DATE) AS 'Gift Card Letter Sent',	CAST([Gift Card Letter Sent 2] AS DATE) AS 'Gift Card Letter Sent 2',	CAST([Gift Card Letter Sent 3] AS DATE) AS 'Gift Card Letter Sent 3',	CAST([Sent For Gift Card Processing] AS DATE) AS 'Sent For Gift Card Processing',	CAST([Document Returned] AS DATE) AS 'Document Returned',	CAST([Ledger Letter Document Returned] AS DATE) AS 'Ledger Letter Document Returned',	CAST([Ledger Letter Sent 1] AS DATE) AS 'Ledger Letter Sent 1',	CAST([Ledger Letter Sent 2] AS DATE) AS 'Ledger Letter Sent 2',	CAST([Ledger Letter Sent 3] AS DATE) AS 'Ledger Letter Sent 3',	CAST([Ledger Sent for Gift Card Processing] AS DATE) AS 'Ledger Sent for Gift Card Processing',	CAST([Non GC Letter Sent 1] AS DATE) AS 'Non GC Letter Sent 1',	CAST([Non GC Letter Sent 2] AS DATE) AS 'Non GC Letter Sent 2',	CAST([Non GC Letter Sent 3] AS DATE) AS 'Non GC Letter Sent 3',	CAST([Non GC Letter Document Returned] AS DATE) AS 'Non GC Letter Document Returned',CAST([Max Date] AS DATE) AS 'Max Date',
[LTR Count]
INTO #OCC
FROM #LoanStatus A
LEFT JOIN #Exceptions B
ON A.[Loan Number] = B.[Loan Number]
WHERE B.[Document] IN ('Current OCC Cert') AND A.[MCA %] >= 95

--NTS--

SELECT A.[Loan Number] ,CAST(GETDATE() AS DATE) AS 'TODAY',A.[Loan Status],A.[TAG 2],A.[Incurable Flag],CAST(A.[MCA %] AS Float(2)) AS 'MCA %'
,CASE 
/*
WHEN A.[MCA %] >= 97 AND B.[Ledger Sent for Gift Card Processing] IS NOT NULL THEN 'DO NOT SEND - Ledger Fulfilled'
WHEN [Sent For Gift Card Processing] IS NOT NULL AND [ISSUE] NOT IN ('Missing Contact Info','Missing') THEN 'DO NOT SEND - GC Sent'
WHEN [Non GC Letter Document Returned] IS NOT NULL AND [ISSUE] NOT IN ('Missing Contact Info','Missing') THEN 'DO NOT SEND - NON GC RECEIVED'
WHEN [Sent For Gift Card Processing] IS NOT NULL AND [ISSUE] IN ('Missing Contact Info','Missing') THEN 'Review Issue - Doc Received'
WHEN [Non GC Letter Document Returned] IS NOT NULL AND [ISSUE] IN ('Missing Contact Info','Missing') THEN 'Review Issue - Doc Received'
WHEN A.[MCA %] >= 97 AND B.[Ledger Letter Sent 1] IS NULL THEN 'Send Ledger 1'
WHEN A.[MCA %] >= 97.5 AND B.[Ledger Letter Sent 2] IS NULL THEN 'Send Ledger 2'
WHEN A.[MCA %] >= 98 AND B.[Ledger Letter Sent 3] IS NULL THEN 'Send Ledger 3'
WHEN A.[MCA %] >= 98 AND B.[Ledger Letter Sent 3] IS NOT NULL THEN 'Incurable Review'*/
--WHEN [Non GC Letter Document Returned] IS NOT NULL AND [ISSUE] NOT IN ('Missing Contact Info','Missing') THEN 'DO NOT SEND - NON GC REVEIVED'
WHEN DATEDIFF(Day,CAST([Max Date] AS DATE),CAST(GETDATE() AS DATE)) < 45 THEN  'DO_NOT_SEND'
WHEN C.[Sent For Gift Card Processing] IS NOT NULL THEN 'Review to Reopen'
WHEN C.[Gift Card Letter Sent] IS NULL THEN 'Send GC 1'
WHEN C.[Gift Card Letter Sent 2] IS NULL THEN 'Send GC 2'
WHEN C.[Gift Card Letter Sent 3] IS NULL THEN 'Send GC 3'
WHEN C.[Gift Card Letter Sent 3] IS NOT NULL AND [Sent to Inspection Vendor] IS NOT NULL AND [Document] IN ('Proof of Repair') THEN 'DO_NOT_SEND'
WHEN C.[Gift Card Letter Sent 3] IS NOT NULL THEN 'Send GC 3 - Incurable Review'
/*
WHEN A.[MCA %] < 96.5 AND [Non GC Letter Sent 1] IS NULL THEN 'Send Non GC 1'
WHEN (A.[MCA %] < 96.5 AND A.[MCA %] >=95.5) AND [Non GC Letter Sent 2] IS NULL THEN 'Send Non GC 2'
WHEN (A.[MCA %] < 96.5 AND A.[MCA %] >=96) AND [Non GC Letter Sent 3] IS NULL THEN 'Send Non GC 3'*/
ELSE 'DO_NOT_SEND'
END AS 'Send Flag'
,C.[Exception ID],[Proof of Repairs Status],[Sent to Inspection Vendor],
C.[Document],C.[Exception Status],C.[Issue],CAST(C.[Gift Card Letter Sent] AS DATE) AS 'Gift Card Letter Sent',	CAST(C.[Gift Card Letter Sent 2] AS DATE) AS 'Gift Card Letter Sent 2',	CAST(C.[Gift Card Letter Sent 3] AS DATE) AS 'Gift Card Letter Sent 3',	CAST(C.[Sent For Gift Card Processing] AS DATE) AS 'Sent For Gift Card Processing',	CAST(C.[Document Returned] AS DATE) AS 'Document Returned',	CAST(C.[Ledger Letter Document Returned] AS DATE) AS 'Ledger Letter Document Returned',	CAST(C.[Ledger Letter Sent 1] AS DATE) AS 'Ledger Letter Sent 1',	CAST(C.[Ledger Letter Sent 2] AS DATE) AS 'Ledger Letter Sent 2',	CAST([Ledger Letter Sent 3] AS DATE) AS 'Ledger Letter Sent 3',	CAST([Ledger Sent for Gift Card Processing] AS DATE) AS 'Ledger Sent for Gift Card Processing',	CAST([Non GC Letter Sent 1] AS DATE) AS 'Non GC Letter Sent 1',	CAST([Non GC Letter Sent 2] AS DATE) AS 'Non GC Letter Sent 2',	CAST([Non GC Letter Sent 3] AS DATE) AS 'Non GC Letter Sent 3',	CAST([Non GC Letter Document Returned] AS DATE) AS 'Non GC Letter Document Returned',CAST([Max Date] AS DATE) AS 'Max Date',
[LTR Count]
INTO #NTS
FROM #LoanStatus A
LEFT JOIN (SELECT [Loan Number],[Exception ID] FROM #Exceptions) B
ON B.[Loan Number] = A.[Loan Number]
LEFT JOIN #Exceptions C
ON B.[Exception ID] = C.[Exception ID]
WHERE A.[MCA %] >= 95 AND C.[Document] IN ('Death Cert HACG','Trust - HACG','Proof of Repair')

--Final Exception Level--
SELECT 
CASE WHEN B.[Send Flag] IS NOT NULL THEN B.[Send Flag]
WHEN C.[Send Flag] IS NOT NULL THEN C.[Send Flag] 
WHEN D.[Send Flag] IS NOT NULL THEN D.[Send Flag]
END AS 'Send Flag',Z.[MCA_Percent],A.*
INTO #Final
FROM (SELECT [Loan Number],[MCA %] AS 'MCA_Percent' FROM [#LoanStatus]) Z
Right JOIN #Exceptions A
ON Z.[Loan Number] = A.[Loan Number]
LEFT JOIN #HOA B
ON A.[Exception ID] = B.[Exception ID]
LEFT JOIN #OCC C
On A.[Exception ID] = C.[Exception ID]
LEFT JOIN #NTS D
On A.[Exception ID] = D.[Exception ID]
ORDER BY [Document],[Send Flag]

--[Template Scrub]--
SELECT E.[Loan Number]
,CASE 
	WHEN B.[Send Flag] IN ('Send Ledger 1','Send Ledger 2','Send Ledger 3') THEN '94-13 CHP HOA Ledger Template'
	WHEN B.[Send Flag] IN ('Send Non GC 1','Send Non GC 2','Send Non GC 3') THEN '94-32 CHP HOA - No Gift Card Template'
	
END AS 'HOA_Template'
,CASE 
	WHEN C.[Send Flag] IN ('Send GC 1','Send GC 2','Send GC 3') THEN '93-71 CHP Annual Occupancy Cert with gift card Template'
	WHEN C.[Send Flag] IN ('Send Non GC 1','Send Non GC 2','Send Non GC 3') THEN '94-31 CHP Annual Occupancy Cert-No Gift Card Template'
	
END AS 'OCC_Template'
,CASE 
	WHEN D.Document IN ('Death Cert HACG') AND D.[Send Flag] IN ('Send GC 1','Send GC 2','Send GC 3') THEN '93-65 CHP Death Certificate Template'
	END AS 'DC_Template'

,CASE	
	WHEN F.Document IN ('Trust - HACG') AND F.[Send Flag] IN ('Send GC 1','Send GC 2','Send GC 3') THEN '93-63 Trust_Giftcard Letter Template'
	END AS 'Trust_Template'
,CASE	
	WHEN G.Document IN ('Proof of Repair') AND G.[Send Flag] IN ('Send GC 1') THEN '93-62 CHP Proof of Repairs Template_5.21.2019'
	WHEN G.Document IN ('Proof of Repair') AND G.[Send Flag] IN ('Send GC 2','Send GC 3') THEN ('93-75 CHP No contact Proof of Repair_5.21.2019')
	END AS 'POR_Template'
INTO #Template
FROM #LoanStatus E
LEFT JOIN #HOA B
ON E.[Loan Number] = B.[Loan Number]
LEFT JOIN #OCC C
On E.[Loan Number] = C.[Loan Number]
LEFT JOIN (SELECT * FROM #NTS WHERE Document IN ('Death Cert HACG')) D
ON E.[Loan Number] = D.[Loan Number]
LEFT JOIN (SELECT * FROM #NTS WHERE Document IN ('Trust - HACG')) F
ON E.[Loan Number] = F.[Loan Number]
LEFT JOIN (SELECT * FROM #NTS WHERE Document IN ('Proof of Repair')) G
ON E.[Loan Number] = G.[Loan Number]

SELECT * FROM #FINAL

--Manifest--
SELECT DISTINCT A.Document
,GETDATE() AS 'Refreshed'
,A.[Send Flag],'50' AS 'Amount',convert(varchar(10), CAST(GETDATE() AS DATE), 101) AS 'Letter_Date',A.[Exception ID], CMT.LOAN_NBR
	/*,CASE WHEN CAST(CMT.BORROWER_DATE_OF_DEATH AS VARCHAR) NOT IN ('NULL') 
		THEN 'Estate of ' + CMT.BORROWER_FIRST_NAME + ' ' + CMT.BORROWER_LAST_NAME
	ELSE CMT.BORROWER_FIRST_NAME + ' ' + CMT.BORROWER_LAST_NAME
	END*/
	,[Borrower Name] AS "Borr1"
	/*,CASE WHEN CAST(CMT.COBORROWER_DATE_OF_DEATH as varchar) NOT IN ('NULL')
		THEN 'Estate of ' + CMT.COBORROWER_FIRST_NAME + ' ' + CMT.COBORROWER_LAST_NAME
	ELSE ISNULL(CMT.COBORROWER_FIRST_NAME,' ') + ' ' + ISNULL(CMT.COBORROWER_LAST_NAME,' ')
	END*/ 
,ISNULL([CoBorrower Name],' ') AS "Borr2"
,CMT.Status_DESCRIPTION
,CMT.BORROWER_MAIL_ADDRESS
,CMT.BORROWER_MAIL_CITY
,CMT.BORROWER_MAIL_STATE
,CASE WHEN LEN(CMT.borrower_mail_zip_code) > 5
	THEN CAST(SUBSTRING(BORROWER_MAIL_ZIP_CODE, 1,5)+'-'+SUBSTRING(borrower_mail_zip_code,6,4) AS NVARCHAR)
	--WHEN LEN(CMT.borrower_mail_zip_code) <= 5
	--THEN CAST(CMT.BORROWER_MAIL_ZIP_CODE AS NVARCHAR)
	ELSE CAST(CMT.BORROWER_MAIL_ZIP_CODE AS NVARCHAR)
	END AS "BORROWER_MAIL_ZIP_CODE"
	,CMT.PROP_ADDRESS
	,CMT.PROP_CITY
	,CMT.PROP_STATE
	,CASE WHEN LEN(CMT.PROP_ZIP_CODE) > 5
		THEN CAST(SUBSTRING(CMT.PROP_ZIP_CODE, 1,5)+'-'+SUBSTRING(CMT.PROP_ZIP_CODE,6,4) AS NVARCHAR)
	ELSE CAST(CMT.PROP_ZIP_CODE AS NVARCHAR)
	END AS "PROP_ZIP_CODE"
,Case
	--WHEN CMT.BORROWER_MAIL_STATE LIKE ('%HI%') AND (CMT.BORROWER_MAIL_ADDRESS LIKE ('PO Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P.O. Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P O Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P. O. BOX%')) THEN 'HI - PO BOX'
	WHEN CMT.BORROWER_MAIL_STATE LIKE ('%PR%') THEN 'PR Address' 
	WHEN CMT.BORROWER_MAIL_ADDRESS LIKE ('PO Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P.O. Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P O Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P. O. BOX%') THEN 'PO BOX'
	ELSE 'Standard Address'
	END AS 'PO Box Flag'	
	,CMT.MCA_PERCENT
	--,[Exception Last Resolved]

--,C.HOA_Template,C.OCC_Template,C.DC_Template,C.Trust_Template,C.POR_Template
FROM #Final A
LEFT JOIN Tact_Rev.[dbo].[champbase] CMT
ON A.[Loan Number] = CMT.Loan_Nbr
LEFT JOIN #Template C
ON A.[Loan Number] = C.[Loan Number]
WHERE A.[Send Flag] NOT IN ('DO_NOT_SEND')
/*('Send GC 1',
'Send GC 2',
'Send GC 3','Send Non GC 3',	'Send Non GC 2',	'Send Ledger 1',	'Send Ledger 3',	'Send Non GC 1',	'Send Ledger 2')  --CMT.BORROWER_MAIL_ADDRESS LIKE ('PO Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P.O. Box%') or CMT.BORROWER_MAIL_ADDRESS LIKE ('P O Box%')
*/
ORDER BY A.Document,('PO Box Flag')



DROP TABLE #LoanStatus,#Exceptions,#HOA,#OCC,#NTS,#FINAL,#Template