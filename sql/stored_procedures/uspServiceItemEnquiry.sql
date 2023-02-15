IF OBJECT_ID('[dbo].[uspServiceItemEnquiry]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspServiceItemEnquiry]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspServiceItemEnquiry]
(
	@CHFID NVARCHAR(50),
	@ServiceCode NVARCHAR(6) = N'',
	@ItemCode NVARCHAR(6) = N'',
	@MinDateService DATE OUTPUT,
	@MinDateItem DATE OUTPUT,
	@ServiceLeft INT OUTPUT,
	@ItemLeft INT OUTPUT,
	@isItemOK BIT OUTPUT,
	@isServiceOK BIT OUTPUT
)
AS
BEGIN

	DECLARE @InsureeId INT = (SELECT InsureeId FROM tblInsuree WHERE (CHFID = @CHFID OR InsureeUUID = TRY_CONVERT(UNIQUEIDENTIFIER, @CHFID)) AND ValidityTo IS NULL)
	DECLARE @Age INT = (SELECT DATEDIFF(YEAR,DOB,GETDATE()) FROM tblInsuree WHERE InsureeID = @InsureeId)
	
	

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
		(CASE WHEN @Age >= 18 THEN NULLIF(PS.LimitNoAdult,0) ELSE NULLIF(PS.LimitNoChild,0) END) - SUM(CASE WHEN CS.QtyApproved IS NULL THEN CS.QtyProvided ELSE CS.QtyApproved END) ServicesLeft
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
		(CASE WHEN @Age >= 18 THEN NULLIF(PItem.LimitNoAdult,0) ELSE NULLIF(PItem.LimitNoChild,0) END) - SUM(CASE WHEN CI.QtyApproved IS NULL THEN CI.QtyProvided ELSE CI.QtyApproved END) ItemsLeft
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
	SELECT TOP 1 Prod.ProdId,
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

	SELECT * FROM @Result

END
GO
