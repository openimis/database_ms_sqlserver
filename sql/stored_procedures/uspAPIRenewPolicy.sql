IF OBJECT_ID('[dbo].[uspAPIRenewPolicy]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIRenewPolicy]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIRenewPolicy]
(	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(50),
	@RenewalDate DATE,
	@ProductCode NVARCHAR(8),
	@EnrollmentOfficerCode NVARCHAR(8)
)

AS
BEGIN
	/*
	RESPONSE CODES
		1-Wrong format or missing insurance number 
		2-Insurance number of not found
		3- Wrong or missing product code (not existing or not applicable to the family/group)
		4- Wrong or missing renewal date
		5- Wrong or missing enrolment officer code (not existing or not applicable to the family/group)
		0 - all ok
		-1 Unknown Error

	*/


/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
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


	--Validating Conversional product
		DECLARE @ProdId INT,
				@ConvertionalProdId INT,
				@DateTo DATE
		
		SELECT @DateTo = DateTo, @ConvertionalProdId = ConversionProdID, @ProdId = ProdID FROM tblProduct WHERE ProductCode = @ProductCode  AND ValidityTo IS NULL
			
		IF GETDATE() > = @DateTo 
			BEGIN
				IF @ConvertionalProdId IS NOT NULL
						SET @ProdId = @ConvertionalProdId
					ELSE
						RETURN 3
			END
				
		--4- Wrong or missing renewal date
		IF NULLIF(@RenewalDate,'') IS NULL
			RETURN 4

		--5- Wrong or missing enrolment officer code (not existing or not applicable to the family/group)
		IF LEN(ISNULL(@EnrollmentOfficerCode,'')) = 0
			RETURN 5
	
		IF NOT EXISTS(SELECT 1 FROM tblInsuree I 
						INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
						INNER JOIN tblLocations V ON V.LocationId = F.LocationId
						INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
						INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
						INNER JOIN tblOfficer O ON O.LocationId = D.LocationId
						WHERE 
						I.CHFID = @InsuranceNumber AND O.Code= @EnrollmentOfficerCode
						AND I.ValidityTo IS NULL
						AND F.ValidityTo IS NULL
						AND V.ValidityTo IS NULL
						AND O.ValidityTo IS NULL)
		 RETURN 5

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION RENEWPOLICY
			
				DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
				DECLARE @FamilyId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@PolicyStage CHAR(1)='R',
				@StartDate DATE,
				@ExpiryDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId INT,
				@Active TINYINT=2,
				@Idle TINYINT=1,
				@OfficerID INT,
				@HasCycle BIT

				SELECT @FamilyId = FamilyID FROM tblInsuree WHERE CHFID = @InsuranceNumber  AND ValidityTo IS NULL
				INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
				EXEC uspGetPolicyPeriod @ProdId, @RenewalDate, @HasCycle OUTPUT, @PolicyStage;
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @RenewalDate, 0, @ErrorCode OUTPUT;
				SELECT @StartDate = startDate FROM @tblPeriod
				SELECT @ExpiryDate = expiryDate FROM @tblPeriod
				SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @EnrollmentOfficerCode AND ValidityTo IS NULL

					INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
					SELECT	 @FamilyId,@RenewalDate,@StartDate,@EffectiveDate,@ExpiryDate,@Idle,@PolicyValue,@ProdId,@OfficerID,@PolicyStage,GETDATE(),@AuditUserId, 0 isOffline 
					SET @PolicyId = SCOPE_IDENTITY()

	

							DECLARE @InsureeId INT
							DECLARE CurNewPolicy CURSOR FOR SELECT I.InsureeID FROM tblInsuree I 
							INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID 
							INNER JOIN tblPolicy P ON P.FamilyID = F.FamilyID 
							WHERE P.PolicyId = @PolicyId 
							AND I.ValidityTo IS NULL 
							AND F.ValidityTo IS NULL
							AND P.ValidityTo IS NULL
							OPEN CurNewPolicy;
							FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								EXEC uspAddInsureePolicy @InsureeId;
								FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
							END
							CLOSE CurNewPolicy;
							DEALLOCATE CurNewPolicy; 

			COMMIT TRANSACTION RENEWPOLICY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION RENEWPOLICY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END
GO
