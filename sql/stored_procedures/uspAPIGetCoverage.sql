IF OBJECT_ID('[dbo].[uspAPIGetCoverage]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIGetCoverage]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIGetCoverage]
(
	@InsureeNumber NVARCHAR(50),
	@MinDateService DATE=NULL  OUTPUT,
	@MinDateItem DATE=NULL OUTPUT,
	@ServiceLeft INT=0 OUTPUT,
	@ItemLeft INT =0 OUTPUT,
	@isItemOK BIT =0 OUTPUT,
	@isServiceOK BIT=0 OUTPUT
)
AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of head
		2-Insurance number of head not found
		
	*/

	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1- Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3

	--2 - Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
		RETURN 4

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/
	DECLARE @LocationId int =  0
	IF NOT OBJECT_ID('tempdb..#tempBase') IS NULL DROP TABLE #tempBase

		SELECT PL.PolicyValue,PL.EffectiveDate, PR.ProdID,PL.PolicyID,I.CHFID,P.PhotoFolder + case when RIGHT(P.PhotoFolder,1) = '\\' then '' else '\\' end + P.PhotoFileName PhotoPath,I.LastName, I.OtherNames,
		DOB, CASE WHEN I.Gender = 'M' THEN 'Male' ELSE 'Female' END Gender,PR.ProductCode,PR.ProductName,IP.ExpiryDate, 
		CASE WHEN IP.EffectiveDate IS NULL OR CAST(GETDATE() AS DATE) < IP.EffectiveDate  THEN 'I' WHEN CAST(GETDATE() AS DATE) NOT BETWEEN IP.EffectiveDate AND IP.ExpiryDate THEN 'E' ELSE 
		CASE PL.PolicyStatus WHEN 1 THEN 'I' WHEN 2 THEN 'A' WHEN 4 THEN 'S' WHEN 16 THEN 'R' ELSE 'E' END
		END  AS [Status]
		INTO #tempBase
		FROM tblInsuree I LEFT OUTER JOIN tblPhotos P ON I.PhotoID = P.PhotoID
		INNER JOIN tblFamilies F ON I.FamilyId = F.FamilyId 
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		LEFT OUTER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
		LEFT OUTER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
		LEFT OUTER JOIN tblInsureePolicy IP ON IP.InsureeId = I.InsureeId AND IP.PolicyId = PL.PolicyID
		WHERE I.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND P.ValidityTo IS NULL AND PR.ValidityTo IS NULL AND IP.ValidityTo IS NULL AND F.ValidityTo IS NULL
		AND (I.CHFID = @InsureeNumber OR @InsureeNumber = '')
		AND (D.DistrictID = @LocationId or @LocationId= 0)


	DECLARE @Members INT = (SELECT COUNT(1) FROM tblInsuree WHERE FamilyID = (SELECT TOP 1 FamilyId FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL) AND ValidityTo IS NULL); 		
	DECLARE @InsureeId INT = (SELECT InsureeId FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
	DECLARE @FamilyId INT = (SELECT FamilyId FROM tblInsuree WHERE ValidityTO IS NULL AND CHFID = @InsureeNumber);

		
	IF NOT OBJECT_ID('tempdb..#tempDedRem')IS NULL DROP TABLE #tempDedRem
	CREATE TABLE #tempDedRem (PolicyId INT,ProdID INT,DedInsuree DECIMAL(18,2),DedOPInsuree DECIMAL(18,2),DedIPInsuree DECIMAL(18,2),MaxInsuree DECIMAL(18,2),MaxOPInsuree DECIMAL(18,2),MaxIPInsuree DECIMAL(18,2),DedTreatment DECIMAL(18,2),DedOPTreatment DECIMAL(18,2),DedIPTreatment DECIMAL(18,2),MaxTreatment DECIMAL(18,2),MaxOPTreatment DECIMAL(18,2),MaxIPTreatment DECIMAL(18,2),DedPolicy DECIMAL(18,2),DedOPPolicy DECIMAL(18,2),DedIPPolicy DECIMAL(18,2),MaxPolicy DECIMAL(18,2),MaxOPPolicy DECIMAL(18,2),MaxIPPolicy DECIMAL(18,2))

	INSERT INTO #tempDedRem(PolicyId, ProdID ,DedInsuree ,DedOPInsuree ,DedIPInsuree ,MaxInsuree ,MaxOPInsuree ,MaxIPInsuree ,DedTreatment ,DedOPTreatment ,DedIPTreatment ,MaxTreatment ,MaxOPTreatment ,MaxIPTreatment ,DedPolicy ,DedOPPolicy ,DedIPPolicy ,MaxPolicy ,MaxOPPolicy ,MaxIPPolicy)
					SELECT #tempBase.PolicyId, #tempBase.ProdID,
					DedInsuree ,DedOPInsuree ,DedIPInsuree ,
					MaxInsuree,MaxOPInsuree,MaxIPInsuree ,
					DedTreatment ,DedOPTreatment ,DedIPTreatment,
					MaxTreatment ,MaxOPTreatment ,MaxIPTreatment,
					DedPolicy ,DedOPPolicy ,DedIPPolicy , 
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy > MaxCeilingPolicy THEN MaxCeilingPolicy ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy END MaxPolicy ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy > MaxCeilingPolicyOP THEN MaxCeilingPolicyOP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy END MaxOPPolicy ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy > MaxCeilingPolicyIP THEN MaxCeilingPolicyIP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy END MaxIPPolicy
					FROM tblProduct INNER JOIN #tempBase ON tblProduct.ProdID = #tempBase.ProdID
					WHERE ValidityTo IS NULL



	IF EXISTS(SELECT 1 FROM tblClaimDedRem WHERE InsureeID = @InsureeId AND ValidityTo IS NULL)
	BEGIN			
		UPDATE #tempDedRem
		SET 
		DedInsuree = (SELECT DedInsuree - ISNULL(SUM(DedG),0) 
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyID = #tempDedRem.PolicyId
				AND InsureeId = @InsureeId
				GROUP BY DedInsuree),
		DedOPInsuree = (select DedOPInsuree - ISNULL(SUM(DedOP),0) 
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND InsureeId = @InsureeId
				GROUP BY DedOPInsuree),
		DedIPInsuree = (SELECT DedIPInsuree - ISNULL(SUM(DedIP),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND InsureeId = @InsureeId
				GROUP BY DedIPInsuree) ,
		MaxInsuree = (SELECT MaxInsuree - ISNULL(SUM(RemG),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND InsureeId = @InsureeId
				GROUP BY MaxInsuree ),
		MaxOPInsuree = (SELECT MaxOPInsuree - ISNULL(SUM(RemOP),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND InsureeId = @InsureeId
				GROUP BY MaxOPInsuree ) ,
		MaxIPInsuree = (SELECT MaxIPInsuree - ISNULL(SUM(RemIP),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND InsureeId = @InsureeId
				GROUP BY MaxIPInsuree),
		DedTreatment = (SELECT DedTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID ) ,
		DedOPTreatment = (SELECT DedOPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
		DedIPTreatment = (SELECT DedIPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
		MaxTreatment = (SELECT MaxTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
		MaxOPTreatment = (SELECT MaxOPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
		MaxIPTreatment = (SELECT MaxIPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) 
		
	END



	IF EXISTS(SELECT 1
				FROM tblInsuree I INNER JOIN tblClaimDedRem DR ON I.InsureeId = DR.InsureeId
				WHERE I.ValidityTo IS NULL
				AND DR.ValidityTO IS NULL
				AND I.FamilyId = @FamilyId)			
	BEGIN
		UPDATE #tempDedRem SET
		DedPolicy = (SELECT DedPolicy - ISNULL(SUM(DedG),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND FamilyId = @FamilyId
				GROUP BY DedPolicy),
		DedOPPolicy = (SELECT DedOPPolicy - ISNULL(SUM(DedOP),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND FamilyId = @FamilyId
				GROUP BY DedOPPolicy),
		DedIPPolicy = (SELECT DedIPPolicy - ISNULL(SUM(DedIP),0)
				FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
				LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
				WHERE tblProduct.ValidityTo IS NULL 
				AND tblProduct.ProdID = #tempDedRem.ProdID
				AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
				AND FamilyId = @FamilyId
				GROUP BY DedIPPolicy)


		UPDATE t SET MaxPolicy = MaxPolicyLeft, MaxOPPolicy = MaxOPLeft, MaxIPPolicy = MaxIPLeft
		FROM #tempDedRem t LEFT OUTER JOIN
		(SELECT t.PolicyId, t.ProdId, t.MaxPolicy - ISNULL(SUM(RemG),0)MaxPolicyLeft
		FROM #tempDedRem t INNER JOIN tblPolicy ON t.ProdID = tblPolicy.ProdID --AND tblPolicy.PolicyStatus = 2 
		LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID AND tblClaimDedRem.PolicyId = t.PolicyId
		WHERE FamilyId = @FamilyId
		
		--AND Prod.ValidityTo IS NULL AND Prod.ProdID = t.ProdID
		GROUP BY t.ProdId, t.MaxPolicy, t.PolicyId)MP ON t.ProdID = MP.ProdID AND t.PolicyId = MP.PolicyId
		LEFT OUTER JOIN
		--UPDATE t SET MaxOPPolicy = MaxOPLeft
		--FROM #tempDedRem t LEFT OUTER JOIN
		(SELECT t.PolicyId, t.ProdId, MaxOPPolicy - ISNULL(SUM(RemOP),0) MaxOPLeft
		FROM #tempDedRem t INNER JOIN tblPolicy ON t.ProdID = tblPolicy.ProdID  --AND tblPolicy.PolicyStatus = 2
		LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID AND tblClaimDedRem.PolicyId = t.PolicyId
		WHERE FamilyId = @FamilyId
		
		--WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID
		GROUP BY t.ProdId, MaxOPPolicy, t.PolicyId)MOP ON t.ProdId = MOP.ProdID AND t.PolicyId = MOP.PolicyId
		LEFT OUTER JOIN
		(SELECT t.PolicyId, t.ProdId, MaxIPPolicy - ISNULL(SUM(RemIP),0) MaxIPLeft
		FROM #tempDedRem t INNER JOIN tblPolicy ON t.ProdID = tblPolicy.ProdID  --AND tblPolicy.PolicyStatus = 2
		LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID AND tblClaimDedRem.PolicyId = t.PolicyId
		WHERE FamilyId = @FamilyId
		
		--WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID
		GROUP BY t.ProdId, MaxIPPolicy, t.PolicyId)MIP ON t.ProdId = MIP.ProdID AND t.PolicyId = MIP.PolicyId	
	END
 
 	BEGIN


		-- @InsureeId  = (SELECT InsureeId FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
		DECLARE @Age INT = (SELECT DATEDIFF(YEAR,DOB,GETDATE()) FROM tblInsuree WHERE InsureeID = @InsureeId)
		
		DECLARE @ServiceCode NVARCHAR(6) = N''
		DECLARE @ItemCode NVARCHAR(6) = N''

		SET NOCOUNT ON

		--Service Information
		
		IF LEN(@ServiceCode) > 0
		BEGIN
			DECLARE @ServiceId INT = (SELECT ServiceId FROM tblServices WHERE ServCode = @ServiceCode AND ValidityTo IS NULL)
			DECLARE @ServiceCategory CHAR(1) = (SELECT ServCategory FROM tblServices WHERE ServiceID = @ServiceId)
			
			DECLARE @tblService TABLE(EffectiveDate DATE,ProdId INT,MinDate DATE,ServiceLeft INT)
			
			INSERT INTO @tblService
			SELECT IP.EffectiveDate, PL.ProdID,
			DATEADD(MONTH,CASE WHEN @Age >= 18 THEN  PS.WaitingPeriodAdult ELSE PS.WaitingPeriodChild END,IP.EffectiveDate) MinDate,
			(CASE WHEN @Age >= 18 THEN NULLIF(PS.LimitNoAdult,0) ELSE NULLIF(PS.LimitNoChild,0) END) - COUNT(CS.ServiceID) ServicesLeft
			FROM tblInsureePolicy IP INNER JOIN tblPolicy PL ON IP.PolicyId = PL.PolicyID
			INNER JOIN tblProductServices PS ON PL.ProdID = PS.ProdID
			LEFT OUTER JOIN tblClaim C ON IP.InsureeId = C.InsureeID
			LEFT JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
			WHERE IP.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND PS.ValidityTo IS NULL AND C.ValidityTo IS NULL AND CS.ValidityTo IS NULL
			AND IP.InsureeId = @InsureeId
			AND PS.ServiceID = @ServiceId
			AND (C.ClaimStatus > 2 OR C.ClaimStatus IS NULL)
			AND (CS.ClaimServiceStatus = 1 OR CS.ClaimServiceStatus IS NULL)
			AND PL.PolicyStatus = 2
			GROUP BY IP.EffectiveDate, PL.ProdID,PS.WaitingPeriodAdult,PS.WaitingPeriodChild,PS.LimitNoAdult,PS.LimitNoChild


			IF EXISTS(SELECT 1 FROM @tblService WHERE MinDate <= GETDATE())
				SET @MinDateService = (SELECT MIN(MinDate) FROM @tblService WHERE MinDate <= GETDATE())
			ELSE
				SET @MinDateService = (SELECT MIN(MinDate) FROM @tblService)
				
			IF EXISTS(SELECT 1 FROM @tblService WHERE MinDate <= GETDATE() AND ServiceLeft IS NULL)
				SET @ServiceLeft = NULL
			ELSE
				SET @ServiceLeft = (SELECT MAX(ServiceLeft) FROM @tblService WHERE ISNULL(MinDate, GETDATE()) <= GETDATE())
		END
		--

		--Item Information
		
		
		IF LEN(@ItemCode) > 0
		BEGIN
			DECLARE @ItemId INT = (SELECT ItemId FROM tblItems WHERE ItemCode = @ItemCode AND ValidityTo IS NULL)
			
			DECLARE @tblItem TABLE(EffectiveDate DATE,ProdId INT,MinDate DATE,ItemsLeft INT)

			INSERT INTO @tblItem
			SELECT IP.EffectiveDate, PL.ProdID,
			DATEADD(MONTH,CASE WHEN @Age >= 18 THEN  PItem.WaitingPeriodAdult ELSE PItem.WaitingPeriodChild END,IP.EffectiveDate) MinDate,
			(CASE WHEN @Age >= 18 THEN NULLIF(PItem.LimitNoAdult,0) ELSE NULLIF(PItem.LimitNoChild,0) END) - COUNT(CI.ItemID) ItemsLeft
			FROM tblInsureePolicy IP INNER JOIN tblPolicy PL ON IP.PolicyId = PL.PolicyID
			INNER JOIN tblProductItems PItem ON PL.ProdID = PItem.ProdID
			LEFT OUTER JOIN tblClaim C ON IP.InsureeId = C.InsureeID
			LEFT OUTER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
			WHERE IP.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND PItem.ValidityTo IS NULL AND C.ValidityTo IS NULL AND CI.ValidityTo IS NULL
			AND IP.InsureeId = @InsureeId
			AND PItem.ItemID = @ItemId
			AND (C.ClaimStatus > 2  OR C.ClaimStatus IS NULL)
			AND (CI.ClaimItemStatus = 1 OR CI.ClaimItemStatus IS NULL)
			AND PL.PolicyStatus = 2
			GROUP BY IP.EffectiveDate, PL.ProdID,PItem.WaitingPeriodAdult,PItem.WaitingPeriodChild,PItem.LimitNoAdult,PItem.LimitNoChild


			IF EXISTS(SELECT 1 FROM @tblItem WHERE MinDate <= GETDATE())
				SET @MinDateItem = (SELECT MIN(MinDate) FROM @tblItem WHERE MinDate <= GETDATE())
			ELSE
				SET @MinDateItem = (SELECT MIN(MinDate) FROM @tblItem)
				
			IF EXISTS(SELECT 1 FROM @tblItem WHERE MinDate <= GETDATE() AND ItemsLeft IS NULL)
				SET @ItemLeft = NULL
			ELSE
				SET @ItemLeft = (SELECT MAX(ItemsLeft) FROM @tblItem WHERE ISNULL(MinDate, GETDATE()) <= GETDATE())
		END
		
		--

		DECLARE @Result TABLE(ProdId INT, TotalAdmissionsLeft INT, TotalVisitsLeft INT, TotalConsultationsLeft INT, TotalSurgeriesLeft INT, TotalDelivieriesLeft INT, TotalAntenatalLeft INT,
						ConsultationAmountLeft DECIMAL(18,2),SurgeryAmountLeft DECIMAL(18,2),DeliveryAmountLeft DECIMAL(18,2),HospitalizationAmountLeft DECIMAL(18,2), AntenatalAmountLeft DECIMAL(18,2))

		INSERT INTO @Result
		SELECT  Prod.ProdId,
		Prod.MaxNoHospitalizaion - ISNULL(TotalAdmissions,0)TotalAdmissionsLeft,
		Prod.MaxNoVisits - ISNULL(TotalVisits,0)TotalVisitsLeft,
		Prod.MaxNoConsultation - ISNULL(TotalConsultations,0)TotalConsultationsLeft,
		Prod.MaxNoSurgery - ISNULL(TotalSurgeries,0)TotalSurgeriesLeft,
		Prod.MaxNoDelivery - ISNULL(TotalDelivieries,0)TotalDelivieriesLeft,
		Prod.MaxNoAntenatal - ISNULL(TotalAntenatal, 0)TotalAntenatalLeft,
		--Changes by Rogers Start
		Prod.MaxAmountConsultation ConsultationAmountLeft, --- SUM(ISNULL(Rem.RemConsult,0)) ConsultationAmountLeft,
		Prod.MaxAmountSurgery SurgeryAmountLeft ,--- SUM(ISNULL(Rem.RemSurgery,0)) SurgeryAmountLeft ,
		Prod.MaxAmountDelivery DeliveryAmountLeft,--- SUM(ISNULL(Rem.RemDelivery,0)) DeliveryAmountLeft,By Rogers (Amount must Remain Constant)
		Prod.MaxAmountHospitalization HospitalizationAmountLeft, -- SUM(ISNULL(Rem.RemHospitalization,0)) HospitalizationAmountLeft, By Rogers (Amount must Remain Constant)
		Prod.MaxAmountAntenatal AntenatalAmountLeft -- - SUM(ISNULL(Rem.RemAntenatal, 0)) AntenatalAmountLeft By Rogers (Amount must Remain Constant)
		--Changes by Rogers End
		FROM tblInsureePolicy IP INNER JOIN tblPolicy PL ON IP.PolicyId = PL.PolicyID
		INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
		LEFT OUTER JOIN tblClaimDedRem Rem ON PL.PolicyID = Rem.PolicyID AND Rem.InsureeID = IP.InsureeId

		LEFT OUTER JOIN
			(SELECT COUNT(C.ClaimID)TotalAdmissions,CS.ProdID
			FROM tblClaim C INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
			INNER JOIN tblInsureePolicy IP ON C.InsureeID = IP.InsureeID
			WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL AND IP.ValidityTo IS NULL
			AND C.ClaimStatus > 2
			AND CS.RejectionReason = 0
			AND C.InsureeID = @InsureeId
			AND C.ClaimCategory = 'H'
			AND (ISNULL(C.DateTo,C.DateFrom) BETWEEN IP.EffectiveDate AND IP.ExpiryDate)
			GROUP BY CS.ProdID)TotalAdmissions ON TotalAdmissions.ProdID = Prod.ProdId
			
			LEFT OUTER JOIN
			(SELECT COUNT(C.ClaimID)TotalVisits,CS.ProdID
			FROM tblClaim C INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
			WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL 
			AND C.ClaimStatus > 2
			AND CS.RejectionReason = 0
			AND C.InsureeID = @InsureeId
			AND C.ClaimCategory = 'V'
			GROUP BY CS.ProdID)TotalVisits ON Prod.ProdID = TotalVisits.ProdID
			LEFT OUTER JOIN
			
			(SELECT COUNT(C.ClaimID) TotalConsultations,CS.ProdID
			FROM tblClaim C 
			INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
			WHERE C.ValidityTo IS NULL 
			AND C.ClaimStatus > 2
			AND C.InsureeID = @InsureeId
			AND C.ClaimCategory = 'C'
			GROUP BY CS.ProdID) TotalConsultations ON Prod.ProdID = TotalConsultations.ProdID
			LEFT OUTER JOIN
			
			(SELECT COUNT(C.ClaimID) TotalSurgeries,CS.ProdID
			FROM tblClaim C 
			INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
			WHERE C.ValidityTo IS NULL 
			AND C.ClaimStatus > 2
			AND C.InsureeID = @InsureeId
			AND C.ClaimCategory = 'S'
			GROUP BY CS.ProdID)TotalSurgeries ON Prod.ProdID = TotalSurgeries.ProdID
			LEFT OUTER JOIN
			
			(SELECT COUNT(C.ClaimID) TotalDelivieries,CS.ProdID
			FROM tblClaim C 
			INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
			WHERE C.ValidityTo IS NULL 
			AND C.ClaimStatus > 2
			AND C.InsureeID = @InsureeId
			AND C.ClaimCategory = 'D'
			GROUP BY CS.ProdID)TotalDelivieries ON Prod.ProdID = TotalDelivieries.ProdID
			LEFT OUTER JOIN
			
			(SELECT COUNT(C.ClaimID) TotalAntenatal,CS.ProdID
			FROM tblClaim C 
			INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
			WHERE C.ValidityTo IS NULL 
			AND C.ClaimStatus > 2
			AND C.InsureeID = @InsureeId
			AND C.ClaimCategory = 'A'
			GROUP BY CS.ProdID)TotalAntenatal ON Prod.ProdID = TotalAntenatal.ProdID
			
		WHERE IP.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL AND Rem.ValidityTo IS NULL
		AND IP.InsureeId = @InsureeId

		GROUP BY Prod.ProdID,Prod.MaxNoHospitalizaion,TotalAdmissions, Prod.MaxNoVisits, TotalVisits, Prod.MaxNoConsultation, 
		TotalConsultations, Prod.MaxNoSurgery, TotalSurgeries, Prod.MaxNoDelivery, Prod.MaxNoAntenatal, TotalDelivieries, TotalAntenatal,Prod.MaxAmountConsultation,
		Prod.MaxAmountSurgery, Prod.MaxAmountDelivery, Prod.MaxAmountHospitalization, Prod.MaxAmountAntenatal
		
		Update @Result set TotalAdmissionsLeft=0 where TotalAdmissionsLeft<0;
		Update @Result set TotalVisitsLeft=0 where TotalVisitsLeft<0;
		Update @Result set TotalConsultationsLeft=0 where TotalConsultationsLeft<0;
		Update @Result set TotalSurgeriesLeft=0 where TotalSurgeriesLeft<0;
		Update @Result set TotalDelivieriesLeft=0 where TotalDelivieriesLeft<0;
		Update @Result set TotalAntenatalLeft=0 where TotalAntenatalLeft<0;

		DECLARE @MaxNoSurgery INT,
				@MaxNoConsultation INT,
				@MaxNoDeliveries INT,
				@TotalAmountSurgery DECIMAL(18,2),
				@TotalAmountConsultant DECIMAL(18,2),
				@TotalAmountDelivery DECIMAL(18,2)
				
		SELECT TOP 1 @MaxNoSurgery = TotalSurgeriesLeft, @MaxNoConsultation = TotalConsultationsLeft, @MaxNoDeliveries = TotalDelivieriesLeft,
		@TotalAmountSurgery = SurgeryAmountLeft, @TotalAmountConsultant = ConsultationAmountLeft, @TotalAmountDelivery = DeliveryAmountLeft 
		FROM @Result 


		

		IF @ServiceCategory = N'S'
			BEGIN
				IF @MaxNoSurgery = 0 OR @ServiceLeft = 0 OR @MinDateService > GETDATE() OR @TotalAmountSurgery <= 0
					SET @isServiceOK = 0
				ELSE
					SET @isServiceOK = 1
			END
		ELSE IF @ServiceCategory = N'C'
			BEGIN
				IF @MaxNoConsultation = 0 OR @ServiceLeft = 0 OR @MinDateService > GETDATE() OR @TotalAmountConsultant <= 0
					SET @isServiceOK = 0
				ELSE
					SET @isServiceOK = 1
			END
		ELSE IF @ServiceCategory = N'D'
			BEGIN
				IF @MaxNoDeliveries = 0 OR @ServiceLeft = 0 OR @MinDateService > GETDATE() OR @TotalAmountDelivery  <= 0
					SET @isServiceOK = 0
				ELSE
					SET @isServiceOK = 1
			END
		ELSE IF @ServiceCategory = N'O'
			BEGIN
				IF  @ServiceLeft = 0 OR @MinDateService > GETDATE() 
					SET @isServiceOK = 0
				ELSE
					SET @isServiceOK = 1
			END
		ELSE 
			BEGIN
				IF  @ServiceLeft = 0 OR @MinDateService > GETDATE() 
					SET @isServiceOK = 0
				ELSE
					SET @isServiceOK = 1
			END

		

		IF @ItemLeft = 0 OR @MinDateItem > GETDATE() 
			SET @isItemOK = 0
		ELSE
			SET @isItemOK = 1
	END

	ALTER TABLE #tempBase ADD DedType FLOAT NULL
	ALTER TABLE #tempBase ADD Ded1 DECIMAL(18,2) NULL
	ALTER TABLE #tempBase ADD Ded2 DECIMAL(18,2) NULL
	ALTER TABLE #tempBase ADD Ceiling1 DECIMAL(18,2) NULL
	ALTER TABLE #tempBase ADD Ceiling2 DECIMAL(18,2) NULL
			
	DECLARE @ProdID INT
	DECLARE @DedType FLOAT = NULL
	DECLARE @Ded1 DECIMAL(18,2) = NULL
	DECLARE @Ded2 DECIMAL(18,2) = NULL
	DECLARE @Ceiling1 DECIMAL(18,2) = NULL
	DECLARE @Ceiling2 DECIMAL(18,2) = NULL
	DECLARE @PolicyID INT


	DECLARE @InsuranceNumber NVARCHAR(50)
	DECLARE @OtherNames NVARCHAR(100)
	DECLARE @LastName NVARCHAR(100)
	DECLARE @BirthDate DATE
	DECLARE @Gender NVARCHAR(1)
	DECLARE @ProductCode NVARCHAR(8) = NULL
	DECLARE @ProductName NVARCHAR(50)
	DECLARE @PolicyValue DECIMAL
	DECLARE @EffectiveDate DATE=NULL
	DECLARE @ExpiryDate DATE=NULL
	DECLARE @PolicyStatus BIT =0
	DECLARE @DeductionType INT
	DECLARE @DedNonHospital DECIMAL(18,2)
	DECLARE @DedHospital DECIMAL(18,2)
	DECLARE @CeilingHospital DECIMAL(18,2)
	DECLARE @CeilingNonHospital DECIMAL(18,2)
	DECLARE @AdmissionLeft NVARCHAR
	DECLARE @PhotoPath NVARCHAR
	DECLARE @VisitLeft NVARCHAR(200)=NULL
	DECLARE @ConsultationLeft NVARCHAR(50)=NULL
	DECLARE @SurgeriesLeft NVARCHAR
	DECLARE @DeliveriesLeft NVARCHAR(50)=NULL
	DECLARE @Anc_CareLeft NVARCHAR(100)=NULL
	DECLARE @IdentificationNumber NVARCHAR(25)=NULL
	DECLARE @ConsultationAmount DECIMAL(18,2)
	DECLARE @SurgriesAmount DECIMAL(18,2)
	DECLARE @DeliveriesAmount DECIMAL(18,2)


	DECLARE Cur CURSOR FOR SELECT DISTINCT ProdId, PolicyId FROM #tempDedRem
	OPEN Cur
	FETCH NEXT FROM Cur INTO @ProdID, @PolicyId

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Ded1 = NULL
		SET @Ded2 = NULL
		SET @Ceiling1 = NULL
		SET @Ceiling2 = NULL
		
		SELECT @Ded1 =  CASE WHEN NOT DedInsuree IS NULL THEN DedInsuree WHEN NOT DedTreatment IS NULL THEN DedTreatment WHEN NOT DedPolicy IS NULL THEN DedPolicy ELSE NULL END  FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
		IF NOT @Ded1 IS NULL SET @DedType = 1
		
		IF @Ded1 IS NULL
		BEGIN
			SELECT @Ded1 = CASE WHEN NOT DedIPInsuree IS NULL THEN DedIPInsuree WHEN NOT DedIPTreatment IS NULL THEN DedIPTreatment WHEN NOT DedIPPolicy IS NULL THEN DedIPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			SELECT @Ded2 = CASE WHEN NOT DedOPInsuree IS NULL THEN DedOPInsuree WHEN NOT DedOPTreatment IS NULL THEN DedOPTreatment WHEN NOT DedOPPolicy IS NULL THEN DedOPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			IF NOT @Ded1 IS NULL OR NOT @Ded2 IS NULL SET @DedType = 1.1
		END
		
		SELECT @Ceiling1 =  CASE WHEN NOT MaxInsuree IS NULL THEN MaxInsuree WHEN NOT MaxTreatment IS NULL THEN MaxTreatment WHEN NOT MaxPolicy IS NULL THEN MaxPolicy ELSE NULL END  FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
		IF NOT @Ceiling1 IS NULL SET @DedType = 1
		
		IF @Ceiling1 IS NULL
		BEGIN
			SELECT @Ceiling1 = CASE WHEN NOT MaxIPInsuree IS NULL THEN MaxIPInsuree WHEN NOT MaxIPTreatment IS NULL THEN MaxIPTreatment WHEN NOT MaxIPPolicy IS NULL THEN MaxIPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			SELECT @Ceiling2 = CASE WHEN NOT MaxOPInsuree IS NULL THEN MaxOPInsuree WHEN NOT MaxOPTreatment IS NULL THEN MaxOPTreatment WHEN NOT MaxOPPolicy IS NULL THEN MaxOPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			IF NOT @Ceiling1 IS NULL OR NOT @Ceiling2 IS NULL SET @DedType = 1.1
		END
		
			UPDATE #tempBase SET DedType = @DedType, Ded1 = @Ded1, Ded2 = CASE WHEN @DedType = 1 THEN @Ded1 ELSE @Ded2 END,Ceiling1 = @Ceiling1,Ceiling2 = CASE WHEN @DedType = 1 THEN @Ceiling1 ELSE @Ceiling2 END
		WHERE ProdID = @ProdID
		 AND PolicyId = @PolicyId
		
	FETCH NEXT FROM Cur INTO @ProdID, @PolicyId
	END

	CLOSE Cur
	DEALLOCATE Cur

	--DECLARE @LASTRESULT TABLE(PolicyValue DECIMAL(18,2) NULL,EffectiveDate DATE NULL, LastName NVARCHAR(100) NULL, OtherNames NVARCHAR(100) NULL,CHFID NVARCHAR(50), PhotoPath  NVARCHAR(100) NULL,  DOB DATE NULL ,Gender NVARCHAR(1) NULL,ProductCode NVARCHAR(8) NULL,ProductName NVARCHAR(50) NULL, ExpiryDate DATE NULL, [Status] NVARCHAR(1) NULL,DedType FLOAT NULL, Ded1 DECIMAL(18,2)NULL,  Ded2 DECIMAL(18,2)NULL, Ceiling1 DECIMAL(18,2)NULL, Ceiling2 DECIMAL(18,2)NULL)
  	IF (SELECT COUNT(*) FROM #tempBase WHERE [Status] = 'A') > 0
 		SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft,  r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft, PolicyValue, EffectiveDate, LastName, OtherNames,CHFID, PhotoPath,  DOB,Gender,ProductCode ,ProductName, ExpiryDate, [Status],DedType, Ded1,  Ded2, CASE WHEN Ceiling1 < 0 THEN 0 ELSE  Ceiling1 END Ceiling1 , CASE WHEN Ceiling2< 0 THEN 0 ELSE Ceiling2 END Ceiling2   from #tempBase T LEFT OUTER JOIN @Result R ON R.ProdId = T.ProdID WHERE [Status] = 'A';
	ELSE 
		IF (SELECT COUNT(1) FROM #tempBase WHERE (YEAR(GETDATE()) - YEAR(ExpiryDate)) <= 2) > 1
	  		SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft,  r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft,  PolicyValue,EffectiveDate, LastName, OtherNames,CHFID, PhotoPath,  DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase T LEFT OUTER JOIN @Result R ON R.ProdId = T.ProdID WHERE (YEAR(GETDATE()) - YEAR(ExpiryDate)) <= 2;
		ELSE
			SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft, r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft, PolicyValue,EffectiveDate, LastName, OtherNames, CHFID, PhotoPath,  DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase T LEFT OUTER JOIN @Result R  ON R.ProdId = T.ProdID
END
GO
