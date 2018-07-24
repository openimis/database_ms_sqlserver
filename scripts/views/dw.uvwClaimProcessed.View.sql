USE [IMIS]
GO
/****** Object:  View [dw].[uvwClaimProcessed]    Script Date: 7/24/2018 6:47:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dw].[uvwClaimProcessed] 
AS
	SELECT COUNT(1)TotalClaimProcessed,MONTH(ISNULL(C.DateTo, C.DateFrom))MonthTime, DATENAME(QUARTER,ISNULL(C.DateTo, C.DateFrom))QuarterTime, YEAR(ISNULL(C.DateTo, C.DateFrom))YearTime,
	HF.HFLevel,HF.HFCode, HF.HFName,HFD.DistrictName HFDistrict, HFD.DistrictName, Prod.ProductCode, Prod.ProductName, HFR.RegionName Region, HFR.RegionName HFRegion
	FROM tblClaim C  
	LEFT OUTER JOIN
	(SELECT ClaimId,ProdId FROM tblClaimItems WHERE ValidityTo IS NULL AND ProdId IS NOT NULL GROUP BY ClaimId,ProdId
	UNION
	SELECT ClaimId,ProdID FROM tblClaimServices WHERE ValidityTo IS NULL AND ProdId IS NOT NULL GROUP BY ClaimId,ProdId
	)Details ON C.ClaimID = Details.ClaimID

	LEFT OUTER JOIN tblHF HF ON C.HFID = HF.HFID
	LEFT OUTER JOIN tblDistricts HFD ON HF.LocationId = HFD.DistrictID
	LEFT OUTER JOIN tblProduct Prod ON Details.ProdID = Prod.ProdID
	LEFT OUTER JOIN tblRegions HFR ON HFD.Region = HFR.RegionId

	WHERE C.ValidityTo IS NULL 
	AND (C.ClaimStatus >= 8)
	GROUP BY MONTH(ISNULL(C.DateTo, C.DateFrom)), DATENAME(QUARTER,ISNULL(C.DateTo, C.DateFrom)), YEAR(ISNULL(C.DateTo, C.DateFrom)),
	HF.HFLevel,HF.HFCode, HF.HFName,HFD.DistrictName , Prod.ProductCode, Prod.ProductName, HFR.RegionName


GO
