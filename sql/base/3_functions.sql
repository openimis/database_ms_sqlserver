CREATE FUNCTION [dbo].[udfRejectedClaims]
(
	@ProdID INT = 0,
	@HFID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT
)
RETURNS TABLE
AS
RETURN
	SELECT Claims.HFID,Claims.ProdID,COUNT(ClaimID)RejectedClaims FROM
	(
		SELECT C.ClaimID,HF.HfID,CI.ProdID
		FROM tblClaim C 
		INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId 
		WHERE C.ValidityTo IS NULL 
		AND CI.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL
		AND C.ClaimStatus = 1 
		AND (CI.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		GROUP BY C.ClaimID,HF.HfID,CI.ProdID
		UNION 
		SELECT C.ClaimID,HF.HfID,CS.ProdID
		FROM tblClaim C 
		INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId 
		WHERE C.ValidityTo IS NULL 
		AND CS.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL
		AND C.ClaimStatus = 1 
		AND (CS.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		GROUP BY C.ClaimID,HF.HfID,CS.ProdID
	)Claims
	GROUP BY Claims.HFID,Claims.ProdID
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfTotalClaims]
(
	@ProdID INT = 0,
	@HFID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT
)
RETURNS TABLE
AS
RETURN
  
	SELECT ClaimStat.ProdID, ClaimStat.HFID,COUNT(ClaimStat.ClaimID)TotalClaims
	FROM
	(
		 	SELECT CI.ProdId, HF.HFID, C.ClaimID
	FROM tblClaim C 
	INNER JOIN tblClaimItems CI ON CI.ClaimId = C.ClaimID
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN uvwLocations L ON L.DistrictId = HF.LocationId
	WHERE C.ValidityTo IS NULL
	AND CI.ValidityTo IS NULL
	AND HF.ValidityTo IS NULL
	AND MONTH(C.DateFrom) = @Month
	AND YEAR(C.DateFrom) = @Year
	AND (CI.ProdId = @ProdId OR @ProdId = 0)
	AND (HF.HFID = @HFId OR @HFId = 0)
	AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	GROUP BY ProdId, HF.HFID, C.ClaimID, C.ClaimCode
	UNION 
	SELECT CS.ProdId, HF.HFID ,C.ClaimID
	FROM tblClaim C 
	INNER JOIN tblClaimServices CS ON CS.ClaimId = C.ClaimID
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN uvwLocations L ON L.DistrictId = HF.LocationId
	WHERE C.ValidityTo IS NULL
	AND CS.ValidityTo IS NULL
	AND HF.ValidityTo IS NULL
	AND MONTH(C.DateFrom) = @Month
	AND YEAR(C.DateFrom) = @Year
	AND (CS.ProdId = @ProdId OR @ProdId = 0)
	AND (HF.HFID = @HFId OR @HFId = 0)
	AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	GROUP BY ProdId, HF.HFID, C.ClaimID
	)ClaimStat
	GROUP BY ClaimStat.ProdID, ClaimStat.HFID
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE  FUNCTION [dbo].[udfRemunerated]
(
	@HFID INT = 0,
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT
)
RETURNS TABLE
AS
RETURN
	
	SELECT Remunerated.ProdID, Remunerated.HFID,SUM(Rem)Remunerated FROM
	(
		SELECT CI.ProdID,HF.HfID,ISNULL(SUM(CI.RemuneratedAmount), 0) AS Rem
		FROM tblClaim C 
		INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId   --Changed From DistrictId to HFLocationId 29062017 Rogers
		WHERE C.ValidityTo IS NULL 
		AND CI.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL 
		AND (CI.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		AND CI.ClaimItemStatus = 1
		AND C.ClaimStatus = 16
		GROUP BY CI.ProdID,HF.HfID
		UNION ALL
		SELECT CS.ProdID,HF.HfID,ISNULL(SUM(CS.RemuneratedAmount), 0) AS Rem
		FROM tblClaim C 
		INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId   --Changed From DistrictId to HFLocationId 29062017 Rogers
		WHERE C.ValidityTo IS NULL 
		AND CS.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL 
		AND (CS.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		AND CS.ClaimServiceStatus = 1
		AND C.ClaimStatus = 16
		GROUP BY CS.ProdID,HF.HfID
	)Remunerated
	GROUP BY Remunerated.ProdID, Remunerated.HFID
GO
