IF OBJECT_ID('[dbo].[uspAddFund]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAddFund]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAddFund]
(
	@ProductId INT,
	@payerId INT,
	@PayDate DATE,
	@Amount DECIMAL(18,2),
	@Receipt NVARCHAR(50),
	@AuditUserID INT,
	@isOffline BIT
)
AS
BEGIN
/*========================ERROR CODES===============================
0:	ALl OK
1:	Invalid Product
==================================================================*/

	DECLARE @FundingCHFID NVARCHAR(50) = N'999999999'

	DECLARE @LocationId INT,
			@InsurancePeriod INT	,
			@FamilyId INT,
			@InsureeId INT, 
			@PolicyId INT,
			@PolicyValue DECIMAL(18,2)
			
	BEGIN TRY

--========================================================================================================
--Check if given product is valid
--========================================================================================================
		IF NOT EXISTS(SELECT 1 FROM tblProduct WHERE ProdId = @ProductId AND ValidityTo IS NULL)
			RETURN 1

--========================================================================================================
--Get Product's details
--========================================================================================================
		SELECT @LocationId = LocationId, @InsurancePeriod = InsurancePeriod, @PolicyValue = ISNULL(NULLIF(LumpSum,0),PremiumAdult)
		FROM tblProduct WHERE ProdID = @ProductId AND ValidityTo IS NULL

--========================================================================================================
--Check if the Family with CHFID 999999999 exists in given district
--========================================================================================================
		SELECT @FamilyId = F.FamilyID 
		FROM tblInsuree I 
		INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID 
		INNER JOIN uvwLocations L ON ISNULL(F.LocationId,0) = ISNULL(L.LocationId,-0)
		WHERE I.CHFID = @FundingCHFID  AND ISNULL(F.LocationId,0) = ISNULL(@LocationId,0)
		AND I.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		
		BEGIN TRAN AddFund

--========================================================================================================
--Check if funding District,Ward and Village exists
--========================================================================================================

		DECLARE @RegionId INT,
				@DistrictId INT,
				@WardId INT,
				@VillageID INT

			--Region level added by Rogers on 27092017 
			SELECT @RegionId = LocationId FROM tblLocations WHERE ParentLocationId IS NULL AND ValidityTo IS NULL AND LocationCode = N'FR' AND LocationName = N'Funding';
			IF @RegionId IS NULL
				BEGIN
					INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserID)
					SELECT N'FR' LocationCode,  N'Funding' LocationtName, NULL ParentLocationId, N'R' LocationType, @AuditUserID AuditUserId;
					SELECT @RegionId = SCOPE_IDENTITY();
				END
				
			
			SELECT @DistrictID = LocationId FROM tblLocations WHERE ParentLocationId = @RegionId AND ValidityTo IS NULL AND LocationCode = N'FD' AND LocationName = N'Funding';
			IF @DistrictId IS NULL
				BEGIN
					INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserID)
					SELECT N'FD' LocationCode,  N'Funding' LocationtName, @RegionId ParentLocationId, N'D' LocationType, @AuditUserID AuditUserId;
					SELECT @DistrictId = SCOPE_IDENTITY();
				END

			SELECT @WardId = LocationId FROM tblLocations WHERE ParentLocationId = @DistrictId AND ValidityTo IS NULL;
			IF @WardId IS NULL
				BEGIN 
					
					INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserID)
					SELECT N'FW' LocationCode,  N'Funding' LocationtName, @DistrictId ParentLocationId, N'W' LocationType, @AuditUserID AuditUserId;
					SELECT @WardId = SCOPE_IDENTITY();

				END
		 
			SELECT @VillageID = LocationId FROM tblLocations WHERE ParentLocationId = @WardId AND ValidityTo IS NULL;
			 IF @VillageId IS NULL
				BEGIN
					INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserID)
					SELECT N'FV' LocationCode,  N'Funding' LocationtName, @WardId ParentLocationId, N'V' LocationType, @AuditUserID AuditUserId;
					SELECT @VillageID = SCOPE_IDENTITY();
				END

				IF @FamilyId IS  NULL
					BEGIN
						--Insert a record in tblFamilies
						INSERT INTO tblFamilies (LocationId,Poverty,isOffline,AuditUserID) 
										VALUES  (@LocationId,0,@isOffline,@AuditUserID); 
			
						SELECT @FamilyId = SCOPE_IDENTITY();
			
						INSERT INTO tblInsuree(FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead,CardIssued,AuditUserID, isOffline)
						SELECT @FamilyId FamilyId, @FundingCHFID CHFID, N'Funding' LastName, N'Funding' OtherNames, @PayDate DOB, NULL Gender, NULL Marital, 1 IsHead, 0 CardIssued, @AuditUserID AuditUseId,  @isOffline isOffline;

						SELECT @InsureeId = SCOPE_IDENTITY();

						UPDATE tblFamilies set InsureeId = @InsureeId WHERE FamilyId = @FamilyId;

					END

--========================================================================================================
--Insert Policy
--========================================================================================================
			
				INSERT INTO tblPolicy(FamilyId, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdId, OfficerId, AuditUserID,isOffline)
				SELECT @FamilyId FamilyId, @PayDate EnrollDate, @payDate StartDate, @PayDate EffectiveDate, DATEADD(MONTH, @InsurancePeriod,@payDate)ExpiryDate, 2 PolicyStatus, @PolicyValue PolicyValue, @ProductId ProductId, NULL OfficerId,@AuditUserId AuditUserId, @isOffline isOffline

				SELECT @PolicyId = SCOPE_IDENTITY();


--========================================================================================================
--Insert Insuree Policy
--========================================================================================================
				INSERT INTO tblInsureePolicy(InsureeId, PolicyId, EnrollmentDate, StartDate, EffectiveDate, ExpiryDate,AuditUserId, isOffline)
				SELECT @InsureeId InsureeId, PL.PolicyId, PL.EnrollDate, PL.StartDate, PL.EffectiveDate, PL.ExpiryDate, PL.AuditUserId, @isOffline isOffline
				FROM tblPolicy PL
				WHERE PL.ValidityTo IS NULL
				AND PL.PolicyId = @PolicyId;


--========================================================================================================
--Insert Premium (Fund)
--========================================================================================================
			
				INSERT INTO tblPremium(PolicyId, PayerId, Amount,Receipt, PayDate, PayType, AuditUserID, isOffline)
				SELECT @PolicyId PolicyId, @payerId PayerId, @Amount Amount, @Receipt Receipt, @PayDate  PayDate, N'F' PayType, @AuditUserID, @isOffline;

		COMMIT TRAN AddFund
		
		RETURN 0;

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK TRAN AddFund;
		RETURN 99;
	END CATCH
END
GO
