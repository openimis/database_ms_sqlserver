IF OBJECT_ID('uspSSRSProcessBatchWithClaim', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSProcessBatchWithClaim
GO

CREATE PROCEDURE [dbo].[uspSSRSProcessBatchWithClaim]
	(
		@LocationId INT = 0,
		@ProdId INT = 0,
		@RunID INT = 0,
		@HFID INT = 0,
		@HFLevel CHAR(1) = N'',
		@DateFrom DATE = NULL,
		@DateTo DATE = NULL
	)
	AS
	BEGIN
			IF @LocationId=-1
        BEGIN
        	SET @LocationId = NULL
        END

        IF @DateFrom = '' OR @DateFrom IS NULL OR @DateTo = '' OR @DateTo IS NULL
        BEGIN
	        SET @DateFrom = N'1900-01-01'
	        SET @DateTo = N'3000-12-31'
        END


    ;WITH CDetails AS
	    (
		    SELECT CI.ClaimId, CI.ProdId,
		    SUM(ISNULL(CI.PriceApproved, CI.PriceAsked) * ISNULL(CI.QtyApproved, CI.QtyProvided)) PriceApproved,
		    SUM(CI.PriceValuated) PriceAdjusted, SUM(CI.RemuneratedAmount)RemuneratedAmount
		    FROM tblClaimItems CI
		    WHERE CI.ValidityTo IS NULL
		    AND CI.ClaimItemStatus = 1
		    GROUP BY CI.ClaimId, CI.ProdId
		    UNION ALL

		    SELECT CS.ClaimId, CS.ProdId,
		    SUM(ISNULL(CS.PriceApproved, CS.PriceAsked) * ISNULL(CS.QtyApproved, CS.QtyProvided)) PriceApproved,
		    SUM(CS.PriceValuated) PriceValuated, SUM(CS.RemuneratedAmount) RemuneratedAmount

		    FROM tblClaimServices CS
		    WHERE CS.ValidityTo IS NULL
		    AND CS.ClaimServiceStatus = 1
		    GROUP BY CS.CLaimId, CS.ProdId
	    )
	SELECT C.ClaimCode, C.DateClaimed, CA.OtherNames OtherNamesAdmin, CA.LastName LastNameAdmin, C.DateFrom, C.DateTo, I.CHFID, I.OtherNames,
	I.LastName, C.HFID, HF.HFCode, HF.HFName, HF.AccCode, Prod.ProdID, Prod.ProductCode, Prod.ProductName, 
	C.Claimed PriceAsked, SUM(CDetails.PriceApproved)PriceApproved, SUM(CDetails.PriceAdjusted)PriceAdjusted, SUM(CDetails.RemuneratedAmount)RemuneratedAmount,
	D.DistrictID, D.DistrictName, R.RegionId, R.RegionName

	FROM tblClaim C
	INNER JOIN tblInsuree I ON I.InsureeId = C.InsureeID
	LEFT OUTER JOIN tblClaimAdmin CA ON CA.ClaimAdminId = C.ClaimAdminId
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN CDetails ON CDetails.ClaimId = C.ClaimID
	INNER JOIN tblProduct Prod ON Prod.ProdId = CDetails.ProdID
	INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region

	WHERE C.ValidityTo IS NULL
	AND (Prod.LocationId = @LocationId OR @LocationId = 0 OR Prod.LocationId IS NULL)
	AND(Prod.ProdId = @ProdId OR @ProdId = 0)
	AND (C.RunId = @RunId OR @RunId = 0)
	AND (HF.HFId = @HFID OR @HFId = 0)
	AND (HF.HFLevel = @HFLevel OR @HFLevel = N'')
	AND (C.DateTo BETWEEN @DateFrom AND @DateTo)
	-- TO AVOID DOUBLE COUNT WITH CAPITATION
	AND  CONCAT(HF.HFLevel,'.',HF.HFSublevel) NOT IN (
		SELECT CONCAT(HFlevel,'.',HFSublevel) 
		FROM  (values ('H'), ('C'), ('D')) v(HFLevel)
		JOIN tblHFSublevel  on 1=1
		INNER JOIN tblProduct Prod on prodid = @ProdID
		and NOT (
			    ((HF.HFLevel = prod.Level1) AND (HF.HFSublevel = Prod.SubLevel1 OR Prod.SubLevel1 IS NULL))
			    OR ((HF.HFLevel = Prod.Level2 ) AND (HF.HFSublevel = Prod.SubLevel2 OR Prod.SubLevel2 IS NULL))
			    OR ((HF.HFLevel = Prod.Level3) AND (HF.HFSublevel = Prod.SubLevel3 OR Prod.SubLevel3 IS NULL))
			    OR ((HF.HFLevel = Prod.Level4) AND (HF.HFSublevel = Prod.SubLevel4 OR Prod.SubLevel4 IS NULL))
		      )
	)

	GROUP BY C.ClaimCode, C.DateClaimed, CA.OtherNames, CA.LastName , C.DateFrom, C.DateTo, I.CHFID, I.OtherNames,
	I.LastName, C.HFID, HF.HFCode, HF.HFName, HF.AccCode, Prod.ProdID, Prod.ProductCode, Prod.ProductName, C.Claimed,
	D.DistrictId, D.DistrictName, R.RegionId, R.RegionName
END
GO
