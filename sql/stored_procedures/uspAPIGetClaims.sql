IF OBJECT_ID('[dbo].[uspAPIGetClaims]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIGetClaims]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIGetClaims]
(
	@ClaimAdminCode NVARCHAR(MAX),
	@StartDate DATE = NULL, 
	@EndDate DATE = NULL,
	@DateProcessedFrom DATE = NULL,
	@DateProcessedTo DATE = NULL,
	@ClaimStatus INT= NULL
)
AS
BEGIN
	SELECT 
		C.ClaimUUID claim_uuid,
		C.ClaimCode claim_number,
		I.ItemName item,
		I.ItemCode item_code,
		CI.QtyProvided item_qty,
		CI.PriceAsked item_price,
		CI.QtyApproved item_adjusted_qty,
		CI.PriceAdjusted item_adjusted_price,
		CI.Explanation item_explination,
		CI.Justification item_justificaion,
		CI.PriceValuated item_valuated, 
		CI.RejectionReason item_result
	FROM tblClaimItems CI
		join tblClaim C ON C.ClaimID=CI.ClaimID
		join tblItems I ON I.ItemID=CI.ItemID
		join tblClaimAdmin CA ON CA.ClaimAdminId=C.ClaimAdminId
	WHERE C.ValidityTo IS NULL AND CI.ValidityTo IS NULL AND I.ValidityTo IS NULL
		AND CA.ValidityTo IS NULL AND CA.ClaimAdminCode = @ClaimAdminCode
		AND(C.ClaimStatus = @ClaimStatus OR @ClaimStatus IS NULL)
		AND ISNULL(C.DateTo, C.DateFrom) BETWEEN ISNULL(@StartDate, (SELECT CAST(-53690 AS DATETIME))) AND ISNULL(@EndDate, GETDATE())
		AND(C.DateProcessed BETWEEN ISNULL(@DateProcessedFrom, CAST('1753-01-01' AS DATE)) AND ISNULL(@DateProcessedTo, GETDATE()) OR C.DateProcessed IS NULL);

	SELECT 
		C.ClaimUUID claim_uuid,
		C.ClaimCode claim_number,
		S.ServName "service",
		S.ServCode service_code,
		CS.QtyProvided service_qty,
		CS.PriceAsked service_price,
		CS.QtyApproved service_adjusted_qty,
		CS.PriceAdjusted service_adjusted_price,
		CS.Explanation service_explination,
		CS.Justification service_justificaion,
		CS.PriceValuated service_valuated, 
		CS.RejectionReason service_result
	FROM tblClaimServices CS
		join tblClaim C ON C.ClaimID=CS.ClaimID
		join tblServices S ON S.ServiceID=CS.ServiceID
		join tblClaimAdmin CA ON CA.ClaimAdminId=C.ClaimAdminId
	WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL AND S.ValidityTo IS NULL
		AND CA.ValidityTo IS NULL AND CA.ClaimAdminCode = @ClaimAdminCode
		AND(C.ClaimStatus = @ClaimStatus OR @ClaimStatus IS NULL)
		AND ISNULL(C.DateTo, C.DateFrom) BETWEEN ISNULL(@StartDate, (SELECT CAST(-53690 AS DATETIME))) AND ISNULL(@EndDate, GETDATE())
		AND(C.DateProcessed BETWEEN ISNULL(@DateProcessedFrom, CAST('1753-01-01' AS DATE)) AND ISNULL(@DateProcessedTo, GETDATE()) OR C.DateProcessed IS NULL);

	WITH TotalForItems AS
	(
		SELECT C.ClaimId, SUM(CI.PriceAsked * CI.QtyProvided)Claimed,
			SUM(ISNULL(CI.PriceApproved, ISNULL(CI.PriceAsked, 0)) * ISNULL(CI.QtyApproved, ISNULL(CI.QtyProvided, 0))) Approved,
			SUM(ISNULL(CI.PriceValuated, 0))Adjusted,
			SUM(ISNULL(CI.RemuneratedAmount, 0))Remunerated
		FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimId = CI.ClaimID
		WHERE C.ValidityTo IS NULL
			AND CI.ValidityTo IS NULL
		GROUP BY C.ClaimID
	), TotalForServices AS
	(
		SELECT C.ClaimId, SUM(CS.PriceAsked * CS.QtyProvided)Claimed,
			SUM(ISNULL(CS.PriceApproved, ISNULL(CS.PriceAsked, 0)) * ISNULL(CS.QtyApproved, ISNULL(CS.QtyProvided, 0))) Approved,
			SUM(ISNULL(CS.PriceValuated, 0))Adjusted,
			SUM(ISNULL(CS.RemuneratedAmount, 0))Remunerated
		FROM tblClaim C
			LEFT OUTER JOIN tblClaimServices CS ON C.ClaimId = CS.ClaimID
		WHERE C.ValidityTo IS NULL
			AND CS.ValidityTo IS NULL
		GROUP BY C.ClaimID
	)
	SELECT
		C.ClaimUUID claim_uuid,
		HF.HFCode health_facility_code, 
		HF.HFName health_facility_name,
		INS.CHFID insurance_number, 
		Ins.LastName + ' ' + Ins.OtherNames patient_name,
		ICD.ICDName main_dg,
		C.ClaimCode claim_number, 
		CONVERT(NVARCHAR, C.DateClaimed, 111) date_claimed,
		CONVERT(NVARCHAR, C.DateFrom, 111) visit_date_from,
		CONVERT(NVARCHAR, C.DateTo, 111) visit_date_to,
		CASE C.VisitType WHEN 'E' THEN 'Emergency' WHEN 'R' THEN 'Referral' WHEN 'O' THEN 'Others' END visit_type,
		CASE C.ClaimStatus WHEN 1 THEN N'Rejected' WHEN 2 THEN N'Entered' WHEN 4 THEN N'Checked' WHEN 8 THEN N'Processed' WHEN 16 THEN N'Valuated' END claim_status,
		ICD1.ICDName sec_dg_1,
		ICD2.ICDName sec_dg_2,
		ICD3.ICDName sec_dg_3,
		ICD4.ICDName sec_dg_4,
		COALESCE(TFI.Claimed + TFS.Claimed, TFI.Claimed, TFS.Claimed) claimed, 
		COALESCE(TFI.Approved + TFS.Approved, TFI.Approved, TFS.Approved) approved,
		COALESCE(TFI.Adjusted + TFS.Adjusted, TFI.Adjusted, TFS.Adjusted) adjusted,
		C.Explanation explanation,
		C.Adjustment adjustment,
		C.GuaranteeId guarantee_number
	FROM
		TBLClaim C
		join tblClaimAdmin CA ON CA.ClaimAdminId=C.ClaimAdminId
		LEFT JOIN tblHF HF ON C.HFID = HF.HfID
		LEFT JOIN tblInsuree INS ON C.InsureeId = INS.InsureeId
		LEFT JOIN TotalForItems TFI ON C.ClaimID = TFI.ClaimID
		LEFT JOIN TotalForServices TFS ON C.ClaimID = TFS.ClaimID
		LEFT JOIN tblICDCodes ICD ON C.ICDID = ICD.ICDID
		LEFT JOIN tblICDCodes ICD1 ON C.ICDID1 = ICD1.ICDID
		LEFT JOIN tblICDCodes ICD2 ON C.ICDID2 = ICD2.ICDID
		LEFT JOIN tblICDCodes ICD3 ON C.ICDID3 = ICD3.ICDID
		LEFT JOIN tblICDCodes ICD4 ON C.ICDID4 = ICD4.ICDID
	WHERE
		C.ValidityTo IS NULL AND HF.ValidityTo IS NULL AND INS.ValidityTo IS NULL AND ICD.ValidityTo IS NULL
		AND ICD1.ValidityTo IS NULL AND ICD2.ValidityTo IS NULL AND ICD3.ValidityTo IS NULL AND ICD4.ValidityTo IS NULL
		AND CA.ValidityTo IS NULL AND CA.ClaimAdminCode = @ClaimAdminCode
		AND(C.ClaimStatus = @ClaimStatus OR @ClaimStatus IS NULL)
		AND ISNULL(C.DateTo, C.DateFrom) BETWEEN ISNULL(@StartDate, (SELECT CAST(-53690 AS DATETIME))) AND ISNULL(@EndDate, GETDATE())
		AND(C.DateProcessed BETWEEN ISNULL(@DateProcessedFrom, CAST('1753-01-01' AS DATE)) AND ISNULL(@DateProcessedTo, GETDATE()) OR C.DateProcessed IS NULL)	
END
GO
