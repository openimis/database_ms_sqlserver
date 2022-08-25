IF OBJECT_ID('[dbo].[uspAPIEnterContribution]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIEnterContribution]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIEnterContribution]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(50),
	@Payer NVARCHAR(100),
	@PaymentDate DATE,
	@ProductCode NVARCHAR(8),
	@ContributionAmount DECIMAL(18,2),
	@ReceiptNo NVARCHAR(50),
	@PaymentType CHAR(1),
	@ContributionCategory CHAR(1) = NULL,
	@ReactionType BIT
	
)

AS
BEGIN
	/*
	RESPONSE CODES
		1-Wrong format or missing insurance number 
		2-Insurance number of not found
		3- Wrong or missing  product code (policy of the product code not assigned to the family/group)
		4- Wrong or missing payment date
		5- Wrong contribution category
		6-Wrong or missing payment type
		7-Wrong or missing payer
		8-Missing receipt no.
		9-Duplicated receipt no.
		0 - all ok
		-1 Unknown Error

	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	DECLARE @tblPaymentType TABLE(PaymentTypeCode NVARCHAR(1))
		DECLARE @isValid BIT
		INSERT INTO @tblPaymentType(PaymentTypeCode) 
		VALUES ('B'),('C'),('F'),('M')
	--1-Wrong format or missing insurance number 
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1
	
	--2-Insurance number of not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong or missing product code (not existing or not applicable to the family/group)
	IF LEN(ISNULL(@ProductCode,'')) = 0
		RETURN 3

	IF NOT EXISTS(SELECT F.LocationId, V.LocationName, V.LocationType, D.ParentLocationId, PR.ProductCode FROM tblInsuree I
		INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
		INNER JOIN tblLocations V ON V.LocationId = F.LocationId
		INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
		INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
		INNER JOIN tblProduct PR ON (PR.LocationId = D.LocationId) OR PR.LocationId =  D.ParentLocationId OR PR.LocationId IS NULL 
		WHERE
		F.ValidityTo IS NULL
		AND V.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL AND PR.ProductCode =@ProductCode
		AND I.CHFID = @InsuranceNumber AND I.ValidityTo IS NULL AND I.IsHead = 1)
		RETURN 3

	--4- Wrong or missing payment date
	IF NULLIF(@PaymentDate,'') IS NULL
		RETURN 4

	--5- Wrong contribution category
	IF LEN(ISNULL(@ContributionCategory,'')) > 0
	IF NOT (@ContributionCategory = 'C' OR @ContributionCategory  = 'P') 
		 RETURN 5

		 --6-Wrong or missing payment type
	IF NOT EXISTS(SELECT 1 FROM @tblPaymentType WHERE PaymentTypeCode = @PaymentType) 
		 RETURN 6

	--7-Wrong or missing payer
	IF NOT EXISTS(SELECT 1 FROM tblPayer WHERE PayerName = @Payer AND ValidityTo IS NULL)
		RETURN 7
	
	--8-Missing receipt no.
	IF NULLIF(@ReceiptNo,'') IS NULL
		 RETURN 8

	--9-Duplicated receipt no.
	IF EXISTS(SELECT 1 FROM tblPolicy PL 
				INNER JOIN tblPremium PR ON PL.PolicyID = PR.PolicyID 
				INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
				WHERE PL.ValidityTo IS NULL AND PR.ValidityTo IS NULL
				AND PR.Amount = @ContributionAmount AND PR.Receipt = @ReceiptNo AND Prod.ProductCode = @ProductCode)
		RETURN 9


	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION ENTERCONTRIBUTION
			
				DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
				DECLARE @FamilyId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@PaidAmount DECIMAL(18, 4),
				@PayerID INT,
				@PolicyStage CHAR(1),
				@EnrollmentDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId INT,
				@ProdId INT,
				@Active TINYINT=2,
				@Idle TINYINT=1,
				@OfficerID INT,
				@isPhotoFee BIT,
				@Installment INT, 
				@MaxInstallments INT,
				@LastDate DATE,
				@PremiumPayCount as INT 
				

				SELECT @ProdId = ProdID , @MaxInstallments = MaxInstallments  FROM tblProduct  WHERE ValidityTo IS NULL AND ProductCode = @ProductCode
				--find the right policy and family
				select @FamilyId = FamilyID  from tblInsuree where CHFID = @InsuranceNumber and ValidityTo IS NULL
				SELECT TOP 1 @PolicyId = PL.PolicyID, @PolicyStatus = PolicyStatus, @EnrollmentDate = PL.EnrollDate, @PolicyStage = PL.PolicyStage  FROM tblPolicy PL   WHERE FamilyID = @FamilyId AND PL.ValidityTo IS NULL AND PL.ProdID = @ProdId AND PolicyStatus = 1 ORDER BY PolicyStatus ASC,PolicyID DESC  
				
				DECLARE  @MaxDate TABLE (LastDate  Date) 
				INSERT @MaxDate (LastDate)
				EXECUTE  [dbo].[uspLastDateForPayment] 
				   @PolicyId
				
				SELECT @Installment = COUNT(PremiumID) from tblPremium WHERE PolicyID = @PolicyID and ValidityTo IS NULL
				SET @Installment = ISNULL(@Installment,0) + 1 

				SELECT @LastDate = LastDate FROM @MaxDate  
				
				SELECT @PayerID = PayerID FROM tblPayer WHERE ValidityTo IS NULL AND PayerName = @Payer
				
				IF ISNULL(@ContributionCategory,'') = 'P'
					SET @isPhotoFee = 1
				ELSE
					SET @isPhotoFee = 0

				INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee)
				SELECT @PolicyId,@PayerID,ISNULL(@ContributionAmount,0),@ReceiptNo, @PaymentDate, @PaymentType,GETDATE(),@AuditUserId,@isPhotoFee

				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollmentDate, 0, @ErrorCode OUTPUT;
					
				
				SELECT @PaidAmount = ISNULL(SUM(Amount),0) FROM tblPremium WHERE PolicyId = @PolicyId and ValidityTo IS NULL AND isPhotoFee = 0 
				IF ((@PaidAmount >= @PolicyValue AND ( @Installment <= @MaxInstallments) AND (@PaymentDate <= @LastDate ) ) OR @ReactionType = 1) 
				BEGIN
					IF @PolicyStatus = 1
					BEGIN
						-- only activate if the policy was not yet activated (do not change anything on already suspended or expired policies 
						SET @PolicyStatus = @Active
						SET @EffectiveDate = @PaymentDate
						
						UPDATE tblInsureePolicy SET EffectiveDate = @EffectiveDate WHERE PolicyID = @PolicyId
						UPDATE tblPolicy SET PolicyStatus = @PolicyStatus, EffectiveDate = @EffectiveDate WHERE PolicyID = @PolicyId	
					END

				END
				--ELSE 
				--BEGIN
				--	--now check if we have problems in installments OR GracePeriod 
				--	SET @PolicyStatus = @Idle
				--	SET @EffectiveDate = NULL
				--END
			
			COMMIT TRANSACTION ENTERCONTRIBUTION
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENTERCONTRIBUTION
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END
GO
