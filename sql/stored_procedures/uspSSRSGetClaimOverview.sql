
IF OBJECT_ID('uspSSRSGetClaimOverview', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSGetClaimOverview
GO

CREATE PROCEDURE [dbo].[uspSSRSGetClaimOverview]
	(
		@HFID INT,	
		@LocationId INT,
		@ProdId INT, 
		@StartDate DATE, 
		@EndDate DATE,
		@ClaimStatus INT = NULL,
		@ClaimRejReason xClaimRejReasons READONLY,
		@Scope INT = NULL
	)
	AS
	BEGIN
		-- no scope -1
		-- claim only 0
		-- claimand rejection 1
		-- all 2
		;WITH TotalForItems AS
		(
			SELECT C.ClaimId, SUM(CI.PriceAsked * CI.QtyProvided)Claimed,
			SUM(ISNULL(CI.PriceApproved, CI.PriceAsked) * ISNULL(CI.QtyApproved, CI.QtyProvided)) Approved,
			SUM(CI.PriceValuated)Adjusted,
			SUM(CI.RemuneratedAmount)Remunerated
			FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimId = CI.ClaimID
			WHERE C.ValidityTo IS NULL
			AND CI.ValidityTo IS NULL
			GROUP BY C.ClaimID
		), TotalForServices AS
		(
			SELECT C.ClaimId, SUM(CS.PriceAsked * CS.QtyProvided)Claimed,
			SUM(ISNULL(CS.PriceApproved, CS.PriceAsked) * ISNULL(CS.QtyApproved, CS.QtyProvided)) Approved,
			SUM(CS.PriceValuated)Adjusted,
			SUM(CS.RemuneratedAmount)Remunerated
			FROM tblClaim C 
			LEFT OUTER JOIN tblClaimServices CS ON C.ClaimId = CS.ClaimID
			WHERE C.ValidityTo IS NULL
			AND CS.ValidityTo IS NULL
			GROUP BY C.ClaimID
		)

		SELECT C.DateClaimed, C.ClaimID, I.ItemId, S.ServiceID, HF.HFCode, HF.HFName, C.ClaimCode, C.DateClaimed, CA.LastName + ' ' + CA.OtherNames ClaimAdminName,
		C.DateFrom, C.DateTo, Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsureeName,
		CASE C.ClaimStatus WHEN 1 THEN N'Rejected' WHEN 2 THEN N'Entered' WHEN 4 THEN N'Checked' WHEN 8 THEN N'Processed' WHEN 16 THEN N'Valuated' END ClaimStatus,
		C.RejectionReason, COALESCE(TFI.Claimed + TFS.Claimed, TFI.Claimed, TFS.Claimed) Claimed, 
		COALESCE(TFI.Approved + TFS.Approved, TFI.Approved, TFS.Approved) Approved,
		COALESCE(TFI.Adjusted + TFS.Adjusted, TFI.Adjusted, TFS.Adjusted) Adjusted,
		COALESCE(TFI.Remunerated + TFS.Remunerated, TFI.Remunerated, TFS.Remunerated)Paid,
		CASE WHEN @Scope =2 OR CI.RejectionReason <> 0 THEN I.ItemCode ELSE NULL END RejectedItem, CI.RejectionReason ItemRejectionCode,
		CASE WHEN @Scope =2 OR CS.RejectionReason <> 0 THEN S.ServCode ELSE NULL END RejectedService, CS.RejectionReason ServiceRejectionCode,
		CASE WHEN @Scope =2 OR CI.QtyProvided <> COALESCE(CI.QtyApproved,CI.QtyProvided) THEN I.ItemCode ELSE NULL END AdjustedItem,
		CASE WHEN @Scope =2 OR CI.QtyProvided <> COALESCE(CI.QtyApproved,CI.QtyProvided) THEN ISNULL(CI.QtyProvided,0) ELSE NULL END OrgQtyItem,
		CASE WHEN @Scope =2 OR CI.QtyProvided <> COALESCE(CI.QtyApproved ,CI.QtyProvided)  THEN ISNULL(CI.QtyApproved,0) ELSE NULL END AdjQtyItem,
		CASE WHEN @Scope =2 OR CS.QtyProvided <> COALESCE(CS.QtyApproved,CS.QtyProvided)  THEN S.ServCode ELSE NULL END AdjustedService,
		CASE WHEN @Scope =2 OR CS.QtyProvided <> COALESCE(CS.QtyApproved,CS.QtyProvided)   THEN ISNULL(CS.QtyProvided,0) ELSE NULL END OrgQtyService,
		CASE WHEN @Scope =2 OR CS.QtyProvided <> COALESCE(CS.QtyApproved ,CS.QtyProvided)   THEN ISNULL(CS.QtyApproved,0) ELSE NULL END AdjQtyService,
		C.Explanation,
		-- ALL claims
		 CASE WHEN @Scope = 2 THEN CS.QtyApproved ELSE NULL END ServiceQtyApproved, 
		 CASE WHEN @Scope = 2 THEN CI.QtyApproved ELSE NULL END ItemQtyApproved,
		 CASE WHEN @Scope = 2 THEN cs.PriceAsked ELSE NULL END ServicePrice, 
		 CASE WHEN @Scope = 2 THEN CI.PriceAsked ELSE NULL END ItemPrice,
		 CASE WHEN @Scope = 2 THEN ISNULL(cs.PriceApproved,0) ELSE NULL END ServicePriceApproved,
		 CASE WHEN @Scope = 2 THEN ISNULL(ci.PriceApproved,0) ELSE NULL END ItemPriceApproved, 
		 CASE WHEN @Scope = 2 THEN ISNULL(cs.Justification,NULL) ELSE NULL END ServiceJustification,
		 CASE WHEN @Scope = 2 THEN ISNULL(CI.Justification,NULL) ELSE NULL END ItemJustification,
		 CASE WHEN @Scope = 2 THEN cs.ClaimServiceID ELSE NULL END ClaimServiceID,
		 CASE WHEN @Scope = 2 THEN  CI.ClaimItemID ELSE NULL END ClaimItemID,
		--,cs.PriceApproved ServicePriceApproved,ci.PriceApproved ItemPriceApproved--,
		CASE WHEN @Scope > 0 THEN  CONCAT(CS.RejectionReason,' - ', XCS.Name) ELSE NULL END ServiceRejectionReason,
		CASE WHEN @Scope > 0 THEN CONCAT(CI.RejectionReason, ' - ', XCI.Name) ELSE NULL END ItemRejectionReason

		-- end all claims


		FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimId = CI.ClaimID
		LEFT OUTER JOIN tblClaimServices CS ON C.ClaimId = CS.ClaimID
		LEFT OUTER JOIN tblItems I ON CI.ItemId = I.ItemID
		LEFT OUTER JOIN tblServices S ON CS.ServiceID = S.ServiceID
		--INNER JOIN tblProduct PROD ON PROD.ProdID = CS.ProdID AND PROD.ProdID = CI.ProdID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		LEFT OUTER JOIN tblClaimAdmin CA ON C.ClaimAdminId = CA.ClaimAdminId
		INNER JOIN tblInsuree Ins ON C.InsureeId = Ins.InsureeId
		LEFT OUTER JOIN TotalForItems TFI ON C.ClaimId = TFI.ClaimID
		LEFT OUTER JOIN TotalForServices TFS ON C.ClaimId = TFS.ClaimId
		-- all claims
		LEFT JOIN @ClaimRejReason XCI ON XCI.ID = CI.RejectionReason
		LEFT JOIN @ClaimRejReason XCS ON XCS.ID = CS.RejectionReason
		-- and all claims
		WHERE C.ValidityTo IS NULL
		AND ISNULL(C.DateTo,C.DateFrom) BETWEEN @StartDate AND @EndDate
		AND (C.ClaimStatus = @ClaimStatus OR @ClaimStatus IS NULL)
		AND (HF.LocationId = @LocationId OR @LocationId = 0)
		AND (HF.HFID = @HFID OR @HFID = 0)
		AND (CI.ProdID = @ProdId OR CS.ProdID = @ProdId  
		OR COALESCE(CS.ProdID, CI.ProdId) IS NULL OR @ProdId = 0)
	END
Go
