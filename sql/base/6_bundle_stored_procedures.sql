



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAcknowledgeControlNumberRequest]
(
	
	@XML XML
)
AS
BEGIN

	DECLARE
	@PaymentID INT,
    @Success BIT,
    @Comment  NVARCHAR(MAX)
	SELECT @PaymentID = NULLIF(T.H.value('(PaymentID)[1]','INT'),''),
		   @Success = NULLIF(T.H.value('(Success)[1]','BIT'),''),
		   @Comment = NULLIF(T.H.value('(Comment)[1]','NVARCHAR(MAX)'),'')
	FROM @XML.nodes('ControlNumberAcknowledge') AS T(H)

				BEGIN TRY

				UPDATE tblPayment 
					SET PaymentStatus =  CASE @Success WHEN 1 THEN 2 ELSE-3 END, 
					RejectedReason = CASE @Success WHEN 0 THEN  @Comment ELSE NULL END,  
					ValidityFrom = GETDATE(),
					AuditedUserID = -1 
				WHERE PaymentID = @PaymentID AND ValidityTo IS NULL AND PaymentStatus < 3

				RETURN 0
			END TRY
			BEGIN CATCH
				ROLLBACK TRAN GETCONTROLNUMBER
				SELECT ERROR_MESSAGE()
				RETURN -1
			END CATCH
	

	
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspAddFund] 
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

	DECLARE @FundingCHFID NVARCHAR(12) = N'999999999'

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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspPolicyValue]
(
	@FamilyId INT =0,			--Provide if policy is not saved
	@ProdId INT =0,				--Provide if policy is not saved
	@PolicyId INT = 0,			--Provide if policy id is known
	@PolicyStage CHAR(1),		--Provide N if new policy, R if renewal
	@EnrollDate DATE = NULL,	--Enrollment date of the policy
	@PreviousPolicyId INT = 0,	--To determine the Expiry Date (For Renewal)
	@ErrorCode INT = 0 OUTPUT
)
AS

/*
********ERROR CODE***********
-1	:	Policy does not exists at the time of enrolment
-2	:	Policy was deleted at the time of enrolment

*/

BEGIN

	SET @ErrorCode = 0;

	DECLARE @LumpSum DECIMAL(18,2) = 0,
			@PremiumAdult DECIMAL(18,2) = 0,
			@PremiumChild DECIMAL(18,2) = 0,
			@RegistrationLumpSum DECIMAL(18,2) = 0,
			@RegistrationFee DECIMAL(18,2) = 0,
			@GeneralAssemblyLumpSum DECIMAL(18,2) = 0,
			@GeneralAssemblyFee DECIMAL(18,2) = 0,
			@Threshold SMALLINT = 0,
			@MemberCount INT = 0,
			@AdultMembers INT =0,
			@ChildMembers INT = 0,
			@OAdultMembers INT =0,
			@OChildMembers INT = 0,
			@Registration DECIMAL(18,2) = 0,
			@GeneralAssembly DECIMAL(18,2) = 0,
			@Contribution DECIMAL(18,2) = 0,
			@PolicyValue DECIMAL(18,2) = 0,
			@ExtraAdult INT = 0,
			@ExtraChild INT = 0,
			@AddonAdult DECIMAL(18,2) = 0,
			@AddonChild DECIMAL(18,2) = 0,
			@DiscountPeriodR INT = 0,
			@DiscountPercentR DECIMAL(18,2) =0,
			@DiscountPeriodN INT = 0,
			@DiscountPercentN DECIMAL(18,2) =0,
			@ExpiryDate DATE
		

		IF @EnrollDate IS NULL 
			SET @EnrollDate = GETDATE();



	--This means you are calculating existing policy
		IF @PolicyId > 0
		BEGIN
			SELECT TOP 1 @FamilyId = FamilyId, @ProdId = ProdId,@PolicyStage = PolicyStage,@EnrollDate = EnrollDate, @ExpiryDate = ExpiryDate FROM tblPolicy WHERE PolicyID = @PolicyId
		END

		DECLARE @ValidityTo DATE = NULL,
				@LegacyId INT = NULL

	/*--Get all the required fiedls from product (Valide product at the enrollment time)--*/
		SELECT TOP 1 @LumpSum = ISNULL(LumpSum,0),@PremiumAdult = ISNULL(PremiumAdult,0),@PremiumChild = ISNULL(PremiumChild,0),@RegistrationLumpSum = ISNULL(RegistrationLumpSum,0),
		@RegistrationFee = ISNULL(RegistrationFee,0),@GeneralAssemblyLumpSum = ISNULL(GeneralAssemblyLumpSum,0), @GeneralAssemblyFee = ISNULL(GeneralAssemblyFee,0), 
		@Threshold = ISNULL(Threshold ,0),@MemberCount = ISNULL(MemberCount,0), @ValidityTo = ValidityTo, @LegacyId = LegacyID, @DiscountPeriodR = ISNULL(RenewalDiscountPeriod, 0), @DiscountPercentR = ISNULL(RenewalDiscountPerc,0)
		, @DiscountPeriodN = ISNULL(EnrolmentDiscountPeriod, 0), @DiscountPercentN = ISNULL(EnrolmentDiscountPerc,0)
		FROM tblProduct 
		WHERE (ProdID = @ProdId OR LegacyID = @ProdId)
		AND CONVERT(DATE,ValidityFrom,103) <= @EnrollDate
		ORDER BY ValidityFrom Desc

		IF @@ROWCOUNT = 0	--No policy found
			SET @ErrorCode = -1
		IF NOT @ValidityTo IS NULL AND @LegacyId IS NULL	--Policy is deleted by the time of enrollment
			SET @ErrorCode = -2
			

	/*
		Relationships to be excluded from the normal family Count
		7: Others
	*/

	--Get only valid insurees according to the maximum members of the product from the family

	IF NOT OBJECT_ID('tempdb..#tblInsuree') IS NULL DROP TABLE #tblInsuree
	SELECT * INTO #tblInsuree FROM tblInsuree WHERE FamilyID = @FamilyId AND ValidityTo IS NULL;

	;WITH TempIns AS
	(
	SELECT ROW_NUMBER() OVER(ORDER BY ValidityFrom) Number, * FROM #tblInsuree
	)DELETE I FROM #tblInsuree I INNER JOIN TempIns T ON I.InsureeId = T.InsureeId
	 WHERE Number > @MemberCount;


	--Get the number of adults, Children, OtherAdult and Other Children from the family
		SET @AdultMembers = (SELECT COUNT(InsureeId) FROM #tblInsuree WHERE DATEDIFF(YEAR,DOB,GETDATE()) >= 18 AND ISNULL(Relationship,0) <> 7 AND ValidityTo IS NULL AND FamilyID = @FamilyId) 
		SET @ChildMembers = (SELECT COUNT(InsureeId) FROM #tblInsuree WHERE DATEDIFF(YEAR,DOB,GETDATE()) < 18 AND ISNULL(Relationship,0) <> 7  AND ValidityTo IS NULL AND FamilyID = @FamilyId)
		SET @OAdultMembers = (SELECT COUNT(InsureeId) FROM #tblInsuree WHERE DATEDIFF(YEAR,DOB,GETDATE()) >= 18 AND ISNULL(Relationship,0) = 7 AND ValidityTo IS NULL AND FamilyID = @FamilyId) 
		SET @OChildMembers = (SELECT COUNT(InsureeId) FROM #tblInsuree WHERE DATEDIFF(YEAR,DOB,GETDATE()) < 18 AND ISNULL(Relationship,0) = 7 AND ValidityTo IS NULL AND FamilyID = @FamilyId)


	--Get extra members in family
		IF @Threshold > 0 AND @AdultMembers > @Threshold
			SET @ExtraAdult = @AdultMembers - @Threshold
		IF @Threshold > 0 AND @ChildMembers > (@Threshold - @AdultMembers + @ExtraAdult )
					SET @ExtraChild = @ChildMembers - ((@Threshold - @AdultMembers + @ExtraAdult))
			

	--Get the Contribution
		IF @LumpSum > 0
			SET @Contribution = @LumpSum
		ELSE
			SET @Contribution = (@AdultMembers * @PremiumAdult) + (@ChildMembers * @PremiumChild)

	--Get the Assembly
		IF @GeneralAssemblyLumpSum > 0
			SET @GeneralAssembly = @GeneralAssemblyLumpSum
		ELSE
			SET @GeneralAssembly = (@AdultMembers + @ChildMembers + @OAdultMembers + @OChildMembers) * @GeneralAssemblyFee;

	--Get the Registration
		IF @PolicyStage = N'N'	--Don't calculate if it's renewal
		BEGIN
			IF @RegistrationLumpSum > 0
				SET @Registration = @RegistrationLumpSum
			ELSE
				SET @Registration = (@AdultMembers + @ChildMembers  + @OAdultMembers + @OChildMembers) * @RegistrationFee;
		END

	

		SET @AddonAdult = (@ExtraAdult + @OAdultMembers) * @PremiumAdult;
		SET @AddonChild = (@ExtraChild + @OChildMembers) * @PremiumChild;

		SET @Contribution += @AddonAdult + @AddonChild;
		
		--Line below was a mistake, All adults and children are already included in GeneralAssembly and Registration
		--SET @GeneralAssembly += (@OAdultMembers + @OChildMembers + @ExtraAdult + @ExtraChild) * @GeneralAssemblyFee;
		
		--IF @PolicyStage = N'N'
		--	SET @Registration += (@OAdultMembers + @OChildMembers + @ExtraAdult + @ExtraChild) * @RegistrationFee;


	SET @PolicyValue = @Contribution + @GeneralAssembly + @Registration;


	--The total policy value is calculated, So if the enroldate is earlier than the discount period then apply discount
	DECLARE @HasCycle BIT
	DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)
	INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
	EXEC uspGetPolicyPeriod @ProdId, @EnrollDate, @HasCycle OUTPUT, @PolicyStage;

	DECLARE @StartDate DATE =(SELECT StartDate FROM @tblPeriod);


	DECLARE @MinDiscountDateR DATE,
			@MinDiscountDateN DATE

	IF @PolicyStage = N'N'
	BEGIN
		SET @MinDiscountDateN = DATEADD(MONTH,-(@DiscountPeriodN),@StartDate);
		IF @EnrollDate <= @MinDiscountDateN AND @HasCycle = 1
			SET @PolicyValue -=  (@PolicyValue * 0.01 * @DiscountPercentN);
	END
	ELSE IF @PolicyStage  = N'R'
	BEGIN
		DECLARE @PreviousExpiryDate DATE = NULL

		IF @PreviousPolicyId > 0
		BEGIN
			SELECT @PreviousExpiryDate = DATEADD(DAY, 1, ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyId = @PreviousPolicyId;	
		END
		ELSE
		BEGIN
			SET @PreviousExpiryDate = @StartDate;
		END

		SET @MinDiscountDateR = DATEADD(MONTH,-(@DiscountPeriodR),@PreviousExpiryDate);
		IF @EnrollDate <= @MinDiscountDateR
			SET @PolicyValue -=  (@PolicyValue * 0.01 * @DiscountPercentR);
	END

	SELECT @PolicyValue PolicyValue;
	RETURN @PolicyValue;

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAddInsureePolicy]
(
	@InsureeId INT,
	@Activate BIT = 0
)
AS
BEGIN
	DECLARE @FamilyId INT,
			@PolicyId INT,
			@NewPolicyValue DECIMAL(18,2),
			@EffectiveDate DATE,
			@PolicyValue DECIMAL(18,2),
			@PolicyStage NVARCHAR(1),
			@ProdId INT,
			@AuditUserId INT,
			@isOffline BIT,
			@ErrorCode INT,
			@TotalInsurees INT,
			@MaxMember INT,
			@ThresholdMember INT

	SELECT @FamilyId = FamilyID,@AuditUserId = AuditUserID FROM tblInsuree WHERE InsureeID = @InsureeId
	SELECT @TotalInsurees = COUNT(InsureeId) FROM tblInsuree WHERE FamilyId = @FamilyId AND ValidityTo IS NULL 
	SELECT @isOffline = ISNULL(OfflineCHF,0)  FROM tblIMISDefaults
	
	DECLARE @Premium decimal(18,2) = 0
	
	DECLARE Cur CURSOR FOR SELECT PolicyId,PolicyValue,EffectiveDate,PolicyStage,ProdID FROM tblPolicy WHERE FamilyID  = @FamilyId AND ValidityTo IS NULL
	OPEN Cur
	FETCH NEXT FROM Cur INTO @PolicyId,@PolicyValue,@EffectiveDate,@PolicyStage,@ProdId
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @MaxMember = MemberCount FROM tblProduct WHERE ProdId = @ProdId;
		--amani 07/12
		SELECT @ThresholdMember = Threshold FROM tblProduct WHERE ProdId = @ProdId;

		IF @MaxMember < @TotalInsurees
			GOTO NEXT_POLICY;

		EXEC @NewPolicyValue = uspPolicyValue @PolicyId = @PolicyId, @PolicyStage = @PolicyStage, @ErrorCode = @ErrorCode OUTPUT;
		--If new policy value is changed then the current insuree will not be insured
		IF @NewPolicyValue <> @PolicyValue OR @ErrorCode <> 0
		BEGIN
			IF @Activate = 0
			BEGIN
				
				SET @Premium=ISNULL((SELECT SUM(Amount) Amount FROM tblPremium WHERE PolicyID=@PolicyId AND ValidityTo IS NULL and isPhotoFee = 0 ),0) 
				IF @Premium < @NewPolicyValue 
					SET @EffectiveDate = NULL
			END
		END
				
		INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,AuditUserId,isOffline)
		SELECT @InsureeId, @PolicyId,EnrollDate,P.StartDate,@EffectiveDate,P.ExpiryDate,@AuditUserId,@isOffline
		FROM tblPolicy P 
		WHERE P.PolicyID = @PolicyId
			
NEXT_POLICY:
		FETCH NEXT FROM Cur INTO @PolicyId,@PolicyValue,@EffectiveDate,@PolicyStage,@ProdId
	END
	CLOSE Cur
	DEALLOCATE Cur
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspAddInsureePolicyOffline]
(
	--@InsureeId INT,
	@PolicyId INT,
	@Activate BIT = 0
)
AS
BEGIN

	DECLARE @FamilyId INT,			
			@NewPolicyValue DECIMAL(18,2),
			@EffectiveDate DATE,
			@PolicyValue DECIMAL(18,2),
			@PolicyStage NVARCHAR(1),
			@ProdId INT,
			@AuditUserId INT,
			@isOffline BIT,
			@ErrorCode INT,
			@TotalInsurees INT,
			@MaxMember INT,
			@ThresholdMember INT,
			@Premium DECIMAL(18,2),
			@NewFamilyId INT,
			@NewPolicyId INT,
			@NewInsureeId INT
	DECLARE @Result TABLE(ErrorMessage NVARCHAR(500))
	DECLARE @tblInsureePolicy TABLE(
	InsureeId int NULL,
	PolicyId int NULL,
	EnrollmentDate date NULL,
	StartDate date NULL,
	EffectiveDate date NULL,
	ExpiryDate date NULL,
	ValidityFrom datetime NULL ,
	ValidityTo datetime NULL,
	LegacyId int NULL,
	AuditUserId int NULL,
	isOffline bit NULL,
	RowId timestamp NULL
)

----BY AMANI 19/12/2017
	--SELECT @FamilyId = FamilyID,@AuditUserId = AuditUserID FROM tblInsuree WHERE InsureeID = @InsureeId
	SELECT @FamilyId = F.FamilyID,@AuditUserId = F.AuditUserID FROM tblFamilies F
	INNER JOIN tblPolicy P ON P.FamilyID=F.FamilyID AND P.PolicyID=@PolicyId  AND F.ValidityTo IS NULL  AND P.ValidityTo IS NULL
	SELECT @isOffline = ISNULL(OfflineCHF,0)  FROM tblIMISDefaults
	SELECT @ProdId=ProdID FROM tblPolicy WHERE PolicyID=@PolicyId
	SET    @Premium=ISNULL((SELECT SUM(Amount) Amount FROM tblPremium WHERE PolicyID=@PolicyId AND ValidityTo IS NULL),0)
	SELECT @MaxMember = ISNULL(MemberCount,0) FROM tblProduct WHERE ProdId = @ProdId;		
	SELECT @ThresholdMember = Threshold FROM tblProduct WHERE ProdId = @ProdId;

	SELECT @PolicyStage = PolicyStage FROM tblPolicy WHERE PolicyID=@PolicyId
				
BEGIN TRY
	SAVE TRANSACTION TRYSUB	---BEGIN SAVE POINT

	--INSERT TEMPORARY FAMILY
	INSERT INTO tblFamilies(InsureeID, LocationId, Poverty, ValidityFrom, ValidityTo, LegacyID, AuditUserID, FamilyType, FamilyAddress, isOffline, Ethnicity, ConfirmationNo, ConfirmationType)
	SELECT					InsureeID, LocationId, Poverty, ValidityFrom, ValidityTo, LegacyID, AuditUserID, FamilyType, FamilyAddress, isOffline, Ethnicity, ConfirmationNo, ConfirmationType
	FROM tblFamilies WHERE FamilyID=@FamilyId  AND ValidityTo IS NULL 
	SET @NewFamilyId = (SELECT SCOPE_IDENTITY());

	EXEC @NewPolicyValue = uspPolicyValue @FamilyId=@NewFamilyId, @PolicyStage=@PolicyStage, @ErrorCode = @ErrorCode OUTPUT;

	--INSERT TEMP POLICY
	INSERT INTO dbo.tblPolicy
           (FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,ValidityTo,LegacyID,AuditUserID,isOffline)
 SELECT		@NewFamilyId,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,@NewPolicyValue,ProdID,OfficerID,@PolicyStage,ValidityFrom,ValidityTo,LegacyID,AuditUserID,isOffline
  FROM dbo.tblPolicy WHERE PolicyID=@PolicyId
	SET @NewPolicyId = (SELECT SCOPE_IDENTITY());


		--SELECT InsureeID FROM tblInsuree WHERE FamilyID =@FamilyId AND ValidityTo IS NULL 	ORDER BY InsureeID ASC

		DECLARE @NewCurrentInsureeId INT =0
	
		DECLARE CurTempInsuree CURSOR FOR 
		SELECT InsureeID FROM tblInsuree WHERE FamilyID =@FamilyId AND ValidityTo IS NULL 	ORDER BY InsureeID ASC
		OPEN CurTempInsuree
		FETCH NEXT FROM CurTempInsuree INTO @NewCurrentInsureeId
		WHILE @@FETCH_STATUS = 0
		BEGIN
				INSERT INTO dbo.tblInsuree
		  (FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,passport,Phone,PhotoID,PhotoDate,CardIssued,ValidityFrom,ValidityTo,LegacyID,AuditUserID,Relationship,Profession,Education,Email,isOffline,TypeOfId,HFID,CurrentAddress ,GeoLocation,CurrentVillage)
  
		SELECT   
		   @NewFamilyId,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,passport,Phone,PhotoID,PhotoDate,CardIssued,ValidityFrom,ValidityTo,LegacyID,AuditUserID,Relationship,Profession,Education,Email,isOffline,TypeOfId,HFID,CurrentAddress,GeoLocation,CurrentVillage
		  FROM dbo.tblInsuree WHERE InsureeID=@NewCurrentInsureeId
		  SET @NewInsureeId= (SELECT SCOPE_IDENTITY());
			SELECT @TotalInsurees = COUNT(InsureeId) FROM tblInsuree WHERE FamilyId = @NewFamilyId AND ValidityTo IS NULL 
				IF  @TotalInsurees > @MaxMember 
				GOTO CLOSECURSOR;
		
	SELECT @EffectiveDate= EffectiveDate, @PolicyValue=ISNULL(PolicyValue,0) FROM tblPolicy  WHERE PolicyID =@NewPolicyId AND ValidityTo IS NULL 
			EXEC @NewPolicyValue = uspPolicyValue @PolicyId = @NewPolicyId, @PolicyStage = @PolicyStage, @ErrorCode = @ErrorCode OUTPUT;
			--If new policy value is changed then the current insuree will not be insured
		IF @NewPolicyValue <> @PolicyValue OR @ErrorCode <> 0
		BEGIN
	UPDATE tblPolicy SET PolicyValue=@NewPolicyValue WHERE PolicyID=@NewPolicyId
		IF @Activate = 0 
			IF  @Premium < @NewPolicyValue
			BEGIN
				SET @EffectiveDate = NULL
			END
		END

		--INSERT TEMP INSUREEPOLICY
	
		INSERT INTO @tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,ValidityFrom,AuditUserId,isOffline)
			SELECT @NewCurrentInsureeId, @PolicyId,EnrollDate,P.StartDate,@EffectiveDate,P.ExpiryDate,GETDATE(),@AuditUserId,@isOffline
			FROM tblPolicy P 
			WHERE P.PolicyID = @NewPolicyId
		

		CLOSECURSOR:
		FETCH NEXT FROM CurTempInsuree INTO @NewCurrentInsureeId
		END														
		CLOSE CurTempInsuree
		
	
		ROLLBACK TRANSACTION  TRYSUB --ROLLBACK SAVE POINT			
		SELECT * FROM @tblInsureePolicy

		--BEGIN TRY	

		--MERGE TO THE REAL TABLE


		MERGE INTO tblInsureePolicy  AS TARGET
			USING @tblInsureePolicy AS SOURCE
				ON TARGET.InsureeId = SOURCE.InsureeId
				AND TARGET.PolicyId = SOURCE.PolicyId
				AND TARGET.ValidityTo IS NULL
			WHEN MATCHED THEN 
				UPDATE SET TARGET.EffectiveDate = SOURCE.EffectiveDate
			WHEN NOT MATCHED BY TARGET THEN
				INSERT (InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,ValidityFrom,AuditUserId,isOffline)
				VALUES (SOURCE.InsureeId,
						SOURCE.PolicyId, 
						SOURCE.EnrollmentDate, 
						SOURCE.StartDate, 
						SOURCE.EffectiveDate, 
						SOURCE.ExpiryDate, 
						SOURCE.ValidityFrom, 
						SOURCE.AuditUserId, 
						SOURCE.isOffline);
		--END TRY
		--BEGIN CATCH
		--	SELECT ERROR_MESSAGE();
		--	ROLLBACK TRANSACTION  TRYSUB;	
		--END CATCH
	

END TRY
BEGIN CATCH
		ROLLBACK TRANSACTION  TRYSUB;	
		SELECT @ErrorCode;
		INSERT INTO @Result(ErrorMessage) VALUES(ERROR_MESSAGE())
		SELECT * INTO TempError FROM @Result
END CATCH
	
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIDeleteMemberFamily]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12)
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number  of member
		2-Insurance number of member not found
		3- Member is head of family
		0 - Success (0 OK), 
		-1 -Unknown  Error 
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1

	--2-Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Member is head of family
	IF  EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL AND IsHead = 1)
		RETURN 3

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION DELETEMEMBERFAMILY
			
				DECLARE @InsureeId INT


				SELECT @InsureeID = InsureeID FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL
				
				INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,TypeOfId, HFID, CurrentAddress, CurrentVillage,GeoLocation ) 
				SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,getdate(),@insureeId ,TypeOfId, HFID, CurrentAddress, CurrentVillage, GeoLocation 
				FROM tblInsuree WHERE InsureeID = @InsureeID AND ValidityTo IS NULL
				UPDATE [tblInsuree] SET [ValidityFrom] = GetDate(),[ValidityTo] = GetDate(),[AuditUserID] = @AuditUserID 
				WHERE InsureeId = @InsureeID AND ValidityTo IS NULL

       

			COMMIT TRANSACTION DELETEMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION DELETEMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH


END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIEditFamily]
(
	@AuditUserID INT = -3,
	@InsuranceNumberOfHead NVARCHAR(12),
	@VillageCode NVARCHAR(8)= NULL,
	@OtherNames NVARCHAR(100) = NULL,
	@LastName NVARCHAR(100) = NULL,
	@BirthDate DATE = NULL,
	@Gender NVARCHAR(1) = NULL,
	@PovertyStatus BIT = NULL,
	@ConfirmationType NVARCHAR(1) = NULL,
	@GroupType NVARCHAR(2) = NULL,
	@ConfirmationNumber NVARCHAR(12) = NULL,
	@PermanentAddress NVARCHAR(200) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = NULL,
	@CurrentVillageCode NVARCHAR(8) = NULL,
	@CurrentAddress NVARCHAR(200) = NULL,
	@Proffesion NVARCHAR(50) = NULL,
	@Education NVARCHAR(50) = NULL,
	@PhoneNumber NVARCHAR(50) = NULL,
	@Email NVARCHAR(100) = NULL,
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = NULL,
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODES
		1 - Wrong format or missing insurance number of head
		2 - Insurance number of head not found
		3 - Wrong or missing permanent village code
		4 - Wrong current village code
		5 - Wrong  gender
		6 - Wrong confirmation type
		7 - Wrong group type
		8 - Wrong marital status
		9 - Wrong education
		10 - Wrong profession
		11 - FSP code not found
		12 - Wrong identification type
		0 - Success 
		-1 Unknown Error

	*/
	

	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1 - Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumberOfHead,'')) = 0
		RETURN 1
	
	--2 - Insurance number of head not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumberOfHead AND ValidityTo IS NULL AND IsHead = 1)
		RETURN 2

	--3 - Wrong missing permanent village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND  LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 3

	--4 - Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL AND LocationType ='V') AND  LEN(ISNULL(@CurrentVillageCode,'')) > 0
		RETURN 4
	
	--5 - Wrong   gender
	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender) AND LEN(ISNULL(@Gender,'')) > 0
		RETURN 5
	
	--6 - Wrong confirmation type
	IF NOT EXISTS(SELECT 1 FROM tblConfirmationTypes WHERE ConfirmationTypeCode = @ConfirmationType) AND LEN(ISNULL(@ConfirmationType,'')) > 0
		RETURN 6
	
	--7 - Wrong group type
	IF NOT EXISTS(SELECT  1 FROM tblFamilyTypes WHERE FamilyTypeCode = @GroupType) AND LEN(ISNULL(@GroupType,'')) > 0
		RETURN 7

	--8 - Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 8

	--9 - Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 9

	--10 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 10

	--11 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 11

	--12 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 12


	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION EDITROLFAMILY
			
				DECLARE @FamilyID INT,
						@InsureeID INT,
						@ProfessionId INT,
						@EducationId INT,
						@RelationId INT,
						@LocationId INT,
						@CurrentLocationId INT,
						@HfID INT,
						@DBLocationID INT = NULL,
						@DBOtherNames NVARCHAR(100) = NULL,
						@DBLastName NVARCHAR(100) = NULL,
						@DBBirthDate DATE = NULL,
						@DBGender NVARCHAR(1) = NULL,
						@DBMaritalStatus NVARCHAR(1) = NULL,
						@DBBeneficiaryCard BIT = NULL,
						@DBVillageID INT = NULL,
						@DBCurrentAddress NVARCHAR(200) = NULL,
						@DBProffesionID INT = NULL,
						@DBEducationID INT = NULL,
						@DBPhoneNumber NVARCHAR(50) = NULL,
						@DBEmail NVARCHAR(100) = NULL,
						@DBConfirmationType NVARCHAR(25) = NULL,
						@DBIdentificationNumber NVARCHAR(25) = NULL,
						@DBIdentificationType NVARCHAR(1) = NULL,
						@DBGroupType nvarchar(2) = NULL,
						@DBHFID INT = NULL,
						@DBCurrentLocationId INT=NULL
						

						SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
						SELECT @FamilyID = FamilyID FROM tblInsuree WHERE CHFID = @InsuranceNumberOfHead AND IsHead = 1 
						SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
						SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
						SELECT @CurrentLocationId = LocationId FROM tblLocations WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL
						SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL
						SELECT @InsureeId = I.InsureeID, @DBOtherNames = OtherNames, @DBLastName= LastName, @DBBirthDate = DOB, @DBGender = Gender, @DBMaritalStatus= Marital, 
						@DBBeneficiaryCard = CardIssued, @DBCurrentLocationId = CurrentVillage, @DBCurrentAddress = CurrentAddress, @DBProffesionID = Profession, @DBEducationID =Education, 
						@DBPhoneNumber = Phone, @DBEmail = Email, @DBIdentificationNumber = passport, @DBHFID = HFID, @DBLocationID = F.LocationId, @DBConfirmationType = F.ConfirmationType,
						@DBIdentificationType = [TypeOfId], @DBGroupType = FamilyType
						FROM tblInsuree I INNER JOIN tblFamilies  F ON F.FamilyID = I.FamilyID  WHERE CHFID = @InsuranceNumberOfHead AND I.ValidityTo IS NULL AND F.ValidityTo IS NULL

						SET	@LocationId = ISNULL(@LocationId, @DBLocationID)
						SET	@OtherNames = ISNULL(@OtherNames, @DBOtherNames)
						SET	@LastName = ISNULL(@LastName, @DBLastName)
						SET	@BirthDate = ISNULL(@BirthDate, @DBBirthDate)
						SET	@Gender = ISNULL(@Gender, @DBGender)
						SET	@MaritalStatus = ISNULL(@MaritalStatus, @DBMaritalStatus)
						SET	@BeneficiaryCard = ISNULL(@BeneficiaryCard, @DBBeneficiaryCard)
						SET	@CurrentAddress = ISNULL(@CurrentAddress, @DBCurrentAddress)
						SET	@ProfessionId = ISNULL(@ProfessionId, @DBProffesionID)
						SET	@EducationId = ISNULL(@EducationId, @DBEducationID)
						SET	@PhoneNumber = ISNULL(@PhoneNumber, @DBPhoneNumber)
						SET	@Email = ISNULL(@Email, @DBEmail)
						SET	@ConfirmationType = ISNULL(@ConfirmationType, @DBConfirmationType)
						SET @IdentificationType = ISNULL(@IdentificationType,@DBIdentificationType )
						SET	@IdentificationNumber = ISNULL(@IdentificationNumber, @DBIdentificationNumber)
						SET	@HfID = ISNULL(@HfID, @DBHFID )
						SET @GroupType = ISNULL(@GroupType, @DBGroupType)
						SET @CurrentLocationId = ISNULL(@CurrentLocationId,@DBCurrentLocationId)

						INSERT INTO tblFamilies ([insureeid],[Poverty],[ConfirmationType],isOffline,[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],FamilyType, FamilyAddress,Ethnicity,ConfirmationNo, LocationId) 
						SELECT [insureeid], [Poverty], [ConfirmationType], isOffline, [ValidityFrom], getdate() ValidityTo, FamilyID, @AuditUserID, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo, LocationId FROM tblFamilies
						WHERE FamilyID = @FamilyID 
								AND ValidityTo IS NULL
						

						UPDATE tblFamilies SET LocationId = @LocationId, Poverty = @PovertyStatus, ValidityFrom = GETDATE(),AuditUserID = @AuditUserID,FamilyType = @GroupType,FamilyAddress = @PermanentAddress,ConfirmationType =@ConfirmationType,
							  ConfirmationNo = @ConfirmationNumber WHERE FamilyID = @FamilyID AND ValidityTo IS NULL

						--Insert Insuree History
						INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
						SELECT	I.[FamilyID],I.[CHFID],I.[LastName],I.[OtherNames],I.[DOB],I.[Gender],I.[Marital],I.[IsHead],I.[passport],I.[Phone],I.[PhotoID],I.[PhotoDate],I.[CardIssued],I.isOffline,I.[AuditUserID],I.[ValidityFrom] ,GETDATE() ValidityTo,I.InsureeID,I.[Relationship],I.[Profession],I.[Education],I.[Email] ,I.[TypeOfId],I.[HFID], I.[CurrentAddress], I.[GeoLocation], [CurrentVillage] FROM tblInsuree I
						WHERE I.CHFID = @InsuranceNumberOfHead AND  I.ValidityTo IS NULL
					
						UPDATE tblInsuree  SET [LastName] = @LastName, [OtherNames] = @OtherNames,[DOB] = @BirthDate, [Gender] = @Gender,[Marital] = @MaritalStatus, [TypeOfId]  = @IdentificationType , [passport] = @IdentificationNumber,[Phone] = @PhoneNumber,[CardIssued] = ISNULL(@BeneficiaryCard,0),[ValidityFrom] = GetDate(),[AuditUserID] = @AuditUserID , [Profession] = @ProfessionId, [Education] = @EducationId,[Email] = @Email ,HFID = @HFID, CurrentAddress = @CurrentAddress, CurrentVillage = @CurrentLocationId
						WHERE InsureeID = @InsureeId AND  ValidityTo IS NULL 


			COMMIT TRANSACTION EDITROLFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION EDITROLFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIEditMemberFamily]
(
	@AuditUserID INT = -3,
	@InsureeNumber NVARCHAR(12),
	@OtherNames NVARCHAR(100) = NULL,
	@LastName NVARCHAR(100) = NULL,
	@BirthDate DATE = NULL,
	@Gender NVARCHAR(1) = NULL,
	@Relationship NVARCHAR(50) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = NULL,
	@VillageCode NVARCHAR(8) = NULL,
	@CurrentAddress NVARCHAR(200) = NULL,
	@Proffesion NVARCHAR(50) = NULL,
	@Education NVARCHAR(50) = NULL,
	@PhoneNumber NVARCHAR(50) = NULL,
	@Email NVARCHAR(100) = NULL,
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = NULL,
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of a member
		2-Insurance number of head not found
		3- Wrong format or missing insurance number of member
		4-Insurance number of member not found
		5-Wrong current village code
		6-Wrong gender
		7-Wrong marital status
		8-Wrong education
		9 - Wrong profession
		10 - FSP code not found
		11 - Wrong identification type
		12 - Wrong Relation
		-1 - Unexpected error
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--3- Wrong format or missing insurance number of member
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3

	--4 - Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
		RETURN 4

	--5-Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 5

	--6-Wrong gender
	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender) AND LEN(ISNULL(@Gender,'')) > 0
		RETURN 6

	--7-Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 7

	--8-Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 8

	--9 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 9

	--10 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 10
	--11 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 11

	--12 - Wrong Relation
	IF NOT EXISTS(SELECT  1 FROM tblRelations WHERE Relation = @Relationship) AND LEN(ISNULL(@Relationship,'')) > 0
		RETURN 12

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION EDITMEMBERFAMILY
			
				DECLARE @FamilyID INT,
				
						@ProfessionId INT,
						@RelationId INT,
						@EducationId INT,
						@LocationId INT,
						@HfID INT,
						@InsureeId INT,
						@AssociatedPhotoFolder NVARCHAR(255),
						@DBOtherNames NVARCHAR(100) = NULL,
						@DBLastName NVARCHAR(100) = NULL,
						@DBBirthDate DATE = NULL,
						@DBGender NVARCHAR(1) = NULL,
						@DBRelationshipID NVARCHAR(50) = NULL,
						@DBMaritalStatus NVARCHAR(1) = NULL,
						@DBBeneficiaryCard BIT = NULL,
						@DBVillageID INT = NULL,
						@DBCurrentAddress NVARCHAR(200) = NULL,
						@DBProffesionID INT = NULL,
						@DBEducationID INT = NULL,
						@DBPhoneNumber NVARCHAR(50) = NULL,
						@DBEmail NVARCHAR(100) = NULL,
						@DBIdentificationNumber NVARCHAR(25) = NULL,
						@DBIdentificationType NVARCHAR(1) = NULL,
						@DBFSPCode NVARCHAR(8) = NULL


				SET @AssociatedPhotoFolder=(SELECT AssociatedPhotoFolder FROM tblIMISDefaults)
				SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
				SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
				SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
				SELECT @RelationId = RelationId FROM tblRelations WHERE Relation = @Relationship
				SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL
				SELECT @InsureeId = InsureeID, @DBOtherNames = OtherNames, @DBLastName= LastName, @DBBirthDate = DOB, @DBGender = Gender, @DBMaritalStatus= Marital, @DBBeneficiaryCard = CardIssued, 
				@DBVillageID = CurrentVillage, @DBCurrentAddress = CurrentAddress, @DBProffesionID = Profession, @DBEducationID =Education, @DBPhoneNumber = Phone, @DBEmail = Email, 
				@DBIdentificationNumber = passport, @DBFSPCode = HFID, @DBIdentificationType = TypeOfId, @DBRelationshipID=Relationship 
				FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL

					SET	@OtherNames = ISNULL(@OtherNames, @DBOtherNames)
					SET	@LastName = ISNULL(@LastName, @DBLastName)
					SET	@BirthDate = ISNULL(@BirthDate, @DBBirthDate)
					SET	@Gender = ISNULL(@Gender, @DBGender)
					SET	@RelationId = ISNULL(@RelationId, @DBRelationshipID)
					SET	@MaritalStatus = ISNULL(@MaritalStatus, @DBMaritalStatus)
					SET	@BeneficiaryCard = ISNULL(@BeneficiaryCard, @DBBeneficiaryCard)
					SET	@LocationId = ISNULL(@LocationId, @DBVillageID)
					SET	@CurrentAddress = ISNULL(@CurrentAddress, @DBCurrentAddress)
					SET	@ProfessionId = ISNULL(@ProfessionId, @DBProffesionID)
					SET	@EducationId = ISNULL(@EducationId, @DBEducationID)
					SET	@PhoneNumber = ISNULL(@PhoneNumber, @DBPhoneNumber)
					SET	@Email = ISNULL(@Email, @DBEmail)
					SET @IdentificationType = ISNULL(@IdentificationType,@DBIdentificationType )
					SET	@IdentificationNumber = ISNULL(@IdentificationNumber, @DBIdentificationNumber)

					SET	@FSPCode = ISNULL(@FSPCode, @DBFSPCode)

				--Insert Insuree History
					INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
					SELECT	I.[FamilyID],I.[CHFID],I.[LastName],I.[OtherNames],I.[DOB],I.[Gender],I.[Marital],I.[IsHead],I.[passport],I.[Phone],I.[PhotoID],I.[PhotoDate],I.[CardIssued],I.isOffline,I.[AuditUserID],I.[ValidityFrom] ,GETDATE() ValidityTo,I.InsureeID,I.[Relationship],I.[Profession],I.[Education],I.[Email]  ,I.[TypeOfId],I.[HFID], I.[CurrentAddress], I.[GeoLocation], [CurrentVillage] FROM tblInsuree I
					WHERE I.InsureeID = @InsureeId AND  I.ValidityTo IS NULL
					
					UPDATE tblInsuree  SET [LastName] = @LastName, [OtherNames] = @OtherNames,[DOB] = @BirthDate, [Gender] = @Gender,[Marital] = @MaritalStatus, [TypeOfId]  = @IdentificationType ,[passport] = @IdentificationNumber,[Phone] = @PhoneNumber,[CardIssued] = ISNULL(@BeneficiaryCard,0),[ValidityFrom] = GetDate(),[AuditUserID] = @AuditUserID ,[Relationship] = @RelationId, [Profession] = @ProfessionId, [Education] = @EducationId,[Email] = @Email ,HFID = @HFID, CurrentAddress = @CurrentAddress, CurrentVillage = @LocationId, GeoLocation = @LocationId 
					WHERE InsureeID = @InsureeId AND  ValidityTo IS NULL 
				
					
								


			COMMIT TRANSACTION EDITMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION EDITMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIEnterContribution]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12),
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIEnterFamily]
(
	@AuditUserID INT = -3,
	@PermanentVillageCode NVARCHAR(8),
	@InsuranceNumber NVARCHAR(12),
	@OtherNames NVARCHAR(100),
	@LastName NVARCHAR(100),
	@BirthDate DATE,
	@Gender NVARCHAR(1),
	@PovertyStatus BIT = NULL,
	@ConfirmationNo nvarchar(12) = '' ,
	@ConfirmationType NVARCHAR(1) = NULL,
	@PermanentAddress NVARCHAR(200) = '',
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = 0 ,
	@CurrentVillageCode NVARCHAR(8) = NULL ,
	@CurrentAddress NVARCHAR(200) = '',
	@Proffesion NVARCHAR(50) = NULL,
	@Education NVARCHAR(50) = NULL,
	@PhoneNumber NVARCHAR(50) = '',
	@Email NVARCHAR(100) = '',
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = '',
	@FSPCode NVARCHAR(8) = NULL,
	@GroupType NVARCHAR(2)= NULL
)
AS
BEGIN

	/*
	RESPONSE CODES
		1 - Wrong format or missing insurance number of head
		2 - Duplicated insurance number of head
		3 - Wrong or missing permanent village code
		4 - Wrong current village code
		5 - Wrong or missing  gender
		6 - Wrong format or missing birth date
		7 - Missing last name
		8 - Missing other name
		9 - Wrong confirmation type
		10 - Wrong group type
		11 - Wrong marital status
		12 - Wrong education
		13 - Wrong profession
		14 - FSP code not found
		15 - wrong identification type 
		0 - Success 
		-1 Unknown Error

	*/



	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1 - Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1
	
	--2 - Duplicated insurance number of head
	IF EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3 - Wrong or missing permanent village code
	IF LEN(ISNULL(@PermanentVillageCode,'')) = 0
		RETURN 3

	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @PermanentVillageCode AND ValidityTo IS NULL AND LocationType ='V')
		RETURN 3

	--4 - Wrong current village code
	IF LEN(ISNULL(@CurrentVillageCode,'')) <> 0
	BEGIN
		IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL AND LocationType ='V')
		RETURN 4
	END

	--5 - Wrong or missing  gender
	IF LEN(ISNULL(@Gender,'')) = 0
		RETURN 5

	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender)
		RETURN 5
	
	--6 - Wrong format or missing birth date
	IF NULLIF(@BirthDate,'') IS NULL
		RETURN 6
	
	--7 - Missing last name
	IF LEN(ISNULL(@LastName,'')) = 0 
		RETURN 7
	
	--8 - Missing other name
	IF LEN(ISNULL(@OtherNames,'')) = 0 
		RETURN 8

	--9 - Wrong confirmation type
	IF NOT EXISTS(SELECT 1 FROM tblConfirmationTypes WHERE ConfirmationTypeCode = @ConfirmationType) AND LEN(ISNULL(@ConfirmationType,'')) > 0
		RETURN 9
	
	--10 - Wrong group type
	IF NOT EXISTS(SELECT  1 FROM tblFamilyTypes WHERE FamilyTypeCode = @GroupType) AND LEN(ISNULL(@GroupType,'')) > 0
		RETURN 10

	--11 - Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 11

	--12 - Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 12

	--13 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 13

	--14 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 14

	--15 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 15


	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION ENROLFAMILY
			
				DECLARE @FamilyID INT,
						@InsureeID INT,
			
						@ProfessionId INT,
						@LocationId INT,
						@CurrentLocationId INT=0,
						@EducationId INT,
						@HfID INT

						SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
						SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
						SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
						SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
						SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
						SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
						SELECT @CurrentLocationId = LocationId FROM tblLocations WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL
						SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @PermanentVillageCode AND ValidityTo IS NULL


					INSERT INTO dbo.tblFamilies
						   (InsureeID,LocationId,Poverty,ValidityFrom,AuditUserID,FamilyType,FamilyAddress,isOffline,ConfirmationType,ConfirmationNo )
					SELECT 0 InsureeID, @LocationId LocationId, @PovertyStatus Poverty, GETDATE() ValidityFrom, @AuditUserID AuditUserID, @GroupType FamilyType, @PermanentAddress FamilyAddress, 0 isOffline, @ConfirmationType ConfirmationType, @ConfirmationNo ConfirmationNo
					SET @FamilyID = SCOPE_IDENTITY()

	

				INSERT INTO dbo.tblInsuree
					(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Phone, CardIssued, passport,TypeOfId , ValidityFrom,AuditUserID,Profession,Education,Email,isOffline,HFID,CurrentAddress,CurrentVillage)
					SELECT @FamilyID FamilyID, @InsuranceNumber CHFID, @LastName LastName, @OtherNames OtherNames, @BirthDate BirthDate, @Gender Gender, @MaritalStatus Marital, 1 IsHead, @PhoneNumber Phone, isnull(@BeneficiaryCard,0) BeneficiaryCard, @IdentificationNumber PassPort, @IdentificationType  ,GETDATE() ValidityFrom,@AuditUserID AuditUserID, @ProfessionId Profession, @EducationId Education, @Email Email, 0 IsOffline, @HfID, @CurrentAddress CurrentAddress, @CurrentLocationId CurrentVillage
					SET @InsureeID = SCOPE_IDENTITY()


					INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
					SELECT InsureeID,CHFID,'','',0,GETDATE(),ValidityFrom,AuditUserID from tblInsuree WHERE InsureeID = @InsureeID; 
					UPDATE tblInsuree SET PhotoID = (SELECT IDENT_CURRENT('tblPhotos')), PhotoDate=GETDATE() WHERE InsureeID = @InsureeID ;

					UPDATE tblFamilies SET InsureeID = @InsureeID WHERE FamilyID = @FamilyID

			COMMIT TRANSACTION ENROLFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENROLFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH


END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIEnterMemberFamily]
(
	@AuditUserID INT = -3,
	@InsureeNumberOfHead NVARCHAR(12),
	@InsureeNumber NVARCHAR(12),
	@OtherNames NVARCHAR(100),
	@LastName NVARCHAR(100),
	@BirthDate DATE,
	@Gender NVARCHAR(1),
	@Relationship NVARCHAR(50) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = 0,
	@VillageCode NVARCHAR(8)= NULL,
	@CurrentAddress NVARCHAR(200) = '',
	@Proffesion NVARCHAR(50)= NULL,
	@Education NVARCHAR(50)= NULL,
	@PhoneNumber NVARCHAR(50) = '',
	@Email NVARCHAR(100)= '',
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = '',
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of head
		2-Insurance number of head not found
		3- Wrong format or missing insurance number of member
		4-Wrong or missing  gender
		5-Wrong format or missing birth date
		6-Missing last name
		7-Missing other name
		8- Insurance number of member duplicated
		9- Wrong current village code
		10-Wrong marital status
		11-Wrong education
		12-Wrong profession
		13-Wrong RelationShip
		14-FSP code not found 
		15 - wrong identification type 
		0 - Success (0 OK), 
		-1 -Unknown  Error 
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsureeNumberOfHead,'')) = 0
		RETURN 1

	--2-Insurance number of head not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumberOfHead AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong format or missing insurance number of member
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3
	--4-Wrong or missing  gender
	IF LEN(ISNULL(@Gender,'')) = 0
		RETURN 4

	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender)
		RETURN 4

	--5-Wrong format or missing birth date
	IF NULLIF(@BirthDate,'') IS NULL
		RETURN 5

	--6-Missing last name
	IF LEN(ISNULL(@LastName,'')) = 0 
			RETURN 6
	
	--7-Missing other name
	IF LEN(ISNULL(@OtherNames,'')) = 0 
		RETURN 7

	--8- Insurance number of member duplicated
	IF EXISTS(SELECT 1 FROM tblInsuree WHERE ValidityTo IS NULL AND CHFID = @InsureeNumber)
		RETURN 8

	--9- Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 9

	--10-Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 10

	--11-Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 11

	--12 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 12

	--13 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 13

	--14 - Wrong Relation
	IF NOT EXISTS(SELECT  1 FROM tblRelations WHERE Relation = @Relationship) AND LEN(ISNULL(@Relationship,'')) > 0
		RETURN 14



	--15 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 15
	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION ENROLMEMBERFAMILY
			
				DECLARE @FamilyID INT,
						@ProfessionId INT,
						@RelationId INT,
						@EducationId INT,
						@LocationId INT,
						@HfID INT,
						@InsureeId INT



				SET @FamilyID = (SELECT TOP 1 FamilyID FROM tblInsuree WHERE CHFID = @InsureeNumberOfHead AND ValidityTo IS NULL ORDER BY FamilyID DESC)
				SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
				SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
				SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
				SELECT @RelationId = RelationId FROM tblRelations WHERE Relation = @Relationship
				SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL


				INSERT INTO dbo.tblInsuree
					(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Phone, CardIssued, passport,TypeOfId , ValidityFrom,AuditUserID,Profession,Education, Relationship, Email,isOffline,HFID,CurrentAddress,CurrentVillage)
					SELECT @FamilyID FamilyID, @InsureeNumber CHFID, @LastName LastName, @OtherNames OtherNames, @BirthDate BirthDate, @Gender Gender, @MaritalStatus Marital, 0  IsHead, @PhoneNumber Phone, @BeneficiaryCard BeneficiaryCard, @IdentificationNumber PassPort, @IdentificationType , GETDATE() ValidityFrom,@AuditUserID AuditUserID, @ProfessionId Profession, @EducationId Education, @RelationId Relation, @Email Email, 0 IsOffline, @HfID, @CurrentAddress CurrentAddress, @LocationId CurrentVillage
							SET @InsureeId = SCOPE_IDENTITY()

							INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
					SELECT InsureeID,CHFID,'','',0,GETDATE(),ValidityFrom,AuditUserID from tblInsuree WHERE InsureeID = @InsureeID; 
					UPDATE tblInsuree SET PhotoID = (SELECT IDENT_CURRENT('tblPhotos')),PhotoDate=GETDATE() WHERE InsureeID = @InsureeID;

							EXEC uspAddInsureePolicy @InsureeId;
								
				

			COMMIT TRANSACTION ENROLMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENROLMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH

END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIEnterPolicy]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12),
	@EnrollmentDate DATE,
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
		4- Wrong or missing enrolment date
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
		AND PR.ValidityTo IS NULL AND PR.ProductCode =@ProductCode AND PR.DateTo >= GETDATE()
		AND I.CHFID = @InsuranceNumber AND I.ValidityTo IS NULL AND I.IsHead = 1)
		RETURN 3

	--4- Wrong or missing enrolment date
	IF NULLIF(@EnrollmentDate,'') IS NULL
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
			BEGIN TRANSACTION ENTERPOLICY
			
				DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
				DECLARE @FamilyId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@ProdId INT,
				@PolicyStage CHAR(1) = N'N',
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
				SELECT @ProdId = ProdID FROM tblProduct WHERE ProductCode = @ProductCode  AND ValidityTo IS NULL
				INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
				EXEC uspGetPolicyPeriod @ProdId, @EnrollmentDate, @HasCycle OUTPUT, @PolicyStage;
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollmentDate, 0, @ErrorCode OUTPUT;
				SELECT @StartDate = startDate FROM @tblPeriod
				SELECT @ExpiryDate = expiryDate FROM @tblPeriod
				SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @EnrollmentOfficerCode AND ValidityTo IS NULL

					INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
					SELECT	 @FamilyId,@EnrollmentDate,@StartDate,@EffectiveDate,@ExpiryDate,@Idle,@PolicyValue,@ProdId,@OfficerID,@PolicyStage,GETDATE(),@AuditUserId, 0 isOffline 
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

			COMMIT TRANSACTION ENTERPOLICY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENTERPOLICY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIGetCoverage]
(
	@InsureeNumber NVARCHAR(12),
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


	DECLARE @InsuranceNumber NVARCHAR(12)
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

	--DECLARE @LASTRESULT TABLE(PolicyValue DECIMAL(18,2) NULL,EffectiveDate DATE NULL, LastName NVARCHAR(100) NULL, OtherNames NVARCHAR(100) NULL,CHFID NVARCHAR(12), PhotoPath  NVARCHAR(100) NULL,  DOB DATE NULL ,Gender NVARCHAR(1) NULL,ProductCode NVARCHAR(8) NULL,ProductName NVARCHAR(50) NULL, ExpiryDate DATE NULL, [Status] NVARCHAR(1) NULL,DedType FLOAT NULL, Ded1 DECIMAL(18,2)NULL,  Ded2 DECIMAL(18,2)NULL, Ceiling1 DECIMAL(18,2)NULL, Ceiling2 DECIMAL(18,2)NULL)
  IF (SELECT COUNT(*) FROM #tempBase WHERE [Status] = 'A') > 0
 SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft,  r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft, PolicyValue, EffectiveDate, LastName, OtherNames,CHFID, PhotoPath,  DOB,Gender,ProductCode ,ProductName, ExpiryDate, [Status],DedType, Ded1,  Ded2, CASE WHEN Ceiling1 < 0 THEN 0 ELSE  Ceiling1 END Ceiling1 , CASE WHEN Ceiling2< 0 THEN 0 ELSE Ceiling2 END Ceiling2   from #tempBase T LEFT OUTER JOIN @Result R ON R.ProdId = T.ProdID WHERE [Status] = 'A';
		
	ELSE 
		IF (SELECT COUNT(1) FROM #tempBase WHERE (YEAR(GETDATE()) - YEAR(ExpiryDate)) <= 2) > 1
	  SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft,  r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft,  PolicyValue,EffectiveDate, LastName, OtherNames,CHFID, PhotoPath,  DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase T LEFT OUTER JOIN @Result R ON R.ProdId = T.ProdID WHERE (YEAR(GETDATE()) - YEAR(ExpiryDate)) <= 2;
		ELSE
	
			 SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft, r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft, PolicyValue,EffectiveDate, LastName, OtherNames, CHFID, PhotoPath,  DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase T LEFT OUTER JOIN @Result R  ON R.ProdId = T.ProdID
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAPIRenewPolicy]
(	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12),
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspBackupDatabase]
(
	@Path NVARCHAR(255)= '', 
	@Save BIT  = 0
)
AS
BEGIN
	
	DECLARE @DefaultPath NVARCHAR(255) = (select DatabaseBackupFolder from tblIMISDefaults)
	
	IF @Path = '' 
		SET @Path= @DefaultPath
	
	
	SET @Path += CASE WHEN RIGHT(LTRIM(RTRIM(@Path)), 1) <> '\\' THEN '\\' ELSE '' END;
		
	IF LOWER(@DefaultPath) <> LOWER(@Path) AND @Save = 1
	BEGIN
		UPDATE tblIMISDefaults SET DatabaseBackupFolder = @Path
	END
	
	DECLARE @DBName NVARCHAR(50) = DB_NAME();
	DECLARE @FileName NVARCHAR(255) = @Path + ''+ @DBName +'_BACKUP_' + CONVERT(NVARCHAR(50),GETDATE(),105) + '_' + CONVERT(NVARCHAR(2),DATEPART(HOUR,GETDATE())) + '-' + CONVERT(NVARCHAR(2),DATEPART(MINUTE,GETDATE())) + '.bak';
	
	DECLARE @SQL NVARCHAR(500) = 'BACKUP DATABASE ' + @DBName + ' TO DISK = ''' + @FileName + '''';

	EXEC (@SQL);


	
END
GO



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspClaimSelection]
(
	@ReviewType TINYINT,	--1: Review 2:Feedback
	@Claims dbo.xClaimSelection READONLY,
	@SelectionType TINYINT,		--0: All 1: Random 2: Variance
	@SelectionValue DECIMAL(18,2),
	@Value DECIMAL(18,2) = 0,
	@Submitted INT = 0 OUTPUT,
	@Selected INT = 0 OUTPUT,
	@NotSelected INT = 0 OUTPUT
)
AS
BEGIN
	DECLARE @tbl TABLE(ClaimID INT)
	
	IF @ReviewType = 1
	BEGIN
		INSERT INTO @tbl(ClaimID)
		SELECT udtClaims.ClaimID 
		FROM @Claims as udtClaims INNER JOIN tblClaim ON tblClaim.ClaimID = udtClaims.ClaimID
		AND tblClaim.ReviewStatus = 1
		
		UPDATE tblClaim SET ReviewStatus = 2
		FROM tblClaim INNER JOIN @tbl tbl ON tblClaim.ClaimID = tbl.ClaimID
		
	END
	ELSE
	BEGIn
		INSERT INTO @tbl(ClaimID)
		SELECT udtClaims.ClaimID 
		FROM @Claims as udtClaims INNER JOIN tblClaim ON tblClaim.ClaimID = udtClaims.ClaimID
		AND tblClaim.FeedbackStatus = 1
		
		UPDATE tblClaim SET FeedbackStatus = 2
		FROM tblClaim INNER JOIN @tbl tbl ON tblClaim.ClaimID = tbl.ClaimID
		
	END
	
	IF @SelectionType = 0
		BEGIN
			IF @ReviewType = 1
			BEGIN
				UPDATE tblClaim SET ReviewStatus = 4
				FROM tblClaim INNER JOIN @tbl t ON tblClaim.ClaimID = t.ClaimID
				WHERE tblClaim.ValidityTo IS NULL AND ISNULL(tblClaim.Claimed,0) >= @Value
				
				SELECT @Selected = @@ROWCOUNT
			END
			ELSE
			BEGIN
				UPDATE tblClaim SET FeedbackStatus = 4
				FROM tblClaim INNER JOIN @tbl t ON tblClaim.ClaimID = t.ClaimID
				WHERE tblClaim.ValidityTo IS NULL AND ISNULL(tblClaim.Claimed,0) >= @Value
				
				SELECT @Selected = @@ROWCOUNT
			END	
		END
		
	IF @SelectionType = 1
		BEGIN
			IF @ReviewType = 1
			BEGIN
				UPDATE tblClaim SET ReviewStatus = 4
				WHERE ClaimID IN 
				(SELECT TOP (@SelectionValue) PERCENT tblClaim.ClaimID 
					FROM tblClaim INNER JOIN @Claims udtClaims ON tblClaim.ClaimID = udtClaims.ClaimID
					WHERE tblClaim.ValidityTo IS NULL
					ORDER BY NEWID())
					
				SELECT @Selected = @@ROWCOUNT
			END
			ELSE
			BEGIN
				UPDATE tblClaim SET FeedbackStatus = 4
				WHERE ClaimID IN 
				(SELECT TOP (@SelectionValue) PERCENT tblClaim.ClaimID 
					FROM tblClaim INNER JOIN @Claims udtClaims ON tblClaim.ClaimID = udtClaims.ClaimID
					WHERE tblClaim.ValidityTo IS NULL
					ORDER BY NEWID())
					
				SELECT @Selected = @@ROWCOUNT
			END
		END
	IF @SelectionType = 2
		BEGIN
			
			DECLARE @tmp TABLE(ClaimID INT, ICDID INT,Claimed DECIMAL(18,2), Average DECIMAL(18,2),	Variance DECIMAL(18,2),isExceeds AS CASE WHEN Claimed >= Variance THEN 1 ELSE 0 END)

			INSERT INTO @tmp(ClaimID,ICDID,Claimed)
			SELECT t.ClaimID,C.ICDID,C.Claimed
			FROM @tbl t INNER JOIN tblClaim C ON t.ClaimID = C.ClaimID
			WHERE C.ValidityTo IS NULL 
			AND ISNULL(C.Claimed,0) >= @Value 
		
			UPDATE @tmp SET Average = a.Average, Variance= a.Average + (a.Average * (0.01 * 
			@SelectionValue))
			FROM @tmp t INNER JOIN 
			(SELECT tmp.ICDID,AVG(tblClaim.Claimed) Average
			from tblClaim INNER JOIN @tmp tmp ON tblClaim.ICDID = tmp.ICDID
			WHERE tblClaim.ValidityTo IS NULL AND tblClaim.ClaimStatus IN (8,16)
			AND DateClaimed between DATEADD(Year,-1,GetDATE()-1) AND GETDATE() - 1
			GROUP BY tmp.ICDID)a ON t.ICDID = a.ICDID
		
			IF @ReviewType = 1
			BEGIN
				UPDATE tblClaim SET ReviewStatus = 4
				WHERE ClaimID IN 
				(SELECT ClaimID FROM @tmp WHERE isExceeds = 1)
				
				SELECT @Selected = @@ROWCOUNT
			END
			ELSE
			BEGIN
				UPDATE tblClaim SET FeedbackStatus = 4
				WHERE ClaimID IN 
				(SELECT ClaimID FROM @tmp WHERE isExceeds = 1)
				
				SELECT @Selected = @@ROWCOUNT
			END
		END
	
	
	SELECT @Submitted = COUNT(*) FROM @tbl
	SET @NotSelected = @Submitted - @Selected 
	
	
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[UspS_ReseedTable]
	(
		@Table nvarchar(64) = '' 	)

AS
	SET NOCOUNT ON
	declare @ReseedYes as Integer
	
	IF LEN(LTRIM(RTRIM(@Table))) > 0 
	BEGIN
		set @ReseedYes = OBJECTPROPERTY ( object_id (@Table) ,'TableHasIdentity')  
		IF @ReseedYes  = 1  
			DBCC CHECKIDENT(@Table,RESEED,0)
	END
	ELSE
	BEGIN
		EXEC sp_MSforeachtable '(IF OBJECTPROPERTY(OBJECT_ID(''?''),''TableHasIdentity'') = 1 DBCC CHECKIDENT (''?'',RESEED,1))'
	END
RETURN

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspCleanTables]
	@OffLine as int = 0		--0: For Online, 1: HF Offline, 2: CHF Offline
AS
BEGIN
	
	DECLARE @LocationId INT
	DECLARE @ParentLocationId INT

	--SELECT @ParentLocationId = ParentLocationId, @LocationId =LocationId  FROM tblLocations WHERE LocationName='Dummy' AND ValidityTo IS NULL AND LocationType = N'D'
	 
	--Phase 2
	DELETE FROM tblFeedbackPrompt;
	EXEC [UspS_ReseedTable] 'tblFeedbackPrompt';
	DELETE FROM tblReporting;
	EXEC [UspS_ReseedTable] 'tblReporting';
	DELETE FROM tblSubmittedPhotos;
	EXEC [UspS_ReseedTable] 'tblSubmittedPhotos';
	DELETE FROM dbo.tblFeedback;
	EXEC [UspS_ReseedTable] 'tblFeedback';
	DELETE FROM dbo.tblClaimServices;
	EXEC [UspS_ReseedTable] 'tblClaimServices';
	DELETE FROM dbo.tblClaimItems ;
	EXEC [UspS_ReseedTable] 'tblClaimItems';
	DELETE FROM dbo.tblClaimDedRem;
	EXEC [UspS_ReseedTable] 'tblClaimDedRem';
	DELETE FROM dbo.tblClaim;
	EXEC [UspS_ReseedTable] 'tblClaim';
	DELETE FROM dbo.tblClaimAdmin
	EXEC [USPS_ReseedTable] 'tblClaimAdmin'
	DELETE FROM dbo.tblICDCodes;
	EXEC [UspS_ReseedTable] 'tblICDCodes'
	
	
	DELETE FROM dbo.tblRelDistr;
	EXEC [UspS_ReseedTable] 'tblRelDistr';
	DELETE FROM dbo.tblRelIndex ;
	EXEC [UspS_ReseedTable] 'tblRelIndex';
	DELETE FROM dbo.tblBatchRun;
	EXEC [UspS_ReseedTable] 'tblBatchRun';
	DELETE FROM dbo.tblExtracts;
	EXEC [UspS_ReseedTable] 'tblExtracts';
	TRUNCATE TABLE tblPremium;
	
	--Phase 1
	EXEC [UspS_ReseedTable] 'tblPremium';
	DELETE FROM tblPayer;
	EXEC [UspS_ReseedTable] 'tblPayer';

	DELETE FROM dbo.tblPolicyRenewalDetails;
	EXEC [UspS_ReseedTable] 'tblPolicyRenewalDetails';
	DELETE FROM dbo.tblPolicyRenewals;
	EXEC [UspS_ReseedTable] 'tblPolicyRenewals';


	DELETE FROM tblInsureePolicy;
	EXEC [UspS_ReseedTable] 'tblInsureePolicy';
	DELETE FROM tblPolicy;
	EXEC [UspS_ReseedTable] 'tblPolicy';
	DELETE FROM tblProductItems;
	EXEC [UspS_ReseedTable] 'tblProductItems';
	DELETE FROM tblProductServices;
	EXEC [UspS_ReseedTable] 'tblProductServices';

	DELETE FROM dbo.tblRelDistr;
	EXEC [UspS_ReseedTable] 'tblRelDistr';


	DELETE FROM tblProduct;
	EXEC [UspS_ReseedTable] 'tblProduct';
	UPDATE tblInsuree set PhotoID = NULL ;
	DELETE FROM tblPhotos;
	EXEC [UspS_ReseedTable] 'tblPhotos';
	DELETE FROM tblInsuree;
	EXEC [UspS_ReseedTable] 'tblInsuree';
	DELETE FROM tblGender;
	DELETE FROM tblFamilies;
	EXEC [UspS_ReseedTable] 'tblFamilies';
	DELETE FROM tblOfficerVillages;
	EXEC [UspS_ReseedTable] 'tblOfficerVillages';
	DELETE FROM dbo.tblOfficer;
	EXEC [UspS_ReseedTable] 'tblOfficer';
	DELETE FROM dbo.tblHFCatchment;
	EXEC [UspS_ReseedTable] 'tblHFCatchment';
	DELETE FROM dbo.tblHF;
	EXEC [UspS_ReseedTable] 'tblHF';
	DELETe FROM dbo.tblPLItemsDetail;
	EXEC [UspS_ReseedTable] 'tblPLItemsDetail';
	DELETE FROM dbo.tblPLItems;
	EXEC [UspS_ReseedTable] 'tblPLItems';
	DELETE FROM dbo.tblItems;
	EXEC [UspS_ReseedTable] 'tblItems';
	DELETE FROM dbo.tblPLServicesDetail;
	EXEC [UspS_ReseedTable] 'tblPLServicesDetail';
	DELETE FROM dbo.tblPLServices;
	EXEC [UspS_ReseedTable] 'tblPLServices';
	DELETE FROM dbo.tblServices;
	EXEC [UspS_ReseedTable] 'tblServices';
	DELETE FROM dbo.tblUsersDistricts;
	EXEC [UspS_ReseedTable] 'tblUsersDistricts';


	DELETE FROM tblLocations;
	EXEC [UspS_ReseedTable] 'tblLocations';
	DELETE FROM dbo.tblLogins ;
	EXEC [UspS_ReseedTable] 'tblLogins';

	DELETE FROM dbo.tblUsers;
	EXEC [UspS_ReseedTable] 'tblUsers';

	TRUNCATE TABLE tblFromPhone;
	EXEC [UspS_ReseedTable] 'tblFromPhone';

	TRUNCATE TABLE tblEmailSettings;

	DBCC SHRINKDATABASE (0);
	
	--Drop the encryption set
	IF EXISTS(SELECT * FROM sys.symmetric_keys WHERE name = N'EncryptionKey')
	DROP SYMMETRIC KEY EncryptionKey;
		
	IF EXISTS(SELECT * FROM sys.certificates WHERE name = N'EncryptData')
	DROP CERTIFICATE EncryptData;
	
	IF EXISTS(SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
	DROP MASTER KEY;
	
	--insert new user Admin-Admin
	IF @OffLine = 2  --CHF offline
	BEGIN
		
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[RoleID],[LanguageID],[HFID],[AuditUserID],StoredPassword,PrivateKey)
        VALUES('Admin', 'Admin', '', 'Admin', 1048576,'en',0,0
		--storedPassword
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST('Admin' AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2))),2)
		 -- PrivateKey
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2)
		)
       
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0, FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0, DatabaseBackupFolder = ''
        
	END
	
	
	IF @OffLine = 1 --HF offline
	BEGIN
		
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[RoleID],[LanguageID],[HFID],[AuditUserID],StoredPassword,PrivateKey)
        VALUES('Admin', 'Admin', '', 'Admin', 524288,'en',0,0
		--storedPassword
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST('Admin' AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2))),2)
		 -- PrivateKey
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2)
		)
        
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0,FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0, DatabaseBackupFolder = ''
        
	END
	IF @OffLine = 0 --ONLINE CREATION NEW COUNTRY NO DEFAULTS KEPT
	BEGIN
		
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[RoleID],[LanguageID],[HFID],[AuditUserID],StoredPassword,PrivateKey)
        VALUES('Admin', 'Admin', '', 'Admin',  1023,'en',0,0
		--storedPassword
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST('Admin' AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2))),2)
		 -- PrivateKey
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2)
		)
		
       	UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0,FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0,				DatabaseBackupFolder = ''
    END
	
	IF @OffLine = -1 --ONLINE CREATION WITH DEFAULTS KEPT AS PREVIOUS CONTENTS
	BEGIN
		
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[RoleID],[LanguageID],[HFID],[AuditUserID],StoredPassword,PrivateKey)
        VALUES('Admin', 'Admin', '', 'Admin', 1023,'en',0,0
		--storedPassword
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST('Admin' AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2))),2)
		 -- PrivateKey
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST('Admin' AS VARCHAR(MAX))),2)
		)
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0
    END


	SET IDENTITY_INSERT tblLocations ON
	INSERT INTO tblLocations(LocationId, LocationCode, Locationname, LocationType, AuditUserId, ParentLocationId) VALUES
	(1, N'R0001', N'Region', N'R', -1, NULL),
	(2, N'D0001', N'Dummy', N'D', -1, 1)
	SET IDENTITY_INSERT tblLocations OFF
		
	INSERT INTO tblUsersDistricts ([UserID],[LocationId],[AuditUserID]) VALUES (1,2,-1)
END

GO

CREATE OR ALTER PROCEDURE [dbo].[uspCreateCHFID]
(
	@HowMany INT
)
AS
BEGIN
	CREATE TABLE #tbl(Number NVARCHAR(12))

	DECLARE @CHFID VARCHAR(12)
	DECLARE @lower INT = 1
	DECLARE @upper INT = 10000000
	DECLARE @Number DECIMAL(18,0)
	DECLARE @Count INT = 0
	
	IF @HowMany > @upper 
		SET @upper = @HowMany

	WHILE @Count < @HowMany
		BEGIN
		NEXT_NUMBER:
			SET @Number = ROUND((@upper - @lower) * RAND() + @lower,0)
			IF NOT EXISTS(SELECT Number From #tbl WHERE Number = @Number)
				INSERT INTO #tbl values(@Number)
			ELSE
				GOTO NEXT_NUMBER
			SET @Count = @Count + 1
		END

	UPDATE #tbl SET [Number] = RIGHT('000000000' + CAST([Number] AS VARCHAR(8)) + CAST([Number] % 7 AS CHAR(1)),9)

	SELECT DISTINCT * FROM #tbl
	DROP TABLE #tbl
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspCreateCHFIDHANS]
(
	@HowMany INT
)
AS
BEGIN
	CREATE TABLE #tbl(Number NVARCHAR(9))

	DECLARE @CHFID VARCHAR(9)
	DECLARE @CHFIDNEW VARCHAR(9)
	DECLARE @lower INT = 1
	DECLARE @upper INT = 1000000
	DECLARE @Number DECIMAL(18,0)
	DECLARE @Count INT = 0
	
	IF @HowMany > @upper 
		SET @upper = @HowMany

	WHILE @Count < @HowMany
		BEGIN
		NEXT_NUMBER:
			SET @Number = ROUND((@upper - @lower) * RAND() + @lower,0)
			IF NOT EXISTS(SELECT Number From #tbl WHERE Number = @Number)
				INSERT INTO #tbl values(@Number)
			ELSE
				GOTO NEXT_NUMBER
			SET @Count = @Count + 1
		END

	UPDATE #tbl SET [Number] = RIGHT('000000000' + CAST([Number] AS VARCHAR(8)) + CAST([Number] % 7 AS CHAR(1)),9)

	SELECT DISTINCT * FROM #tbl
	
	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR SELECT CHFID FROM tblInsuree WHERE ValidityTo IS NULL FOR UPDATE 
	OPEN LOOP1
	DECLARE LOOP2 CURSOR LOCAL FORWARD_ONLY FOR SELECT Number FROM #tbl
	OPEN LOOP2
	FETCH NEXT FROM LOOP2 INTO @CHFIDNEW
	FETCH NEXT FROM LOOP1 INTO @CHFID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		UPDATE dbo.tblInsuree SET CHFID = @CHFIDNEW where current of LOOP1
		
		FETCH NEXT FROM LOOP2 INTO @CHFIDNEW	
		FETCH NEXT FROM LOOP1 INTO @CHFID
		
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1
	CLOSE LOOP2
	DEALLOCATE LOOP2
	
	
	
	DROP TABLE #tbl
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspCreateClaimXML]
(
	@ClaimID INT
)
AS
BEGIN
	SELECT
	(SELECT CONVERT(VARCHAR(10),C.DateClaimed,103) ClaimDate, HF.HFCode HFCode,C.ClaimCode, I.CHFID, 
	CONVERT(VARCHAR(10),C.DateFrom,103) StartDate, CONVERT(VARCHAR(10),ISNULL(C.DateTo,C.DateFrom),103) EndDate,ICD.ICDCode, 
	C.Explanation Comment, ISNULL(C.Claimed,0) Total,CA.ClaimAdminCode ClaimAdmin,
	ICD1.ICDCode ICDCode1,ICD2.ICDCode ICDCode2,ICD3.ICDCode ICDCode3 ,ICD4.ICDCode ICDCode4 ,C.VisitType
	from tblClaim C INNER JOIN tblHF HF ON C.HFID = HF.HfID
	INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID
	INNER JOIN tblICDCodes ICD ON C.ICDID = ICD.ICDID
	LEFT OUTER JOIN tblIcdCodes ICD1 ON C.ICDID1 = ICD1.ICDID
	LEFT OUTER JOIN tblIcdCodes ICD2 ON C.ICDID2 = ICD2.ICDID
	LEFT OUTER JOIN tblIcdCodes ICD3 ON C.ICDID3 = ICD3.ICDID
	LEFT OUTER JOIN tblIcdCodes ICD4 ON C.ICDID4 = ICD4.ICDID
	LEFT OUTER JOIN tblClaimAdmin CA ON CA.ClaimAdminId = C.ClaimAdminId
	WHERE C.ClaimID = @ClaimID
	FOR XML PATH('Details'),TYPE),
	(SELECT I.ItemCode,CI.PriceAsked ItemPrice, CI.QtyProvided ItemQuantity
	FROM tblClaim C INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
	INNER JOIN tblItems I ON CI.ItemID = I.ItemID
	WHERE C.ClaimID = @ClaimID
	FOR XML PATH('Item'),ROOT ('Items'), TYPE),
	(SELECT S.ServCode ServiceCode,CS.PriceAsked ServicePrice, CS.QtyProvided ServiceQuantity
	FROM tblClaim C INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
	INNER JOIN tblServices S ON CS.ServiceID = S.ServiceID
	WHERE C.ClaimID = @ClaimID
	FOR XML PATH('Service'),ROOT ('Services'), TYPE)
	FOR XML PATH(''), ROOT('Claim')
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspCreateEnrolmentXML]
(
	@FamilyExported INT = 0 OUTPUT,
	@InsureeExported INT = 0 OUTPUT,
	@PolicyExported INT = 0 OUTPUT,
	@PremiumExported INT = 0 OUTPUT
)
AS
BEGIN
	SELECT
	(SELECT * FROM (SELECT F.FamilyId,F.InsureeId, I.CHFID , F.LocationId, F.Poverty FROM tblInsuree I 
	INNER JOIN tblFamilies F ON F.FamilyID=I.FamilyID
	WHERE F.FamilyID IN (SELECT FamilyID FROM tblInsuree WHERE isOffline=1 AND ValidityTo IS NULL GROUP BY FamilyID) 
	AND I.IsHead=1 AND F.ValidityTo IS NULL
	UNION
SELECT F.FamilyId,F.InsureeId, I.CHFID , F.LocationId, F.Poverty
	FROM tblFamilies F 
	LEFT OUTER JOIN tblInsuree I ON F.insureeID = I.InsureeID AND I.ValidityTo IS NULL
	LEFT OUTER JOIN tblPolicy PL ON F.FamilyId = PL.FamilyID AND PL.ValidityTo IS NULL
	LEFT OUTER JOIN tblPremium PR ON PR.PolicyID = PL.PolicyID AND PR.ValidityTo IS NULL
	WHERE F.ValidityTo IS NULL 
	AND (F.isOffline = 1 OR I.isOffline = 1 OR PL.isOffline = 1 OR PR.isOffline = 1)	
	GROUP BY F.FamilyId,F.InsureeId,F.LocationId,F.Poverty,I.CHFID) aaa	
	FOR XML PATH('Family'),ROOT('Families'),TYPE),
	
	(SELECT * FROM (
	SELECT I.InsureeID,I.FamilyID,I.CHFID,I.LastName,I.OtherNames,I.DOB,I.Gender,I.Marital,I.IsHead,I.passport,I.Phone,I.CardIssued,NULL EffectiveDate, I.Vulnerability
	FROM tblInsuree I
	LEFT OUTER JOIN tblInsureePolicy IP ON IP.InsureeId=I.InsureeID
	WHERE I.ValidityTo IS NULL AND I.isOffline = 1
	AND IP.ValidityTo IS NULL 
	GROUP BY I.InsureeID,I.FamilyID,I.CHFID,I.LastName,I.OtherNames,I.DOB,I.Gender,I.Marital,I.IsHead,I.passport,I.Phone,I.CardIssued, I.Vulnerability
	)xx
	FOR XML PATH('Insuree'),ROOT('Insurees'),TYPE),

	(SELECT P.PolicyID,P.FamilyID,P.EnrollDate,P.StartDate,P.EffectiveDate,P.ExpiryDate,P.PolicyStatus,P.PolicyValue,P.ProdID,P.OfficerID, P.PolicyStage
	FROM tblPolicy P 
	LEFT OUTER JOIN tblPremium PR ON P.PolicyID = PR.PolicyID
	INNER JOIN tblFamilies F ON P.FamilyId = F.FamilyID
	WHERE P.ValidityTo IS NULL 
	AND PR.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND (P.isOffline = 1 OR PR.isOffline = 1)
	FOR XML PATH('Policy'),ROOT('Policies'),TYPE),
	(SELECT Pr.PremiumId,Pr.PolicyID,Pr.PayerID,Pr.Amount,Pr.Receipt,Pr.PayDate,Pr.PayType
	FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyID
	WHERE Pr.ValidityTo IS NULL 
	AND PL.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND Pr.isOffline = 1
	FOR XML PATH('Premium'),ROOT('Premiums'),TYPE)
	FOR XML PATH(''), ROOT('Enrolment')
	
	
	SELECT @FamilyExported = ISNULL(COUNT(*),0)	FROM tblFamilies F 	WHERE ValidityTo IS NULL AND isOffline = 1
	SELECT @InsureeExported = ISNULL(COUNT(*),0) FROM tblInsuree I WHERE I.ValidityTo IS NULL AND I.isOffline = 1
	SELECT @PolicyExported = ISNULL(COUNT(*),0)	FROM tblPolicy P WHERE ValidityTo IS NULL AND isOffline = 1
	SELECT @PremiumExported = ISNULL(COUNT(*),0)	FROM tblPremium Pr WHERE ValidityTo IS NULL AND isOffline = 1
END
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 CREATE OR ALTER PROCEDURE [dbo].[uspDeleteFromPhone]
 (
		@Id INT,
		@AuditUserId INT,
		@DeleteInfo CHAR(2),
		@ErrorMessage NVARCHAR(300) = OUTPUT
	)
AS 
BEGIN
	BEGIN TRY
		IF @DeleteInfo = 'F'
			BEGIN
				--Delete Family
			
				IF EXISTS(SELECT * FROM tblPolicy WHERE FamilyID =@Id AND ValidityTo IS NULL) RETURN 3
				INSERT INTO tblFamilies ([insureeid],LocationId, [Poverty], [ConfirmationType],isOffline,[ValidityFrom],[ValidityTo], [LegacyID],[AuditUserID],[Ethnicity], [ConfirmationNo])
				SELECT [insureeid],LocationId,[Poverty], [ConfirmationType],isOffline,[ValidityFrom],GETDATE(), @Id, [AuditUserID],Ethnicity, [ConfirmationNo] 
				FROM tblFamilies 
				WHERE FamilyID = @Id 
					  AND ValidityTo IS NULL; 
				UPDATE [tblFamilies] set [ValidityFrom]=GETDATE(),[ValidityTo]=GETDATE(),[AuditUserID] = @AuditUserID 
				WHERE FamilyID = @Id AND ValidityTo IS NULL;

				--Delete Insuree
				INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],
				[ValidityFrom] ,[ValidityTo],legacyId,TypeOfId, HFID, CurrentAddress, CurrentVillage,GeoLocation )  
				SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,GETDATE(),@Id ,TypeOfId, HFID, CurrentAddress, CurrentVillage, GeoLocation 
				FROM tblInsuree 
				WHERE FamilyID = @Id  
				AND ValidityTo IS NULL; 
				UPDATE [tblInsuree] SET [ValidityFrom] = GETDATE(),[ValidityTo] = GETDATE(),[AuditUserID] = @AuditUserID  
				WHERE FamilyID = @Id  
				AND ValidityTo IS NULL;

				--Delete Policy
				 INSERT INTO tblPolicy (FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStatus,PolicyValue,isOffline, ValidityTo, LegacyID, AuditUserID) 
				 SELECT FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStatus,PolicyValue,isOffline, GETDATE(), @Id, AuditUserID 
				 FROM tblPolicy WHERE FamilyID = @Id AND ValidityTo IS NULL; 
				 UPDATE tblPolicy set ValidityFrom = GETDATE(), ValidityTo = GETDATE(), AuditUserID = @AuditUserID WHERE FamilyID = @Id AND ValidityTo IS NULL
			
				--Delete Premium
				INSERT INTO tblPremium (PolicyID, PayerID, Amount, Receipt, PayDate, PayType,isOffline, ValidityTo, LegacyID, AuditUserID,isPhotoFee) 
				SELECT P.PolicyID, PayerID, Amount, Receipt, PayDate, PayType,P.isOffline, GETDATE(), @Id,P.AuditUserID,isPhotoFee 
				FROM tblPremium P
				INNER JOIN tblPolicy Po ON P.PolicyID =Po.PolicyID
				WHERE FamilyId = @Id 
				AND P.ValidityTo IS NULL
				AND Po.ValidityTo IS NULL; 

				UPDATE  PR SET [ValidityFrom] = GETDATE(),[ValidityTo] = GETDATE(),[AuditUserID] = @AuditUserID FROM tblPremium PR
				INNER JOIN tblPolicy Po ON PR.PolicyID =Po.PolicyID
				WHERE FamilyID = @Id 
				AND PR.ValidityTo IS NULL
				AND Po.ValidityTo IS NULL
			END
		ELSE IF @DeleteInfo ='I'
			BEGIN
				IF EXISTS(SELECT 1 FROM tblInsuree WHERE InsureeID =@Id AND IsHead = 1) RETURN 2
				INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],
				[ValidityFrom] ,[ValidityTo],legacyId,TypeOfId, HFID, CurrentAddress, CurrentVillage,GeoLocation )  
				SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,GETDATE(),@Id ,TypeOfId, HFID, CurrentAddress, CurrentVillage, GeoLocation 
				FROM tblInsuree 
				WHERE InsureeID = @Id  
				AND ValidityTo IS NULL; 
				UPDATE [tblInsuree] SET [ValidityFrom] = GETDATE(),[ValidityTo] = GETDATE(),[AuditUserID] = @AuditUserID  
				WHERE InsureeID = @Id  
				AND ValidityTo IS NULL;
			END
		ELSE IF @DeleteInfo ='PO'
			BEGIN
				 INSERT INTO tblPolicy (FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStatus,PolicyValue,isOffline, ValidityTo, LegacyID, AuditUserID) 
				 SELECT FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStatus,PolicyValue,isOffline, GETDATE(), @Id, AuditUserID 
				 FROM tblPolicy WHERE PolicyID = @Id AND ValidityTo IS NULL; 
				 UPDATE tblPolicy set ValidityFrom = GETDATE(), ValidityTo = GETDATE(), AuditUserID = @AuditUserID WHERE PolicyID = @Id AND ValidityTo IS NULL

				INSERT INTO tblPremium (PolicyID, PayerID, Amount, Receipt, PayDate, PayType,isOffline, ValidityTo, LegacyID, AuditUserID,isPhotoFee) 
				SELECT P.PolicyID, PayerID, Amount, Receipt, PayDate, PayType,P.isOffline, GETDATE(), @Id,P.AuditUserID,isPhotoFee 
				FROM tblPremium P
				WHERE PolicyID = @Id 
				AND P.ValidityTo IS NULL;

				UPDATE  PR SET [ValidityFrom] = GETDATE(),[ValidityTo] = GETDATE(),[AuditUserID] = @AuditUserID FROM tblPremium PR
				WHERE PolicyID=@Id 
				AND PR.ValidityTo IS NULL; 
			END
		ELSE IF @DeleteInfo ='PR'
			BEGIN
				INSERT INTO tblPremium (PolicyID, PayerID, Amount, Receipt, PayDate, PayType,isOffline, ValidityTo, LegacyID, AuditUserID,isPhotoFee) 
				SELECT P.PolicyID, PayerID, Amount, Receipt, PayDate, PayType,P.isOffline, GETDATE(), @Id,P.AuditUserID,isPhotoFee 
				FROM tblPremium P
				WHERE PremiumId = @Id 
				AND P.ValidityTo IS NULL; 

				UPDATE  PR SET [ValidityFrom] = GETDATE(),[ValidityTo] = GETDATE(),[AuditUserID] = @AuditUserID FROM tblPremium PR
				WHERE PremiumID=@Id 
				AND PR.ValidityTo IS NULL;
			 
			END
	RETURN 1
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE();
		RETURN 0
	END CATCH
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract1]
	
	@RowID as bigint = 0
AS
BEGIN
	SET NOCOUNT ON

	SELECT LocationId, LocationCode, LocationName, ParentLocationId, LocationType, ValidityFrom, ValidityTo, LegacyId, AuditUserId 
	FROM tblLocations
	WHERE RowID > @RowID;

	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract2]
	
	@LocationId as int,
	@RowID as bigint = 0
	
AS
BEGIN
	SET NOCOUNT ON
	
	--**S Items**
	SELECT [ItemID],[ItemCode],[ItemName],[ItemType],[ItemPackage],[ItemPrice],[ItemCareType],[ItemFrequency],[ItemPatCat],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID] FROM [dbo].[tblItems] WHERE RowID > @RowID
	
	--**S Services**
	SELECT [ServiceID],[ServCode],[ServName],[ServType],[ServLevel],[ServPrice],[ServCareType],[ServFrequency],[ServPatCat],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],ServCategory FROM [dbo].[tblServices] WHERE RowID > @RowID
	
	--**S PLItems**
	SELECT [PLItemID],[PLItemName],[DatePL],[LocationId],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID] FROM [dbo].[tblPLItems] WHERE RowID > @RowID --AND (( (CASE @DistrictID  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @DistrictID) OR (DistrictID IS NULL))
	
	--**S PLItemsDetails**
	SELECT [PLItemDetailID],[dbo].[tblPLItemsDetail].[PLItemID],[ItemID],[PriceOverule],[dbo].[tblPLItemsDetail].[ValidityFrom],[dbo].[tblPLItemsDetail].[ValidityTo],[dbo].[tblPLItemsDetail].[LegacyID],[dbo].[tblPLItemsDetail].[AuditUserID] FROM [dbo].[tblPLItemsDetail] INNER JOIN [dbo].[tblPLItems] ON [dbo].[tblPLItems].PLItemID = [dbo].[tblPLItemsDetail].PLItemID WHERE [dbo].[tblPLItemsDetail].RowID > @RowID --AND (( (CASE @DistrictID  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @DistrictID) OR (DistrictID IS NULL))
		
	--**S PLServices**
	SELECT [PLServiceID],[PLServName],[DatePL],[LocationId],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID] FROM [dbo].[tblPLServices] WHERE RowID > @RowID --AND (( (CASE @DistrictID  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @DistrictID) OR (DistrictID IS NULL))
	
	--**S PLServicesDetails**
	SELECT [PLServiceDetailID],[dbo].[tblPLServicesDetail].[PLServiceID],[ServiceID],[PriceOverule],[dbo].[tblPLServicesDetail].[ValidityFrom],[dbo].[tblPLServicesDetail].[ValidityTo],[dbo].[tblPLServicesDetail].[LegacyID],[dbo].[tblPLServicesDetail].[AuditUserID] FROM [dbo].[tblPLServicesDetail] INNER JOIN [dbo].[tblPLServices] ON [dbo].[tblPLServicesDetail].PLServiceID = [dbo].[tblPLServices].PLServiceID  WHERE [dbo].[tblPLServicesDetail].RowID > @RowID --AND (( (CASE @DistrictID  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @DistrictID) OR (DistrictID IS NULL))
				
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract3]
	 @RegionId INT = 0,
	 @DistrictId INT = 0,
	 @RowID as bigint = 0,
	 @isFullExtract bit=0
	
AS
BEGIN
	SET NOCOUNT ON
	
	--**tblICDCodes**
	SELECT [ICDID],[ICDCode],[ICDName],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID] FROM [dbo].[tblICDCodes] WHERE RowID > @RowID 
	
	--**HF**
	SELECT [HfID],[HFCode],[HFName],[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[PLServiceID],[PLItemID],[AccCode],[OffLine],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID] FROM [dbo].[tblHF] WHERE RowID > @RowID --AND (CASE @LocationId  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @LocationId
	
	
	;WITH Family AS (
	SELECT F.[FamilyID]
	FROM [dbo].[tblFamilies] F 
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE F.RowID > @RowID 
	
	AND (@RegionId =0 or (
	((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId) AND
	((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId)
	))
	UNION 
	SELECT F.[FamilyID]
	FROM tblFamilies F 
	INNER JOIN tblInsuree I ON F.FamilyId = I.FamilyID
	INNER JOIN tblHF HF ON I.HFId = HF.HfID
	WHERE F.RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId 
	)
	SELECT * INTO #FamiliesWProd From Family



	--**tblPayer**
	; WITH Payers As(
	SELECT [PayerID],[PayerType],[PayerName],[PayerAddress],P.[LocationId],[Phone],[Fax],[eMail],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID] FROM [dbo].[tblPayer]  p
	LEFT JOIN uvwLocations L ON L.LocationId = p.LocationId
	WHERE RowID > @RowID  
		  AND ( L.RegionId = @RegionId OR @RegionId =0 OR P.LocationId IS NULL )  
		  AND (L.DistrictId =@DistrictId OR L.DistrictId IS NULL OR @DistrictId =0 )
	UNION ALL
	SELECT Pay.[PayerID],[PayerType],[PayerName],[PayerAddress],Pay.[LocationId],[Phone],[Fax],[eMail],Pay.[ValidityFrom], Pay.[ValidityTo], Pay.[LegacyID], Pay.[AuditUserID] 
	FROM [dbo].[tblPayer] Pay
	INNER JOIN tblPremium PR ON PR.PayerID = Pay.PayerID OR  PR.PayerID = Pay.LegacyID
	INNER JOIN tblPolicy PL ON PL.PolicyId = PR.PolicyId
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyID
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictId
	WHERE  Pay.RowID > @RowID 
		AND (((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictId]  END) = @DistrictId) OR D.Region = @RegionId) 
	
	)
	SELECT * FROM Payers Pay
	GROUP BY Pay.[PayerID],[PayerType],[PayerName],[PayerAddress],Pay.[LocationId],[Phone],[Fax],[eMail],Pay.[ValidityFrom], Pay.[ValidityTo], Pay.[LegacyID], Pay.[AuditUserID]
	

	--**tblOfficer**
	--SELECT [OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],[DistrictID],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],EmailId FROM [dbo].[tblOfficer]  WHERE RowID > @RowID AND (CASE @LocationId  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @LocationId
	; WITH Officer AS (
	SELECT [OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],EmailId, PhoneCommunication,PermanentAddress FROM [dbo].[tblOfficer] 
	WHERE RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE [LocationId]  END) = @DistrictId
	UNION ALL
	 SELECT O.[OfficerID],[Code],O.[LastName],O.[OtherNames],O.[DOB],O.[Phone],O.[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],O.[ValidityFrom],O.[ValidityTo],O.[LegacyID],O.[AuditUserID],EmailId, O.PhoneCommunication,O.PermanentAddress FROM [dbo].[tblOfficer] O 
	INNER JOIN tblPolicy P ON P.OfficerID = O.OfficerID
	INNER JOIN #FamiliesWProd F ON F.FamilyID =P.FamilyID
	UNION  ALL
	SELECT O.[OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],O.[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],O.[ValidityFrom], O.[ValidityTo], O.[LegacyID], O.[AuditUserID],EmailId, PhoneCommunication,PermanentAddress
	FROM [dbo].[tblOfficer]  O 
	INNER JOIN tblPolicy PL ON PL.OfficerId = O.OfficerID
	INNER JOIN tblFamilies F ON F.Familyid = PL.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE O.RowID > @RowID AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region =@RegionId)
	 )
	SELECT * FROM Officer O
	GROUP BY O.[OfficerID],[Code],O.[LastName],O.[OtherNames],O.[DOB],O.[Phone],O.[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],O.[ValidityFrom],O.[ValidityTo],O.[LegacyID],O.[AuditUserID],EmailId, PhoneCommunication,PermanentAddress
	

	--**Product  Changed on 11.11.2017**
	

	; WITH Product AS (
	  SELECT [ProdID],[ProductCode],[ProductName],P.[LocationId],[InsurancePeriod],[DateFrom],[DateTo],[ConversionProdID],[LumpSum],[MemberCount],[PremiumAdult],[PremiumChild],[DedInsuree],[DedOPInsuree],[DedIPInsuree],[MaxInsuree],[MaxOPInsuree],[MaxIPInsuree],[PeriodRelPrices],[PeriodRelPricesOP],[PeriodRelPricesIP],[AccCodePremiums],[AccCodeRemuneration],[DedTreatment],[DedOPTreatment],[DedIPTreatment],[MaxTreatment],[MaxOPTreatment],[MaxIPTreatment],[DedPolicy],[DedOPPolicy],[DedIPPolicy],[MaxPolicy],[MaxOPPolicy],[MaxIPPolicy],[GracePeriod],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],[RegistrationLumpSum],[RegistrationFee],[GeneralAssemblyLumpSum],[GeneralAssemblyFee],[StartCycle1],[StartCycle2],[MaxNoConsultation],[MaxNoSurgery],[MaxNoDelivery],[MaxNoHospitalizaion],[MaxNoVisits],[MaxAmountConsultation],[MaxAmountSurgery],[MaxAmountDelivery],[MaxAmountHospitalization],[GracePeriodRenewal],[MaxInstallments],[WaitingPeriod]
		,RenewalDiscountPerc,RenewalDiscountPeriod,StartCycle3,StartCycle4,AdministrationPeriod,Threshold
		,MaxPolicyExtraMember,MaxPolicyExtraMemberIP,MaxPolicyExtraMemberOP,MaxCeilingPolicy,MaxCeilingPolicyIP,MaxCeilingPolicyOP, EnrolmentDiscountPeriod, EnrolmentDiscountPerc,MaxAmountAntenatal,MaxNoAntenatal,CeilingInterpretation,[Level1],[Sublevel1],[Level2],[Sublevel2],[Level3],[Sublevel3],[Level4],[Sublevel4],[ShareContribution],[WeightPopulation],WeightNumberFamilies,[WeightInsuredPopulation],[WeightNumberInsuredFamilies],[WeightNumberVisits],[WeightAdjustedAmount] FROM [dbo].[tblProduct]  P
		INNER JOIN uvwLocations L ON ISNULL(L.LocationId,0) = ISNULL(P.LocationId,0)
		WHERE  RowID > @RowID  
		AND (L.RegionId = @RegionId OR @RegionId =0 OR L.LocationId =0  )  
		AND (L.DistrictId =@DistrictId OR L.DistrictId IS NULL OR @DistrictId =0 )
		
		UNION  ALL
		
		SELECT Prod.[ProdID],[ProductCode],[ProductName],[LocationId],[InsurancePeriod],[DateFrom],[DateTo],[ConversionProdID],[LumpSum],[MemberCount],[PremiumAdult],[PremiumChild],[DedInsuree],[DedOPInsuree],[DedIPInsuree],[MaxInsuree],[MaxOPInsuree],[MaxIPInsuree],[PeriodRelPrices],[PeriodRelPricesOP],[PeriodRelPricesIP],[AccCodePremiums],[AccCodeRemuneration],[DedTreatment],[DedOPTreatment],[DedIPTreatment],[MaxTreatment],[MaxOPTreatment],[MaxIPTreatment],[DedPolicy],[DedOPPolicy],[DedIPPolicy],[MaxPolicy],[MaxOPPolicy],[MaxIPPolicy],[GracePeriod],Prod.[ValidityFrom],Prod.[ValidityTo],Prod.[LegacyID],Prod.[AuditUserID],[RegistrationLumpSum],[RegistrationFee],[GeneralAssemblyLumpSum],[GeneralAssemblyFee],[StartCycle1],[StartCycle2],[MaxNoConsultation],[MaxNoSurgery],[MaxNoDelivery],[MaxNoHospitalizaion],[MaxNoVisits],[MaxAmountConsultation],[MaxAmountSurgery],[MaxAmountDelivery],[MaxAmountHospitalization],[GracePeriodRenewal],[MaxInstallments],[WaitingPeriod]
		,RenewalDiscountPerc,RenewalDiscountPeriod,StartCycle3,StartCycle4,AdministrationPeriod,Threshold
		,MaxPolicyExtraMember,MaxPolicyExtraMemberIP,MaxPolicyExtraMemberOP,MaxCeilingPolicy,MaxCeilingPolicyIP,MaxCeilingPolicyOP, EnrolmentDiscountPeriod, EnrolmentDiscountPerc,MaxAmountAntenatal,MaxNoAntenatal,CeilingInterpretation,[Level1],[Sublevel1],[Level2],[Sublevel2],[Level3],[Sublevel3],[Level4],[Sublevel4],[ShareContribution],[WeightPopulation],WeightNumberFamilies,[WeightInsuredPopulation],[WeightNumberInsuredFamilies],[WeightNumberVisits],[WeightAdjustedAmount]
		 FROM tblProduct Prod
		INNER JOIN tblPolicy P ON Prod.ProdID = P.ProdID
		INNER JOIN #FamiliesWProd F ON F.FamilyID = P.FamilyID
	)
	SELECT * FROM Product Prod

	--ADDED
	UNION
	SELECT 
	Prod.[ProdID],[ProductCode],[ProductName],Prod.[LocationId],[InsurancePeriod],[DateFrom],[DateTo],[ConversionProdID],[LumpSum],[MemberCount],[PremiumAdult],[PremiumChild],[DedInsuree],[DedOPInsuree],[DedIPInsuree],[MaxInsuree],[MaxOPInsuree],[MaxIPInsuree],[PeriodRelPrices],[PeriodRelPricesOP],[PeriodRelPricesIP],[AccCodePremiums],[AccCodeRemuneration],[DedTreatment],[DedOPTreatment],[DedIPTreatment],[MaxTreatment],[MaxOPTreatment],[MaxIPTreatment],[DedPolicy],[DedOPPolicy],[DedIPPolicy],[MaxPolicy],[MaxOPPolicy],[MaxIPPolicy],[GracePeriod], Prod.[ValidityFrom], Prod.[ValidityTo], Prod.[LegacyID], Prod.[AuditUserID],[RegistrationLumpSum],[RegistrationFee],[GeneralAssemblyLumpSum],[GeneralAssemblyFee],[StartCycle1],[StartCycle2],[MaxNoConsultation],[MaxNoSurgery],[MaxNoDelivery],[MaxNoHospitalizaion],[MaxNoVisits],[MaxAmountConsultation],[MaxAmountSurgery],[MaxAmountDelivery],[MaxAmountHospitalization],[GracePeriodRenewal],[MaxInstallments],[WaitingPeriod]
	,RenewalDiscountPerc,RenewalDiscountPeriod,StartCycle3,StartCycle4,AdministrationPeriod,Threshold
	,MaxPolicyExtraMember,MaxPolicyExtraMemberIP,MaxPolicyExtraMemberOP,MaxCeilingPolicy,MaxCeilingPolicyIP,MaxCeilingPolicyOP, EnrolmentDiscountPeriod, EnrolmentDiscountPerc,MaxAmountAntenatal,MaxNoAntenatal,CeilingInterpretation,[Level1],[Sublevel1],[Level2],[Sublevel2],[Level3],[Sublevel3],[Level4],[Sublevel4],[ShareContribution],[WeightPopulation],WeightNumberFamilies,[WeightInsuredPopulation],[WeightNumberInsuredFamilies],[WeightNumberVisits],[WeightAdjustedAmount]
	 FROM tblProduct Prod WHERE ProdID IN (	SELECT ConversionProdID FROM Product WHERE NOT ConversionProdID IS NULL)
	 --END ADDED

	GROUP BY  Prod.[ProdID],[ProductCode],[ProductName],Prod.[LocationId],[InsurancePeriod],[DateFrom],[DateTo],[ConversionProdID],[LumpSum],[MemberCount],[PremiumAdult],[PremiumChild],[DedInsuree],[DedOPInsuree],[DedIPInsuree],[MaxInsuree],[MaxOPInsuree],[MaxIPInsuree],[PeriodRelPrices],[PeriodRelPricesOP],[PeriodRelPricesIP],[AccCodePremiums],[AccCodeRemuneration],[DedTreatment],[DedOPTreatment],[DedIPTreatment],[MaxTreatment],[MaxOPTreatment],[MaxIPTreatment],[DedPolicy],[DedOPPolicy],[DedIPPolicy],[MaxPolicy],[MaxOPPolicy],[MaxIPPolicy],[GracePeriod], Prod.[ValidityFrom], Prod.[ValidityTo], Prod.[LegacyID], Prod.[AuditUserID],[RegistrationLumpSum],[RegistrationFee],[GeneralAssemblyLumpSum],[GeneralAssemblyFee],[StartCycle1],[StartCycle2],[MaxNoConsultation],[MaxNoSurgery],[MaxNoDelivery],[MaxNoHospitalizaion],[MaxNoVisits],[MaxAmountConsultation],[MaxAmountSurgery],[MaxAmountDelivery],[MaxAmountHospitalization],[GracePeriodRenewal],[MaxInstallments],[WaitingPeriod]
	,RenewalDiscountPerc,RenewalDiscountPeriod,StartCycle3,StartCycle4,AdministrationPeriod,Threshold
	,MaxPolicyExtraMember,MaxPolicyExtraMemberIP,MaxPolicyExtraMemberOP,MaxCeilingPolicy,MaxCeilingPolicyIP,MaxCeilingPolicyOP, EnrolmentDiscountPeriod, EnrolmentDiscountPerc,MaxAmountAntenatal,MaxNoAntenatal,CeilingInterpretation,[Level1],[Sublevel1],[Level2],[Sublevel2],[Level3],[Sublevel3],[Level4],[Sublevel4],[ShareContribution],[WeightPopulation],WeightNumberFamilies,[WeightInsuredPopulation],[WeightNumberInsuredFamilies],[WeightNumberVisits],[WeightAdjustedAmount]
	
	--**End Product
	--**ProductItems**
	SELECT [ProdItemID],[tblProductItems].[ProdID],[ItemID],[LimitationType],[PriceOrigin],[LimitAdult],[LimitChild],[tblProductItems].[ValidityFrom] ,[tblProductItems].[ValidityTo],[tblProductItems].[LegacyID],[tblProductItems].[AuditUserID],[WaitingPeriodAdult],[WaitingPeriodChild],[LimitNoAdult],[LimitNoChild],LimitationTypeR,LimitationTypeE,LimitAdultR,LimitAdultE,LimitChildR,LimitChildE,CeilingExclusionAdult,CeilingExclusionChild FROM [dbo].[tblProductItems] 
	INNER JOIN [dbo].[tblProduct] P ON P.ProdID = tblProductItems.ProdID  
	INNER JOIN uvwLocations L ON ISNULL(L.LocationId,0) = ISNULL(P.LocationId,0)
	WHERE tblProductItems.RowID  > @RowID 
	    AND (L.RegionId = @RegionId OR @RegionId =0 OR L.LocationId =0  )  
		AND (L.DistrictId =@DistrictId OR L.DistrictId IS NULL OR @DistrictId =0 )

	--**ProductServices**
	SELECT [ProdServiceID],[dbo].[tblProductServices].[ProdID],[ServiceID],[LimitationType],[PriceOrigin],[LimitAdult],[LimitChild],[dbo].[tblProductServices].[ValidityFrom],[dbo].[tblProductServices].[ValidityTo],[dbo].[tblProductServices].[LegacyID],[dbo].[tblProductServices].[AuditUserID],[WaitingPeriodAdult],[WaitingPeriodChild],[LimitNoAdult],[LimitNoChild],LimitationTypeR,LimitationTypeE,LimitAdultR,LimitAdultE,LimitChildR,LimitChildE,CeilingExclusionAdult,CeilingExclusionChild FROM [dbo].[tblProductServices]
	 INNER JOIN [dbo].[tblProduct] P ON P.ProdID = tblProductServices.ProdID  
	 INNER JOIN uvwLocations L ON ISNULL(L.LocationId,0) = ISNULL(P.LocationId,0)
	WHERE tblProductServices.RowID  > @RowID 
	    AND (L.RegionId = @RegionId OR @RegionId =0 OR L.LocationId =0  )  
		AND (L.DistrictId =@DistrictId OR L.DistrictId IS NULL OR @DistrictId =0 ) 

	--**Product-RelDistr**
	SELECT [DistrID],[DistrType] ,[DistrCareType],[dbo].[tblRelDistr].[ProdID],[Period],[DistrPerc],[dbo].[tblRelDistr].[ValidityFrom],[dbo].[tblRelDistr].[ValidityTo],[dbo].[tblRelDistr].[LegacyID],[dbo].[tblRelDistr].[AuditUserID] 
	FROM [dbo].[tblRelDistr] 
	INNER JOIN [dbo].[tblProduct] P ON P.ProdID = tblRelDistr.ProdID   
	INNER JOIN uvwLocations L ON ISNULL(L.LocationId,0) = ISNULL(P.LocationId,0)
	WHERE [tblRelDistr].RowID  > @RowID 
	    AND (L.RegionId = @RegionId OR @RegionId =0 OR L.LocationId =0  )  
		AND (L.DistrictId =@DistrictId OR L.DistrictId IS NULL OR @DistrictId =0 ) 

	--**tblClaimAdmin**
	SELECT ClaimAdminId,ClaimAdminCode,LastName,OtherNames,DOB,CA.Phone,CA.HFId,CA.ValidityFrom,CA.ValidityTo,CA.LegacyId,CA.AuditUserId,EmailId 
	FROM tblClaimAdmin CA 
	INNER JOIN tblHF HF ON CA.HFId = HF.HfID 
	WHERE CA.RowId > @RowID
	AND (HF.LocationId = @DistrictId OR @DistrictId = 0)



	--********S tblOfficerVillage 
; WITH OfficerVillage AS (
	SELECT [OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],EmailId, PhoneCommunication,PermanentAddress FROM [dbo].[tblOfficer] 
	WHERE RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE [LocationId]  END) = @DistrictId
	UNION ALL
	 SELECT O.[OfficerID],[Code],O.[LastName],O.[OtherNames],O.[DOB],O.[Phone],O.[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],O.[ValidityFrom],O.[ValidityTo],O.[LegacyID],O.[AuditUserID],EmailId, O.PhoneCommunication,O.PermanentAddress FROM [dbo].[tblOfficer] O 
	INNER JOIN tblPolicy P ON P.OfficerID = O.OfficerID
	INNER JOIN #FamiliesWProd F ON F.FamilyID =P.FamilyID
	UNION  ALL
	SELECT O.[OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],O.[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],O.[ValidityFrom], O.[ValidityTo], O.[LegacyID], O.[AuditUserID],EmailId, PhoneCommunication,PermanentAddress
	FROM [dbo].[tblOfficer]  O 
	INNER JOIN tblPolicy PL ON PL.OfficerId = O.OfficerID
	INNER JOIN tblFamilies F ON F.Familyid = PL.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE O.RowID > @RowID AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region =@RegionId)
	 )
	SELECT OV.OfficerVillageId, OV.OfficerId, OV.LocationId, OV.ValidityFrom, OV.ValidityTo, OV.LegacyId, OV.AuditUserId FROM  tblOfficerVillages OV
	INNER JOIN OfficerVillage O ON O.OfficerID = OV.OfficerId
	GROUP BY OV.OfficerVillageId, OV.OfficerId, OV.LocationId, OV.ValidityFrom, OV.ValidityTo, OV.LegacyId, OV.AuditUserId
	
	DROP TABLE #FamiliesWProd

	--*******E tblOffficerVillage

	--Get Genders
	SELECT Code, Gender, AltLanguage,SortOrder FROM tblGender WHERE @isFullExtract = 1
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract4]
     @RegionId INT = 0,
	 @DistrictId INT = 0,
	 @RowID as bigint = 0,
	 
	--updated by Amani 22/09/2017
	@WithInsuree as bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	--**Families**
	--SELECT [FamilyID],[InsureeID],[DistrictID],[VillageID],[WardID],[Poverty],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],[FamilyType],[FamilyAddress],Ethnicity,ConfirmationNo FROM [dbo].[tblFamilies] WHERE RowID > @RowID AND (CASE @LocationId  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @LocationId
	;WITH Family AS (
	SELECT F.[FamilyID],F.[InsureeID],F.[LocationId],[Poverty],F.[ValidityFrom],F.[ValidityTo],F.[LegacyID],F.[AuditUserID],[FamilyType],[FamilyAddress],Ethnicity,isOffline ,ConfirmationNo,F.ConfirmationType  
	FROM [dbo].[tblFamilies] F 
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE F.RowID > @RowID 
	--AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region = @RegionId) Commented by Rogers
	AND (@RegionId =0 or (
	((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId) AND
	((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId)
	))
	
	AND D.[DistrictID] =  CASE WHEN	@WithInsuree=0 THEN NULL ELSE D.[DistrictID] END --ADDED BY AMANI
	UNION ALL
	SELECT F.[FamilyID],F.[InsureeID],F.[LocationId],[Poverty],F.[ValidityFrom],F.[ValidityTo],F.[LegacyID],F.[AuditUserID],[FamilyType],[FamilyAddress],Ethnicity,F.isOffline,ConfirmationNo,F.ConfirmationType 
	FROM tblFamilies F 
	INNER JOIN tblInsuree I ON F.FamilyId = I.FamilyID
	INNER JOIN tblHF HF ON I.HFId = HF.HfID
	WHERE F.RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId 
	AND HF.[LocationId] =  CASE WHEN	@WithInsuree=0 THEN NULL ELSE HF.[LocationId] END --ADDED BY AMANI

	)
	SELECT * FROM Family F 
	GROUP BY F.[FamilyID],F.[InsureeID],F.[LocationId],[Poverty],F.[ValidityFrom],F.[ValidityTo],F.[LegacyID],F.[AuditUserID],[FamilyType],[FamilyAddress],Ethnicity,ConfirmationNo,F.ConfirmationType,F.isOffline

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract5]
	@RegionId INT = 0,
	@DistrictId INT = 0,
	@RowID as bigint = 0,
	@WithInsuree as bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	
	--**Insurees**
	--SELECT [dbo].[tblInsuree].[InsureeID],[dbo].[tblInsuree].[FamilyID] ,[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],[dbo].[tblInsuree].[ValidityFrom],[dbo].[tblInsuree].[ValidityTo],[dbo].[tblInsuree].[LegacyID],[dbo].[tblInsuree].[AuditUserID],[Relationship],[Profession],[Education],[Email],TypeOfId,HFId FROM [dbo].[tblInsuree] INNER JOIN tblFamilies ON tblFamilies.FamilyID = tblInsuree.FamilyID WHERE tblInsuree.RowID > @RowID AND (CASE @LocationId  WHEN 0 THEN 0 ELSE [DistrictID]  END) = @LocationId
	;WITH Insurees AS (
	SELECT [dbo].[tblInsuree].[InsureeID],[dbo].[tblInsuree].[FamilyID] ,[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],[dbo].[tblInsuree].[ValidityFrom],[dbo].[tblInsuree].[ValidityTo],[dbo].[tblInsuree].[LegacyID],[dbo].[tblInsuree].[AuditUserID],[Relationship],[Profession],[Education],[Email],[dbo].[tblInsuree].isOffline,TypeOfId,HFId, CurrentAddress, tblInsuree.CurrentVillage, GeoLocation, Vulnerability
	FROM [dbo].[tblInsuree] INNER JOIN tblFamilies ON tblFamilies.FamilyID = tblInsuree.FamilyID 
	INNER JOIN tblVillages V ON V.VillageID = tblFamilies.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE tblInsuree.RowID > @RowID 
	--AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region = @RegionId) Commented by Rogers
	AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR @DistrictId =0)  --added by Rogers 0n 10.11.2017
	AND ((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId OR @RegionId =0)
	AND[tblInsuree].[InsureeID] =  CASE WHEN	@WithInsuree=0 THEN NULL ELSE [tblInsuree].[InsureeID] END
	--Amani 22/09/2017 change to this------>AND[tblInsuree].[InsureeID] =  CASE WHEN	@WithInsuree=0 THEN NULL END
	UNION ALL
 	SELECT I.[InsureeID],I.[FamilyID] ,[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],I.[Phone],[PhotoID],[PhotoDate],[CardIssued],I.[ValidityFrom],I.[ValidityTo],I.[LegacyID],I.[AuditUserID],[Relationship],[Profession],[Education],I.[Email],I.isOffline,TypeOfId,I.HFId, CurrentAddress, I.CurrentVillage, GeoLocation, Vulnerability
	FROM tblFamilies F INNER JOIN tblInsuree I ON F.FamilyId = I.FamilyID
	INNER JOIN tblHF HF ON I.HFId = HF.HfID
	WHERE I.RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId
	AND I.[InsureeID] =  CASE WHEN	@WithInsuree=0 THEN NULL ELSE I.[InsureeID] END
	)
	SELECT * FROM Insurees I
	GROUP BY I.[InsureeID],I.[FamilyID] ,[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],I.[ValidityFrom],I.[ValidityTo],I.[LegacyID],I.[AuditUserID],[Relationship],[Profession],[Education],[Email],I.isOffline,TypeOfId,HFId, CurrentAddress, I.CurrentVillage, GeoLocation, Vulnerability

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract6]
	 @RegionId INT = 0,
	 @DistrictId INT = 0,
	 @RowID as bigint = 0,
	 
	--updated by Amani 22/09/2017
	@WithInsuree as bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	
	;WITH Insurees AS (
	SELECT [dbo].[tblInsuree].[InsureeID],PhotoID
	FROM [dbo].[tblInsuree] INNER JOIN tblFamilies ON tblFamilies.FamilyID = tblInsuree.FamilyID 
	INNER JOIN tblVillages V ON V.VillageID = tblFamilies.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE tblInsuree.RowID > @RowID 
	--AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region = @RegionId) Commented by Rogers
	AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR @DistrictId =0)  --added by Rogers 0n 10.11.2017
	AND ((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId OR @RegionId =0)
	AND[tblInsuree].[InsureeID] =  CASE WHEN	@WithInsuree=0 THEN NULL ELSE [tblInsuree].[InsureeID] END
	--Amani 22/09/2017 change to this------>AND[tblInsuree].[InsureeID] =  CASE WHEN	@WithInsuree=0 THEN NULL END
	UNION ALL
 	SELECT I.[InsureeID],PhotoID
	FROM tblFamilies F INNER JOIN tblInsuree I ON F.FamilyId = I.FamilyID
	INNER JOIN tblHF HF ON I.HFId = HF.HfID
	WHERE I.RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId
	AND I.[InsureeID] =  CASE WHEN	@WithInsuree=0 THEN NULL ELSE I.[InsureeID] END
	)
	--select * from Insurees 

	SELECT P.PhotoID, P.InsureeID, P.CHFID, P.PhotoFolder, P.PhotoFileName, P.OfficerID, P.PhotoDate,P.ValidityFrom, P.ValidityTo, P.AuditUserID
	FROM (SELECT Insurees.InsureeID,Insurees.PhotoID FROM Insurees  Group BY InsureeID,PhotoID) I 
	INNER JOIN tblPhotos P ON I.PhotoID = P.PhotoID --AND I.InsureeID=P.InsureeID
	GROUP BY P.PhotoID, P.InsureeID, P.CHFID, P.PhotoFolder, P.PhotoFileName, P.OfficerID, P.PhotoDate,P.ValidityFrom, P.ValidityTo, P.AuditUserID
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract7]
	 @RegionId INT = 0,
	 @DistrictId INT = 0,
	 @RowID as bigint = 0,
	 
	--updated by Amani 22/09/2017
	@WithInsuree as bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	; WITH Policy AS(
	SELECT [PolicyID],[dbo].[tblPolicy].[FamilyID],[EnrollDate],[StartDate],[EffectiveDate],[ExpiryDate],[PolicyStatus],[PolicyValue],[ProdID],[OfficerID],[dbo].[tblPolicy].[PolicyStage],[dbo].[tblPolicy].[ValidityFrom],[dbo].[tblPolicy].[ValidityTo],[dbo].[tblPolicy].[LegacyID],[dbo].[tblPolicy].[AuditUserID]  ,[dbo].[tblPolicy].isOffline
	FROM [dbo].[tblPolicy]             INNER JOIN tblFamilies ON tblFamilies.FamilyID = tblPolicy.FamilyID 
	INNER JOIN tblVillages V ON V.VillageID = tblFamilies.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE tblPolicy .RowID > @RowID 
	--AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region =@RegionId) Commented by Rogers
	AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR @DistrictId =0)  --added by Rogers 0n 10.11.2017
	AND ((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId OR @RegionId =0)
	AND D.[DistrictId]=CASE WHEN @WithInsuree =0 THEN NULL ELSE D.[DistrictId] END --ADDED 25/09
	UNION ALL
	SELECT [PolicyID],[dbo].[tblPolicy].[FamilyID],[EnrollDate],[StartDate],[EffectiveDate],[ExpiryDate],[PolicyStatus],[PolicyValue],[ProdID],[OfficerID],[dbo].[tblPolicy].[PolicyStage],[dbo].[tblPolicy].[ValidityFrom],[dbo].[tblPolicy].[ValidityTo],[dbo].[tblPolicy].[LegacyID],[dbo].[tblPolicy].[AuditUserID] ,[dbo].[tblPolicy].isOffline 
	FROM [dbo].[tblPolicy] INNER JOIN tblFamilies ON tblFamilies.FamilyID = tblPolicy.FamilyID 
	INNER JOIN tblInsuree ON tblFamilies.FamilyId = tblInsuree.FamilyID
	INNER JOIN tblHF HF ON tblInsuree.HFId = HF.HfID
	WHERE tblPolicy .RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId 
	AND HF.LocationId =CASE WHEN @WithInsuree=0 THEN NULL ELSE HF.LocationId END --ADDED 25/09
	)
	SELECT * FROM Policy P 
	GROUP BY p.[PolicyID],P.[FamilyID],[EnrollDate],[StartDate],[EffectiveDate],[ExpiryDate],[PolicyStatus],[PolicyValue],[ProdID],[OfficerID],P.[PolicyStage],P.[ValidityFrom],P.[ValidityTo],P.[LegacyID],P.[AuditUserID],P.isOffline
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract8]
	 @RegionId INT = 0,
	 @DistrictId INT = 0,
	 @RowID as bigint = 0,
	 
	--updated by Amani 22/09/2017
	@WithInsuree as bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	
	;WITH Premium AS(
	SELECT tblPremium.PremiumId, tblPremium.PolicyID, tblPremium.PayerID, tblPremium.Amount, tblPremium.Receipt, tblPremium.PayDate, tblPremium.PayType,tblPremium.ValidityFrom, tblPremium.ValidityTo, tblPremium.LegacyID, tblPremium.AuditUserID ,tblPremium.isPhotoFee,tblPremium.ReportingId,tblPremium.isOffline
	FROM tblPremium INNER JOIN tblPolicy ON tblPremium.PolicyID = tblPolicy.PolicyID 
	INNER JOIN tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID 
	INNER JOIN tblVillages V ON V.VillageID = tblFamilies.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE tblPremium.RowID > @RowID 
	--AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR D.Region =@RegionId) Commented by Rogers
	AND ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR @DistrictId =0) --added by Rogers 0n 10.11.2017
	AND ((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId OR @RegionId =0)
	AND D.[DistrictId] = CASE WHEN @WithInsuree=0 THEN NULL ELSE D.[DistrictId] END --ADDED 25/09
	UNION ALL
	SELECT tblPremium.PremiumId, tblPremium.PolicyID, tblPremium.PayerID, tblPremium.Amount, tblPremium.Receipt, tblPremium.PayDate, tblPremium.PayType,tblPremium.ValidityFrom, tblPremium.ValidityTo, tblPremium.LegacyID, tblPremium.AuditUserID ,tblPremium.isPhotoFee,tblPremium.ReportingId,tblPremium.isOffline
	FROM tblPremium INNER JOIN tblPolicy ON tblPremium.PolicyID = tblPolicy.PolicyID 
	INNER JOIN tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID 
	INNER JOIN tblInsuree ON tblFamilies.FamilyId = tblInsuree.FamilyID
	INNER JOIN tblHF HF ON tblInsuree.HFId = HF.HfID
	WHERE tblPremium.RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId 
	AND HF.[LocationId] = CASE WHEN @WithInsuree =0 THEN NULL ELSE HF.[LocationId] END --ADDED 25/09
	)
	SELECT * FROM Premium P 
	GROUP BY P.PremiumId, P.PolicyID, P.PayerID, P.Amount, P.Receipt, P.PayDate, P.PayType,P.ValidityFrom, P.ValidityTo, P.LegacyID, P.AuditUserID ,P.isPhotoFee,P.ReportingId,P.isOffline
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspExportOffLineExtract9]
@RegionId INT = 0,
	 @DistrictId INT = 0,
	 @RowID as bigint = 0,
	 
	--updated by Amani 22/09/2017
	@WithInsuree as bit = 0
AS
BEGIN
	SET NOCOUNT ON
	
	
	
	; WITH InsureePolicy AS (
	SELECT Ip.InsureePolicyId,IP.InsureeId,IP.PolicyId,IP.EnrollmentDate,Ip.StartDate,IP.EffectiveDate,IP.ExpiryDate,IP.ValidityFrom,IP.ValidityTo,IP.LegacyId,IP.AuditUserId,IP.isOffline
	FROM tblInsureePolicy IP RIGHT OUTER JOIN tblInsuree I ON IP.InsureeId = I.InsureeID
	LEFT OUTER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE 
	 --IP.ValidityTo IS NULL AND F.ValidityTo IS NULL
	--AND (D.DistrictID = @DistrictId OR @DistrictId = 0 OR D.Region =@RegionId)Commented by Rogers
	 ((CASE @DistrictId  WHEN 0 THEN 0 ELSE D.[DistrictID]  END) = @DistrictId OR @DistrictId =0)  --added by Rogers 0n 10.11.2017
	AND ((CASE @DistrictId  WHEN 0 THEN  D.Region  ELSE @RegionId END) = @RegionId OR @RegionId =0)
	AND IP.RowId > @RowID
	AND D.[DistrictId]= CASE WHEN @WithInsuree=0 THEN NULL ELSE D.[DistrictId] END --ADDED 25/09
	UNION ALL
	SELECT Ip.InsureePolicyId,IP.InsureeId,IP.PolicyId,IP.EnrollmentDate,Ip.StartDate,IP.EffectiveDate,IP.ExpiryDate,IP.ValidityFrom,IP.ValidityTo,IP.LegacyId,IP.AuditUserId ,IP.isOffline
	FROM tblInsureePolicy IP RIGHT OUTER JOIN tblInsuree I ON IP.InsureeId = I.InsureeID
	LEFT OUTER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
	INNER JOIN tblHF HF ON I.HFId = HF.HfID
	WHERE IP.RowID > @RowID 
	AND (CASE @DistrictId  WHEN 0 THEN 0 ELSE HF.[LocationId]  END) = @DistrictId 
	AND HF.[LocationId] = CASE WHEN @WithInsuree=0 THEN NULL ELSE HF.LocationId END --ADDED 25/09
	)
	SELECT * FROM InsureePolicy IP 
	GROUP BY IP.InsureePolicyId,IP.InsureeId,IP.PolicyId,IP.EnrollmentDate,Ip.StartDate,IP.EffectiveDate,IP.ExpiryDate,IP.ValidityFrom,IP.ValidityTo,IP.LegacyId,IP.AuditUserId,IP.isOffline 

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspFeedbackPromptSMS]
(
	@RangeFrom DATE = '',
	@RangeTo DATE = ''
)
AS
BEGIN
	DECLARE @LinkBreak NVARCHAR(10) = CHAR(10)

	IF @RangeFrom = '' SET @RangeFrom = GETDATE()
	IF @RangeTo = '' SET @RangeTo = GETDATE()

	DECLARE @SMSQueue TABLE (SMSID int IDENTITY(1,1), PhoneNumber nvarchar(50) , SMSMessage nvarchar(4000) , SMSLength AS LEN(SMSMessage) )

	INSERT INTO @SMSQueue(PhoneNumber,SMSMessage)
	SELECT FP.PhoneNumber,'--Feedback--' + @LinkBreak +
	CAST(C.ClaimID AS VARCHAR(15)) + @LinkBreak +  I.LastName + ' ' + I.OtherNames + @LinkBreak + V.VillageName + @LinkBreak + W.WardName + @LinkBreak + HF.HFName + @LinkBreak + 
	CAST(C.DateFrom AS VARCHAR(10)) + @LinkBreak + I.CHFID + @LinkBreak AS SMS
	FROM tblFeedbackPrompt FP INNER JOIN tblClaim C ON FP.ClaimID = C.ClaimID 
	INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID
	INNER JOIN tblFamilies F ON I.FamilyID =F.FamilyID
	INNER JOIN tblVillages V ON F.LocationId = V.VillageId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblHF HF ON C.HFID =HF.HfID
	WHERE C.ValidityTo IS NULL AND I.ValidityTo IS NULL AND F.ValidityTo IS NULL AND V.ValidityTo IS NULL AND W.ValidityTo IS NULL AND HF.ValidityTo IS NULL
	AND FP.FeedbackPromptDate BETWEEN @RangeFrom AND @RangeTo
	
	SELECT 'IMIS-FEEDBACK' seder,
	(
	SELECT REPLACE(PhoneNumber,' ','')[to]
	FROM @SMSQueue PNo
	WHERE PNo.SMSID = SMS.SMSID
	FOR XML PATH('recipients'), TYPE
	)PhoneNumber,
	SMS.SMSMessage [text]
	FROM @SMSQueue SMS
	WHERE LEN(SMS.PhoneNumber) > 0
	AND LEN(ISNULL(SMS.SMSMessage,'')) > 0
	FOR XML PATH('message'), ROOT('request'), TYPE;

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspGetPolicyPeriod]
(
	@ProdId INT,
	@EnrolDate DATE,
	@HasCycles BIT = 0 OUTPUT,
	@PolicyStage NVARCHAR(1) = N'N'
)
AS
BEGIN
		DECLARE	@StartCycle1 DATE,
				@StartCycle2 DATE,
				@StartCycle3 DATE,
				@StartCycle4 DATE,
				@GracePeriod INT,
				@StartDate DATE,
				@InsurancePeriod INT,
				@AdministratorPeriod INT
	
	--Add administration period to the enrolment date and then check the cycle
	SELECT @AdministratorPeriod = ISNULL(AdministrationPeriod,0) FROM tblProduct WHERE ProdID = @ProdId;
	IF @PolicyStage = N'N'
		SET @EnrolDate = DATEADD(MONTH, @AdministratorPeriod, @EnrolDate);

--Check if they work on cycles
	IF EXISTS(SELECT 1 FROM tblProduct WHERE ProdId = @ProdId AND LEN(StartCycle1) > 0)
	BEGIN

		SET @HasCycles = 1;
		
		SELECT @StartCycle1 = CONVERT(DATE,StartCycle1 + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
		, @StartCycle2 = CONVERT(DATE,ISNULL(NULLIF(StartCycle2,''),StartCycle1) + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
		, @StartCycle3 = CONVERT(DATE,ISNULL(NULLIF(StartCycle3,''),ISNULL(NULLIF(StartCycle2,''),StartCycle1)) + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
, @StartCycle4 = CONVERT(DATE,ISNULL(NULLIF(StartCycle4,''),ISNULL(NULLIF(StartCycle3,''),ISNULL(NULLIF(StartCycle2,''),StartCycle1))) + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
		

		/*SELECT @StartCycle1 = CONVERT(DATE,StartCycle1 + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
		, @StartCycle2 = CONVERT(DATE,ISNULL(NULLIF(StartCycle2,''),StartCycle1) + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
		, @StartCycle3 = CONVERT(DATE,ISNULL(NULLIF(StartCycle3,''),StartCycle2) + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)
		, @StartCycle4 = CONVERT(DATE,ISNULL(NULLIF(StartCycle4,''),StartCycle3) + '-' + CAST(YEAR(@EnrolDate)AS NVARCHAR(4)),103)*/
		,@GracePeriod = GracePeriod,@InsurancePeriod = InsurancePeriod
		FROM tblProduct WHERE ProdID = @ProdId

		IF @EnrolDate < DATEADD(MONTH,@GracePeriod,@StartCycle1)
			SET @StartDate = @StartCycle1
		ELSE IF @EnrolDate < DATEADD(MONTH,@GracePeriod,@StartCycle2)
			SET @StartDate = @StartCycle2
		ELSE IF @EnrolDate < DATEADD(MONTH,@GracePeriod,@StartCycle3)
			SET @StartDate = @StartCycle3
		ELSE IF @EnrolDate < DATEADD(MONTH,@GracePeriod,@StartCycle4)
			SET @StartDate = @StartCycle4
		ELSE
			SET @StartDate = DATEADD(YEAR,1,@StartCycle1)
		
		SELECT @StartDate StartDate, DATEADD(DAY,-1,DATEADD(MONTH,@InsurancePeriod,@StartDate)) ExpiryDate, @HasCycles HasCycle;
	END
	ELSE	--They don't work on cycles so get the enrolment date as start date and derive expiry date from product period
	BEGIN
		
		SET @HasCycles = 0;
		
		SELECT @StartDate = @EnrolDate,@InsurancePeriod = InsurancePeriod 
		FROM tblProduct WHERE ProdID = @ProdId

		SELECT @StartDate StartDate, DATEADD(DAY,-1,DATEADD(MONTH,@InsurancePeriod,@StartDate)) ExpiryDate, @HasCycles HasCycle;
	END
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspGetPolicyRenewals]
(
	@OfficerCode NVARCHAR(8)
)
AS
BEGIN
	DECLARE @OfficerId INT
	DECLARE @LegacyOfficer INT
	DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

	SELECT @OfficerId = OfficerID FROM tblOfficer WHERE Code= @OfficerCode AND ValidityTo IS NULL
	INSERT INTO @tblOfficerSub(OldOfficer, NewOfficer)
	SELECT DISTINCT @OfficerID, @OfficerID

	SET @LegacyOfficer = (SELECT OfficerID FROM tblOfficer WHERE ValidityTo IS NULL AND OfficerIDSubst = @OfficerID)
	WHILE @LegacyOfficer IS NOT NULL
		BEGIN
			INSERT INTO @tblOfficerSub(OldOfficer, NewOfficer)
			SELECT DISTINCT @OfficerID, @LegacyOfficer
			IF EXISTS(SELECT 1 FROM @tblOfficerSub  GROUP BY NewOfficer HAVING COUNT(1) > 1)
				BREAK;
			SET @LegacyOfficer = (SELECT OfficerID FROM tblOfficer WHERE ValidityTo IS NULL AND OfficerIDSubst = @LegacyOfficer)
		END;


	;WITH FollowingPolicies AS
	(
		SELECT P.PolicyId, P.FamilyId, ISNULL(Prod.ConversionProdId, Prod.ProdId)ProdID, P.StartDate
		FROM tblPolicy P
		INNER JOIN tblProduct Prod ON P.ProdId = ISNULL(Prod.ConversionProdId, Prod.ProdId)
		WHERE P.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
	)

	SELECT R.RenewalUUID, R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, R.RenewalpromptDate RenewalpromptDate, O.Phone,  RenewalDate EnrollDate, 'R' PolicyStage, F.FamilyID, Prod.ProdID, R.ResponseDate, R.ResponseStatus
	FROM tblPolicyRenewals R
	INNER JOIN tblOfficer O ON R.NewOfficerId = O.OfficerId
	INNER JOIN tblInsuree I ON R.InsureeId = I.InsureeId
	LEFT OUTER JOIN tblProduct Prod ON R.NewProdId = Prod.ProdId
	INNER JOIN tblFamilies F ON I.FamilyId = F.Familyid
	INNER JOIN tblVillages V ON F.LocationId = V.VillageId
	INNER JOIN tblPolicy Po ON Po.PolicyID = R.PolicyID
	INNER JOIN @tblOfficerSub OS ON OS.NewOfficer = R.NewOfficerID
	LEFT OUTER JOIN FollowingPolicies FP ON FP.FamilyID = F.FamilyId
										AND FP.ProdId = Po.ProdID
										AND FP.PolicyId <> R.PolicyID
										AND FP.PolicyId IS NULL
	WHERE R.ValidityTo Is NULL
	AND ISNULL(R.ResponseStatus, 0) = 0
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspImportHFXML]
(
	@File NVARCHAR(300),
	@StratergyId INT,	--1	: Insert Only,	2: Insert & Update	3: Insert, Update & Delete
	@AuditUserID INT = -1,
	@DryRun BIT=0,
	@SentHF INT = 0 OUTPUT,
	@Inserts INT  = 0 OUTPUT,
	@Updates INT  = 0 OUTPUT
)
AS
BEGIN

	/* Result type in @tblResults
	-------------------------------
		E	:	Error
		C	:	Conflict
		FE	:	Fatal Error

	Return Values
	------------------------------
		0	:	All Okay
		-1	:	Fatal error
	*/
	

	DECLARE @Query NVARCHAR(500)
	DECLARE @XML XML
	DECLARE @tblHF TABLE(LegalForms NVARCHAR(15), [Level] NVARCHAR(15)  NULL, SubLevel NVARCHAR(15), Code NVARCHAR (50) NULL, Name NVARCHAR (101) NULL, [Address] NVARCHAR (101), DistrictCode NVARCHAR (50) NULL,Phone NVARCHAR (51), Fax NVARCHAR (51), Email NVARCHAR (51), CareType CHAR (15) NULL, AccountCode NVARCHAR (26), IsValid BIT )
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))

	BEGIN TRY
		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE HF FROM THE XML
		INSERT INTO @tblHF(LegalForms,[Level],SubLevel,Code,Name,[Address],DistrictCode,Phone,Fax,Email,CareType,AccountCode,IsValid)
		SELECT 
		NULLIF(T.F.value('(LegalForm)[1]','NVARCHAR(15)'),''),
		NULLIF(T.F.value('(Level)[1]','NVARCHAR(15)'),''),
		NULLIF(T.F.value('(SubLevel)[1]','NVARCHAR(15)'),''),
		T.F.value('(Code)[1]','NVARCHAR(50)'),
		T.F.value('(Name)[1]','NVARCHAR(101)'),
		T.F.value('(Address)[1]','NVARCHAR(101)'),
		NULLIF(T.F.value('(DistrictCode)[1]','NVARCHAR(50)'),''),
		T.F.value('(Phone)[1]','NVARCHAR(51)'),
		T.F.value('(Fax)[1]','NVARCHAR(51)'),
		T.F.value('(Email)[1]','NVARCHAR(51)'),
		NULLIF(T.F.value('(CareType)[1]','NVARCHAR(15)'),''),
		T.F.value('(AccountCode)[1]','NVARCHAR(26)'),
		1
		FROM @XML.nodes('HealthFacilities/HealthFacility') AS T(F)

		SELECT @SentHF=@@ROWCOUNT

		/*========================================================================================================
		VALIDATION STARTS
		========================================================================================================*/	
		--Invalidate empty code or empty name 
			IF EXISTS(
				SELECT 1
				FROM @tblHF HF 
				WHERE LEN(ISNULL(HF.Code, '')) = 0
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT CONVERT(NVARCHAR(3), COUNT(HF.Code)) + N' HF(s) have empty code', N'E'
			FROM @tblHF HF 
			WHERE LEN(ISNULL(HF.Code, '')) = 0

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty name field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Name, '')) = 0


			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Name, '')) = 0 OR LEN(ISNULL(HF.Code, '')) = 0

			--Ivalidate empty Legal Forms
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty LegaForms field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.LegalForms, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.LegalForms, '')) = 0 


			--Ivalidate empty Level
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty Level field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Level, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Level, '')) = 0 

			--Ivalidate empty District Code
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty District Code field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.DistrictCode, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.DistrictCode, '')) = 0 OR LEN(ISNULL(HF.Code, '')) = 0

				--Ivalidate empty Care Type
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty Care Type field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.CareType, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.CareType, '')) = 0 OR LEN(ISNULL(HF.Code, '')) = 0


			--Invalidate HF with duplicate Codes
			IF EXISTS(SELECT 1 FROM @tblHF  GROUP BY Code HAVING COUNT(Code) >1)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT QUOTENAME(Code) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(Code)) + ' times in the file', N'C'
			FROM @tblHF  GROUP BY Code HAVING COUNT(Code) >1

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE code in (SELECT code from @tblHF GROUP BY Code HAVING COUNT(Code) >1)

			--Invalidate HF with invalid Legal Forms
			INSERT INTO @tblResult(Result,ResultType)
			SELECT 'HF Code '+QUOTENAME(Code) +' has invalid Legal Form', N'E'  FROM @tblHF HF LEFT OUTER JOIN tblLegalForms LF ON HF.LegalForms = LF.LegalFormCode 	WHERE LF.LegalFormCode IS NULL AND NOT HF.LegalForms IS NULL
			
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN tblLegalForms LF ON HF.LegalForms = LF.LegalFormCode 	WHERE LF.LegalFormCode IS NULL AND NOT HF.LegalForms IS NULL)


			--Ivalidate HF with invalid Disrict Code
			IF EXISTS(SELECT 1  FROM @tblHF HF 	LEFT OUTER JOIN tblLocations L ON L.LocationCode=HF.DistrictCode AND L.ValidityTo IS NULL	WHERE	L.LocationCode IS NULL AND NOT HF.DistrictCode IS NULL)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has invalid District Code', N'E'
			FROM @tblHF HF 	LEFT OUTER JOIN tblLocations L ON L.LocationCode=HF.DistrictCode AND L.ValidityTo IS NULL	WHERE L.LocationCode IS NULL AND NOT HF.DistrictCode IS NULL
	
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE HF.DistrictCode IN (SELECT HF.DistrictCode  FROM @tblHF HF 	LEFT OUTER JOIN tblLocations L ON L.LocationCode=HF.DistrictCode AND L.ValidityTo IS NULL WHERE  L.LocationCode IS NULL)

			--Invalidate HF with invalid Level
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+ QUOTENAME(HF.Code)+' has invalid Level', N'E'   FROM @tblHF HF LEFT OUTER JOIN (SELECT HFLevel FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFLevel) L ON HF.Level = L.HFLevel WHERE L.HFLevel IS NULL AND NOT HF.Level IS NULL
			
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF 
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN (SELECT HFLevel FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFLevel) L ON HF.Level = L.HFLevel WHERE L.HFLevel IS NULL AND NOT HF.Level IS NULL)
			
			--Invalidate HF with invalid SubLevel
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+QUOTENAME(HF.Code) +' has invalid SubLevel' ,N'E'  FROM @tblHF HF LEFT OUTER JOIN tblHFSublevel HSL ON HSL.HFSublevel= HF.SubLevel WHERE HSL.HFSublevel IS NULL AND NOT HF.SubLevel IS NULL
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF 
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN tblHFSublevel HSL ON HSL.HFSublevel= HF.SubLevel WHERE HSL.HFSublevel IS NULL AND NOT HF.SubLevel IS NULL)

			--Remove HF with invalid CareType
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+QUOTENAME(HF.Code) +' has invalid CareType',N'E'   FROM @tblHF HF LEFT OUTER JOIN (SELECT HFCareType FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFCareType) CT ON HF.CareType = CT.HFCareType WHERE CT.HFCareType IS NULL AND NOT HF.CareType IS NULL
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF 
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN (SELECT HFCareType FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFCareType) CT ON HF.CareType = CT.HFCareType WHERE CT.HFCareType IS NULL)


			--Check if any HF Code is greater than 8 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Code ' + QUOTENAME(HF.Code) + ' is greater than 8 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Code) > 8;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Code) > 8;

			--Check if any HF Name is greater than 100 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Name ' + QUOTENAME(HF.Code) + ' is greater than 100 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Name) > 100;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Name) > 100;


			--Check if any HF Address is greater than 100 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Address ' + QUOTENAME(HF.Code) + ' is greater than 100 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Address) > 100;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Address) > 100;

			--Check if any HF Phone is greater than 50 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Phone ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Phone) > 50;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Phone) > 50;

			--Check if any HF Fax is greater than 50 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Fax ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Fax) > 50;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Fax) > 50;

			--Check if any HF Email is greater than 50 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Email ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Email) > 50;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Email) > 50;

			--Check if any HF AccountCode is greater than 25 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Account Code ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.AccountCode) > 25;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.AccountCode) > 25;

			--Get the counts
			--To be udpated
			IF @StratergyId=2
				BEGIN
					SELECT @Updates=COUNT(1) FROM @tblHF TempHF
					INNER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
					WHERE TempHF.IsValid=1
				END
			
			--To be Inserted
			SELECT @Inserts=COUNT(1) FROM @tblHF TempHF
			LEFT OUTER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
			WHERE TempHF.IsValid=1
			AND HF.HFCode IS NULL
			
		/*========================================================================================================
		VALIDATION ENDS
		========================================================================================================*/	
		IF @DryRun=0
		BEGIN
			BEGIN TRAN UPLOAD
				
			/*========================================================================================================
			UDPATE STARTS
			========================================================================================================*/	
			IF @StratergyId = 2
				BEGIN

				--Make a copy of the original record
					INSERT INTO tblHF(HFCode, HFName,[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[PLServiceID],[PLItemID],[AccCode],[OffLine],[ValidityFrom],[ValidityTo],LegacyID, AuditUserId)
					SELECT HF.[HFCode] ,HF.[HFName],HF.[LegalForm],HF.[HFLevel],HF.[HFSublevel],HF.[HFAddress],HF.[LocationId],HF.[Phone],HF.[Fax],HF.[eMail],HF.[HFCareType],HF.[PLServiceID],HF.[PLItemID],HF.[AccCode],HF.[OffLine],[ValidityFrom],GETDATE()[ValidityTo],HF.HfID, @AuditUserID AuditUserId 
					FROM tblHF HF
					INNER JOIN @tblHF TempHF  ON TempHF.Code=HF.HFCode
					WHERE HF.ValidityTo IS NULL
					AND TempHF.IsValid = 1;

					SELECT @Updates = @@ROWCOUNT;
				--Upadte the record
					UPDATE HF SET HF.HFName = TempHF.Name, HF.LegalForm=TempHF.LegalForms,HF.HFLevel=TempHF.Level, HF.HFSublevel=TempHF.SubLevel,HF.HFAddress=TempHF.Address,HF.LocationId=L.LocationId, HF.Phone=TempHF.Phone, HF.Fax=TempHF.Fax, HF.eMail=TempHF.Email,HF.HFCareType=TempHF.CareType, HF.AccCode=TempHF.AccountCode, HF.OffLine=0, HF.ValidityFrom=GETDATE(), AuditUserID = @AuditUserID
					FROM tblHF HF
					INNER JOIN @tblHF TempHF  ON HF.HFCode=TempHF.Code
					INNER JOIN tblLocations L ON L.LocationCode=TempHF.DistrictCode
					WHERE HF.ValidityTo IS NULL
					AND L.ValidityTo IS NULL
					AND TempHF.IsValid = 1;
				END
			/*========================================================================================================
			UPDATE ENDS
			========================================================================================================*/	


			/*========================================================================================================
			INSERT STARTS
			========================================================================================================*/	

				INSERT INTO tblHF(HFCode, HFName,[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[AccCode],[OffLine],[ValidityFrom],AuditUserId)
				SELECT TempHF.[Code] ,TempHF.[Name],TempHF.[LegalForms],TempHF.[Level],TempHF.[Sublevel],TempHF.[Address],L.LocationId,TempHF.[Phone],TempHF.[Fax],TempHF.[Email],TempHF.[CareType],TempHF.[AccountCode],0 [OffLine],GETDATE()[ValidityFrom], @AuditUserID AuditUserId 
				FROM @tblHF TempHF 
				LEFT OUTER JOIN tblHF HF  ON TempHF.Code=HF.HFCode
				INNER JOIN tblLocations L ON L.LocationCode=TempHF.DistrictCode
				WHERE HF.ValidityTo IS NULL
				AND L.ValidityTo IS NULL
				AND HF.HFCode IS NULL
				AND TempHF.IsValid = 1;
	
				SELECT @Inserts = @@ROWCOUNT;


			/*========================================================================================================
			INSERT ENDS
			========================================================================================================*/	

			COMMIT TRAN UPLOAD
		END

		
	END TRY
	BEGIN CATCH
		INSERT INTO @tblResult(Result, ResultType)
		SELECT ERROR_MESSAGE(), N'FE';

		IF @@TRANCOUNT > 0 ROLLBACK TRAN UPLOAD;
		SELECT * FROM @tblResult;
		RETURN -1;
	END CATCH

	SELECT * FROM @tblResult;
	RETURN 0;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspImportLocations]
(

	@RegionsFile NVARCHAR(255),
	@DistrictsFile NVARCHAR(255),
	@WardsFile NVARCHAR(255),
	@VillagesFile NVARCHAR(255)
)
AS
BEGIN
BEGIN TRY
	--CREATE TEMP TABLE FOR REGION
	IF OBJECT_ID('tempdb..#tempRegion') IS NOT NULL DROP TABLE #tempRegion
	CREATE TABLE #tempRegion(RegionCode NVARCHAR(50), RegionName NVARCHAR(50))

	--CREATE TEMP TABLE FOR DISTRICTS
	IF OBJECT_ID('tempdb..#tempDistricts') IS NOT NULL DROP TABLE #tempDistricts
	CREATE TABLE #tempDistricts(RegionCode NVARCHAR(50),DistrictCode NVARCHAR(50),DistrictName NVARCHAR(50))

	--CREATE TEMP TABLE FOR WARDS
	IF OBJECT_ID('tempdb..#tempWards') IS NOT NULL DROP TABLE #tempWards
	CREATE TABLE #tempWards(DistrictCode NVARCHAR(50),WardCode NVARCHAR(50),WardName NVARCHAR(50))

	--CREATE TEMP TABLE FOR VILLAGES
	IF OBJECT_ID('tempdb..#tempVillages') IS NOT NULL DROP TABLE #tempVillages
	CREATE TABLE #tempVillages(WardCode NVARCHAR(50),VillageCode NVARCHAR(50), VillageName NVARCHAR(50),MalePopulation INT,FemalePopulation INT, OtherPopulation INT, Families INT)



	--INSERT REGION IN TEMP TABLE
	DECLARE @InsertRegion NVARCHAR(2000)
	SET @InsertRegion = N'BULK INSERT #tempRegion FROM ''' + @RegionsFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertRegion


	--INSERT DISTRICTS IN TEMP TABLE
	DECLARE @InsertDistricts NVARCHAR(2000)
	SET @InsertDistricts = N'BULK INSERT #tempDistricts FROM ''' + @DistrictsFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertDistricts

	--INSERT WARDS IN TEMP TABLE
	DECLARE @InsertWards NVARCHAR(2000)
	SET @InsertWards = N'BULK INSERT #tempWards FROM ''' + @WardsFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertWards


	
	--INSERT VILLAGES IN TEMP TABLE
	DECLARE @InsertVillages NVARCHAR(2000)
	SET @InsertVillages = N'BULK INSERT #tempVillages FROM ''' + @VillagesFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertVillages
    
	--check if the location is null or empty space
	IF EXISTS(
	SELECT 1 FROM #tempRegion WHERE RegionCode IS NULL OR RegionName IS NULL
	UNION
	SELECT 1FROM #tempDistricts WHERE (RegionCode IS NULL OR LEN(RegionCode)=0) OR (DistrictCode IS NULL OR LEN(DistrictCode)=0) OR (DistrictName IS NULL OR LEN(DistrictName)=0)
	UNION
	SELECT 1 FROM #tempWards WHERE (DistrictCode IS NULL OR LEN(DistrictCode)=0) OR (WardCode IS NULL OR LEN(WardCode)=0) OR (WardName IS NULL OR LEN(WardName)=0)
	UNION
	SELECT 1 FROM #tempVillages WHERE (WardCode IS NULL OR LEN(WardCode)=0) OR (VillageCode IS NULL OR LEN(VillageCode)=0) OR (VillageName IS NULL OR  LEN(VillageName)=0)
	)
	RAISERROR ('LocationCode Or LocationName is Missing in excel', 16, 1)



	--check if the population is numeric
	IF EXISTS(
		SELECT * FROM #tempVillages WHERE   (ISNUMERIC(MalePopulation)=0 AND LEN(MalePopulation)>0) OR  (ISNUMERIC(FemalePopulation)=0  AND LEN(FemalePopulation)>0) OR  (ISNUMERIC(OtherPopulation)=0 AND LEN(OtherPopulation)>0) OR  (ISNUMERIC(Families)=0 AND LEN(Families)>0)
	)
	RAISERROR ('Village population must be numeric in excel', 16, 1)



	DECLARE @AllCodes AS TABLE(LocationCode NVARCHAR(8))
	;WITH AllCodes AS
	(
		SELECT RegionCode LocationCode FROM #tempRegion
		UNION ALL
		SELECT DistrictCode FROM #tempDistricts
		UNION ALL
		SELECT WardCode FROM #tempWards
		UNION ALL
		SELECT VillageCode FROM #tempVillages
	)
	INSERT INTO @AllCodes(LocationCode)
	SELECT LocationCode
	FROM AllCodes

	IF EXISTS(SELECT LocationCode FROM @AllCodes GROUP BY LocationCode HAVING COUNT(1) > 1)
		BEGIN
			SELECT LocationCode FROM @AllCodes GROUP BY LocationCode HAVING COUNT(1) > 1;
			RAISERROR ('Duplicate in excel', 16, 1)
		END

	--;WITH AllLocations AS
	--(
	--	SELECT RegionCode LocationCode, RegionName LocationName FROM tblRegions
	--	UNION ALL
	--	SELECT DistrictCode, DistrictName FROM tblDistricts
	--	UNION ALL
	--	SELECT WardCode, WardName FROM tblWards
	--	UNION ALL
	--	SELECT VillageCode, VillageName FROM tblVillages
	--)
	--SELECT AC.LocationCode ExistingCodenNDB, AL.LocationName ExistingNameInDB
	--FROM @AllCodes AC
	--INNER JOIN AllLocations AL ON AC.LocationCode COLLATE DATABASE_DEFAULT = AL.LocationCode COLLATE DATABASE_DEFAULT

	--IF @@ROWCOUNT > 0
	--	RAISERROR ('One or more location codes are already existing in database', 16, 1)
	
	--DELETE EXISTING LOCATIONS
	DELETE Temp
	OUTPUT deleted.RegionCode OmmitedRegionCode, deleted.RegionName OmmitedRegionName
	FROM #tempRegion Temp
	INNER JOIN tblLocations L ON Temp.RegionCode COLLATE DATABASE_DEFAULT = L.LocationCode COLLATE DATABASE_DEFAULT
	WHERE L.ValidityTo IS NULL;

	DELETE Temp
	OUTPUT deleted.DistrictCode OmmitedDistrictCode, deleted.DistrictName OmmitedDistrictName
	FROM #tempDistricts Temp
	INNER JOIN tblLocations L ON Temp.DistrictCode COLLATE DATABASE_DEFAULT = L.LocationCode COLLATE DATABASE_DEFAULT
	WHERE L.ValidityTo IS NULL;

	DELETE Temp
	OUTPUT deleted.WardCode OmmitedWardCode, deleted.WardName OmmitedWardName
	FROM #tempWards Temp
	INNER JOIN tblLocations L ON Temp.WardCode COLLATE DATABASE_DEFAULT = L.LocationCode COLLATE DATABASE_DEFAULT
	WHERE L.ValidityTo IS NULL;

	DELETE Temp
	OUTPUT deleted.VillageCode OmmitedVillageCode, deleted.VillageName OmmitedVillageName
	FROM #tempVillages Temp
	INNER JOIN tblLocations L ON Temp.VillageCode COLLATE DATABASE_DEFAULT = L.LocationCode COLLATE DATABASE_DEFAULT
	WHERE L.ValidityTo IS NULL;


	BEGIN TRAN
	
 
	--INSERT REGION IN DATABASE
	IF EXISTS(SELECT * FROM tblRegions
			 INNER JOIN #tempRegion ON tblRegions.RegionCode COLLATE DATABASE_DEFAULT = #tempRegion.RegionCode COLLATE DATABASE_DEFAULT)
		BEGIN
			ROLLBACK TRAN

			--RETURN -4
		END
	ELSE
		INSERT INTO tblLocations(LocationCode, LocatioNname, LocationType, AuditUserId)
		SELECT TR.RegionCode, REPLACE(TR.RegionName,CHAR(12),''),'R',-1 
		FROM #tempRegion TR
		--LEFT OUTER JOIN tblRegions R ON TR.RegionCode COLLATE DATABASE_DEFAULT = R.RegionCode COLLATE DATABASE_DEFAULT AND R.ValidityTo IS NULL
		WHERE TR.RegionName IS NOT NULL
		--AND R.RegionCode IS NULL;

		
	--INSERT DISTRICTS IN DATABASE
	IF EXISTS(SELECT * FROM tblDistricts
			 INNER JOIN #tempDistricts ON tblDistricts.DistrictCode COLLATE DATABASE_DEFAULT = #tempDistricts.DistrictCode COLLATE DATABASE_DEFAULT)
		BEGIN
			ROLLBACK TRAN
			--RETURN -1
		END
	ELSE
		--INSERT INTO tblDistricts(Region,DistrictName,DistrictCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserId)
		SELECT #tempDistricts.DistrictCode, REPLACE(#tempDistricts.DistrictName,CHAR(9),''),tblRegions.RegionId,'D', -1
		FROM #tempDistricts 
		INNER JOIN tblRegions ON #tempDistricts.RegionCode COLLATE DATABASE_DEFAULT = tblRegions.RegionCode COLLATE DATABASE_DEFAULT
		--LEFT OUTER JOIN tblDistricts D ON #tempDistricts.DistrictCode COLLATE DATABASE_DEFAULT = D.DistrictCode COLLATE DATABASE_DEFAULT AND D.ValidityTo IS NULL
		WHERE #tempDistricts.DistrictName is NOT NULL
		--AND D.DistrictCode IS NULL;
		 
		
	--INSERT WARDS IN DATABASE
	IF EXISTS (SELECT * 
				FROM tblWards 
				INNER JOIN tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID
				INNER JOIN #tempWards ON tblWards.WardCode COLLATE DATABASE_DEFAULT = #tempWards.WardCode COLLATE DATABASE_DEFAULT
									AND tblDistricts.DistrictCode COLLATE DATABASE_DEFAULT = #tempWards.DistrictCode COLLATE DATABASE_DEFAULT)	
		BEGIN
			ROLLBACK TRAN
			--RETURN -2
		END
	ELSE
		--INSERT INTO tblWards(DistrictID,WardName,WardCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserId)
		SELECT #tempWards.WardCode, REPLACE(#tempWards.WardName,CHAR(9),''),tblDistricts.DistrictID,'W',-1
		FROM #tempWards 
		INNER JOIN tblDistricts ON #tempWards.DistrictCode COLLATE DATABASE_DEFAULT = tblDistricts.DistrictCode COLLATE DATABASE_DEFAULT
		--LEFT OUTER JOIN tblWards W ON #tempWards.WardCode COLLATE DATABASE_DEFAULT = W.WardCode COLLATE DATABASE_DEFAULT AND W.ValidityTo IS NULL
		WHERE #tempWards.WardName is NOT NULL
		


	--INSERT VILLAGES IN DATABASE
	IF EXISTS (SELECT * FROM 
				tblVillages 
				INNER JOIN tblWards ON tblVillages.WardID = tblWards.WardID
				INNER JOIN tblDistricts ON tblDistricts.DistrictID = tblWards.DistrictID
				INNER JOIN #tempVillages ON #tempVillages.VillageCode COLLATE DATABASE_DEFAULT = tblVillages.VillageCode COLLATE DATABASE_DEFAULT
										AND #tempVillages.WardCode COLLATE DATABASE_DEFAULT = tblWards.WardCode COLLATE DATABASE_DEFAULT
				)
		BEGIN
			ROLLBACK TRAN
			--RETURN -3
		END
	ELSE
		--INSERT INTO tblVillages(WardID,VillageName,VillageCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, MalePopulation,FemalePopulation,OtherPopulation,Families, AuditUserId)
		SELECT VillageCode,REPLACE(#tempVillages.VillageName,CHAR(9),''),tblWards.WardID,'V', MalePopulation,FemalePopulation,OtherPopulation,Families,-1
		FROM #tempVillages 
		INNER JOIN tblWards ON #tempVillages.WardCode COLLATE DATABASE_DEFAULT = tblWards.WardCode COLLATE DATABASE_DEFAULT 
		--LEFT OUTER JOIN tblVillages V ON #tempVillages.VillageCode COLLATE DATABASE_DEFAULT = V.VillageCode COLLATE DATABASE_DEFAULT AND V.ValidityTo IS  NULL
		WHERE VillageName IS NOT NULL
	
	COMMIT TRAN				
	
		--DROP ALL THE TEMP TABLES
		DROP TABLE #tempRegion
		DROP TABLE #tempDistricts
		DROP TABLE #tempWards
		DROP TABLE #tempVillages
	
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRAN;
		THROW SELECT ERROR_MESSAGE();
	END CATCH
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspImportOffLineExtract1]
	@AuditUser as int = 0 ,
	@xLocations as dbo.xLocations READONLY,
	@LocationsIns as bigint = 0 OUTPUT,  
	@LocationsUpd as bigint  = 0 OUTPUT
	
AS
BEGIN
	--SELECT * INTO REGIONS FROM @xtRegions
	--RETURN
	--**S Locations**
	
	SET NOCOUNT OFF
	UPDATE Src  SET Src.LocationCode = Etr.LocationCode ,Src.LocationName = Etr.LocationName,Src.ParentLocationId = Etr.ParentLocationId, 
	Src.LocationType = Etr.LocationType , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo, Src.LegacyId = Etr.LegacyId,
	Src.AuditUserId = @AuditUser
	FROM tblLocations Src , @xLocations Etr
	WHERE Src.LocationId = Etr.LocationId
	
	SET @LocationsUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT tblLocations ON
	--INSERT INTO [dbo].[tblRegions](RegionId,RegionName,RegionCode,[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID])   
	INSERT INTO tblLocations(LocationId, LocationCode, LocationName, ParentLocationId, LocationType, ValidityFrom, ValidityTo, Legacyid, AuditUserId)
	SELECT LocationId,LocationCode,LocationName, ParentLocationId, LocationType,[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser 
	FROM @xLocations 
	WHERE LocationId NOT IN 
	(SELECT LocationId FROM tblLocations)
 

	SET @LocationsIns  = @@ROWCOUNT
	SET IDENTITY_INSERT tblLocations OFF
	SET NOCOUNT ON
	--**E Locations*
	 
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspImportOffLineExtract2]
	
	@HFID as int = 0,
	@LocationId INT = 0,
	@AuditUser as int = 0 ,
	@xtItems dbo.xItems READONLY,
	@xtServices dbo.xServices READONLY,
	@xtPLItems dbo.xPLItems READONLY,
	@xtPLItemsDetail dbo.xPLItemsDetail READONLY,
	@xtPLServices dbo.xPLServices READONLY,
	@xtPLServicesDetail dbo.xPLServicesDetail READONLY,
	@ItemsIns as bigint = 0 OUTPUT  ,
	@ItemsUpd as bigint = 0 OUTPUT  ,
	@ServicesIns as bigint = 0 OUTPUT  ,
	@ServicesUpd as bigint  = 0 OUTPUT  ,
	@PLItemsIns as bigint = 0 OUTPUT  ,
	@PLItemsUpd as bigint  = 0 OUTPUT,
	@PLItemsDetailIns as bigint = 0 OUTPUT  ,
	@PLItemsDetailUpd as bigint  = 0 OUTPUT , 
	@PLServicesIns as bigint = 0 OUTPUT  ,
	@PLServicesUpd as bigint  = 0 OUTPUT,
	@PLServicesDetailIns as bigint = 0 OUTPUT  ,
	@PLServicesDetailUpd as bigint  = 0 OUTPUT
	
	
AS
BEGIN
	
	--**S Items**
	SET NOCOUNT OFF
	UPDATE Src  SET Src.ItemCode = Etr.ItemCode ,Src.ItemName = Etr.ItemName ,Src.ItemType = Etr.ItemType , Src.ItemPackage = Etr.ItemPackage , Src.ItemPrice = Etr.ItemPrice , Src.ItemCareType = Etr.ItemCareType, Src.ItemFrequency = Etr.ItemFrequency, Src.[ItemPatCat] = Etr.ItemPatCat,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser  FROM tblItems  Src , @xtItems  Etr WHERE Src.ItemID  = Etr.ItemID   
	SET @ItemsUpd  = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblItems] ON
	
	INSERT INTO dbo.tblItems ([ItemID],[ItemCode],[ItemName],[ItemType],[ItemPackage],[ItemPrice],[ItemCareType],[ItemFrequency],[ItemPatCat],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID]) 
	SELECT [ItemID],[ItemCode],[ItemName],[ItemType],[ItemPackage],[ItemPrice],[ItemCareType],[ItemFrequency],[ItemPatCat],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtItems WHERE [ItemID] NOT IN 
	(SELECT ItemID FROM tblItems)
	
	SET @ItemsIns  = @@ROWCOUNT
	SET IDENTITY_INSERT [tblItems] OFF
	SET NOCOUNT ON
	--**E Items**
	
	--**S Services**
	SET NOCOUNT OFF
	UPDATE Src SET Src.[ServCode] = Etr.[ServCode], Src.[ServName] = Etr.[ServName] ,Src.[ServType] = Etr.[ServType] ,Src.ServLevel = Etr.ServLevel ,Src.ServPrice = Etr.ServPrice, Src.ServCareType = Etr.ServCareType ,Src.ServFrequency = Etr.ServFrequency, Src.ServPatCat = Etr.ServPatCat , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser FROM tblServices Src , @xtServices Etr WHERE Src.ServiceID  = Etr.ServiceID 
	SET @ServicesUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblServices] ON
	INSERT INTO dbo.tblServices ([ServiceID],[ServCode],[ServName],[ServType],[ServLevel],[ServPrice],[ServCareType],[ServFrequency],[ServPatCat],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID]) 
	SELECT [ServiceID],[ServCode],[ServName],[ServType],[ServLevel],[ServPrice],[ServCareType],[ServFrequency],[ServPatCat],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtServices  WHERE [ServiceID]  NOT IN 
	(Select ServiceID from tblServices)
	
	SET @ServicesIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblServices] OFF
	SET NOCOUNT ON
	--**E Services**
	
	--**S PLItems**
	SET NOCOUNT OFF
	UPDATE Src SET Src.PLItemName = Etr.PLItemName ,Src.DatePL = Etr.DatePL ,Src.LocationId = Etr.LocationId , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser FROM tblPLItems Src , @xtPLItems Etr WHERE Src.PLItemID  = Etr.PLItemID 
	SET @PLItemsUpd  = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPLItems] ON
	INSERT INTO dbo.tblPLItems ([PLItemID],[PLItemName],[DatePL],[LocationId],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID])
	SELECT [PLItemID],[PLItemName],[DatePL],[LocationId],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtPLItems WHERE [PLItemID] NOT IN 
	(SELECT PLItemID FROM tblPLItems)
	--AND (LocationId = @LocationId OR @LocationId = 0)
	
	SET @PLItemsIns  = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPLItems] OFF
	SET NOCOUNT ON
	--**E PLItems**
	
	--**S PLItemsDetail**
	SET NOCOUNT OFF
	UPDATE Src SET Src.PLItemID = Etr.PLItemID, Src.ItemID = Etr.ItemID, Src.PriceOverule = Etr.PriceOverule ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser FROM tblPLItemsDetail Src , @xtPLItemsDetail  Etr WHERE Src.PLItemDetailID   = Etr.PLItemDetailID  
	SET @PLItemsDetailUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPLItemsDetail] ON
	INSERT INTO [tblPLItemsDetail] ([PLItemDetailID],[PLItemID],[ItemID],[PriceOverule],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID]) 
	SELECT [PLItemDetailID],[PLItemID],[ItemID],[PriceOverule],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser 
	FROM @xtPLItemsDetail 
	WHERE [PLItemDetailID] NOT IN 
	(SELECT PLItemDetailID  FROM tblPLItemsDetail )
	AND PLItemID IN (SELECT PLItemID FROM tblPLItems)
	
	SET @PLItemsDetailIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPLItemsDetail] OFF
	SET NOCOUNT ON
	--**E PLItemsDetail**
	
		
	--**S PLServices**
	SET NOCOUNT OFF
	UPDATE Src SET Src.PLServName = Etr.PLServName ,Src.DatePL = Etr.DatePL ,Src.LocationId = Etr.LocationId , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser FROM tblPLServices Src , @xtPLServices Etr WHERE Src.PLServiceID  = Etr.PLServiceID 
	SET @PLServicesUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPLServices] ON
	INSERT INTO dbo.tblPLServices ([PLServiceID],[PLServName],[DatePL],[LocationId],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID])
	SELECT [PLServiceID],[PLServName],[DatePL],[LocationId],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtPLServices  WHERE [PLServiceID] NOT IN 
	(SELECT PLServiceID FROM tblPLServices)
	--AND (LocationId = @LocationId OR @LocationId = 0)
	
	SET @PLServicesIns  = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPLServices] OFF
	SET NOCOUNT ON
	--**E PLServices**
	
	--**S PLServicesDetail**
	SET NOCOUNT OFF
	UPDATE Src SET Src.PLServiceID = Etr.PLServiceID, Src.ServiceID = Etr.ServiceID, Src.PriceOverule = Etr.PriceOverule ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser FROM tblPLServicesDetail Src , @xtPLServicesDetail  Etr WHERE Src.PLServiceDetailID   = Etr.PLServiceDetailID  
	SET @PLServicesDetailUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPLServicesDetail] ON
	INSERT INTO [tblPLServicesDetail] ([PLServiceDetailID],[dbo].[tblPLServicesDetail].[PLServiceID],[ServiceID],[PriceOverule],[dbo].[tblPLServicesDetail].[ValidityFrom],[dbo].[tblPLServicesDetail].[ValidityTo],[dbo].[tblPLServicesDetail].[LegacyID],[dbo].[tblPLServicesDetail].[AuditUserID]) 
	SELECT [PLServiceDetailID],[PLServiceID],[ServiceID],[PriceOverule],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtPLServicesDetail WHERE [PLServiceDetailID] NOT IN 
	(SELECT PLServiceDetailID  FROM tblPLServicesDetail )
	AND PLServiceID IN (SELECT PLServiceID FROM tblPLServices)
		
	SET @PLServicesDetailIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPLServicesDetail] OFF
	SET NOCOUNT ON
	--**E PLServicesDetail**
			
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspImportOffLineExtract3]
(

	@HFID as int = 0,
	@DistrictId INT = 0,
	@AuditUser as int = 0 ,
	@xtICDCodes dbo.xICDCodes READONLY,
	@xtHF dbo.xHF READONLY,
	@xtOfficers dbo.xOfficers READONLY,
	@xtPayers dbo.xPayers READONLY,
	@xtProduct dbo.xProduct READONLY,
	@xtProductItems dbo.xProductItems READONLY,
	@xtProductServices dbo.xProductServices READONLY,
	@xtRelDistr dbo.xRelDistr READONLY,
	@xtClaimAdmin dbo.xClaimAdmin READONLY,
	@xtVillageOfficer dbo.xOfficerVillages READONLY,
	@xGender as dbo.xGender READONLY,

	@ICDIns as bigint = 0 OUTPUT  ,
	@ICDUpd as bigint = 0 OUTPUT  ,
	@HFIns as bigint = 0 OUTPUT  ,
	@HFUpd as bigint  = 0 OUTPUT  ,
	@PayersIns as bigint = 0 OUTPUT  ,
	@PayersUpd as bigint  = 0 OUTPUT,
	@OfficersIns as bigint = 0 OUTPUT  ,
	@OfficersUpd as bigint  = 0 OUTPUT , 
	@ProductIns as bigint = 0 OUTPUT  ,
	@ProductUpd as bigint  = 0 OUTPUT,
	@ProductItemsIns as bigint = 0 OUTPUT  ,
	@ProductItemsUpd as bigint  = 0 OUTPUT,
	@ProductServicesIns as bigint = 0 OUTPUT  ,
	@ProductServicesUpd as bigint  = 0 OUTPUT,
	@RelDistrIns as bigint = 0 OUTPUT  ,
	@RelDistrUpd as bigint  = 0 OUTPUT,
	@ClaimAdminIns BIGINT = 0 OUTPUT,
	@ClaimAdminUpd BIGINT = 0 OUTPUT,
	@OfficerVillageIns BIGINT = 0 OUTPUT,
	@OfficerVillageUpd BIGINT = 0 OUTPUT

)
AS
BEGIN
	
	--**S ICD**
	SET NOCOUNT OFF
	UPDATE Src SET Src.ICDCode = Etr.ICDCode , Src.ICDName = Etr.ICDName , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser  FROM tblICDCodes  Src , @xtICDCodes  Etr WHERE Src.ICDID  = Etr.ICDID   
	SET @ICDUpd  = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblICDCodes] ON
	
	INSERT INTO tblICDCodes ([ICDID],[ICDCode],[ICDName],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID]) 
	SELECT [ICDID],[ICDCode],[ICDName],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtICDCodes  WHERE [ICDID] NOT IN 
	(SELECT ICDID FROM tblICDCodes)
	
	SET @ICDIns  = @@ROWCOUNT
	SET IDENTITY_INSERT [tblICDCodes] OFF
	SET NOCOUNT ON
	--**E ICD**
	
	--**S HF**
	SET NOCOUNT OFF
	UPDATE Src SET Src.HFCode = Etr.HFCode,Src.HFName=Etr.HFName,Src.LegalForm=Etr.LegalForm ,Src.HFLevel=Etr.HFLevel,Src.HFSublevel = Etr.HFSublevel ,Src.HFAddress=Etr.HFAddress,Src.LocationId=Etr.LocationId,Src.Phone=Etr.Phone,Src.Fax= Etr.Fax,Src.eMail=Etr.eMail,Src.HFCareType=Etr.HFCareType,Src.PLServiceID=Etr.PLServiceID,Src.PLItemID=Etr.PLItemID,Src.AccCode= Etr.AccCode ,Src.[OffLine] = Etr.[offLine] , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser  FROM tblHF  Src , @xtHF  Etr WHERE Src.HFID  = Etr.HFID   
	SET @HFUpd  = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblHF] ON
	
	INSERT INTO tblHF ([HfID],[HFCode],[HFName],[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[PLServiceID],[PLItemID],[AccCode],[OffLine],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID])
	SELECT [HfID],[HFCode],[HFName],[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[PLServiceID],[PLItemID],[AccCode],[OffLine],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser 
	FROM @xtHF  WHERE [HFID]  NOT IN
	(SELECT HfID from tblHF)
	
	SET @HFIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblHF] OFF
	SET NOCOUNT ON
	--**E HF**
	
	--**S Officers**
	SET NOCOUNT OFF
	UPDATE Src  SET Src.Code= Etr.Code ,Src.LastName= Etr.LastName ,Src.OtherNames = Etr.OtherNames ,Src.DOB =Etr.DOB ,Src.Phone = Etr.Phone ,Src.LocationId = Etr.LocationId ,Src.OfficerIDSubst = Etr.OfficerIDSubst ,Src.WorksTo = Etr.WorksTo ,Src.VEOCode = Etr.VEOCode ,Src.VEOLastName = Etr.VEOLastName ,Src.VEOOtherNames = Etr.VEOOtherNames ,Src.VEODOB = Etr.VEODOB ,Src.VEOPhone = Etr.VEOPhone ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser,Src.EmailId = Etr.EmailId, Src.PhoneCommunication = Etr.PhoneCommunication, Src.PermanentAddress=Etr.PermanentAddress  FROM tblOfficer Src , @xtOfficers Etr WHERE Src.OfficerID   = Etr.OfficerID   
	SET @OfficersUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblOfficer] ON
	
	INSERT INTO tblOfficer ([OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],EmailId, [PhoneCommunication],[PermanentAddress])
	SELECT [OfficerID],[Code],[LastName],[OtherNames],[DOB],[Phone],[LocationId],[OfficerIDSubst],[WorksTo],[VEOCode],[VEOLastName],[VEOOtherNames],[VEODOB],[VEOPhone],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser,EmailId, PhoneCommunication,PermanentAddress
	FROM @xtOfficers WHERE [OfficerID] NOT IN
	(SELECT OfficerID FROM tblOfficer)
	--AND (DistrictID = @DistrictId OR @DistrictId = 0) 'To do: Insuree can belong to different district.So his/her family's policy's officers belonging to another district should not be ruled out. 
	
	SET @OfficersIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblOfficer] OFF
	SET NOCOUNT ON
	--**E Offciers**
	
	--**S Payers**
	SET NOCOUNT OFF
	UPDATE Src  SET Src.PayerType = Etr.PayerType ,Src.PayerName = Etr.PayerName ,Src.PayerAddress = Etr.PayerAddress ,Src.LocationId = Etr.LocationId ,Src.Phone = Etr.Phone ,Src.Fax = Etr.Fax ,Src.eMail = Etr.eMail ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser  FROM tblPayer Src , @xtpayers Etr WHERE Src.PayerID   = Etr.PayerID   
	SET @PayersUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPayer] ON
	
	INSERT INTO tblPayer ([PayerID],[PayerType],[PayerName],[PayerAddress],[LocationId],[Phone],[Fax],[eMail],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID])
	SELECT [PayerID],[PayerType],[PayerName],[PayerAddress],[LocationId],[Phone],[Fax],[eMail],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtPayers  WHERE [PayerID]  NOT IN
	(SELECT PayerID From tblPayer)
	--AND (DistrictID = @DistrictId OR DistrictId IS NULL)
	
	SET @PayersIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPayer] OFF
	SET NOCOUNT ON
	--**E Payers**
	
	--**S Product**
	SET NOCOUNT OFF
	UPDATE Src SET Src.ProductCode = Etr.ProductCode ,Src.ProductName = Etr.ProductName ,Src.LocationId = Etr.LocationId ,Src.InsurancePeriod = Etr.InsurancePeriod ,Src.DateFrom = Etr.DateFrom ,Src.DateTo = Etr.DateTo ,Src.ConversionProdID = Etr.ConversionProdID ,Src.LumpSum = Etr.LumpSum ,Src.MemberCount = Etr.MemberCount ,Src.PremiumAdult = Etr.PremiumAdult ,Src.PremiumChild = Etr.PremiumChild ,Src.DedInsuree = Etr.DedInsuree ,Src.DedOPInsuree = Etr.DedOPInsuree ,Src.DedIPInsuree = Etr.DedIPInsuree ,Src.MaxInsuree = Etr.MaxInsuree ,Src.MaxOPInsuree = Etr.MaxOPInsuree ,Src.MaxIPInsuree = Etr.MaxIPInsuree ,Src.PeriodRelPrices = Etr.PeriodRelPrices  ,Src.PeriodRelPricesOP = Etr.PeriodRelPricesOP ,Src.PeriodRelPricesIP = Etr.PeriodRelPricesIP ,Src.AccCodePremiums = Etr.AccCodePremiums ,Src.AccCodeRemuneration = Etr.AccCodeRemuneration ,Src.DedTreatment = Etr.DedTreatment ,Src.DedOPTreatment = Etr.DedOPTreatment ,Src.DedIPTreatment = Etr.DedIPTreatment ,Src.MaxTreatment = Etr.MaxTreatment ,Src.MaxOPTreatment = Etr.MaxOPTreatment ,Src.MaxIPTreatment = Etr.MaxIPTreatment ,Src.DedPolicy = Etr.DedPolicy ,Src.DedOPPolicy = Etr.DedOPPolicy ,Src.DedIPPolicy = Etr.DedIPPolicy ,Src.MaxPolicy = Etr.MaxPolicy ,Src.MaxOPPolicy = Etr.MaxOPPolicy ,Src.MaxIPPolicy = Etr.MaxIPPolicy ,Src.GracePeriod = Etr.GracePeriod ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser,Src.RegistrationLumpSum = Etr.RegistrationLumpSum,Src.RegistrationFee = Etr.RegistrationFee,Src.GeneralAssemblyLumpSum = Etr.GeneralAssemblyLumpSum,Src.GeneralAssemblyFee = Etr.GeneralAssemblyFee,Src.StartCycle1 = Etr.StartCycle1,Src.StartCycle2 = Etr.StartCycle2,Src.MaxNoConsultation = Etr.MaxNoConsultation,Src.MaxNoSurgery = Etr.MaxNoSurgery,Src.MaxNoDelivery = Etr.MaxNoDelivery,Src.MaxNoHospitalizaion = Etr.MaxNoHospitalizaion,Src.MaxNoVisits = Etr.MaxNoVisits,Src.MaxAmountConsultation = Etr.MaxAmountConsultation,Src.MaxAmountSurgery = Etr.MaxAmountSurgery,Src.MaxAmountDelivery = Etr.MaxAmountDelivery,Src.MaxAmountHospitalization = Etr.MaxAmountHospitalization,Src.GracePeriodRenewal = Etr.GracePeriodRenewal, Src.MaxInstallments = Etr.MaxInstallments,Src.WaitingPeriod = Etr.WaitingPeriod,src.RenewalDiscountPerc = Etr.RenewalDiscountPerc,Src.RenewalDiscountPeriod = Etr.RenewalDiscountPeriod,Src.StartCycle3 = Etr.StartCycle3,Src.StartCycle4 = Etr.StartCycle4,Src.AdministrationPeriod = Etr.AdministrationPeriod,Src.Threshold = Etr.Threshold
		,Src.MaxPolicyExtraMember = Etr.MaxPolicyExtraMember,Src.MaxPolicyExtraMemberIP = Etr.MaxPolicyExtraMemberIP,Src.MaxPolicyExtraMemberOP = Etr.MaxPolicyExtraMemberOP,Src.MaxCeilingPolicy = Etr.MaxCeilingPolicy,Src.MaxCeilingPolicyIP = Etr.MaxCeilingPolicyIP,Src.MaxCeilingPolicyOP = Etr.MaxCeilingPolicyOP, Src.EnrolmentDiscountPerc = Etr.EnrolmentDiscountPerc, Src.EnrolmentDiscountPeriod = Etr.EnrolmentDiscountPeriod,Src.MaxAmountAntenatal = Etr.MaxAmountAntenatal,Src.MaxNoAntenatal = Etr.MaxNoAntenatal
		,Src.CeilingInterpretation = Etr.CeilingInterpretation,
		Src.Level1=Etr.Level1,
		Src.Sublevel1=Etr.Sublevel1,
		Src.Level2=Etr.Sublevel2,
		Src.Level3=Etr.Sublevel3,
		Src.Level4=Etr.Sublevel4,
		Src.ShareContribution=Etr.Sublevel1,
	Src.WeightPopulation=Etr.WeightPopulation,
	Src.WeightNumberFamilies =Etr.WeightNumberFamilies,
	Src.WeightInsuredPopulation=Etr.WeightInsuredPopulation,
	Src.WeightNumberInsuredFamilies=Etr.WeightNumberInsuredFamilies,
	Src.WeightNumberVisits=Etr.WeightNumberVisits,
	Src.WeightAdjustedAmount=Etr.WeightAdjustedAmount
		 FROM tblProduct Src , @xtProduct  Etr 
		WHERE Src.ProdID = Etr.ProdID   
	SET @ProductUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblProduct] ON
	
	INSERT INTO tblProduct ([ProdID],[ProductCode],[ProductName],[LocationId],[InsurancePeriod],[DateFrom],[DateTo],[ConversionProdID],[LumpSum],[MemberCount],[PremiumAdult],[PremiumChild],[DedInsuree],[DedOPInsuree],[DedIPInsuree],[MaxInsuree],[MaxOPInsuree],[MaxIPInsuree],[PeriodRelPrices],[PeriodRelPricesOP],[PeriodRelPricesIP],[AccCodePremiums],[AccCodeRemuneration],[DedTreatment],[DedOPTreatment],[DedIPTreatment],[MaxTreatment],[MaxOPTreatment],[MaxIPTreatment],[DedPolicy],[DedOPPolicy],[DedIPPolicy],[MaxPolicy],[MaxOPPolicy],[MaxIPPolicy],[GracePeriod],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],RegistrationLumpSum,RegistrationFee,GeneralAssemblyLumpSum,GeneralAssemblyFee,StartCycle1,StartCycle2,MaxNoConsultation,MaxNoSurgery,MaxNoDelivery,MaxNoHospitalizaion,MaxNoVisits,MaxAmountConsultation,MaxAmountSurgery,MaxAmountDelivery,MaxAmountHospitalization,GracePeriodRenewal,MaxInstallments,WaitingPeriod,RenewalDiscountPerc,RenewalDiscountPeriod,StartCycle3,StartCycle4,AdministrationPeriod,Threshold
		,MaxPolicyExtraMember,MaxPolicyExtraMemberIP,MaxPolicyExtraMemberOP,MaxCeilingPolicy,MaxCeilingPolicyIP,MaxCeilingPolicyOP, EnrolmentDiscountPerc, EnrolmentDiscountPeriod,MaxAmountAntenatal,MaxNoAntenatal,CeilingInterpretation, [Level1],[Sublevel1],[Level2] ,[Sublevel2] ,[Level3] ,[Sublevel3] ,[Level4] ,[Sublevel4] ,[ShareContribution],[WeightPopulation],[WeightNumberFamilies],[WeightInsuredPopulation] ,[WeightNumberInsuredFamilies] ,[WeightNumberVisits] ,[WeightAdjustedAmount] )
	SELECT [ProdID],[ProductCode],[ProductName],[LocationId],[InsurancePeriod],[DateFrom],[DateTo],[ConversionProdID],[LumpSum],[MemberCount],[PremiumAdult],[PremiumChild],[DedInsuree],[DedOPInsuree],[DedIPInsuree],[MaxInsuree],[MaxOPInsuree],[MaxIPInsuree],[PeriodRelPrices],[PeriodRelPricesOP],[PeriodRelPricesIP],[AccCodePremiums],[AccCodeRemuneration],[DedTreatment],[DedOPTreatment],[DedIPTreatment],[MaxTreatment],[MaxOPTreatment],[MaxIPTreatment],[DedPolicy],[DedOPPolicy],[DedIPPolicy],[MaxPolicy],[MaxOPPolicy],[MaxIPPolicy],[GracePeriod],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser,RegistrationLumpSum,RegistrationFee,GeneralAssemblyLumpSum,GeneralAssemblyFee,StartCycle1,StartCycle2,MaxNoConsultation,MaxNoSurgery,MaxNoDelivery,MaxNoHospitalizaion,MaxNoVisits,MaxAmountConsultation,MaxAmountSurgery,MaxAmountDelivery,MaxAmountHospitalization,GracePeriodRenewal,MaxInstallments,WaitingPeriod,RenewalDiscountPerc,RenewalDiscountPeriod,StartCycle3,StartCycle4,AdministrationPeriod,Threshold
		,MaxPolicyExtraMember,MaxPolicyExtraMemberIP,MaxPolicyExtraMemberOP,MaxCeilingPolicy,MaxCeilingPolicyIP,MaxCeilingPolicyOP, EnrolmentDiscountPerc, EnrolmentDiscountPeriod,MaxAmountAntenatal,MaxNoAntenatal,CeilingInterpretation, [Level1],[Sublevel1],[Level2] ,[Sublevel2] ,[Level3] ,[Sublevel3] ,[Level4] ,[Sublevel4] ,[ShareContribution],[WeightPopulation],[WeightNumberFamilies],[WeightInsuredPopulation] ,[WeightNumberInsuredFamilies] ,[WeightNumberVisits] ,[WeightAdjustedAmount]  FROM @xtProduct  
		WHERE [ProdID]  NOT IN (SELECT ProdID FROM tblProduct)
	--AND ((DistrictID = @DistrictId OR @DistrictId = 0) OR DistrictID IS NULL)
	
	SET @ProductIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblProduct] OFF
	SET NOCOUNT ON
	--**E Product**
	
	--**S ProductItems**
	SET NOCOUNT OFF
	UPDATE Src  SET Src.ProdID = Etr.ProdID ,Src.ItemID = Etr.ItemID ,Src.LimitationType = Etr.LimitationType ,Src.PriceOrigin = Etr.PriceOrigin ,Src.LimitAdult = Etr.LimitAdult ,Src.LimitChild = Etr.LimitChild  ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser,Src.WaitingPeriodAdult = Etr.WaitingPeriodAdult,Src.WaitingPeriodChild = Etr.WaitingPeriodChild,Src.LimitNoAdult = Etr.LimitNoChild,Src.LimitationTypeR = Etr.LimitationTypeR,Src.LimitationTypeE = Etr.LimitationTypeE,Src.LimitAdultR = Etr.LimitAdultR,Src.LimitAdultE = Etr.LimitAdultE,Src.LimitChildR = Etr.LimitChildR,Src.LimitChildE = Etr.LimitChildE,Src.CeilingExclusionAdult = Etr.CeilingExclusionAdult,Src.CeilingExclusionChild = Etr.CeilingExclusionChild  FROM tblProductItems Src , @xtProductItems Etr WHERE Src.ProdItemID = Etr.ProdItemID   
	SET @ProductItemsUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblProductItems] ON
	
	INSERT INTO tblProductItems ([ProdItemID],[tblProductItems].[ProdID],[ItemID],[LimitationType],[PriceOrigin],[LimitAdult],[LimitChild],[tblProductItems].[ValidityFrom] ,[tblProductItems].[ValidityTo],[tblProductItems].[LegacyID],[AuditUserID],WaitingPeriodAdult,WaitingPeriodChild,LimitNoAdult,LimitNoChild,LimitationTypeR,LimitationTypeE,LimitAdultR,LimitAdultE,LimitChildR,LimitChildE,CeilingExclusionAdult,CeilingExclusionChild)
	SELECT [ProdItemID],[ProdID],[ItemID],[LimitationType],[PriceOrigin],[LimitAdult],[LimitChild],[ValidityFrom] ,[ValidityTo],[LegacyID],@AuditUser,WaitingPeriodAdult,WaitingPeriodChild,LimitNoAdult,LimitNoChild,LimitationTypeR,LimitationTypeE,LimitAdultR,LimitAdultE,LimitChildR,LimitChildE,CeilingExclusionAdult,CeilingExclusionChild FROM @xtProductItems   WHERE [ProdItemID] NOT IN
	(SELECT ProdItemID FROM tblProductItems)
	AND ProdID IN (SELECT ProdID FROM tblProduct)
	
	SET @ProductItemsIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblProductItems] OFF
	SET NOCOUNT ON
	--**E ProductItems**
	
	--**S ProductServices**
	SET NOCOUNT OFF
	UPDATE Src  SET Src.ProdID = Etr.ProdID ,Src.ServiceID = Etr.ServiceID ,Src.LimitationType = Etr.LimitationType ,Src.PriceOrigin = Etr.PriceOrigin ,Src.LimitAdult = Etr.LimitAdult ,Src.LimitChild = Etr.LimitChild  ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser,Src.WaitingPeriodAdult = Etr.WaitingPeriodAdult,Src.WaitingPeriodChild = Etr.WaitingPeriodChild,Src.LimitNoAdult = Etr.LimitNoChild,Src.LimitationTypeR = Etr.LimitationTypeR,Src.LimitationTypeE = Etr.LimitationTypeE,Src.LimitAdultR = Etr.LimitAdultR,Src.LimitAdultE = Etr.LimitAdultE,Src.LimitChildR = Etr.LimitChildR,Src.LimitChildE = Etr.LimitChildE,Src.CeilingExclusionAdult = Etr.CeilingExclusionAdult,Src.CeilingExclusionChild = Etr.CeilingExclusionChild  FROM tblProductServices Src , @xtProductServices Etr WHERE Src.ProdServiceID = Etr.ProdServiceID   
	SET @ProductServicesUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblProductServices] ON
	
	INSERT INTO tblProductServices ([ProdServiceID],[tblProductServices].[ProdID],[ServiceID],[LimitationType],[PriceOrigin],[LimitAdult],[LimitChild],[tblProductServices].[ValidityFrom] ,[tblProductServices].[ValidityTo],[tblProductServices].[LegacyID],[AuditUserID],WaitingPeriodAdult,WaitingPeriodChild,LimitNoAdult,LimitNoChild,LimitationTypeR,LimitationTypeE,LimitAdultR,LimitAdultE,LimitChildR,LimitChildE,CeilingExclusionAdult,CeilingExclusionChild )
	SELECT [ProdServiceID],[ProdID],[ServiceID],[LimitationType],[PriceOrigin],[LimitAdult],[LimitChild],[ValidityFrom] ,[ValidityTo],[LegacyID],@AuditUser,WaitingPeriodAdult,WaitingPeriodChild,LimitNoAdult,LimitNoChild,LimitationTypeR,LimitationTypeE,LimitAdultR,LimitAdultE,LimitChildR,LimitChildE,CeilingExclusionAdult,CeilingExclusionChild   FROM @xtProductServices  WHERE [ProdServiceID] NOT IN
	(SELECT ProdServiceID FROM tblProductServices)
	AND ProdID IN (SELECT ProdID FROM tblProduct)
	
	SET @ProductServicesIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblProductServices] OFF
	SET NOCOUNT ON
	--**E ProductServices**
	
	--**S RelDistr**
	SET NOCOUNT OFF
	UPDATE Src  SET Src.DistrType = Etr.DistrType ,Src.DistrCareType = Etr.DistrCareType ,Src.ProdID =Etr.ProdID ,Src.Period = Etr.Period ,Src.DistrPerc = Etr.DistrPerc ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser  FROM tblRelDistr Src , @xtRelDistr Etr WHERE Src.DistrID = Etr.DistrID  
	SET @RelDistrUpd  = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblRelDistr] ON
	
	INSERT INTO tblRelDistr ([DistrID],[DistrType] ,[DistrCareType],[dbo].[tblRelDistr].[ProdID],[Period],[DistrPerc],[dbo].[tblRelDistr].[ValidityFrom],[dbo].[tblRelDistr].[ValidityTo],[dbo].[tblRelDistr].[LegacyID],[dbo].[tblRelDistr].[AuditUserID])
	SELECT [DistrID],[DistrType] ,[DistrCareType],[ProdID],[Period],[DistrPerc],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtRelDistr WHERE [DistrID] NOT IN
	(SELECT DistrID FROM tblRelDistr)
	AND (DistrID = @DistrictId OR @DistrictId = 0)
	
	SET @RelDistrIns  = @@ROWCOUNT
	SET IDENTITY_INSERT [tblRelDistr] OFF
	SET NOCOUNT ON
	--**E RelDistr**
	
		
	--*S ClaimAdmin**
	SET NOCOUNT OFF
	UPDATE Src SET Src.ClaimAdminCode = Etr.ClaimAdminCode,Src.LastName = Etr.LastName,Src.OtherNames = Etr.OtherNames,Src.DOB = Etr.DOB,Src.Phone = Etr.Phone,Src.HFId = Etr.HFId,Src.ValidityFrom = Etr.ValidityFrom,Src.ValidityTo = Etr.ValidityTo,Src.LegacyId = Etr.LegacyId,Src.AuditUserId = Etr.AuditUserId,Src.EmailId = Etr.EmailId FROM tblClaimAdmin Src,@xtClaimAdmin Etr WHERE Src.ClaimAdminId = Etr.ClaimAdminId
	SET @ClaimAdminUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF
	SET IDENTITY_INSERT[tblClaimAdmin] ON
	
	INSERT INTO tblClaimAdmin(ClaimAdminId,ClaimAdminCode,LastName,OtherNames,DOB,Phone,HFId,ValidityFrom,ValidityTo,LegacyId,AuditUserId,EmailId)
	SELECT ClaimAdminId,ClaimAdminCode,LastName,OtherNames,DOB,Phone,HFId,ValidityFrom,ValidityTo,LegacyId,@AuditUser,EmailId FROM @xtClaimAdmin 
	WHERE ClaimAdminId NOT IN(SELECT ClaimAdminId From tblClaimAdmin)
	AND HFId IN (SELECT HFId FROM tblHF)

	SET @ClaimAdminIns = @@ROWCOUNT
	SET IDENTITY_INSERT[tblClaimAdmin] OFF
	SET NOCOUNT ON;
	
	--*E ClaimAdmin**		
	
	
	--*S tblOfficerVillages**
	SET NOCOUNT OFF
	UPDATE Src SET  Src.OfficerId = Etr.OfficerId,Src.LocationId=Etr.LocationId,Src.AuditUserId=Etr.AuditUserId,Src.LegacyId=Etr.LegacyId,Src.ValidityFrom=Etr.ValidityFrom,Src.ValidityTo=Etr.ValidityTo FROM tblOfficerVillages Src,@xtVillageOfficer Etr WHERE Src.OfficerVillageId = Etr.OfficerVillageId
	SET @OfficerVillageUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF
	SET IDENTITY_INSERT[tblOfficerVillages] ON
	
	INSERT INTO tblOfficerVillages (OfficerVillageId,OfficerId,LocationId,ValidityFrom,ValidityTo,LegacyId,AuditUserId)
	SELECT OfficerVillageId,OfficerId,LocationId,ValidityFrom,ValidityTo,LegacyId,AuditUserId FROM @xtVillageOfficer
	WHERE OfficerVillageId NOT IN (SELECT OfficerVillageId FROM tblOfficerVillages)

	SET @OfficerVillageIns = @@ROWCOUNT
	SET IDENTITY_INSERT[tblOfficerVillages] OFF
	SET NOCOUNT ON;
	--*E tblOfficerVillages**		
	
	--Import Genders
	IF NOT EXISTS(SELECT 1 FROM tblGender)
	INSERT INTO tblGender(Code, Gender, AltLanguage, SortOrder)
	SELECT Code, Gender, AltLanguage, SortOrder FROM @xGender	
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspImportOffLineExtract4]
	
	@HFID as int = 0,
	@LocationId INT = 0,
	@AuditUser as int = 0 ,
	@xtFamilies dbo.xFamilies READONLY,
	@xtInsuree dbo.xInsuree READONLY,
	@xtPhotos dbo.xPhotos READONLY,
	@xtPolicy dbo.xPolicy READONLY,
	@xtPremium dbo.xPremium READONLY,
	@xtInsureePolicy dbo.xInsureePolicy READONLY,
	@FamiliesIns as bigint = 0 OUTPUT  ,
	@FamiliesUpd as bigint = 0 OUTPUT  ,
	@InsureeIns as bigint = 0 OUTPUT  ,
	@InsureeUpd as bigint  = 0 OUTPUT  ,
	@PhotoIns as bigint = 0 OUTPUT  ,
	@PhotoUpd as bigint  = 0 OUTPUT,
	@PolicyIns as bigint = 0 OUTPUT  ,
	@PolicyUpd as bigint  = 0 OUTPUT , 
	@PremiumIns as bigint = 0 OUTPUT  ,
	@PremiumUpd as bigint  = 0 OUTPUT
	
	
AS
BEGIN
	
BEGIN TRY
	/*
	SELECT * INTO TstFamilies  FROM @xtFamilies
	SELECT * INTO TstInsuree  FROM @xtInsuree
	SELECT * INTO TstPhotos  FROM @xtPhotos
	SELECT * INTO TstPolicy  FROM @xtPolicy
	SELECT * INTO TstPremium  FROM @xtPremium
	SELECT * INTO TstInsureePolicy  FROM @xtInsureePolicy
	RETURN
	**/

	--**S Families**
	SET NOCOUNT OFF
	UPDATE Src SET Src.InsureeID = Etr.InsureeID ,Src.LocationId = Etr.LocationId ,Src.Poverty = Etr.Poverty , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser, Src.FamilyType = Etr.FamilyType, Src.FamilyAddress = Etr.FamilyAddress,Src.ConfirmationType = Etr.ConfirmationType FROM tblFamilies Src , @xtFamilies Etr WHERE Src.FamilyID = Etr.FamilyID 
	SET @FamiliesUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblFamilies] ON
	
	INSERT INTO tblFamilies ([FamilyID],[InsureeID],[LocationId],[Poverty],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],FamilyType, FamilyAddress,Ethnicity,ConfirmationNo,ConfirmationType) 
	SELECT [FamilyID],[InsureeID],[LocationId],[Poverty],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser,FamilyType, FamilyAddress,Ethnicity,ConfirmationNo,  ConfirmationType FROM @xtFamilies WHERE [FamilyID] NOT IN 
	(SELECT FamilyID  FROM tblFamilies )
	--AND (DistrictID = @LocationId OR @LocationId = 0) 'To do: Insuree can belong to different district.So his/her family belonging to another district should not be ruled out.
	
	SET @FamiliesIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblFamilies] OFF
	SET NOCOUNT ON
	--**E Families**
	
	--**S Photos**
	SET NOCOUNT OFF
	UPDATE Src SET Src.InsureeID = Etr.InsureeID , Src.CHFID = Etr.CHFID , Src.PhotoFolder = Etr.PhotoFolder ,Src.PhotoFileName = Etr.PhotoFileName , Src.OfficerID = Etr.OfficerID , Src.PhotoDate = Etr.PhotoDate , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.AuditUserID = @AuditUser  
	FROM @xtPhotos Etr INNER JOIN TblPhotos Src ON Src.PhotoID = Etr.PhotoID INNER JOIN (SELECT Ins.InsureeID FROM @xtInsuree Ins WHERE ValidityTo IS NULL) Ins ON Ins.InsureeID  = Src.InsureeID 
	
	SET @PhotoUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPhotos] ON
	
	
	INSERT INTO tblPhotos (PhotoID,InsureeID, CHFID, PhotoFolder, PhotoFileName, OfficerID, PhotoDate,ValidityFrom, ValidityTo, AuditUserID)
	SELECT PhotoID,P.InsureeID, CHFID, PhotoFolder, PhotoFileName, OfficerID, PhotoDate,ValidityFrom, ValidityTo,@AuditUser 
	FROM @xtPhotos P --INNER JOIN (SELECT Ins.InsureeID FROM @xtInsuree Ins WHERE ValidityTo IS NULL) Ins ON Ins.InsureeID  = P.InsureeID 
	WHERE [PhotoID] NOT IN (SELECT PhotoID FROM tblPhotos )
	--AND InsureeID IN (SELECT InsureeID FROM @xtInsuree WHERE FamilyID IN (SELECT FamilyID FROM tblFamilies))
	
	
	SET @PhotoIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPhotos] OFF
	SET NOCOUNT ON
	--**E Photos
	
	--**S insurees**
	SET NOCOUNT OFF
	UPDATE Src SET Src.FamilyID = Etr.FamilyID  ,Src.CHFID = Etr.CHFID ,Src.LastName = Etr.LastName ,Src.OtherNames = Etr.OtherNames ,Src.DOB = Etr.DOB ,Src.Gender = Etr.Gender ,Src.Marital = Etr.Marital ,Src.IsHead = Etr.IsHead ,Src.passport = Etr.passport ,src.Phone = Etr.Phone ,Src.PhotoID = Etr.PhotoID  ,Src.PhotoDate = Etr.PhotoDate ,Src.CardIssued = Etr.CardIssued ,Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser,Src.Relationship = Etr.Relationship, Src.Profession = Etr.Profession,Src.Education = Etr.Education,Src.Email = Etr.Email , 
	Src.TypeOfId = Etr.TypeOfId, Src.HFID = Etr.HFID, Src.CurrentAddress = Etr.CurrentAddress, Src.GeoLocation = Etr.GeoLocation, Src.Vulnerability = Etr.Vulnerability
	FROM tblInsuree Src , @xtInsuree Etr WHERE Src.InsureeID = Etr.InsureeID 
	SET @InsureeUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblInsuree] ON
	
	INSERT INTO tblInsuree ([InsureeID],[FamilyID] ,[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],Relationship,Profession,Education,Email,TypeOfId,HFID, CurrentAddress, GeoLocation, CurrentVillage, Vulnerability)
	SELECT [InsureeID],[FamilyID] ,[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID] ,[PhotoDate],[CardIssued],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser,Relationship,Profession,Education,Email,TypeOfId,HFID, CurrentAddress, GeoLocation,CurrentVillage, Vulnerability
	FROM @xtInsuree WHERE [InsureeID] NOT IN 
	(SELECT InsureeID FROM tblInsuree)
	AND FamilyID IN (SELECT FamilyID FROM tblFamilies)
	
	SET @InsureeIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblInsuree] OFF
	SET NOCOUNT ON
	--**E Insurees**
	
	
	--**S Policies**
	SET NOCOUNT OFF
	UPDATE Src SET Src.FamilyID = Etr.FamilyID ,Src.EnrollDate = Etr.EnrollDate ,Src.StartDate = Etr.StartDate ,Src.EffectiveDate = Etr.EffectiveDate ,Src.ExpiryDate = Etr.ExpiryDate ,Src.PolicyStatus = Etr.PolicyStatus ,Src.PolicyValue = Etr.PolicyValue ,Src.ProdID = Etr.ProdID ,Src.OfficerID = Etr.OfficerID,Src.PolicyStage = Etr.PolicyStage , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser  FROM tblPolicy Src , @xtPolicy Etr WHERE Src.PolicyID = Etr.PolicyID 
	SET @PolicyUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPolicy] ON
	
	INSERT INTO tblPolicy ([PolicyID],[FamilyID],[EnrollDate],[StartDate],[EffectiveDate],[ExpiryDate],[PolicyStatus],[PolicyValue],[ProdID],[OfficerID],[PolicyStage],[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID])
	SELECT [PolicyID],[FamilyID],[EnrollDate],[StartDate],[EffectiveDate],[ExpiryDate],[PolicyStatus],[PolicyValue],[ProdID],[OfficerID],[PolicyStage],[ValidityFrom],[ValidityTo],[LegacyID],@AuditUser FROM @xtPolicy WHERE [PolicyID] NOT IN
	(SELECT PolicyID FROM tblPolicy)
	AND FamilyID IN (SELECT FamilyID FROM tblFamilies)
	
	SET @PolicyIns  = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPolicy] OFF
	SET NOCOUNT ON
	--**E Policies	
	
	--**S Premium**
	SET NOCOUNT OFF
	UPDATE Src SET Src.PolicyID = Etr.PolicyID ,Src.PayerID = Etr.PayerID , Src.Amount = Etr.Amount , Src.Receipt = Etr.Receipt ,Src.PayDate = Etr.PayDate ,Src.PayType = Etr.PayType , Src.ValidityFrom = Etr.ValidityFrom , Src.ValidityTo = Etr.ValidityTo , Src.LegacyID = Etr.LegacyID, Src.AuditUserID = @AuditUser, Src.isPhotoFee = Etr.isPhotoFee,Src.ReportingId = Etr.ReportingId  FROM tblPremium Src , @xtPremium Etr WHERE Src.PremiumId = Etr.PremiumId 
	SET @PremiumUpd = @@ROWCOUNT
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblPremium] ON
	
	INSERT INTO tblPremium (PremiumId, PolicyID, PayerID, Amount, Receipt,PayDate,PayType,ValidityFrom, ValidityTo, LegacyID, AuditUserID, isPhotoFee,ReportingId) 
	SELECT PremiumId, PolicyID, PayerID, Amount, Receipt,PayDate,PayType,ValidityFrom, ValidityTo, LegacyID, @AuditUser, isPhotoFee,ReportingId FROM @xtPremium WHERE PremiumId NOT IN 
	(SELECT PremiumId FROM tblPremium)
	AND PolicyID IN (SELECT PolicyID FROM tblPolicy)
	
	SET @PremiumIns = @@ROWCOUNT
	SET IDENTITY_INSERT [tblPremium] OFF
	SET NOCOUNT ON
	--**E Premium
	
	
	--**S InsureePolicy**
	SET NOCOUNT OFF
	UPDATE Src SET Src.InsureeId = Etr.InsureeId, Src.PolicyId = Etr.PolicyId, Src.EnrollmentDate = Etr.EnrollmentDate, Src.StartDate = Etr.StartDate, Src.EffectiveDate = Etr.EffectiveDate, Src.ExpiryDate = Etr.ExpiryDate, Src.ValidityFrom = Etr.ValidityFrom, Src.ValidityTo = Etr.ValidityTo, Src.LegacyId = Etr.LegacyId , Src.AuditUserID = @AuditUser  FROM tblInsureePolicy  Src , @xtInsureePolicy  Etr WHERE Src.InsureePolicyId  = Etr.InsureePolicyId AND Etr.PolicyId IN (Select PolicyID FROM tblPolicy) 
	SET NOCOUNT ON
	
	SET NOCOUNT OFF;
	SET IDENTITY_INSERT [tblInsureePolicy] ON
	
	INSERT INTO tblInsureePolicy (InsureePolicyId, InsureeId, PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,ValidityFrom,ValidityTo,LegacyId,AuditUserId)
	SELECT InsureePolicyId, InsureeId, PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,ValidityFrom,ValidityTo,LegacyId,@AuditUser FROM @xtInsureePolicy  WHERE InsureePolicyId NOT IN
	(SELECT InsureePolicyId FROM tblInsureePolicy) AND PolicyId IN (Select PolicyID FROM tblPolicy) 
	
	SET IDENTITY_INSERT [tblInsureePolicy] OFF
	SET NOCOUNT ON
	--**E InsureePolicy	
END TRY
BEGIN CATCH
	SELECT ERROR_MESSAGE();
END CATCH			
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspInsertFeedback]
(
	@XML XML
)
/*
	-1: Fatal Error
	0: All OK
	1: Invalid Officer code
	2: Claim does not exist
	3: Invalid CHFID
	4: FeedBack Exists
	
*/
AS
BEGIN
	
	BEGIN TRY
		DECLARE @Query NVARCHAR(3000)
		
		DECLARE @OfficerCode NVARCHAR(8)
		DECLARE @OfficerID INT
		DECLARE @ClaimID INT
		DECLARE @CHFID VARCHAR(12)
		DECLARE @Answers VARCHAR(5)
		DECLARE @FeedbackDate DATE

		SELECT
		@OfficerCode = feedback.value('(Officer)[1]','NVARCHAR(8)'),
		@ClaimID = feedback.value('(ClaimID)[1]','NVARCHAR(8)'),
		@CHFID  = feedback.value('(CHFID)[1]','VARCHAR(12)'),
		@Answers = feedback.value('(Answers)[1]','VARCHAR(5)'),
		@FeedbackDate = feedback.value('(Date)[1]','VARCHAR(10)')
		FROM @XML.nodes('feedback') AS T(feedback)

		DECLARE @ClaimCode NVARCHAR(8)

		SELECT @ClaimCode = ClaimCode FROM tblClaim WHERE ClaimID = @ClaimID AND ValidityTo IS NULL  

		IF NOT EXISTS(SELECT * FROM tblOfficer WHERE Code = @OfficerCode AND ValidityTo IS NULL)
			RETURN 1
		ELSE
			SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @OfficerCode AND ValidityTo IS NULL

		IF NOT EXISTS(SELECT * FROM tblClaim WHERE ClaimCode = @ClaimCode AND ValidityTo IS NULL)
			RETURN 2
		
		IF NOT EXISTS(SELECT C.ClaimID FROM tblClaim C INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID WHERE C.ClaimID = @ClaimID AND I.CHFID = @CHFID)
			RETURN 3

		IF EXISTS(SELECT 1 FROM tblFeedback WHERE ClaimID = @ClaimID AND ValidityTo IS NULL)
			RETURN 4
		
		DECLARE @CareRendered BIT = SUBSTRING(@Answers,1,1)
		DECLARE @PaymentAsked BIT = SUBSTRING(@Answers,2,1) 
		DECLARE @DrugPrescribed BIT  = SUBSTRING(@Answers,3,1)
		DECLARE @DrugReceived BIT = SUBSTRING(@Answers,4,1)
		DECLARE @Asessment TINYINT = SUBSTRING(@Answers,5,1)
		
		INSERT INTO tblFeedback(ClaimID,CareRendered,PaymentAsked,DrugPrescribed,DrugReceived,Asessment,CHFOfficerCode,FeedbackDate,ValidityFrom,AuditUserID)
						VALUES(@ClaimID,@CareRendered,@PaymentAsked,@DrugPrescribed,@DrugReceived,@Asessment,@OfficerID,@FeedbackDate,GETDATE(),-1);
		
		UPDATE tblClaim SET FeedbackStatus = 8 WHERE ClaimID = @ClaimID;
		
	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspPolicyValueProxyFamily]
(
	@ProductCode NVARCHAR(8),			
	@AdultMembers INT ,
	@ChildMembers INT ,
	@OAdultMembers INT =0,
	@OChildMembers INT = 0
)
AS

/*
********ERROR CODE***********
-1	:	Policy does not exists at the time of enrolment
-2	:	Policy was deleted at the time of enrolment

*/

BEGIN

	DECLARE @LumpSum DECIMAL(18,2) = 0,
			@PremiumAdult DECIMAL(18,2) = 0,
			@PremiumChild DECIMAL(18,2) = 0,
			@RegistrationLumpSum DECIMAL(18,2) = 0,
			@RegistrationFee DECIMAL(18,2) = 0,
			@GeneralAssemblyLumpSum DECIMAL(18,2) = 0,
			@GeneralAssemblyFee DECIMAL(18,2) = 0,
			@Threshold SMALLINT = 0,
			@MemberCount INT = 0,
			@Registration DECIMAL(18,2) = 0,
			@GeneralAssembly DECIMAL(18,2) = 0,
			@Contribution DECIMAL(18,2) = 0,
			@PolicyValue DECIMAL(18,2) = 0,
			@ExtraAdult INT = 0,
			@ExtraChild INT = 0,
			@AddonAdult DECIMAL(18,2) = 0,
			@AddonChild DECIMAL(18,2) = 0,
			@DiscountPeriodR INT = 0,
			@DiscountPercentR DECIMAL(18,2) =0,
			@DiscountPeriodN INT = 0,
			@DiscountPercentN DECIMAL(18,2) =0,
			@ExpiryDate DATE,
			@ProdId INT =0,
			@PolicyStage NVARCHAR(1) ='N',
			@ErrorCode INT=0,
			@ValidityTo DATE = NULL,
			@LegacyId INT = NULL,
			@EnrollDate DATE = GETDATE();


			SET @ProdId = ( SELECT ProdID FROM tblProduct WHERE ProductCode = @ProductCode AND ValidityTo IS NULL	)
	


	/*--Get all the required fiedls from product (Valide product at the enrollment time)--*/
		SELECT TOP 1 @LumpSum = ISNULL(LumpSum,0),@PremiumAdult = ISNULL(PremiumAdult,0),@PremiumChild = ISNULL(PremiumChild,0),@RegistrationLumpSum = ISNULL(RegistrationLumpSum,0),
		@RegistrationFee = ISNULL(RegistrationFee,0),@GeneralAssemblyLumpSum = ISNULL(GeneralAssemblyLumpSum,0), @GeneralAssemblyFee = ISNULL(GeneralAssemblyFee,0), 
		@Threshold = ISNULL(Threshold ,0),@MemberCount = ISNULL(MemberCount,0), @ValidityTo = ValidityTo, @LegacyId = LegacyID, @DiscountPeriodR = ISNULL(RenewalDiscountPeriod, 0), @DiscountPercentR = ISNULL(RenewalDiscountPerc,0)
		, @DiscountPeriodN = ISNULL(EnrolmentDiscountPeriod, 0), @DiscountPercentN = ISNULL(EnrolmentDiscountPerc,0)
		FROM tblProduct 
		WHERE (ProdID = @ProdId OR LegacyID = @ProdId)
		AND CONVERT(DATE,ValidityFrom,103) <= @EnrollDate
		ORDER BY ValidityFrom Desc

		IF @@ROWCOUNT = 0	--No policy found
			SET @ErrorCode = -1
		IF NOT @ValidityTo IS NULL AND @LegacyId IS NULL	--Policy is deleted by the time of enrollment
			SET @ErrorCode = -2
			

	

	--Get extra members in family
		IF @Threshold > 0 AND @AdultMembers > @Threshold
			SET @ExtraAdult = @AdultMembers - @Threshold
		IF @Threshold > 0 AND @ChildMembers > (@Threshold - @AdultMembers + @ExtraAdult )
					SET @ExtraChild = @ChildMembers - ((@Threshold - @AdultMembers + @ExtraAdult))
			

	--Get the Contribution
		IF @LumpSum > 0
			SET @Contribution = @LumpSum
		ELSE
			SET @Contribution = (@AdultMembers * @PremiumAdult) + (@ChildMembers * @PremiumChild)

	--Get the Assembly
		IF @GeneralAssemblyLumpSum > 0
			SET @GeneralAssembly = @GeneralAssemblyLumpSum
		ELSE
			SET @GeneralAssembly = (@AdultMembers + @ChildMembers + @OAdultMembers + @OChildMembers) * @GeneralAssemblyFee;

	--Get the Registration
		IF @PolicyStage = N'N'	--Don't calculate if it's renewal
		BEGIN
			IF @RegistrationLumpSum > 0
				SET @Registration = @RegistrationLumpSum
			ELSE
				SET @Registration = (@AdultMembers + @ChildMembers  + @OAdultMembers + @OChildMembers) * @RegistrationFee;
		END

	

		SET @AddonAdult = (@ExtraAdult + @OAdultMembers) * @PremiumAdult;
		SET @AddonChild = (@ExtraChild + @OChildMembers) * @PremiumChild;

		SET @Contribution += @AddonAdult + @AddonChild;
		
		--Line below was a mistake, All adults and children are already included in GeneralAssembly and Registration
		--SET @GeneralAssembly += (@OAdultMembers + @OChildMembers + @ExtraAdult + @ExtraChild) * @GeneralAssemblyFee;
		
		--IF @PolicyStage = N'N'
		--	SET @Registration += (@OAdultMembers + @OChildMembers + @ExtraAdult + @ExtraChild) * @RegistrationFee;


	SET @PolicyValue = @Contribution + @GeneralAssembly + @Registration;


	--The total policy value is calculated, So if the enroldate is earlier than the discount period then apply discount
	DECLARE @HasCycle BIT
	DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)
	INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
	EXEC uspGetPolicyPeriod @ProdId, @EnrollDate, @HasCycle OUTPUT, @PolicyStage;

	DECLARE @StartDate DATE =(SELECT StartDate FROM @tblPeriod);


	DECLARE @MinDiscountDateR DATE,
			@MinDiscountDateN DATE

	IF @PolicyStage = N'N'
	BEGIN
		SET @MinDiscountDateN = DATEADD(MONTH,-(@DiscountPeriodN),@StartDate);
		IF @EnrollDate <= @MinDiscountDateN AND @HasCycle = 1
			SET @PolicyValue -=  (@PolicyValue * 0.01 * @DiscountPercentN);
	END
	ELSE IF @PolicyStage  = N'R'
	BEGIN
		DECLARE @PreviousExpiryDate DATE = NULL

	
		BEGIN
			SET @PreviousExpiryDate = @StartDate;
		END

		SET @MinDiscountDateR = DATEADD(MONTH,-(@DiscountPeriodR),@PreviousExpiryDate);
		IF @EnrollDate <= @MinDiscountDateR
			SET @PolicyValue -=  (@PolicyValue * 0.01 * @DiscountPercentR);
	END

	SELECT @PolicyValue PolicyValue;

	

	
	RETURN @PolicyValue;

END
GO

CREATE OR ALTER PROCEDURE uspPrepareBulkControlNumberRequests
(
	@Count INT,
	@ProductCode NVARCHAR(50),
	@ErrorCode INT OUTPUT
)		
AS
BEGIN
	BEGIN TRY
		/*
			0	:	Success
			1	:	Amount not valid
			2	:	AccCodePremiums not found
			3	:	Couldn't create exact numbers of count requests
		*/

		DECLARE @ExpectedAmount DECIMAL(18, 2),
				@AccCodePremiums NVARCHAR(50),
				@Status INT = 0,
				@PolicyStage NCHAR(1) = N'N'

		SELECT @ExpectedAmount = Lumpsum, @AccCodePremiums = AccCodePremiums FROM tblProduct WHERE ProductCode = @ProductCode AND ValidityTo IS NULL;
		IF ISNULL(@ExpectedAmount, 0) = 0
		BEGIN
			SET @ErrorCode = 1;
			RAISERROR (N'Invalid amount', 16, 1);
		END

		IF ISNULL(@AccCodePremiums, '') = ''
		BEGIN
			SET @ErrorCode = 2;
			RAISERROR (N'Invalid AccCodePremium', 16, 1);
		END

		DECLARE @dt TABLE
		(
			BillId INT,
			ProductCode NVARCHAR(50),
			Amount DECIMAL(18, 2),
			AccCodePremiums NVARCHAR(50)
		)

		DECLARE @PaymentId INT = 0;

		BEGIN TRAN TRAN_CN
			WHILE(@Count > 0)
			BEGIN
		
				-- INSERT INTO Payment
				INSERT INTO tblPayment (ExpectedAmount, RequestDate, PaymentStatus, ValidityFrom, AuditedUSerID)
				SELECT @ExpectedAmount ExprectedAmount, GETDATE() RequestDate, 1 PaymentStatus, GETDATE() ValidityFrom, -1 AuditUserId

				SELECT @PaymentId = IDENT_CURRENT(N'tblPayment');


				--INSERT INTO Payment details
				INSERT INTO tblPaymentDetails(PaymentID, ProductCode, PolicyStage, ValidityFrom, AuditedUserId, ExpectedAmount)
				SELECT @PaymentId PaymentId, @ProductCode ProductCode, @PolicyStage PolicyStage, GETDATE() ValidityFrom, -1 AuditUserId, @ExpectedAmount ExpectedAmount;

				--INSERT INTO Control Number
				INSERT INTO tblControlNumber(PaymentID, RequestedDate, [Status], ValidityFrom, AuditedUserID)
				SELECT @PaymentId PaymentId, GETDATE() RequestedDate, @Status [Status], GETDATE() ValidityFrom, -1 AuditUserId;

				--Prepare return table
				INSERT INTO @dt(BillId, ProductCode, Amount, AccCodePremiums)
				SELECT @PaymentId, @ProductCode ProductCode, @ExpectedAmount Amount, @AccCodePremiums AccCodePremium;

				SET @Count = @Count - 1;
			END

			SELECT BillId, ProductCode, Amount FROM @dt;
			IF (SELECT COUNT(1) FROM @dt) <> @Count
			BEGIN
				SET @ErrorCode = 0;
				COMMIT TRAN TRAN_CN;
			END
			ELSE
			BEGIN 
				SET @ErrorCode = 3;
				RAISERROR (N'Could not create all the requests', 16, 1);
			END
	END TRY
	BEGIN CATCH
		SET @ErrorCode = 99;
		ROLLBACK TRAN TRAN_CN;
		THROW;
	END CATCH
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspInsertPaymentIntent]
(
	@XML XML,
	@ExpectedAmount DECIMAL(18,2) = 0 OUT, 
	@PaymentID INT = 0 OUT,
	@ErrorNumber INT = 0,
	@ErrorMsg NVARCHAR(255)=NULL,
	@ProvidedAmount decimal(18,2) = 0,
	@PriorEnrollment BIT = 0 
	
)

AS
BEGIN
	DECLARE @tblHeader TABLE(officerCode nvarchar(12),requestDate DATE, phoneNumber NVARCHAR(50),LanguageName NVARCHAR(10),SmsRequired BIT, AuditUSerID INT)
	DECLARE @tblDetail TABLE(InsuranceNumber nvarchar(12),productCode nvarchar(8), PolicyStage NVARCHAR(1),  isRenewal BIT, PolicyValue DECIMAL(18,2), isExisting BIT)
	DECLARE @OfficerLocationID INT
	DECLARE @OfficerParentLocationID INT
	DECLARE @AdultMembers INT 
	DECLARE @ChildMembers INT 
	DECLARE @oAdultMembers INT 
	DECLARE @oChildMembers INT


	DECLARE @isEO BIT
		INSERT INTO @tblHeader(officerCode, requestDate, phoneNumber,LanguageName, SmsRequired, AuditUSerID)
		SELECT 
		LEFT(NULLIF(T.H.value('(OfficerCode)[1]','NVARCHAR(50)'),''),12),
		NULLIF(T.H.value('(RequestDate)[1]','NVARCHAR(50)'),''),
		LEFT(NULLIF(T.H.value('(PhoneNumber)[1]','NVARCHAR(50)'),''),50),
		NULLIF(T.H.value('(LanguageName)[1]','NVARCHAR(10)'),''),
		T.H.value('(SmsRequired)[1]','BIT'),
		NULLIF(T.H.value('(AuditUserId)[1]','INT'),'')
		FROM @XML.nodes('PaymentIntent/Header') AS T(H)

		INSERT INTO @tblDetail(InsuranceNumber, productCode, PolicyValue, isRenewal)
		SELECT 
		LEFT(NULLIF(T.D.value('(InsuranceNumber)[1]','NVARCHAR(12)'),''),12),
		LEFT(NULLIF(T.D.value('(ProductCode)[1]','NVARCHAR(8)'),''),8),
		T.D.value('(PolicyValue)[1]','DECIMAL(18,2)'),
		T.D.value('(IsRenewal)[1]','BIT')
		FROM @XML.nodes('PaymentIntent/Details/Detail') AS T(D)
		
		IF @ErrorNumber != 0
		BEGIN
			GOTO Start_Transaction;
		END

		SELECT @AdultMembers =T.P.value('(AdultMembers)[1]','INT'), @ChildMembers = T.P.value('(ChildMembers)[1]','INT') , @oAdultMembers =T.P.value('(oAdultMembers)[1]','INT') , @oChildMembers = T.P.value('(oChildMembers)[1]','INT') FROM @XML.nodes('PaymentIntent/ProxySettings') AS T(P)
		
		SELECT @AdultMembers= ISNULL(@AdultMembers,0), @ChildMembers= ISNULL(@ChildMembers,0), @oAdultMembers= ISNULL(@oAdultMembers,0), @oChildMembers= ISNULL(@oChildMembers,0)
		

		UPDATE D SET D.isExisting = 1 FROM @tblDetail D 
		INNER JOIN  tblInsuree I ON D.InsuranceNumber = I.CHFID 
		WHERE I.IsHead = 1 AND I.ValidityTo IS NULL
	
		UPDATE  @tblDetail SET isExisting = 0 WHERE isExisting IS NULL

		IF EXISTS(SELECT 1 FROM @tblHeader WHERE officerCode IS NOT NULL)
			SET @isEO = 1
	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	/*Error Codes
	2- Not valid insurance or missing product code
	3- Not valid enrolment officer code
	4- Enrolment officer code and insurance product code are not compatible
	5- Beneficiary has no policy of specified insurance product for renewal
	6- Can not issue a control number as default indicated prior enrollment and Insuree has not been enrolled yet 

	7 - 'Insuree not enrolled and prior enrolement mandatory'


	-1. Unexpected error
	0. Success
	*/

	--2. Insurance number missing
		IF EXISTS(SELECT 1 FROM @tblDetail WHERE LEN(ISNULL(InsuranceNumber,'')) =0)
		BEGIN
			SET @ErrorNumber = 2
			SET @ErrorMsg ='Not valid insurance or missing product code'
			GOTO Start_Transaction;
		END

		--4. Missing product or Product does not exists
		IF EXISTS(SELECT 1 FROM @tblDetail D 
				LEFT OUTER JOIN tblProduct P ON P.ProductCode = D.productCode
				WHERE 
				(P.ValidityTo IS NULL AND P.ProductCode IS NULL) 
				OR D.productCode IS NULL
				)
		BEGIN
			SET @ErrorNumber = 4
			SET @ErrorMsg ='Not valid insurance or missing product code'
			GOTO Start_Transaction;
		END


	--3. Invalid Officer Code
		IF EXISTS(SELECT 1 FROM @tblHeader H
				LEFT JOIN tblOfficer O ON H.officerCode = O.Code
				WHERE O.ValidityTo IS NULL
				AND H.officerCode IS NOT NULL
				AND O.Code IS NULL
		)
		BEGIN
			SET @ErrorNumber = 3
			SET @ErrorMsg ='Not valid enrolment officer code'
			GOTO Start_Transaction;
		END

		
		--4. Wrong match of Enrollment Officer agaists Product
		SELECT @OfficerLocationID= L.LocationId, @OfficerParentLocationID = L.ParentLocationId FROM tblLocations L 
		INNER JOIN tblOfficer O ON O.LocationId = L.LocationId AND O.Code = (SELECT officerCode FROM @tblHeader WHERE officerCode IS NOT NULL)
		WHERE 
		L.ValidityTo IS NULL
		AND O.ValidityTo IS NULL


		IF EXISTS(SELECT D.productCode, P.ProductCode FROM @tblDetail D
			LEFT OUTER JOIN tblProduct P ON P.ProductCode = D.productCode AND (P.LocationId IS NULL OR P.LocationId = @OfficerLocationID OR P.LocationId = @OfficerParentLocationID)
			WHERE
			P.ValidityTo IS NULL
			AND P.ProductCode IS NULL
			) AND EXISTS(SELECT 1 FROM @tblHeader WHERE officerCode IS NOT NULL)
		BEGIN
			SET @ErrorNumber = 4
			SET @ErrorMsg ='Enrolment officer code and insurance product code are not compatible'
			GOTO Start_Transaction;
		END
		
		
		--The family does't contain this product for renewal
		IF EXISTS(SELECT 1 FROM @tblDetail D
				LEFT OUTER JOIN tblProduct PR ON PR.ProductCode = D.productCode
				LEFT OUTER JOIN tblInsuree I ON I.CHFID = D.InsuranceNumber
				LEFT OUTER JOIN tblPolicy PL ON PL.FamilyID = I.FamilyID  AND PL.ProdID = PR.ProdID
				WHERE PR.ValidityTo IS NULL
				AND D.isRenewal = 1 AND D.isExisting = 1
				AND I.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL AND PL.PolicyID IS NULL)
		BEGIN
			SET @ErrorNumber = 5
			SET @ErrorMsg ='Beneficiary has no policy of specified insurance product for renewal'
			GOTO Start_Transaction;
		END

		

		--5. Proxy family can not renew
		IF EXISTS(SELECT 1 FROM @tblDetail WHERE isExisting =0 AND isRenewal= 1)
		BEGIN
			SET @ErrorNumber = 5
			SET @ErrorMsg ='Beneficiary has no policy of specified insurance product for renewal'
			GOTO Start_Transaction;
		END


		--7. Insurance number not existing in system 
		IF @PriorEnrollment = 1 AND EXISTS(SELECT 1 FROM @tblDetail D
				LEFT OUTER JOIN tblProduct PR ON PR.ProductCode = D.productCode
				LEFT OUTER JOIN tblInsuree I ON I.CHFID = D.InsuranceNumber
				LEFT OUTER JOIN tblPolicy PL ON PL.FamilyID = I.FamilyID  AND PL.ProdID = PR.ProdID
				WHERE PR.ValidityTo IS NULL
				AND I.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL AND PL.PolicyID IS NULL)
		BEGIN
			SET @ErrorNumber = 7
			SET @ErrorMsg ='Insuree not enrolled and prior enrollment mandatory'
			GOTO Start_Transaction;
		END




	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/
	/**********************************************************************************************************************
			CALCULATIONS STARTS
	*********************************************************************************************************************/
	
	DECLARE @FamilyId INT, @ProductId INT, @PrevPolicyID INT, @PolicyID INT, @PremiumID INT
	DECLARE @PolicyStatus TINYINT=1
	DECLARE @PolicyValue DECIMAL(18,2), @PolicyStage NVARCHAR(1), @InsuranceNumber nvarchar(12), @productCode nvarchar(8), @enrollmentDate DATE, @isRenewal BIT, @isExisting BIT, @ErrorCode NVARCHAR(50)

	IF @ProvidedAmount = 0 
	BEGIN
		--only calcuylate if we want the system to provide a value to settle
		DECLARE CurFamily CURSOR FOR SELECT InsuranceNumber, productCode, isRenewal, isExisting FROM @tblDetail
		OPEN CurFamily
		FETCH NEXT FROM CurFamily INTO @InsuranceNumber, @productCode, @isRenewal, @isExisting;
		WHILE @@FETCH_STATUS = 0
		BEGIN
									
			SET @PolicyStatus=1
			SET @FamilyId = NULL
			SET @ProductId = NULL
			SET @PolicyID = NULL


			IF @isRenewal = 1
				SET @PolicyStage = 'R'
			ELSE 
				SET @PolicyStage ='N'

			IF @isExisting = 1
			BEGIN
											
				SELECT @FamilyId = FamilyId FROM tblInsuree I WHERE IsHead = 1 AND CHFID = @InsuranceNumber  AND ValidityTo IS NULL
				SELECT @ProductId = ProdID FROM tblProduct WHERE ProductCode = @productCode  AND ValidityTo IS NULL
				SELECT TOP 1 @PolicyID =  PolicyID FROM tblPolicy WHERE FamilyID = @FamilyId  AND ProdID = @ProductId AND PolicyStage = @PolicyStage AND ValidityTo IS NULL ORDER BY EnrollDate DESC
											
				IF @isEO = 1
					IF EXISTS(SELECT 1 FROM tblPremium WHERE PolicyID = @PolicyID AND ValidityTo IS NULL)
					BEGIN
						SELECT @PolicyValue =  ISNULL(PR.Amount - ISNULL(MatchedAmount,0),0) FROM tblPremium PR
														INNER JOIN tblPolicy PL ON PL.PolicyID = PR.PolicyID
														LEFT OUTER JOIN (SELECT PremiumID, SUM (Amount) MatchedAmount from tblPaymentDetails WHERE ValidityTo IS NULL GROUP BY PremiumID ) PD ON PD.PremiumID = PR.PremiumId
														WHERE
														PR.ValidityTo IS NULL
														AND PL.ValidityTo IS NULL AND PL.PolicyID = @PolicyID
														IF @PolicyValue < 0
														SET @PolicyValue = 0.00
					END
					ELSE
					BEGIN
						EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProductId, 0, @PolicyStage, NULL, 0;
					END
												
					ELSE IF @PolicyStage ='N'
					BEGIN
						EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProductId, 0, 'N', NULL, 0;
					END
				ELSE
				BEGIN
					SELECT TOP 1 @PrevPolicyID = PolicyID, @PolicyStatus = PolicyStatus FROM tblPolicy  WHERE ProdID = @ProductId AND FamilyID = @FamilyId AND ValidityTo IS NULL AND PolicyStatus != 4 ORDER BY EnrollDate DESC
					IF @PolicyStatus = 1
					BEGIN
						SELECT @PolicyValue =  (ISNULL(SUM(PL.PolicyValue),0) - ISNULL(SUM(Amount),0)) FROM tblPolicy PL 
						LEFT OUTER JOIN tblPremium PR ON PR.PolicyID = PL.PolicyID
						WHERE PL.ValidityTo IS NULL
						AND PR.ValidityTo IS NULL
						AND PL.PolicyID = @PrevPolicyID
						IF @PolicyValue < 0
							SET @PolicyValue =0
					END
					ELSE
					BEGIN 
						EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProductId, 0, 'R', @enrollmentDate, @PrevPolicyID, @ErrorCode OUTPUT;
					END
				END
			END
			ELSE
			BEGIN
				EXEC @PolicyValue = uspPolicyValueProxyFamily @productCode, @AdultMembers, @ChildMembers,@oAdultMembers,@oChildMembers
			END
			UPDATE @tblDetail SET PolicyValue = CASE WHEN PolicyValue<>0 THEN PolicyValue ELSE ISNULL(@PolicyValue,0) END, PolicyStage = @PolicyStage  WHERE InsuranceNumber = @InsuranceNumber AND productCode = @productCode AND isRenewal = @isRenewal
			FETCH NEXT FROM CurFamily INTO @InsuranceNumber, @productCode, @isRenewal, @isExisting;
		END
		CLOSE CurFamily
		DEALLOCATE CurFamily;

	

	END

	
	
		
	--IF IT REACHES UP TO THIS POINT THEN THERE IS NO ERROR
	SET @ErrorNumber = 0
	SET @ErrorMsg = NULL


	/**********************************************************************************************************************
			CALCULATIONS ENDS
	 *********************************************************************************************************************/

	 /**********************************************************************************************************************
			INSERTION STARTS
	 *********************************************************************************************************************/
		Start_Transaction:
		BEGIN TRY
			BEGIN TRANSACTION INSERTPAYMENTINTENT
				
				IF @ProvidedAmount > 0 
					SET @ExpectedAmount = @ProvidedAmount 
				ELSE
					SELECT @ExpectedAmount = SUM(ISNULL(PolicyValue,0)) FROM @tblDetail
				
				SET @ErrorMsg = ISNULL(CONVERT(NVARCHAR(5),@ErrorNumber)+': '+ @ErrorMsg,NULL)
				--Inserting Payment
				INSERT INTO [dbo].[tblPayment]
				 ([ExpectedAmount],[OfficerCode],[PhoneNumber],[RequestDate],[PaymentStatus],[ValidityFrom],[AuditedUSerID],[RejectedReason],[LanguageName],[SmsRequired]) 
				 SELECT
				 @ExpectedAmount, officerCode, phoneNumber, GETDATE(),CASE @ErrorNumber WHEN 0 THEN 0 ELSE -1 END, GETDATE(), AuditUSerID, @ErrorMsg,LanguageName,SmsRequired
				 FROM @tblHeader
				 SELECT @PaymentID= SCOPE_IDENTITY();

				 --Inserting Payment Details
				 DECLARE @AuditedUSerID INT
				 SELECT @AuditedUSerID = AuditUSerID FROM @tblHeader
				INSERT INTO [dbo].[tblPaymentDetails]
			   ([PaymentID],[ProductCode],[InsuranceNumber],[PolicyStage],[ValidityFrom],[AuditedUserId], ExpectedAmount) SELECT
				@PaymentID, productCode, InsuranceNumber,  CASE isRenewal WHEN 0 THEN 'N' ELSE 'R' END, GETDATE(), @AuditedUSerID, PolicyValue
				FROM @tblDetail D
				


			COMMIT TRANSACTION INSERTPAYMENTINTENT
			RETURN @ErrorNumber
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION INSERTPAYMENTINTENT
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH

	 /**********************************************************************************************************************
			INSERTION ENDS
	 *********************************************************************************************************************/

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(200) = '',
	@XML XML
)
/*
	-5: Fatal Error
	 0: All OK
	-1: Duplicate Receipt found
	-2: Grace Period is over
	-3: Renewal was alredy rejected
	-4: Renewal was alredy accepted
	
*/
AS
BEGIN
	BEGIN TRY

	--DECLARE @FilePath NVARCHAR(250)
	--DECLARE @XML XML
	DECLARE @RenewalId INT
	DECLARE @CHFID VARCHAR(12) 
	DECLARE @ProductCode VARCHAR(15)
	DECLARE @Officer VARCHAR(15)
	DECLARE @Date DATE
	DECLARE @Amount DECIMAL(18,2)
	DECLARE @Receipt NVARCHAR(50)
	DECLARE @Discontinue VARCHAR(10)
	DECLARE @PayerId INT
	DECLARE @Query NVARCHAR(3000)
	
	DECLARE @FromPhoneId INT = 0;
	DECLARE @RecordCount INT = 0
	DECLARE @RenewalOrder INT = 0
	DECLARE @ResponseStatus INT = 0
	
	SELECT 
	@RenewalId = T.Policy.query('RenewalId').value('.','INT'),
	@CHFID = T.Policy.query('CHFID').value('.','VARCHAR(12)'),
	@ProductCode =  T.Policy.query('ProductCode').value('.','VARCHAR(15)'),
	@Officer = T.Policy.query('Officer').value('.','VARCHAR(15)') ,
	@Date = T.Policy.query('Date').value('.','DATE'),
	@Amount = T.Policy.query('Amount').value('.','DECIMAL(18,2)'),
	@Receipt = T.Policy.query('ReceiptNo').value('.','NVARCHAR(50)'),
	@Discontinue = T.policy.query('Discontinue').value('.','VARCHAR(10)'),
	@PayerId = NULLIF(T.policy.query('PayerId').value('.', 'INT'), 0)
	FROM 
	@XML.nodes('Policy') AS T(Policy);

	IF NOT ( @XML.exist('(Policy/RenewalId)')=1 )
		RETURN -5


	--Checking if the renewal already exists and get the status
	DECLARE @DocStatus NVARCHAR(1)
	SELECT @DocStatus = FP.DocStatus FROM tblPolicyRenewals PR
			INNER JOIN tblOfficer O ON PR.NewOfficerID = O.OfficerID
			INNER JOIN tblFromPhone FP ON FP.OfficerCode = O.Code
			WHERE O.ValidityTo IS NULL 
			AND OfficerCode = @Officer AND CHFID = @CHFID AND PR.RenewalID = @RenewalId
	
	
	
	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId,@ResponseStatus=ResponseStatus FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;
	IF @ResponseStatus = 1 
		BEGIN
			RETURN - 4
		END


	DECLARE @Tbl TABLE(Id INT)

	
	;WITH PrevProducts
	AS
	(
		SELECT Prod.ProductCode, Prod.ProdId, OldProd.ProdID PrevProd
		FROM tblProduct Prod
		LEFT OUTER JOIN tblProduct OldProd ON Prod.ProdId = OldProd.ConversionProdId
		WHERE Prod.ValidityTo IS NULL
		AND OldProd.ValidityTo IS NULL
		AND Prod.ProductCode = @ProductCode
	)
	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN PrevProducts PR ON PL.ProdId = PR.ProdId OR PL.ProdId = PR.PrevProd --PL.ProdID = PR.ProdID
	WHERE CHFID = @CHFID
	AND PR.ProductCode = @ProductCode
	AND I.ValidityTo IS NULL
	AND PL.ValidityTo IS NULL
	UNION ALL
		SELECT OfficerID
		FROM tblOfficer
		WHERE Code =@Officer
		AND ValidityTo IS NULL
	
	
	DECLARE @FamilyID INT = (SELECT FamilyId from tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL)
	DECLARE @ProdId INT
	DECLARE @StartDate DATE
	DECLARE @ExpiryDate DATE
	DECLARE @HasCycle BIT
	--PAUL -24/04/2019 INSERTED  @@AND tblPolicy.ValidityTo@@ to ensure that query does not include deleted policies
	;WITH PrevProducts
	AS
	(
		SELECT Prod.ProductCode, Prod.ProdId, OldProd.ProdID PrevProd
		FROM tblProduct Prod
		LEFT OUTER JOIN tblProduct OldProd ON Prod.ProdId = OldProd.ConversionProdId
		WHERE Prod.ValidityTo IS NULL
		AND OldProd.ValidityTo IS NULL
		AND Prod.ProductCode = @ProductCode
	)
	SELECT TOP 1 @ProdId = PR.ProdId, @ExpiryDate = PL.ExpiryDate
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN PrevProducts PR ON PL.ProdId = PR.ProdId OR PL.ProdId = PR.PrevProd 
	WHERE CHFID = @CHFID
	AND PR.ProductCode = @ProductCode
	AND I.ValidityTo IS NULL
	AND PL.ValidityTo IS NULL
	ORDER BY PL.ExpiryDate DESC;

	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL
				AND LEN(PR.Receipt) > 0)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	
		--IF EXISTS(SELECT 1 FROM tblProduct WHERE ProdId = @ProdId AND LEN(StartCycle1) > 0)
		--	--CHECK IF IT IS A FREE PRODUCT AND IGNORE GRACE PERIOD RENEWAL, IF IS NOT A FREE PRODUCT RETURN -2	
		--	IF @LastRenewalDate < @Date 
		--		BEGIN					  
		--			RETURN -2
		--		END
		SELECT @RecordCount = COUNT(1) FROM @Tbl;
		
	
	IF @RecordCount = 2
		BEGIN
			IF @Discontinue = 'false' OR @Discontinue = N''
				BEGIN
					
					DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)
					DECLARE @EnrolmentDate DATE =DATEADD(D,1,@ExpiryDate)
					INSERT INTO @tblPeriod
					EXEC uspGetPolicyPeriod @ProdId, @Date, @HasCycle OUTPUT,'R';

					DECLARE @ExpiryDatePreviousPolicy DATE
				
					SELECT @ExpiryDatePreviousPolicy = ExpiryDate FROM tblPolicy WHERE PolicyID=@PreviousPolicyId AND ValidityTo IS NULL
					
				
					IF @HasCycle = 1
						BEGIN
							SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
							IF @StartDate < @ExpiryDatePreviousPolicy
								BEGIN
									UPDATE @tblPeriod SET StartDate=DATEADD(DAY, 1, @ExpiryDatePreviousPolicy)
									SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
								END	
						END
					ELSE
						BEGIN
					
						IF @Date < @ExpiryDate						 
							SELECT @StartDate =DATEADD(D,1,@ExpiryDate), @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,DATEADD(D,1,@ExpiryDate))) FROM tblProduct WHERE ProdID = @ProdId;
						ELSE
							SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;
						END
					


					DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
					DECLARE @PolicyValue DECIMAL(18,2) 
				
						SET @EnrolmentDate = @Date
					EXEC @PolicyValue = uspPolicyValue
											@FamilyId = @FamilyID,
											@ProdId = @ProdId,
											@EnrollDate = @EnrolmentDate,
											@PreviousPolicyId = @PreviousPolicyId,
											@PolicyStage = 'R';
		
					DECLARE @PolicyStatus TINYINT = 2
		
					IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
					INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
									VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
					DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
					
					-- No need to create if the payment is not made yet
					IF @Amount > 0
					BEGIN
						INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
										Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
					END

				
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

					UPDATE tblPolicyRenewals SET ResponseStatus = 1, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId;
				END
			ELSE
				BEGIN
					UPDATE tblPolicyRenewals SET ResponseStatus = 2, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId
				END

				UPDATE tblFromPhone SET DocStatus = N'A' WHERE FromPhoneId = @FromPhoneId;
		
				SELECT * FROM @Tbl;
		END
	ELSE
		BEGIN
			RETURN -5
		END
END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspLastDateForPayment]
(
	@PolicyId INT
)
AS
BEGIN
	DECLARE @ProdId INT,
		@HasCycle BIT = 0,
		@GracePeriod INT,
		@WaitingPeriod INT,
		@StartDate DATE,
		@PolicyStage CHAR(1),
		@ExpiryDate DATE,
		@EnrollDate DATE,
		@LastDate DATE

	SELECT @ProdId = ProdId FROM tblPolicy WHERE PolicyId = @PolicyId;
	IF EXISTS(SELECT 1 FROM tblProduct Prod WHERE ProdID = @ProdId AND (StartCycle1 IS NOT NULL OR StartCycle2 IS NOT NULL OR StartCycle3 IS NOT NULL OR StartCycle4 IS NOT NULL))
		SET @HasCycle = 1;

	SELECT @GracePeriod = CASE PL.PolicyStage WHEN 'N' THEN ISNULL(Prod.GracePeriod, 0) WHEN 'R' THEN ISNULL(Prod.GracePeriodRenewal, 0) END,
	@WaitingPeriod = Prod.WaitingPeriod
	FROM tblProduct Prod
	INNER JOIN tblPolicy PL ON PL.ProdId = Prod.ProdId
	WHERE Prod.ProdId = @ProdId;

	IF @HasCycle = 1
	BEGIN
		PRINT N'Calculate on Fixed Cycle';
		SELECT @StartDate = StartDate FROM tblPolicy WHERE PolicyId = @PolicyId;
		SET @LastDate = DATEADD(MONTH, @GracePeriod, @StartDate)
		PRINT @LastDate
	END
	ELSE
	BEGIN
		PRINT N'Calculate on Free Cycle';
		SELECT @PolicyStage = PolicyStage, @EnrollDate = EnrollDate, @ExpiryDate = ExpiryDate FROM tblPolicy WHERE PolicyId = @PolicyId;
		IF @PolicyStage = 'N'
			SET @LastDate = DATEADD(MONTH, @WaitingPeriod, @EnrollDate);
		IF @PolicyStage = 'R'
			SET @LastDate = DATEADD(MONTH, @WaitingPeriod, DATEADD(DAY, 1, @ExpiryDate));
	END

	SELECT DATEADD(DAY, -1, @LastDate) LastDate;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspMatchPayment]
	@PaymentID INT = NULL,
	@AuditUserId INT = NULL
AS
BEGIN

BEGIN TRY
---CHECK IF PAYMENTID EXISTS
	IF NOT @PaymentID IS NULL
	BEGIN
	     IF NOT EXISTS ( SELECT PaymentID FROM tblPayment WHERE PaymentID = @PaymentID AND ValidityTo IS NULL)
			RETURN 1
	END

	SET @AuditUserId =ISNULL(@AuditUserId, -1)

	DECLARE @InTopIsolation as bit 
	SET @InTopIsolation = -1 
	IF @@TRANCOUNT = 0 	
		SET @InTopIsolation =0
	ELSE
		SET @InTopIsolation =1
	IF @InTopIsolation = 0
	BEGIN
		BEGIN TRANSACTION MATCHPAYMENT
	END
	
	

	DECLARE @tblHeader TABLE(PaymentID BIGINT, officerCode nvarchar(12),PhoneNumber nvarchar(12),paymentDate DATE,ReceivedAmount DECIMAL(18,2),TotalPolicyValue DECIMAL(18,2), isValid BIT, TransactionNo NVARCHAR(50))
	DECLARE @tblDetail TABLE(PaymentDetailsID BIGINT, PaymentID BIGINT, InsuranceNumber nvarchar(12),productCode nvarchar(8),  enrollmentDate DATE,PolicyStage CHAR(1), MatchedDate DATE, PolicyValue DECIMAL(18,2),DistributedValue DECIMAL(18,2), policyID INT, RenewalpolicyID INT, PremiumID INT, PolicyStatus INT,AlreadyPaidDValue DECIMAL(18,2))
	DECLARE @tblResult TABLE(policyID INT, PremiumId INT)
	DECLARE @tblFeedback TABLE(fdMsg NVARCHAR(MAX), fdType NVARCHAR(1),paymentID INT,InsuranceNumber nvarchar(12),PhoneNumber nvarchar(12),productCode nvarchar(8), Balance DECIMAL(18,2), isActivated BIT, PaymentFound INT, PaymentMatched INT, APIKey NVARCHAR(100))
	DECLARE @tblPaidPolicies TABLE(PolicyID INT, Amount DECIMAL(18,2), PolicyValue DECIMAL(18,2))
	DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
	DECLARE @paymentFound INT
	DECLARE @paymentMatched INT


	--GET ALL UNMATCHED RECEIVED PAYMENTS
	INSERT INTO @tblDetail(PaymentDetailsID, PaymentID, InsuranceNumber, ProductCode, enrollmentDate, policyID, PolicyStage, PolicyValue, PremiumID,PolicyStatus, AlreadyPaidDValue)
	SELECT PaymentDetailsID, PaymentID, InsuranceNumber, ProductCode, EnrollDate,  PolicyID, PolicyStage, PolicyValue, PremiumId, PolicyStatus, AlreadyPaidDValue FROM(
	SELECT ROW_NUMBER() OVER(PARTITION BY PR.ProductCode,I.CHFID ORDER BY PL.EnrollDate DESC) RN, PD.PaymentDetailsID, PY.PaymentID,PD.InsuranceNumber, PD.ProductCode,PL.EnrollDate,  PL.PolicyID, PD.PolicyStage, PL.PolicyValue, PRM.PremiumId, PL.PolicyStatus, 
	(SELECT SUM(PDD.Amount) FROM tblPaymentDetails PDD INNER JOIN tblPayment PYY ON PDD.PaymentID = PYY.PaymentID WHERE PYY.MatchedDate IS NOT NULL  and PDD.ValidityTo is NULL) AlreadyPaidDValue FROM tblPaymentDetails PD 
	LEFT OUTER JOIN tblInsuree I ON I.CHFID = PD.InsuranceNumber
	LEFT OUTER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
	LEFT OUTER JOIN tblProduct PR ON PR.ProductCode = PD.ProductCode
	LEFT OUTER JOIN (SELECT  PolicyID, EnrollDate, PolicyValue,FamilyID, ProdID,PolicyStatus FROM tblPolicy WHERE ProdID = ProdID AND FamilyID = FamilyID AND ValidityTo IS NULL AND PolicyStatus NOT IN (4,8)  ) PL ON PL.ProdID = PR.ProdID  AND PL.FamilyID = I.FamilyID
	LEFT OUTER JOIN ( SELECT MAX(PremiumId) PremiumId , PolicyID FROM  tblPremium WHERE ValidityTo IS NULL GROUP BY PolicyID ) PRM ON PRM.PolicyID = PL.PolicyID
	INNER JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID
	WHERE PD.PremiumID IS NULL 
	AND PD.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND PR.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND PY.ValidityTo IS NULL
	AND PY.PaymentStatus = 4 --Received Payment
	AND PD.PaymentID = ISNULL(@PaymentID,PD.PaymentID)
	)XX --WHERE RN =1
	
	INSERT INTO @tblHeader(PaymentID, ReceivedAmount, PhoneNumber, TotalPolicyValue, TransactionNo, officerCode)
	SELECT P.PaymentID, P.ReceivedAmount, P.PhoneNumber, D.TotalPolicyValue, P.TransactionNo, P.OfficerCode FROM tblPayment P
	INNER JOIN (SELECT PaymentID, SUM(PolicyValue) TotalPolicyValue FROM @tblDetail GROUP BY PaymentID)  D ON P.PaymentID = D.PaymentID
	WHERE P.ValidityTo IS NULL AND P.PaymentStatus = 4

	IF EXISTS(SELECT COUNT(1) FROM @tblHeader PH )
		BEGIN
			SET @paymentFound= (SELECT COUNT(1)  FROM @tblHeader PH )
			INSERT INTO @tblFeedback(fdMsg, fdType )
			SELECT CONVERT(NVARCHAR(4), ISNULL(@paymentFound,0))  +' Unmatched Payment(s) found ', 'I' 
		END


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	
	--1. Insurance number is missing on tblPaymentDetails
	IF EXISTS(SELECT 1 FROM @tblDetail WHERE LEN(ISNULL(InsuranceNumber,'')) = 0)
		BEGIN
			INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
			SELECT CONVERT(NVARCHAR(4), COUNT(1) OVER(PARTITION BY InsuranceNumber)) +' Insurance number(s) missing in tblPaymentDetails ', 'E', PaymentID FROM @tblDetail WHERE LEN(ISNULL(InsuranceNumber,'')) = 0
		END

		--2. Product code is missing on tblPaymentDetails
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
		SELECT 'Family with Insurance Number ' + QUOTENAME(PD.InsuranceNumber) + ' is missing product code ', 'E', PD.PaymentID FROM @tblDetail PD WHERE LEN(ISNULL(productCode,'')) = 0

	--2. Insurance number is missing in tblinsuree
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
		SELECT 'Family with Insurance Number' + QUOTENAME(PD.InsuranceNumber) + ' does not exists', 'E', PD.PaymentID FROM @tblDetail PD 
		LEFT OUTER JOIN tblInsuree I ON I.CHFID = PD.InsuranceNumber
		WHERE I.ValidityTo  IS NULL
		AND I.CHFID IS NULL
		
	--1. Policy/Prevous Policy not found
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
		SELECT 'Family with Insurance Number ' + QUOTENAME(PD.InsuranceNumber) + ' does not have Policy or Previous Policy for the product '+QUOTENAME(PD.productCode), 'E', PD.PaymentID FROM @tblDetail PD 
		WHERE policyID IS NULL
		AND ISNULL(LEN(PD.productCode),'') > 0
		AND ISNULL(LEN(PD.InsuranceNumber),'') > 0

	 --3. Invalid Product
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
		SELECT  'Family with insurance number '+ QUOTENAME(PD.InsuranceNumber) +' can not enroll to product '+ QUOTENAME(PD.productCode),'E',PD.PaymentID FROM @tblDetail PD 
		INNER JOIN tblInsuree I ON I.CHFID = PD.InsuranceNumber
		INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		INNER JOIN tblRegions R ON R.RegionId =  D.Region
		LEFT OUTER JOIN tblProduct PR ON (PR.LocationId IS NULL OR PR.LocationId = D.Region OR PR.LocationId = D.DistrictId) AND (GETDATE()  BETWEEN PR.DateFrom AND PR.DateTo) AND PR.ProductCode = PD.ProductCode
		WHERE 
		I.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL
		AND PR.ProdID IS NULL
		AND ISNULL(LEN(PD.productCode),'') > 0
		AND ISNULL(LEN(PD.InsuranceNumber),'') > 0


	--4. Invalid Officer
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
		SELECT 'Enrollment officer '+ QUOTENAME(PY.officerCode) +' does not exists ' ,'E',PD.PaymentID  FROM @tblDetail PD
		INNER JOIN @tblHeader PY ON PY.PaymentID = PD.PaymentID
		LEFT OUTER JOIN tblOfficer O ON O.Code = PY.OfficerCode
		WHERE
		O.ValidityTo IS NULL
		AND PY.OfficerCode IS NOT NULL
		AND O.Code IS NULL


	--4. Invalid Officer/Product Match
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
		SELECT 'Enrollment officer '+ QUOTENAME(PY.officerCode) +' can not sell the product '+ QUOTENAME(PD.productCode),'E',PD.PaymentID  FROM @tblDetail PD
		INNER JOIN @tblHeader PY ON PY.PaymentID = PD.PaymentID
		LEFT OUTER JOIN tblOfficer O ON O.Code = PY.OfficerCode
		INNER JOIN tblDistricts D ON D.DistrictId = O.LocationId
		LEFT JOIN tblProduct PR ON PR.ProductCode = PD.ProductCode AND (PR.LocationId IS NULL OR PR.LocationID = D.Region OR PR.LocationId = D.DistrictId)
		WHERE
		O.ValidityTo IS NULL
		AND PY.OfficerCode IS NOT NULL
		AND PR.ValidityTo IS NULL
		AND D.ValidityTo IS NULL
		AND PR.ProdID IS NULL
		
	--5. Premiums not available
	INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
	SELECT 'Premium from Enrollment officer '+ QUOTENAME(PY.officerCode) +' is not yet available ','E',PD.PaymentID FROM @tblDetail PD 
	INNER JOIN @tblHeader PY ON PY.PaymentID = PD.PaymentID
	WHERE
	PD.PremiumID IS NULL
	AND PY.officerCode IS NOT NULL




	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/
	

	---DELETE ALL INVALID PAYMENTS
		DELETE PY FROM @tblHeader PY
		INNER JOIN @tblFeedback F ON F.paymentID = PY.PaymentID
		WHERE F.fdType ='E'


		DELETE PD FROM @tblDetail PD
		INNER JOIN @tblFeedback F ON F.paymentID = PD.PaymentID
		WHERE F.fdType ='E'

		IF NOT EXISTS(SELECT 1 FROM @tblHeader)
			INSERT INTO @tblFeedback(fdMsg, fdType )
			SELECT 'No Payment matched  ', 'I' FROM @tblHeader P

		--DISTRIBUTE PAYMENTS 
		DECLARE @curPaymentID int, @ReceivedAmount DECIMAL(18,2), @TotalPolicyValue DECIMAL(18,2), @AmountAvailable DECIMAL(18,2)
		DECLARE CUR_Pay CURSOR FAST_FORWARD FOR
		SELECT PH.PaymentID, ReceivedAmount FROM @tblHeader PH
		OPEN CUR_Pay
		FETCH NEXT FROM CUR_Pay INTO  @curPaymentID, @ReceivedAmount
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @AmountAvailable = @ReceivedAmount
			SELECT @TotalPolicyValue = SUM(PD.PolicyValue-PD.DistributedValue-Pd.AlreadyPaidDValue ) FROM @tblDetail pd WHERE pd.PaymentID = @curPaymentID and PD.PolicyValue > (PD.DistributedValue + PD.AlreadyPaidDValue)
			WHILE @AmountAvailable > 0 or @AmountAvailable =   @ReceivedAmount - @TotalPolicyValue
			begin
				UPDATE PD SET PD.DistributedValue = CASE WHEN @TotalPolicyValue <=  @AmountAvailable THEN PD.PolicyValue 
					WHEN @AmountAvailable*( PD.PolicyValue/@TotalPolicyValue)< PD.PolicyValue THEN @AmountAvailable*( PD.PolicyValue/@TotalPolicyValue) 
					ELSE PD.PolicyValue END  FROM @tblDetail PD where pd.PaymentID = @curPaymentID and PD.PolicyValue > PD.DistributedValue
				SELECT @AmountAvailable = (@ReceivedAmount - SUM(PD.DistributedValue)) FROM @tblDetail pd WHERE pd.PaymentID = @curPaymentID
				-- update the remainig policyvalue
				SELECT @TotalPolicyValue = SUM(PD.PolicyValue-PD.DistributedValue-Pd.AlreadyPaidDValue ) FROM @tblDetail pd WHERE pd.PaymentID = @curPaymentID and PD.PolicyValue > (PD.DistributedValue + PD.AlreadyPaidDValue)
			END
			FETCH NEXT FROM CUR_Pay INTO  @curPaymentID, @ReceivedAmount
		END

		

		-- UPDATE POLICY STATUS
		DECLARE @DistributedValue DECIMAL(18, 2)
		DECLARE @InsuranceNumber NVARCHAR(12)
		DECLARE @productCode NVARCHAR(8)
		DECLARE @PhoneNumber NVARCHAR(12)
		DECLARE @PaymentDetailsID INT
		DECLARE @Ready INT = 16
		DECLARe @PolicyStage NVARCHAR(1)
		DECLARE @PreviousPolicyID INT
		DECLARE @PolicyProcessed TABLE(id int, matchedPayment int)
		DECLARE @AlreadyPaidDValue DECIMAL(18, 2)
		DECLARE @PremiumId INT
		-- loop below only INSERT for :
		-- SELF PAYER RENEW (stage R no officer)
		-- contribution without payment (Stage N status @ready status with officer) 
		-- PolicyID and PhoneNumber required in both cases
		IF EXISTS(SELECT 1 FROM @tblDetail PD INNER JOIN @tblHeader P ON PD.PaymentID = P.PaymentID WHERE ((PD.PolicyStage ='R' AND P.officerCode IS NULL ) OR (PD.PolicyStatus=@Ready AND PD.PolicyStage ='N' AND P.officerCode IS NOT NULL))AND P.PhoneNumber IS NOT NULL  AND PD.policyID IS NOT NULL)
			BEGIN
			DECLARE CurPolicies CURSOR FOR SELECT PaymentDetailsID, InsuranceNumber, productCode, PhoneNumber, DistributedValue, policyID, PolicyStage, AlreadyPaidDValue,PremiumID FROM @tblDetail PD INNER JOIN @tblHeader P ON PD.PaymentID = P.PaymentID 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PaymentDetailsID,  @InsuranceNumber, @productCode, @PhoneNumber, @DistributedValue, @PreviousPolicyID, @PolicyStage, @AlreadyPaidDValue, @PremiumID
			WHILE @@FETCH_STATUS = 0
			BEGIN			
						DECLARE @ProdId INT
						DECLARE @FamilyId INT
						DECLARE @OfficerID INT
						DECLARE @PolicyId INT
						
						DECLARE @StartDate DATE
						DECLARE @ExpiryDate DATE
						DECLARE @EffectiveDate DATE
						DECLARE @EnrollmentDate DATE = GETDATE()
						DECLARE @PolicyStatus TINYINT=1
						DECLARE @PreviousPolicyStatus TINYINT=1
						DECLARE @PolicyValue DECIMAL(18, 2)
						DECLARE @PaidAmount DECIMAL(18, 2)
						DECLARE @Balance DECIMAL(18, 2)
						DECLARE @ErrorCode INT
						DECLARE @HasCycle BIT
						DECLARE @isActivated BIT = 0
						DECLARE @TransactionNo NVARCHAR(50)
						
						-- DECLARE @PolicyStage INT
						SELECT @ProdId = ProdID, @FamilyId = FamilyID, @OfficerID = OfficerID, @PreviousPolicyStatus = PolicyStatus  FROM tblPolicy WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL
						-- execute the storeProc for PolicyID unknown
							EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @enrollmentDate, @PreviousPolicyID, @ErrorCode OUTPUT;
							DELETE FROM @tblPeriod
							
							SET @TransactionNo = (SELECT ISNULL(PY.TransactionNo,'') FROM @tblHeader PY INNER JOIN @tblDetail PD ON PD.PaymentID = PY.PaymentID AND PD.policyID = @PreviousPolicyID)
							
							DECLARE @Idle TINYINT = 1
							DECLARE @Active TINYINT = 2
							-- DECLARE @Ready TINYINT = 16
							DECLARE @ActivationOption INT

							SELECT @ActivationOption = ActivationOption FROM tblIMISDefaults
							-- Get the previous paid amount
							SELECT @PaidAmount =  (SUM(PD.DistributedValue))  FROM @tblDetail pd WHERE Pd.PolicyID = @PreviousPolicyID 		--  support multiple payment; FIXME should we support hybrid payment (contribution and payment)	
							
							IF ((@PreviousPolicyStatus = @Idle AND @PolicyStage = 'R') OR (@PreviousPolicyStatus = @Ready AND @ActivationOption = 3 AND @PolicyStage = 'N')) AND (SELECT COUNT(id) FROM @PolicyProcessed WHERE id=@PreviousPolicyID )=0
								BEGIN
									--Get the previous paid amount for only Idle policy
									-- SELECT @PaidAmount =  ISNULL(SUM(Amount),0) FROM tblPremium  PR 
									-- LEFT OUTER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID  
									-- WHERE PR.PolicyID = @PreviousPolicyID 
									-- AND PR.ValidityTo IS NULL 
									--  AND PL.ValidityTo IS NULL
									-- AND PL.PolicyStatus = @Idle								
									SELECT @PolicyValue = ISNULL(PolicyValue,0) FROM tblPolicy WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL
									-- if the policy value is covered and
									IF ( @AlreadyPaidDValue + ISNULL(@PaidAmount,0)) - ISNULL(@PolicyValue,0) >= 0 
									BEGIN
										SET @PolicyStatus = @Active
										SET @EffectiveDate = (SELECT StartDate FROM tblPolicy WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL)
										SET @isActivated = 1
										SET @Balance = 0
		
										INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom, ValidityTo, LegacyID,  AuditUserID, isOffline)
													 SELECT FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,GETDATE(), PolicyID, AuditUserID, isOffline FROM tblPolicy WHERE PolicyID = @PreviousPolicyID
											
										
										INSERT INTO tblInsureePolicy
										(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,ValidityFrom,ValidityTo,LegacyId,AuditUserId,isOffline)
										SELECT InsureeId, PolicyId, EnrollmentDate, StartDate, EffectiveDate,ExpiryDate,ValidityFrom,GETDATE(),PolicyId,AuditUserId,isOffline FROM tblInsureePolicy 
										WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL

										UPDATE tblPolicy SET PolicyStatus = @PolicyStatus,  EffectiveDate  = @EffectiveDate, ExpiryDate = @ExpiryDate, ValidityFrom = GETDATE(), AuditUserID = @AuditUserId WHERE PolicyID = @PreviousPolicyID

										UPDATE tblInsureePolicy SET EffectiveDate = @EffectiveDate, ValidityFrom = GETDATE(), AuditUserID = @AuditUserId WHERE ValidityTo IS NULL AND PolicyId = @PreviousPolicyID  AND EffectiveDate IS NULL
										SET @PolicyId = @PreviousPolicyID
										
										
									END
									ELSE
									BEGIN
										SET @Balance = ISNULL(@PolicyValue,0) - (ISNULL(@DistributedValue,0) + ISNULL(@PaidAmount,0))
										SET @isActivated = 0
										SET @PolicyId = @PreviousPolicyID
									END
									-- mark the policy as processed
									INSERT INTO @PolicyProcessed (id,matchedpayment) VALUES (@PreviousPolicyID,1)
									
								END
							ELSE IF @PreviousPolicyStatus  NOT IN ( @Idle, @Ready) AND (SELECT COUNT(id) FROM @PolicyProcessed WHERE id=@PreviousPolicyID )=0 -- FIXME should we renew suspended ?
								BEGIN --insert new Renewals if the policy is not Iddle
									DECLARE @StartCycle NVARCHAR(5)
									SELECT @StartCycle= ISNULL(StartCycle1, ISNULL(StartCycle2,ISNULL(StartCycle3,StartCycle4))) FROM tblProduct WHERE ProdID = @PreviousPolicyID
									IF @StartCycle IS NOT NULL
									SET @HasCycle = 1
									ELSE
									SET @HasCycle = 0
									SET @EnrollmentDate = (SELECT DATEADD(DAY,1,expiryDate) FROM tblPolicy WHERE PolicyID = @PreviousPolicyID  AND ValidityTo IS NULL)
									INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
									EXEC uspGetPolicyPeriod @ProdId, @EnrollmentDate, @HasCycle;
									SET @StartDate = (SELECT startDate FROM @tblPeriod)
									SET @ExpiryDate =(SELECT expiryDate FROM @tblPeriod)
									
									IF ISNULL(@PaidAmount,0) - ISNULL(@PolicyValue,0) >= 0
										BEGIN
											SET @PolicyStatus = @Active
											SET @EffectiveDate = @StartDate
											SET @isActivated = 1
											SET @Balance = 0
										END
										ELSE
										BEGIN
											SET @Balance = ISNULL(@PolicyValue,0) - (ISNULL(@PaidAmount,0))
											SET @isActivated = 0
											SET @PolicyStatus = @Idle

										END

									INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
									SELECT	@FamilyId, GETDATE(),@StartDate,@EffectiveDate,@ExpiryDate,@PolicyStatus,@PolicyValue,@ProdID,@OfficerID,@PolicyStage,GETDATE(),@AuditUserId, 0 isOffline 
									SELECT @PolicyId = SCOPE_IDENTITY()

									UPDATE @tblDetail SET policyID  = @PolicyId WHERE policyID = @PreviousPolicyID

									DECLARE @InsureeId INT
									DECLARE CurNewPolicy CURSOR FOR SELECT I.InsureeID FROM tblInsuree I WHERE I.FamilyID = @FamilyId AND I.ValidityTo IS NULL
									OPEN CurNewPolicy;
									FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
									WHILE @@FETCH_STATUS = 0
									BEGIN
										EXEC uspAddInsureePolicy @InsureeId;
										FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
									END
									CLOSE CurNewPolicy;
									DEALLOCATE CurNewPolicy; 
									INSERT INTO @PolicyProcessed (id,matchedpayment) VALUES (@PreviousPolicyID,1)
								END	
							ELSE If  (SELECT SUM(matchedpayment) FROM @PolicyProcessed WHERE id=@PreviousPolicyID )>0
									UPDATE @PolicyProcessed SET matchedpayment = matchedpayment +1  WHERE id = @PreviousPolicyID	
								
								
								--INSERT PREMIUMS FOR INDIVIDUAL RENEWALS ONLY
								if ISNULL(@PremiumID,0) = 0 
								BEGIN								
									INSERT INTO tblPremium(PolicyID, Amount, PayType, Receipt, PayDate, ValidityFrom, AuditUserID)
									SELECT @PolicyId, @PaidAmount, 'C',@TransactionNo, GETDATE() PayDate, GETDATE() ValidityFrom, @AuditUserId AuditUserID 
									SELECT @PremiumId = SCOPE_IDENTITY()
								END
				


				UPDATE @tblDetail SET PremiumID = @PremiumId  WHERE PaymentDetailsID = @PaymentDetailsID
				-- insert message only once
				IF (SELECT SUM(matchedpayment) FROM @PolicyProcessed WHERE id=@PreviousPolicyID )=1
					INSERT INTO @tblFeedback(InsuranceNumber, productCode, PhoneNumber, isActivated ,Balance, fdType)
					SELECT @InsuranceNumber, @productCode, @PhoneNumber, @isActivated,@Balance, 'A'

			FETCH NEXT FROM CurPolicies INTO @PaymentDetailsID,  @InsuranceNumber, @productCode, @PhoneNumber, @DistributedValue, @PreviousPolicyID, @PolicyStage, @AlreadyPaidDValue, @PremiumID
			END
			CLOSE CurPolicies;
			DEALLOCATE CurPolicies; 
			END
			
			-- ABOVE LOOP SELF PAYER ONLY

		--Update the actual tblpayment & tblPaymentDetails
			UPDATE PD SET PD.PremiumID = TPD.PremiumId, PD.Amount = TPD.DistributedValue,  ValidityFrom =GETDATE(), AuditedUserId = @AuditUserId 
			FROM @tblDetail TPD
			INNER JOIN tblPaymentDetails PD ON PD.PaymentDetailsID = TPD.PaymentDetailsID 
			

			UPDATE P SET P.PaymentStatus = 5, P.MatchedDate = GETDATE(),  ValidityFrom = GETDATE(), AuditedUSerID = @AuditUserId FROM tblPayment P
			INNER JOIN @tblDetail PD ON PD.PaymentID = P.PaymentID

			IF EXISTS(SELECT COUNT(1) FROM @tblHeader PH )
			BEGIN
				SET @paymentMatched= (SELECT COUNT(1) FROM @tblHeader PH ) -- some unvalid payment were removed after validation
				INSERT INTO @tblFeedback(fdMsg, fdType )
				SELECT CONVERT(NVARCHAR(4), ISNULL(@paymentMatched,0))  +' Payment(s) matched ', 'I' 
			 END
			SELECT paymentMatched = SUM(matchedpayment) FROM @PolicyProcessed
			UPDATE @tblFeedback SET PaymentFound =ISNULL(@paymentFound,0), PaymentMatched = ISNULL(@paymentMatched,0),APIKey = (SELECT APIKey FROM tblIMISDefaults)

		IF @InTopIsolation = 0 
			COMMIT TRANSACTION MATCHPAYMENT
		
		SELECT fdMsg, fdType, productCode, InsuranceNumber, PhoneNumber, isActivated, Balance,PaymentFound, PaymentMatched, APIKey FROM @tblFeedback
		RETURN 0
		END TRY
		BEGIN CATCH
			IF @InTopIsolation = 0
				ROLLBACK TRANSACTION MATCHPAYMENT
			SELECT fdMsg, fdType FROM @tblFeedback
			SELECT ERROR_MESSAGE ()
			RETURN -1
		END CATCH
	

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspMoveLocation](
	@SourceId INT,
	@DestinationId INT,
	@LocationType CHAR(1),		--'D' : District, 'W' : Ward, 'V' : Village
	@AuditUserId INT,
	@ErrorMessage INT = 0 OUTPUT
)
AS	
BEGIN
	BEGIN TRY
	    SET @ErrorMessage=-1;
		DECLARE @DistrictId INT,
				@WardId INT, 
				@Region INT

		BEGIN TRAN LOC
			--Check if the @LocationType parameter is right
				IF @LocationType  NOT IN ('D', 'W', 'V')
				BEGIN
					SET @ErrorMessage=1;
					RAISERROR(N'Invalid Location Type', 16, 1);
				END
			
			--Check if the destination is already a parent
			IF EXISTS(SELECT 1 FROM tblLocations WHERE LocationId = @SourceId AND ParentLocationId = @DestinationId AND ValidityTo IS NULL)
			BEGIN
				SET @ErrorMessage=2;
				RAISERROR('Source location already belongs to the Destination Location', 16, 1);
			END

			--Make a copy of an existing record
			INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, ValidityFrom, ValidityTo, LegacyId, AuditUserId,MalePopulation,FemalePopulation,OtherPopulation,Families)
			SELECT LocationCode, Locationname, ParentLocationId, LocationType, ValidityFrom, GETDATE() ValidityTo, LocationId, AuditUserId ,MalePopulation,FemalePopulation,OtherPopulation,Families
			FROM tblLocations
			WHERE LocationId = @SourceId;


			--Update the location
			UPDATE tblLocations SET ParentLocationId = @DestinationId
			WHERE LocationId = @SourceId;
			
			SET @ErrorMessage=0;
		
		COMMIT TRAN LOC;
	END TRY
	BEGIN CATCH
		SELECT   ERROR_MESSAGE();

		SET @ErrorMessage = 99;
		IF @@TRANCOUNT  > 0 ROLLBACK TRAN LOC;
	END CATCH
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspPhoneExtract]
(
	
	@LocationId int =  0
)
AS
BEGIN
	DECLARE @NotSet as INT = -1

	IF NOT OBJECT_ID('tempdb..#tempBase') IS NULL DROP TABLE #tempBase

		SELECT PR.ProdID,PL.PolicyID,I.CHFID,P.PhotoFolder + case when RIGHT(P.PhotoFolder,1) = '\\' then '' else '\\' end + P.PhotoFileName PhotoPath,I.LastName + ' ' + I.OtherNames InsureeName,
		CONVERT(VARCHAR,DOB,103) DOB, CASE WHEN I.Gender = 'M' THEN 'Male' ELSE 'Female' END Gender,PR.ProductCode,PR.ProductName,
		CONVERT(VARCHAR(12),IP.ExpiryDate,103) ExpiryDate, 
		CASE WHEN IP.EffectiveDate IS NULL THEN 'I' WHEN CAST(GETDATE() AS DATE) NOT BETWEEN IP.EffectiveDate AND IP.ExpiryDate THEN 'E' ELSE 
		CASE PL.PolicyStatus WHEN 1 THEN 'I' WHEN 2 THEN 'A' WHEN 4 THEN 'S' WHEN 16 THEN 'R' ELSE 'E' END
		END  AS [Status], ISNULL(MemCount.Members ,0) as FamCount
		INTO #tempBase
		FROM tblInsuree I LEFT OUTER JOIN tblPhotos P ON I.PhotoID = P.PhotoID
		INNER JOIN tblFamilies F ON I.FamilyId = F.FamilyId 
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		LEFT OUTER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
		LEFT OUTER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
		LEFT OUTER JOIN tblInsureePolicy IP ON IP.InsureeId = I.InsureeId AND IP.PolicyId = PL.PolicyID
		LEFT OUTER JOIN
		(SELECT FamilyID, COUNT(InsureeID) Members FROM tblInsuree WHERE tblInsuree.ValidityTo IS NULL GROUP BY FamilyID) MemCount ON MemCount.FamilyID = F.FamilyID 
 		WHERE I.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND P.ValidityTo IS NULL AND PR.ValidityTo IS NULL AND IP.ValidityTo IS NULL AND F.ValidityTo IS NULL
		AND (D.DistrictID = @LocationId or @LocationId= 0)


		
	IF NOT OBJECT_ID('tempdb..#tempDedRem')IS NULL DROP TABLE #tempDedRem
	CREATE TABLE #tempDedRem (PolicyId INT, ProdID INT,DedInsuree DECIMAL(18,2),DedOPInsuree DECIMAL(18,2),DedIPInsuree DECIMAL(18,2),MaxInsuree DECIMAL(18,2),MaxOPInsuree DECIMAL(18,2),MaxIPInsuree DECIMAL(18,2),DedTreatment DECIMAL(18,2),DedOPTreatment DECIMAL(18,2),DedIPTreatment DECIMAL(18,2),MaxTreatment DECIMAL(18,2),MaxOPTreatment DECIMAL(18,2),MaxIPTreatment DECIMAL(18,2),DedPolicy DECIMAL(18,2),DedOPPolicy DECIMAL(18,2),DedIPPolicy DECIMAL(18,2),MaxPolicy DECIMAL(18,2),MaxOPPolicy DECIMAL(18,2),MaxIPPolicy DECIMAL(18,2))

	INSERT INTO #tempDedRem(PolicyId, ProdID ,DedInsuree ,DedOPInsuree ,DedIPInsuree ,MaxInsuree ,MaxOPInsuree ,MaxIPInsuree ,DedTreatment ,DedOPTreatment ,DedIPTreatment ,MaxTreatment ,MaxOPTreatment ,MaxIPTreatment ,DedPolicy ,DedOPPolicy ,DedIPPolicy ,MaxPolicy ,MaxOPPolicy ,MaxIPPolicy)

					SELECT #tempBase.PolicyId, #tempBase.ProdID,
					DedInsuree ,DedOPInsuree ,DedIPInsuree ,
					MaxInsuree,MaxOPInsuree,MaxIPInsuree ,
					DedTreatment ,DedOPTreatment ,DedIPTreatment,
					MaxTreatment ,MaxOPTreatment ,MaxIPTreatment,
					DedPolicy ,DedOPPolicy ,DedIPPolicy , 
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy > MaxCeilingPolicy THEN MaxCeilingPolicy ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy END MaxPolicy ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy > MaxCeilingPolicyOP THEN MaxCeilingPolicyOP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy END MaxOPPolicy ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy > MaxCeilingPolicyIP THEN MaxCeilingPolicyIP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy END MaxIPPolicy
					
		

					FROM tblProduct INNER JOIN #tempBase ON tblProduct.ProdID = #tempBase.ProdID 
					WHERE ValidityTo IS NULL
					GROUP BY 
					#tempBase.PolicyId, #tempBase.ProdID,
					DedInsuree ,DedOPInsuree ,DedIPInsuree ,
					MaxInsuree,MaxOPInsuree,MaxIPInsuree ,
					DedTreatment ,DedOPTreatment ,DedIPTreatment,
					MaxTreatment ,MaxOPTreatment ,MaxIPTreatment,
					DedPolicy ,DedOPPolicy ,DedIPPolicy , 
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy > MaxCeilingPolicy THEN MaxCeilingPolicy ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy END  ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy > MaxCeilingPolicyOP THEN MaxCeilingPolicyOP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy END  ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy > MaxCeilingPolicyIP THEN MaxCeilingPolicyIP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - FamCount < 0 THEN MemberCount ELSE FamCount END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy END 


IF (SELECT COUNT(*) FROM #tempBase WHERE [Status] = 'A') > 0
		SELECT CHFID, PhotoPath, InsureeName, DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) as DedType
		,
		CASE WHEN (COALESCE(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,@NotSet)) = @NotSet) THEN NULL ELSE COALESCE			(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0))  END
		as Ded1
		,
		--ded2

		CASE WHEN 
		(
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) = 1 
		
		) THEN 
		CASE WHEN (COALESCE(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,@NotSet)) = @NotSet) THEN NULL ELSE COALESCE			(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0))  END
		ELSE CASE WHEN COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) = @NotSet THEN 
		(CASE WHEN COALESCE(DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) = @NotSet THEN NULL ELSE COALESCE(DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,0))  END) 
		ELSE NULL END END
		  as Ded2
		,
		--ceiling 1
		CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,@NotSet)) = @NotSet THEN NULL ELSE (CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) < 0 THEN 0 ELSE COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) END)END 
		 as Ceiling1 ,
		
		--ceiling 2
		CASE WHEN 
		(
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) = 1 
		
		) THEN 
		CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,@NotSet)) = @NotSet THEN NULL ELSE (CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) < 0 THEN 0 ELSE COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) END)END 
		ELSE CASE WHEN COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) = @NotSet THEN 
		(CASE WHEN COALESCE(MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) = @NotSet THEN NULL ELSE COALESCE(MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,0))  END) 
		ELSE NULL END  END 

		
		  as Ceiling2
		
		
		  from #tempBase Base LEFT OUTER JOIN #tempDedRem DedRem ON Base.PolicyID = DedRem.PolicyId AND Base.ProdID = DedRem.ProdID WHERE [Status] = 'A';
		
	ELSE 
		
		IF (SELECT COUNT(1) FROM #tempBase WHERE (YEAR(GETDATE()) - YEAR(CONVERT(DATETIME,ExpiryDate,103))) <= 2) > 1
			SELECT CHFID, PhotoPath, InsureeName, DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],
			CAST( CASE WHEN COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet THEN 1 ELSE 
		(CASE WHEN 
		COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet THEN 1.1 ELSE
		(CASE WHEN COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet THEN 1 ELSE 
		(CASE WHEN COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet THEN 1.1 ELSE 1 END)END)END) END 
		as INT) as DedType
			
		,
		CASE WHEN COALESCE(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0)) = 0 THEN NULL ELSE COALESCE			(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0))  END
		as Ded1
		,
		--Deduct2 
		CASE WHEN 
		(
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) = 1 
		
		) THEN 
		CASE WHEN (COALESCE(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,@NotSet)) = @NotSet) THEN NULL ELSE COALESCE			(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0))  END
		ELSE CASE WHEN COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) = @NotSet THEN 
		(CASE WHEN COALESCE(DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) = @NotSet THEN NULL ELSE COALESCE(DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,0))  END) 
		ELSE NULL END END
		  as Ded2 ,
		--ceiling 1
		CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,@NotSet)) = @NotSet THEN NULL ELSE (CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) < 0 THEN 0 ELSE COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) END)END 
		 as Ceiling1,
		 --ceiling 2
		 CASE WHEN 
		(
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) = 1 
		
		) THEN 
		CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,@NotSet)) = @NotSet THEN NULL ELSE (CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) < 0 THEN 0 ELSE COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) END)END 
		ELSE CASE WHEN COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) = @NotSet THEN 
		(CASE WHEN COALESCE(MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) = @NotSet THEN NULL ELSE COALESCE(MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,0))  END) 
		ELSE NULL END  END 

		
		  as Ceiling2

	 from #tempBase Base LEFT OUTER JOIN #tempDedRem DedRem ON Base.PolicyID = DedRem.PolicyId AND Base.ProdID = DedRem.ProdID WHERE (YEAR(GETDATE()) - YEAR(CONVERT(DATETIME,ExpiryDate,103))) <= 2 
		ELSE
			SELECT CHFID, PhotoPath, InsureeName, DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],
			CAST( CASE WHEN COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet THEN 1 ELSE 
		(CASE WHEN 
		COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet THEN 1.1 ELSE
		(CASE WHEN COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet THEN 1 ELSE 
		(CASE WHEN COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet THEN 1.1 ELSE 1 END)END)END) END 
		as INT) as DedType
		,
		CASE WHEN COALESCE(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0)) = 0 THEN NULL ELSE COALESCE			(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0))  END
		as Ded1
		,
		--ded2

		CASE WHEN 
		(
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) = 1 
		
		) THEN 
		CASE WHEN (COALESCE(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,@NotSet)) = @NotSet) THEN NULL ELSE COALESCE			(DedInsuree,DedTreatment,DedPolicy,DedIPInsuree,DedIPTreatment,ISNULL(DedIPPolicy,0))  END
		ELSE CASE WHEN COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) = @NotSet THEN 
		(CASE WHEN COALESCE(DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) = @NotSet THEN NULL ELSE COALESCE(DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,0))  END) 
		ELSE NULL END END
		  as Ded2
		  ,
		--ceiling 1
		CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,@NotSet)) = @NotSet THEN NULL ELSE (CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) < 0 THEN 0 ELSE COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) END)END 
		 as Ceiling1
		,
		--ceiling 2

		CASE WHEN 
		(
		CAST(
		CASE WHEN (COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN 
		(COALESCE(MaxIPInsuree,MaxIPTreatment,MaxIPPolicy,MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE
		(CASE WHEN (COALESCE(DedInsuree,DedTreatment,ISNULL(DedPolicy,@NotSet)) <> @NotSet) THEN 1 ELSE 
		(CASE WHEN (COALESCE(DedIPInsuree,DedIPTreatment,DedIPPolicy,DedOPInsuree,DedOPTreatment,ISNULL(DedOPPolicy,@NotSet)) <> @NotSet) THEN 1.1 ELSE 1 END)END)END) END 
		 AS INT) = 1 
		
		) THEN 
		CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,@NotSet)) = @NotSet THEN NULL ELSE (CASE WHEN COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) < 0 THEN 0 ELSE COALESCE(MaxInsuree,MaxTreatment,MaxPolicy,MaxIPInsuree,MaxIPTreatment,ISNULL(MaxIPPolicy,0)) END)END 
		ELSE CASE WHEN COALESCE(MaxInsuree,MaxTreatment,ISNULL(MaxPolicy,@NotSet)) = @NotSet THEN 
		(CASE WHEN COALESCE(MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,@NotSet)) = @NotSet THEN NULL ELSE COALESCE(MaxOPInsuree,MaxOPTreatment,ISNULL(MaxOPPolicy,0))  END) 
		ELSE NULL END  END 
		  as Ceiling2
 from #tempBase Base LEFT OUTER JOIN #tempDedRem DedRem ON Base.PolicyID = DedRem.PolicyId AND Base.ProdID = DedRem.ProdID 
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspPolicyInquiry] 
(
	@CHFID NVARCHAR(12) = '',
	@LocationId int =  0
)
AS
BEGIN
	IF NOT OBJECT_ID('tempdb..#tempBase') IS NULL DROP TABLE #tempBase

		SELECT PR.ProdID,PL.PolicyID,I.CHFID,P.PhotoFolder + case when RIGHT(P.PhotoFolder,1) = '\\' then '' else '\\' end + P.PhotoFileName PhotoPath,I.LastName + ' ' + I.OtherNames InsureeName,
		CONVERT(VARCHAR,DOB,103) DOB, CASE WHEN I.Gender = 'M' THEN 'Male' ELSE 'Female' END Gender,PR.ProductCode,PR.ProductName,
		CONVERT(VARCHAR(12),IP.ExpiryDate,103) ExpiryDate, 
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
		AND (I.CHFID = @CHFID OR @CHFID = '')
		AND (D.DistrictID = @LocationId or @LocationId= 0)


	DECLARE @Members INT = (SELECT COUNT(1) FROM tblInsuree WHERE FamilyID = (SELECT TOP 1 FamilyId FROM tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL) AND ValidityTo IS NULL); 		
	DECLARE @InsureeId INT = (SELECT InsureeId FROM tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL)
	DECLARE @FamilyId INT = (SELECT FamilyId FROM tblInsuree WHERE ValidityTO IS NULL AND CHFID = @CHFID);

		
	IF NOT OBJECT_ID('tempdb..#tempDedRem')IS NULL DROP TABLE #tempDedRem
	CREATE TABLE #tempDedRem (PolicyId INT, ProdID INT,DedInsuree DECIMAL(18,2),DedOPInsuree DECIMAL(18,2),DedIPInsuree DECIMAL(18,2),MaxInsuree DECIMAL(18,2),MaxOPInsuree DECIMAL(18,2),MaxIPInsuree DECIMAL(18,2),DedTreatment DECIMAL(18,2),DedOPTreatment DECIMAL(18,2),DedIPTreatment DECIMAL(18,2),MaxTreatment DECIMAL(18,2),MaxOPTreatment DECIMAL(18,2),MaxIPTreatment DECIMAL(18,2),DedPolicy DECIMAL(18,2),DedOPPolicy DECIMAL(18,2),DedIPPolicy DECIMAL(18,2),MaxPolicy DECIMAL(18,2),MaxOPPolicy DECIMAL(18,2),MaxIPPolicy DECIMAL(18,2))

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


IF (SELECT COUNT(*) FROM #tempBase WHERE [Status] = 'A') > 0
		SELECT CHFID, PhotoPath, InsureeName, DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1 ,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase WHERE [Status] = 'A';
		
	ELSE 
		IF (SELECT COUNT(1) FROM #tempBase WHERE (YEAR(GETDATE()) - YEAR(CONVERT(DATETIME,ExpiryDate,103))) <= 2) > 1
			SELECT CHFID, PhotoPath, InsureeName, DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase WHERE (YEAR(GETDATE()) - YEAR(CONVERT(DATETIME,ExpiryDate,103))) <= 2;
		ELSE
			SELECT CHFID, PhotoPath, InsureeName, DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase 
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[uspPolicyInquiry2] 
	@CHFID as nvarchar(9)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @InsureeID as int
    DECLARE @FamilyID as int 
    
    DECLARE @PolicyID as int 
    
    DECLARE @LastName as nvarchar(100)
    DECLARE @OtherNames as nvarchar(100)
    DECLARE @DOB as date
    DECLARE @Gender as nvarchar(1)
    DECLARE @PhotoName as nvarchar(100)
    DECLARE @PhotoFolder as nvarchar(100)
    DECLARE @PolicyStatus as int 
    DECLARE @ExpiryDate as date
    DECLARE @ProductCode as nvarchar(8)
    DECLARE @ProductName as nvarchar(100)
        
    DECLARE @DedInsuree as decimal(18,2) 
    DECLARE @DedOPInsuree as decimal(18,2) 
    DECLARE @DedIPInsuree as decimal(18,2) 
    DECLARE @MaxInsuree as decimal(18,2) 
    DECLARE @MaxOPInsuree as decimal(18,2) 
    DECLARE @MaxIPInsuree as decimal(18,2) 
    
    DECLARE @DedTreatment as decimal(18,2) 
    DECLARE @DedOPTreatment as decimal(18,2) 
    DECLARE @DedIPTreatment as decimal(18,2) 
    DECLARE @MaxTreatment as decimal(18,2) 
    DECLARE @MaxOPTreatment as decimal(18,2) 
    DECLARE @MaxIPTreatment as decimal(18,2) 
    
    DECLARE @DedPolicy as decimal(18,2) 
    DECLARE @DedOPPolicy as decimal(18,2) 
    DECLARE @DedIPPolicy as decimal(18,2) 
    DECLARE @MaxPolicy as decimal(18,2)
    DECLARE @MaxOPPolicy as decimal(18,2) 
    DECLARE @MaxIPPolicy as decimal(18,2) 
    
    DECLARE @CalcDed as decimal(18,2)
    DECLARE @CalcIPDed as decimal(18,2)
    DECLARE @CalcOPDed as decimal(18,2)
    DECLARE @CalcMax as decimal(18,2)
    DECLARE @CalcIPMax as decimal(18,2)
    DECLARE @CalcOPMax as decimal(18,2)
    
    DECLARE @TempValue as decimal(18,2)
    DECLARE @CalcValue as decimal(18,2)
    
    DECLARE @C1 as bit 
    DECLARE @C2 as bit 
    DECLARE @C3 as bit 
    DECLARE @C4 as bit
    DECLARE @C5 as bit
    DECLARE @C6 as bit
    
    SET @C1 = 0
    SET @C2 = 0
    SET @C3 = 0
    SET @C4 = 0
    SET @C5 = 0
    SET @C6 = 0
    
    
    CREATE TABLE #Inquiry  (CHFID nvarchar(9),
							LastName nvarchar(100),
							OtherNames nvarchar(100),
							DOB  date,
							Gender  nvarchar(1),
							PolicyStatus  int ,
							ExpiryDate  date,
							ProductCode nvarchar(8),
							ProductName nvarchar(100),
							Ded decimal(18,2),
							DedIP decimal (18,2),
							DedOP decimal (18,2),
							MaxGEN decimal(18,2),
							MaxIP decimal(18,2),
							MaxOP decimal(18,2)
							)
    
    DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR 
			SELECT      tblInsuree.InsureeID, tblPolicy.PolicyID, tblInsuree.LastName, tblInsuree.OtherNames, tblInsuree.DOB, tblInsuree.Gender, tblPhotos.PhotoFolder, tblPhotos.PhotoFileName, tblPolicy.PolicyStatus, tblPolicy.ExpiryDate, 
						  tblProduct.ProductCode, tblProduct.ProductName, tblProduct.DedInsuree, tblProduct.DedOPInsuree, tblProduct.DedIPInsuree, tblProduct.MaxInsuree, 
						  tblProduct.MaxOPInsuree, tblProduct.MaxIPInsuree, tblProduct.DedTreatment, tblProduct.DedOPTreatment, tblProduct.DedIPTreatment, tblProduct.MaxTreatment, 
						  tblProduct.MaxOPTreatment, tblProduct.MaxIPTreatment, tblProduct.DedPolicy, tblProduct.DedOPPolicy, tblProduct.DedIPPolicy, tblProduct.MaxPolicy, 
						  tblProduct.MaxOPPolicy, tblProduct.MaxIPPolicy
			FROM         tblPhotos RIGHT OUTER JOIN
						  tblInsuree ON tblPhotos.PhotoID = tblInsuree.PhotoID LEFT OUTER JOIN
						  tblPolicy LEFT OUTER JOIN
						  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID RIGHT OUTER JOIN
						  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID ON tblInsuree.FamilyID = tblFamilies.FamilyID
			WHERE     (tblInsuree.ValidityTo IS NULL) AND (tblPolicy.ValidityTo IS NULL) AND (tblInsuree.CHFID = @CHFID)
		--SELECT     tblPolicy.PolicyID, tblInsuree.LastName, tblInsuree.OtherNames, tblInsuree.DOB, tblInsuree.Gender, tblPolicy.PolicyStatus, tblPolicy.ExpiryDate, 
		--					  tblProduct.ProductCode, tblProduct.ProductName, tblProduct.DedInsuree, tblProduct.DedOPInsuree, tblProduct.DedIPInsuree, tblProduct.MaxInsuree, 
		--					  tblProduct.MaxOPInsuree, tblProduct.MaxIPInsuree, tblProduct.DedTreatment, tblProduct.DedOPTreatment, tblProduct.DedIPTreatment, tblProduct.MaxTreatment, 
		--					  tblProduct.MaxOPTreatment, tblProduct.MaxIPTreatment, tblProduct.DedPolicy, tblProduct.DedOPPolicy, tblProduct.DedIPPolicy, tblProduct.MaxPolicy, 
		--					  tblProduct.MaxOPPolicy, tblProduct.MaxIPPolicy
		--FROM         tblInsuree INNER JOIN
		--					  tblFamilies ON tblInsuree.FamilyID = tblFamilies.FamilyID INNER JOIN
		--					  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
		--					  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID
		--WHERE     (tblInsuree.ValidityTo IS NULL) AND (tblPolicy.ValidityTo IS NULL) AND tblInsuree.CHFID = @CHFID
	
	OPEN LOOP1
	FETCH NEXT FROM LOOP1 INTO @InsureeID, @PolicyID, @LastName,@OtherNames,@DOB,@Gender,@PhotoFolder,@PhotoName, @PolicyStatus,@ExpiryDate,@ProductCode,@ProductName,@DedInsuree,@DedOPInsuree,@DedIPInsuree,@MaxInsuree,
    @MaxOPInsuree,@MaxIPInsuree,@DedTreatment,@DedOPTreatment,@DedIPTreatment,@MaxTreatment,@MaxOPTreatment,@MaxIPTreatment,@DedPolicy,@DedOPPolicy,
    @DedIPPolicy,@MaxPolicy,@MaxOPPolicy,@MaxIPPolicy
    
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--reset all deductables and ceilings 
		SET @CalcDed = 0 
		SET @CalcIPDed = 0 
		SET @CalcOPDed = 0 
		SET @CalcMax   = -1 
		SET @CalcIPMax  = -1 
		SET @CalcOPMax  = -1
		
		--************************DEDUCTIONS*********************************
		
		--TREATMENT level
		IF ISNULL(@DedTreatment,0) <> 0   
			SET @CalcDed = @DedTreatment 
		ELSE
		BEGIN
			IF ISNULL(@DedIPTreatment ,0) <> 0   
				SET @CalcIPDed  = @DedIPTreatment  
			IF ISNULL(@DedOPTreatment ,0) <> 0   
				SET @CalcOPDed  = @DedOPTreatment  
		END
		
		--INSUREE level
		IF ISNULL(@DedInsuree ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(DedG),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @DedInsuree > @TempValue 
				SET @CalcDed = @DedInsuree - @TempValue
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@DedIPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedIP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedIPInsuree  > @TempValue 
					SET @CalcIPDed  = @DedIPInsuree  - @TempValue
			END
			
			IF ISNULL(@DedOPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedOP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedOPInsuree  > @TempValue 
					SET @CalcOPDed  = @DedOPInsuree  - @TempValue
			END	
		END
		
		
		--POLICY level
		IF ISNULL(@DedPolicy  ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(DedG),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @DedPolicy  > @TempValue 
				SET @CalcDed = @DedPolicy - @TempValue
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@DedIPPolicy ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedIP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedIPPolicy   > @TempValue 
					SET @CalcIPDed  = @DedIPPolicy - @TempValue
			END
			
			IF ISNULL(@DedOPPolicy  ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedOP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedOPPolicy   > @TempValue 
					SET @CalcOPDed  = @DedOPPolicy - @TempValue
			END	
		END
		
		--********************CEILINGS*************************** 
		
		--TREATMENT level
		IF ISNULL(@MaxTreatment ,0) <> 0   
			SET @CalcMax = @MaxTreatment  
		IF ISNULL(@MaxIPTreatment  ,0) <> 0   
			SET @CalcIPMax   = @MaxIPTreatment   
		IF ISNULL(@MaxOPTreatment  ,0) <> 0   
			SET @CalcOPMax  = @MaxOPTreatment   
		
		--INSUREE level
		IF ISNULL(@MaxInsuree  ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(RemG),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @MaxInsuree > @TempValue 
				SET @Calcmax  = @MaxInsuree - @TempValue
			ELSE 
				SET @Calcmax  = 0   -- no value left !! 
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@MaxIPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemIP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxIPInsuree > @TempValue 
					SET @CalcIPMax   = @MaxIPInsuree  - @TempValue
				ELSE 
					SET @CalcIPMax   = 0   -- no value left !! 
			END
			IF ISNULL(@MaxOPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemOP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxOPInsuree > @TempValue 
					SET @CalcOPMax   = @MaxOPInsuree  - @TempValue
				ELSE 
					SET @CalcOPMax   = 0   -- no value left !! 
			END
			
		END
		
		-- POLICY level
		IF ISNULL(@MaxPolicy ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(RemG),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @MaxPolicy  > @TempValue 
				SET @Calcmax  = @MaxPolicy - @TempValue
			ELSE 
				SET @Calcmax  = 0   -- no value left !! 
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@MaxIPPolicy ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemIP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxIPPolicy  > @TempValue 
					SET @CalcIPMax   = @MaxIPPolicy - @TempValue
				ELSE 
					SET @CalcIPMax   = 0   -- no value left !! 
			END
			IF ISNULL(@MaxOPPolicy  ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemOP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxOPPolicy  > @TempValue 
					SET @CalcOPMax   = @MaxOPPolicy  - @TempValue
				ELSE 
					SET @CalcOPMax   = 0   -- no value left !! 
			END
			
		END
		
		IF @PolicyStatus = 2
		BEGIN
			IF @CalcDed <> 0 
				SET @C1 = 1
			IF @CalcIPDed <> 0 
				SET @C2  = 1
			IF @CalcOPDed  <> 0 
				SET @C3  = 1
			IF @CalcMax  >= 0  
				SET @C4  = 1
			IF @CalcIPMax >= 0  
				SET @C5  = 1
			IF @CalcOPMax >= 0  
				SET @C6  = 1
		END
		
		IF @CalcIPMax = -1 
			SET @CalcIPMax = NULL
		IF @CalcOPMax = -1 
			SET @CalcOPMax = NULL
		IF @CalcMax = -1 
			SET @CalcMax = NULL	
		
		--INSERT Into Temp Table
		INSERT #Inquiry (CHFID,LastName,OtherNames,DOB,Gender,PolicyStatus,ExpiryDate,ProductCode,ProductName,
							Ded,
							DedIP,
							DedOP,
							MaxGEN,
							MaxIP,
							MaxOP)
						VALUES
							(@CHFID,@LastName,@OtherNames,@DOB,@Gender,@PolicyStatus,@ExpiryDate,@ProductCode,@ProductName,
							 @CalcDed,
							 @CalcIPDed,
							 @CalcOPDed,
							 @CalcMax,
							 @CalcIPMax,
							 @CalcOPMax
							)
		
		
		FETCH NEXT FROM LOOP1 INTO @InsureeID, @PolicyID, @LastName,@OtherNames,@DOB,@Gender,@PhotoFolder,@PhotoName,@PolicyStatus,@ExpiryDate,@ProductCode,@ProductName,@DedInsuree,@DedOPInsuree,@DedIPInsuree,@MaxInsuree,
    @MaxOPInsuree,@MaxIPInsuree,@DedTreatment,@DedOPTreatment,@DedIPTreatment,@MaxTreatment,@MaxOPTreatment,@MaxIPTreatment,@DedPolicy,@DedOPPolicy,
    @DedIPPolicy,@MaxPolicy,@MaxOPPolicy,@MaxIPPolicy
    
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1
    
    --Now output table 
    DECLARE @STR as nvarchar(1000)
    
    SET @STR = 'SELECT CHFID as ID,LastName as [Last Name],OtherNames as [Other Names],DOB,Gender,PolicyStatus as [Status],ExpiryDate as [Expiry],ProductCode as [Code],ProductName as [Product]' 
    IF @C1 <> 0 
		SET @STR = @STR + ',Ded as [Deductable]'
    IF @C2 <> 0 
		SET @STR = @STR + ',DedIP as [IP Deductable]'
	IF @C3  <> 0 
		SET @STR = @STR + ',DedOP as [OP Deductable]'
	IF @C4  <> 0  
		SET @STR = @STR + ',MAXGEN as [Ceiling]'
	IF @C5 <> 0  
		SET @STR = @STR + ',MAXIP as [IP Ceiling]'
	IF @C6 <> 0  
		SET @STR = @STR + ',MAXOP as [OP Ceiling]'
		
    SET @STR = @STR + ' FROM #Inquiry' 
    
    DECLARE @Active as int
    
    SELECT @Active = ISNULL(COUNT(CHFID),0) FROM #Inquiry WHERE PolicyStatus = 2
    IF @Active > 0 
	BEGIN
		SET @STR = @STR + ' WHERE PolicyStatus = 2'
	END
    ELSE
    BEGIN
		SET @STR = @STR + ' WHERE (PolicyStatus = 4 OR PolicyStatus = 8) AND ABS(DATEDIFF(y,GETDATE(),ExpiryDate)) < 2 '
	END
    
    EXEC(@STR)
    drop table #Inquiry 
    --SELECT * FROM @Inquiry 
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspPolicyRenewalInserts](
	--@RenewalWarning --> 1 = no valid product for renewal  2= No enrollment officer found (no photo)  4= INVALID Enrollment officer
	@RemindingInterval INT = NULL,
	@RegionId INT = NULL,
	@DistrictId INT = NULL,
	@WardId INT = NULL,
	@VillageId INT = NULL, 
	@OfficerId INT = NULL,
	@DateFrom DATE = NULL,
	@DateTo DATE = NULL
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @RenewalID int
	--DECLARE @RemindingInterval as int --days in advance
	
	DECLARE @PolicyID as int 
	DECLARE @FamilyID as int 
	DECLARE @RenewalDate as date
	DECLARE @InsureeID as int
	DECLARE @ProductID as int 
	DECLARE @ProductCode as nvarchar(8)
	DECLARE @ProductName as nvarchar(100)
	DECLARE @ProductFromDate as date 
	DECLARE @ProductToDate as date
	DECLARE @DistrictName as nvarchar(50)
	DECLARE @VillageName as nvarchar(50) 
	DECLARE @WardName as nvarchar(50)  
	DECLARE @CHFID as nvarchar(12)
	DECLARE @InsLastName as nvarchar(100)
	DECLARE @InsOtherNames as nvarchar(100)
	DECLARE @InsDOB as date
    DECLARE @ConvProdID as int    
    --DECLARE @OfficerID as int               
	DECLARE @OffCode as nvarchar(6)
	DECLARE @OffLastName as nvarchar(100)
	DECLARE @OffOtherNames as nvarchar(100)
	DECLARE @OffPhone as nvarchar(50)
	DECLARE @OffSubstID as int 
	DECLARE @OffWorkTo as date 
	
	DECLARE @RenewalWarning as tinyint 

	DECLARE @SMSStatus as tinyint 
	DECLARE @iCount as int 
	
	IF @RemindingInterval IS NULL
		SELECT @RemindingInterval =  PolicyRenewalInterval from tblIMISDefaults  --later to be passed as parameter or reading from a default table 
	
	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR 
		--SELECT     tblPolicy.PolicyID, tblFamilies.FamilyID, DATEADD(d, 1, tblPolicy.ExpiryDate) AS RenewalDate, tblFamilies.InsureeID, tblProduct.ProdID, tblProduct.ProductCode, 
  --                    tblProduct.ProductName, tblProduct.DateFrom, tblProduct.DateTo, tblDistricts.DistrictName, tblVillages.VillageName, tblWards.WardName, tblInsuree.CHFID, 
  --                    tblInsuree.LastName, tblInsuree.OtherNames, tblInsuree.DOB, tblProduct.ConversionProdID,tblOfficer.OfficerID, tblOfficer.Code, tblOfficer.LastName AS OffLastName, 
  --                    tblOfficer.OtherNames AS OffOtherNames, tblOfficer.Phone, tblOfficer.OfficerIDSubst, tblOfficer.WorksTo
		--FROM         tblPhotos LEFT OUTER JOIN
		--					  tblOfficer ON tblPhotos.OfficerID = tblOfficer.OfficerID RIGHT OUTER JOIN
		--					  tblInsuree ON tblPhotos.PhotoID = tblInsuree.PhotoID RIGHT OUTER JOIN
		--					  tblDistricts RIGHT OUTER JOIN
		--					  tblPolicy INNER JOIN
		--					  tblProduct ON tblProduct.ProdID = tblPolicy.ProdID INNER JOIN
		--					  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID ON tblDistricts.DistrictID = tblFamilies.DistrictID ON 
		--					  tblInsuree.InsureeID = tblFamilies.InsureeID LEFT OUTER JOIN
		--					  tblVillages ON tblFamilies.VillageID = tblVillages.VillageID LEFT OUTER JOIN
		--					  tblWards ON tblFamilies.WardID = tblWards.WardID
		--WHERE     (tblPolicy.PolicyStatus = 2) AND (tblPolicy.ValidityTo IS NULL) AND (DATEDIFF(d, GETDATE(), tblPolicy.ExpiryDate) = @RemindingInterval)


		--============================================================================================
		--NEW QUERY BY HIREN
		--============================================================================================
		SELECT PL.PolicyID, PL.FamilyID, DATEADD(DAY, 1, PL.ExpiryDate) AS RenewalDate, F.InsureeID, Prod.ProdID, Prod.ProductCode, Prod.ProductName,
		Prod.DateFrom, Prod.DateTo, D.DistrictName, V.VillageName, W.WardName, I.CHFID, I.LastName, I.OtherNames, I.DOB, Prod.ConversionProdID, 
		O.OfficerID, O.Code, O.LastName OffLastName, O.OtherNames OffOtherNames, O.Phone, O.OfficerIDSubst, O.WorksTo
		FROM tblPolicy PL 
		INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
		INNER JOIN tblInsuree I ON F.InsureeId = I.InsureeID
		INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdID
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		INNER JOIN tblOfficer O ON PL.OfficerId = O.OfficerID
		LEFT OUTER JOIN tblPolicyRenewals PR ON PL.PolicyID = PR.PolicyID
											AND I.InsureeID = PR.InsureeID
		WHERE PL.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL
		AND PR.PolicyID IS NULL
		AND PL.PolicyStatus IN  (2, 8)
		AND (DATEDIFF(DAY, GETDATE(), PL.ExpiryDate) <= @RemindingInterval OR ISNULL(@RemindingInterval, 0) = 0)
		AND (V.VillageId = @VillageId OR @VillageId IS NULL)
		AND (W.WardId = @WardId OR @WardId IS NULL)
		AND (D.DistrictId = @DistrictId OR @DistrictId IS NULL)
		AND (D.Region = @RegionId OR @RegionId IS NULL)
		AND (O.OfficerId = @OfficerId OR @OfficerId IS NULL)
		AND (PL.ExpiryDate BETWEEN ISNULL(@DateFrom, '00010101') AND ISNULL(@DateTo, '30001231'))

	OPEN LOOP1
	FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
							  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID, @OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @RenewalWarning = 0
		--GET ProductCode or the substitution
		IF ISNULL(@ConvProdID,0) = 0 
		BEGIN
			IF NOT (@RenewalDate BETWEEN @ProductFromDate AND @ProductToDate) 
				SET @RenewalWarning = @RenewalWarning + 1
			
		END
		ELSE
		BEGIN
			SET @iCount = 0 
			WHILE @ConvProdID <> 0 AND @iCount < 20   --this to prevent a recursive loop by wrong datra entries 
			BEGIN
				--get new product info 
				SET @ProductID = @ConvProdID
				SELECT @ConvProdID = ConversionProdID FROM tblProduct WHERE ProdID = @ProductID
				IF ISNULL(@ConvProdID,0) = 0 
				BEGIN
					SELECT @ProductCode = ProductCode from tblProduct WHERE ProdID = @ProductID
					SELECT @ProductName = ProductName  from tblProduct WHERE ProdID = @ProductID
					SELECT @ProductFromDate = DateFrom from tblProduct WHERE ProdID = @ProductID
					SELECT @ProductToDate = DateTo  from tblProduct WHERE ProdID = @ProductID
					
					IF NOT (@RenewalDate BETWEEN @ProductFromDate AND @ProductToDate) 
						SET @RenewalWarning = @RenewalWarning + 1
						
				END
				SET @iCount = @iCount + 1
			END
		END 
		
		IF ISNULL(@OfficerID ,0) = 0 
		BEGIN
			SET @RenewalWarning = @RenewalWarning + 2
		
		END
		ELSE
		BEGIN
			--GET OfficerCode or the substitution
			IF ISNULL(@OffSubstID,0) = 0 
			BEGIN
				IF @OffWorkTo < @RenewalDate
					SET @RenewalWarning = @RenewalWarning + 4
			END
			ELSE
			BEGIN

				SET @iCount = 0 
				WHILE @OffSubstID <> 0 AND @iCount < 20 AND  @OffWorkTo < @RenewalDate  --this to prevent a recursive loop by wrong datra entries 
				BEGIN
					--get new product info 
					SET @OfficerID = @OffSubstID
					SELECT @OffSubstID = OfficerIDSubst FROM tblOfficer  WHERE OfficerID  = @OfficerID
					IF ISNULL(@OffSubstID,0) = 0 
					BEGIN
						SELECT @OffCode = Code from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffLastName = LastName  from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffOtherNames = OtherNames  from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffPhone = Phone  from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffWorkTo = WorksTo  from tblOfficer  WHERE OfficerID  = @OfficerID
						
						IF @OffWorkTo < @RenewalDate
							SET @RenewalWarning = @RenewalWarning + 4
							
					END
					SET @iCount = @iCount + 1
				END
			END 
		END
		

		--Code added by Hiren to check if the policy has another following policy
		IF EXISTS(SELECT 1 FROM tblPolicy 
							WHERE ValidityTo IS NULL 
							AND FamilyId = @FamilyId 
							AND (ProdId = @ProductID OR ProdId = @ConvProdID) 
							AND StartDate >= @RenewalDate)

							GOTO NextPolicy;

		--Check for validity phone number
		SET @SMSStatus = 0   --later to be set as the status of sending !!

		--Insert only if it's not in the table
		IF NOT EXISTS(SELECT 1 FROM tblPolicyRenewals WHERE PolicyId = @PolicyId AND ValidityTo IS NULL)
		BEGIN
			INSERT INTO [dbo].[tblPolicyRenewals]
			   ([RenewalPromptDate]
			   ,[RenewalDate]
			   ,[NewOfficerID]
			   ,[PhoneNumber]
			   ,[SMSStatus]
			   ,[InsureeID]
			   ,[PolicyID]
			   ,[NewProdID]
			   ,[RenewalWarnings]
			   ,[ValidityFrom]
			   ,[AuditCreateUser])
			VALUES
			   (GETDATE()
			   ,@RenewalDate
			   ,@OfficerID
			   ,@OffPhone
			   ,@SMSStatus
			   ,@InsureeID
			   ,@PolicyID
			   ,@ProductID
			   ,@RenewalWarning
			   ,GETDATE()
			   ,0)
		
			--Now get all expired photographs
			SELECT @RenewalID = IDENT_CURRENT('tblPolicyRenewals')
		
			INSERT INTO [dbo].[tblPolicyRenewalDetails]
			   ([RenewalID]
			   ,[InsureeID]
			   ,[ValidityFrom]
			   ,[AuditCreateUser])
           
			   SELECT    @RenewalID,tblInsuree.InsureeID,GETDATE(),0
				FROM         tblFamilies INNER JOIN
						  tblInsuree ON tblFamilies.FamilyID = tblInsuree.FamilyID LEFT OUTER JOIN
						  tblPhotos ON tblInsuree.PhotoID = tblPhotos.PhotoID
						  WHERE tblFamilies.FamilyID = @FamilyID AND tblInsuree.ValidityTo IS NULL AND  
						  ((tblInsuree.PhotoDate IS NULL) 
						  OR
						  (
						   ((DATEDIFF (mm,tblInsuree.PhotoDate,@RenewalDate) >=60 ) 
						  OR ( 
						  DATEDIFF (mm,tblInsuree.PhotoDate,@RenewalDate) >=12 AND DATEDIFF (y,tblInsuree.DOB ,GETDATE() ) < 18
						   ) )
							))
        END
NextPolicy:
		FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
							  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID,@OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo
	
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspPolicyRenewalRpt]
	
	@RangeFrom date = getdate,
	@RangeTo date= getdate,
	@IntervalType as tinyint = 1 ,     -- 1 = Prompt Date in prompting table ; 2 = Expiry Date search in prompting table ; 3 = Dynamic report on expiry in future 
	@OfficerID int = 0,
	@LocationId as int = 0,
	@VillageID as int = 0, 
	@WardID as int = 0 
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF @IntervalType = 1 --Prompting date
	BEGIN 
		SELECT     tblPolicyRenewals.RenewalID,tblPolicyRenewals.RenewalPromptDate , tblPolicyRenewals.RenewalDate, tblPolicyRenewals.PhoneNumber, tblDistricts.DistrictName, tblVillages.VillageName, 
							  tblWards.WardName, tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames, tblProduct.ProductCode, tblProduct.ProductName, 
							  tblPolicyRenewals.RenewalWarnings, tblInsuree_1.CHFID AS PhotoCHFID, tblInsuree_1.LastName AS PhotoLastName, tblInsuree_1.OtherNames AS PhotoOtherNames, tblPolicyRenewals.SMSStatus 
							  
		FROM         tblInsuree AS tblInsuree_1 RIGHT OUTER JOIN
							  tblPolicyRenewalDetails ON tblInsuree_1.InsureeID = tblPolicyRenewalDetails.InsureeID RIGHT OUTER JOIN
							  tblPolicyRenewals INNER JOIN
							  tblInsuree ON tblPolicyRenewals.InsureeID = tblInsuree.InsureeID INNER JOIN
							  tblPolicy ON tblPolicyRenewals.PolicyID = tblPolicy.PolicyID INNER JOIN
							  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID INNER JOIN
							  tblVillages ON tblFamilies.LocationId = tblVillages.VillageID INNER JOIN
							  tblWards ON tblWards.WardID = tblVillages.WardID INNER JOIN
							  tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID INNER JOIN
							  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID ON tblPolicyRenewalDetails.RenewalID = tblPolicyRenewals.RenewalID
		WHERE     (tblPolicyRenewals.RenewalPromptDate BETWEEN @RangeFrom AND @RangeTo) 
				AND CASE @LocationId WHEN 0 THEN 0 ELSE tblDistricts.DistrictID  END = @LocationId
				AND CASE @WardID WHEN 0 THEN 0 ELSE tblWards.WardID  END = @WardID
				AND CASE @VillageID WHEN 0 THEN 0 ELSE tblVillages.VillageID  END = @VillageID
				AND CASE @OfficerID WHEN 0 THEN 0 ELSE tblPolicy.OfficerID   END = @OfficerID
	END
	IF @IntervalType = 2 --Expiry/Renewal date
	BEGIN 
		SELECT     tblPolicyRenewals.RenewalID,tblPolicyRenewals.RenewalPromptDate , tblPolicyRenewals.RenewalDate, tblPolicyRenewals.PhoneNumber, tblDistricts.DistrictName, tblVillages.VillageName, 
							  tblWards.WardName, tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames, tblProduct.ProductCode, tblProduct.ProductName, 
							  tblPolicyRenewals.RenewalWarnings, tblInsuree_1.CHFID AS PhotoCHFID, tblInsuree_1.LastName AS PhotoLastName, tblInsuree_1.OtherNames AS PhotoOtherNames, tblPolicyRenewals.SMSStatus 
							  
		FROM         tblInsuree AS tblInsuree_1 RIGHT OUTER JOIN
							  tblPolicyRenewalDetails ON tblInsuree_1.InsureeID = tblPolicyRenewalDetails.InsureeID RIGHT OUTER JOIN
							  tblPolicyRenewals INNER JOIN
							  tblInsuree ON tblPolicyRenewals.InsureeID = tblInsuree.InsureeID INNER JOIN
							  tblPolicy ON tblPolicyRenewals.PolicyID = tblPolicy.PolicyID INNER JOIN
							  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID INNER JOIN
							  tblVillages ON tblFamilies.LocationId = tblVillages.VillageID INNER JOIN
							  tblWards ON tblVillages.WardID = tblWards.WardID INNER JOIN
							  tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID INNER JOIN
							  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID ON tblPolicyRenewalDetails.RenewalID = tblPolicyRenewals.RenewalID
		WHERE     (tblPolicyRenewals.RenewalDate  BETWEEN @RangeFrom AND @RangeTo) 
				AND CASE @LocationId WHEN 0 THEN 0 ELSE tblDistricts.DistrictID  END = @LocationId
				AND CASE @WardID WHEN 0 THEN 0 ELSE tblWards.WardID  END = @WardID
				AND CASE @VillageID WHEN 0 THEN 0 ELSE tblVillages.VillageID  END = @VillageID
				AND CASE @OfficerID WHEN 0 THEN 0 ELSE tblPolicy.OfficerID   END = @OfficerID
	END
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspPolicyRenewalSMS]
	--@RenewalWarning --> 1 = no valid product for renewal  2= No enrollment officer found (no photo)  4= INVALID Enrollment officer
	@RangeFrom as date = '',
	@RangeTo as date = '',
	@FamilyMessage NVARCHAR(500) = '' 
	
AS
BEGIN
	SET NOCOUNT ON;
	
	/*
	DECLARE @RangeFrom as date
	DECLARE @RangeTo as date 
	SET @RangeFrom = '2012-07-13'
	SET @RangeTo = '2012-07-13'
	*/
	DECLARE @RenewalID int
	
	DECLARE @SMSMessage as nvarchar(4000)
	DECLARE @SMSHeader nvarchar(1000)
	DECLARE @SMSPhotos nvarchar(3000)
	DECLARE @RenewalDate as date
	DECLARE @InsureeID as int
	DECLARE @ProductCode as nvarchar(8)
	DECLARE @ProductName as nvarchar(100)
	DECLARE @DistrictName as nvarchar(50)
	DECLARE @VillageName as nvarchar(50) 
	DECLARE @WardName as nvarchar(50)  
	DECLARE @CHFID as nvarchar(12)
	DECLARE @HeadPhotoRenewal bit 
	DECLARE @InsLastName as nvarchar(100)
	DECLARE @InsOtherNames as nvarchar(100)
	DECLARE @ConvProdID as int    
    DECLARE @OfficerID as int               
	DECLARE @OffPhone as nvarchar(50)
	DECLARE @RenewalWarning as tinyint 

	DECLARE @SMSStatus as tinyint 
	DECLARE @iCount as int 
	
	DECLARE @CHFIDPhoto as nvarchar(12)	
	DECLARE @InsLastNamePhoto as nvarchar(100)
	DECLARE @InsOtherNamesPhoto as nvarchar(100)	
	DECLARE @InsPhoneNumber NVARCHAR(20)

	DECLARE @PhoneCommunication BIT

	IF @RangeFrom = '' SET @RangeFrom = GETDATE()
	IF @RangeTo = '' SET @RangeTo = GETDATE()
	DECLARE @SMSQueue TABLE (SMSID int, PhoneNumber nvarchar(50)  , SMSMessage nvarchar(4000) , SMSLength int)
	
	SET @iCount = 1 
	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT     tblPolicyRenewals.RenewalID, tblPolicyRenewals.RenewalDate, tblPolicyRenewals.PhoneNumber, tblDistricts.DistrictName, tblVillages.VillageName, tblWards.WardName, 
								tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames, tblProduct.ProductCode, tblProduct.ProductName, tblPolicyRenewals.RenewalWarnings, tblInsuree.Phone, tblOfficer.PhoneCommunication
										  
					FROM         tblPolicyRenewals INNER JOIN
										  tblInsuree ON tblPolicyRenewals.InsureeID = tblInsuree.InsureeID INNER JOIN
										  tblPolicy ON tblPolicyRenewals.PolicyID = tblPolicy.PolicyID INNER JOIN
										  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID INNER JOIN
										  tblVillages ON tblFamilies.LocationId = tblVillages.VillageID INNER JOIN
										  tblWards ON tblVillages.WardID = tblWards.WardID INNER JOIN
										  tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID INNER JOIN
										  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID
										  INNER JOIN tblOfficer ON tblPolicyRenewals.NewOfficerID = tblOfficer.OfficerID
										  WHERE NOT (tblPolicyRenewals.PhoneNumber IS NULL) AND tblPolicyRenewals.RenewalPromptDate Between @RangeFrom AND @RangeTo
										  
	OPEN LOOP1
	FETCH NEXT FROM LOOP1 INTO @RenewalID, @RenewalDate,@OffPhone,@DistrictName,@VillageName,@WardName, @CHFID,@InsLastName,@InsOtherNames,@ProductCode,@ProductName,@RenewalWarning, @InsPhoneNumber, @PhoneCommunication
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
			SET @HeadPhotoRenewal = 0
			SET @SMSHeader = ''
			SET @SMSPhotos = ''
			
			--first get the photo renewal string 
			
			DECLARE LOOPPHOTOS CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT     tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames
					FROM         tblPolicyRenewalDetails INNER JOIN
										  tblInsuree ON tblPolicyRenewalDetails.InsureeID = tblInsuree.InsureeID
					WHERE  tblPolicyRenewalDetails.RenewalID = @RenewalID
										  
			OPEN LOOPPHOTOS
			FETCH NEXT FROM LOOPPHOTOS INTO @CHFIDPhoto,@InsLastNamePhoto,@InsOtherNamesPhoto
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				IF @CHFIDPhoto = @CHFID 
				BEGIN
					--remember that the head needs renewal as well 
					SET @HeadPhotoRenewal = 1
				END
				ELSE
				BEGIN
					--add to string of dependant that need photo renewal
					SET @SMSPhotos = @SMSPhotos + char(10) + @CHFIDPhoto + char(10) + @InsLastNamePhoto + ' ' + @InsOtherNamesPhoto 
				END
				FETCH NEXT FROM LOOPPHOTOS INTO @CHFIDPhoto,@InsLastNamePhoto,@InsOtherNamesPhoto
		    END       
			CLOSE LOOPPHOTOS
			DEALLOCATE LOOPPHOTOS
			
			IF LEN(@SMSPhotos) <> 0 OR @HeadPhotoRenewal = 1
			BEGIN
				IF @HeadPhotoRenewal = 1 
					SET @SMSPhotos = '--Photos--' + char(10) + 'HOF' + @SMSPhotos
				ELSE
					SET @SMSPhotos = '--Photos--' + @SMSPhotos
			END
			
			--now construct the header record
			SET @SMSHeader = '--Renewal--' +  char(10) + CONVERT(nvarchar(20),@RenewalDate,103) + char(10) + @CHFIDPhoto + char(10) + @InsLastNamePhoto + ' ' + @InsOtherNamesPhoto + char(10) + @DistrictName + char(10) + @WardName + char(10) + @VillageName + char(10) + @ProductCode  + '-' + @ProductName + char(10)
			SET @SMSMessage = @SMSHeader + char(10) + @SMSPhotos
			--SET @SMSMessage = REPLACE(@SMSMessage,char(10),'%0A')

			IF @PhoneCommunication = 1
			BEGIN
				INSERT INTO @SMSQueue VALUES (@iCount,@OffPhone, @SMSMessage , LEN(@SMSMessage))
				SET @iCount = @iCount + 1
			END
			
			--Create SMS for the family 
			IF LEN(ISNULL(@FamilyMessage,'')) > 0 AND LEN(@InsPhoneNumber) > 0
			BEGIN
				
				--Create dynamic parameters
				DECLARE @ExpiryDate DATE = DATEADD(DAY, -1, @RenewalDate)
				DECLARE @NewFamilyMessage NVARCHAR(500) = ''
				SET @NewFamilyMessage = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@FamilyMessage, '@@InsuranceID', @CHFID), '@@LastName', @InsLastName), '@@OtherNames', @InsOtherNames), '@@ProductCode', @ProductCode), '@@ProductName', @ProductName), '@@ExpiryDate', FORMAT(@ExpiryDate,'dd MMM yyyy'))

				IF LEN(@NewFamilyMessage) > 0 
				BEGIN
					INSERT INTO @SMSQueue VALUES(@iCount, @InsPhoneNumber, @NewFamilyMessage, LEN(@NewFamilyMessage))
					SET @iCount += 1;
				END
			END

		FETCH NEXT FROM LOOP1 INTO @RenewalID, @RenewalDate,@OffPhone,@DistrictName,@VillageName,@WardName, @CHFID,@InsLastName,@InsOtherNames,@ProductCode,@ProductName,@RenewalWarning, @InsPhoneNumber, @PhoneCommunication
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1
	
	--SELECT * FROM @SMSQueue
	
	SELECT N'IMIS-RENEWAL' sender,
		(
			SELECT REPLACE(PhoneNumber,' ','')  [to] 
			FROM @SMSQueue PNo
			WHERE Pno.SMSId = SMS.SMSID
			FOR XML  PATH('recipients'), TYPE
		) PhoneNumber,
	SMS.SMSMessage [text]
	FROM @SMSQueue SMS
	WHERE LEN(SMS.PhoneNumber) > 0 AND LEN(ISNULL(SMS.SMSMessage,'')) > 0
	FOR XML PATH('message'), ROOT('request'), TYPE; 
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspPolicyStatusUpdate]
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PolicyID as int 
	
	UPDATE tblPolicy SET PolicyStatus = 8 WHERE ValidityTo IS NULL AND ExpiryDate < CAST (GETDATE() as DATE)
    
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspPolicyValueBEPHA]
(
	@FamilyId INT,
	@ProdId INT,
	@PolicyId INT = 0,
	@isRenewal BIT = 0
)
AS
BEGIN
	DECLARE @LumpSum DECIMAL(18,2) = 0,
			@PremiumAdult DECIMAL(18,2) = 0,
			@PremiumChild DECIMAL(18,2) = 0,
			@RegistrationLumpSum DECIMAL(18,2) = 0,
			@RegistrationFee DECIMAL(18,2) = 0,
			@GeneralAssemblyLumpSum DECIMAL(18,2) = 0,
			@GeneralAssemblyFee DECIMAL(18,2) = 0,
			@MemberCount SMALLINT = 0,
			@AdultMembers INT =0,
			@ChildMembers INT = 0,
			@Registration DECIMAL(18,2) = 0,
			@GeneralAssembly DECIMAL(18,2) = 0,
			@Contribution DECIMAL(18,2) = 0,
			@PolicyValue DECIMAL(18,2) = 0
		
			
	/*--In case of policy id is provided--*/
	IF @PolicyId > 0
	BEGIN
		SELECT @FamilyId = FamilyId, @ProdId = ProdId,@isRenewal = CASE WHEN PolicyStage = N'R' THEN 1 ELSE 0 END FROM tblPolicy WHERE PolicyID = @PolicyId
	END

	/*--Get all the required fiedls from product--*/
	SELECT @LumpSum = ISNULL(LumpSum,0),@PremiumAdult = ISNULL(PremiumAdult,0),@PremiumChild = ISNULL(PremiumChild,0),@RegistrationLumpSum = ISNULL(RegistrationLumpSum,0),
	@RegistrationFee = ISNULL(RegistrationFee,0),@GeneralAssemblyLumpSum = ISNULL(GeneralAssemblyLumpSum,0), @GeneralAssemblyFee = ISNULL(GeneralAssemblyFee,0), 
	@MemberCount = ISNULL(MemberCount ,0)
	FROM tblProduct WHERE ProdID = @ProdId

	/*--Get all the required fiedls from family--*/
	SET @AdultMembers = (SELECT COUNT(InsureeId) FROM tblInsuree WHERE DATEDIFF(YEAR,DOB,GETDATE()) >= 18 AND ValidityTo IS NULL AND FamilyID = @FamilyId) 
	SET @ChildMembers = (SELECT COUNT(InsureeId) FROM tblInsuree WHERE DATEDIFF(YEAR,DOB,GETDATE()) < 18 AND ValidityTo IS NULL AND FamilyID = @FamilyId)

	/*--Get the General Assembly Fee Depending on the Product Definition--*/
	IF @GeneralAssemblyLumpSum > 0
		SET @GeneralAssembly = @GeneralAssemblyLumpSum
	ELSE IF @GeneralAssemblyFee > 0
		SET @GeneralAssembly = @GeneralAssemblyFee * (@AdultMembers + @ChildMembers)


	/*--Get the Registration Fee Depending on the Product Definition--*/
	IF @isRenewal = 0
	BEGIN
		IF @RegistrationLumpSum > 0 
			SET @Registration  = @RegistrationLumpSum
		ELSE IF @RegistrationFee > 0 
			SET @Registration = @Registration * (@AdultMembers + @ChildMembers)
		
	END
	ELSE
		SET @Registration = 0
		
	/*--Get the contribution Depending on the Product Definition--*/
	IF @LumpSum > 0 
		SET @Contribution = @LumpSum
	ELSE
		SET @Contribution = (@PremiumAdult * @AdultMembers) * (@PremiumChild * @ChildMembers)
		

	SET @PolicyValue = @GeneralAssembly + @Registration + @Contribution

	SELECT @PolicyValue
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspProcessSingleClaimStep1]
	
	@AuditUser as int = 0,
	@ClaimID as int,
	@InsureeID as int, 
	@HFCareType as char(1),
	@RowID as int = 0,
	@AdultChild as nvarchar(1),
	@RtnStatus as int = 0 OUTPUT
	
		
	/*
	Rejection reasons:
	0 = NOT REJECTED
	1 = Item/Service not in Registers
	2 = Item/Service not in HF Pricelist 
	3 = Item/Service not in Covering Product
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATED
	7 = CHFID Not valid / Family Not Valid 
	8 = ICD Code not in current ICD list 
	9 = Target date provision invalid
	10= Care type not consistant with Facility 
	11=
	12=
	*/
	
AS
BEGIN
	DECLARE @RtnItemsPassed as int 
	DECLARE @RtnServicesPassed as int 
	DECLARE @RtnItemsRejected as int 
	DECLARE @RtnServicesRejected as int 

	DECLARE @oReturnValue as int 
	SET @oReturnValue = 0 
	SET @RtnStatus = 0  
	DECLARE @HFID as int  
	DECLARE @FamilyID as int  
	DECLARE @TargetDate as Date 
	DECLARE @ClaimItemID as int 
	DECLARE @ClaimServiceID as int 
	DECLARE @ItemID as int
	DECLARE @ServiceID as int
	DECLARE @ProdItemID as int
	DECLARE @ProdServiceID as int
	DECLARE @ItemPatCat as int 
	DECLARE @ItemPrice as decimal(18,2)
	DECLARE @ServicePrice as decimal(18,2)
	DECLARE @ServicePatCat as int 
	DECLARE @Gender as nvarchar(1)
	DECLARE @Adult as bit
	DECLARE @DOB as date
	DECLARE @PatientMask as int
	DECLARE @CareType as Char
	DECLARE @PriceAsked as decimal(18,2)
	DECLARE @PriceApproved as decimal(18,2)
	DECLARE @PriceAdjusted as decimal(18,2)
	DECLARE @PriceValuated as decimal(18,2)
	DECLARE @PriceOrigin as Char
	DECLARE @ClaimPrice as Decimal(18,2)
	DECLARE @ProductID as int   
	DECLARE @PolicyID as int 
	DECLARE @ProdItemID_C as int 
	DECLARE @ProdItemID_F as int 
	DECLARE @ProdServiceID_C as int 
	DECLARE @ProdServiceID_F as int 
	DECLARE @CoSharingPerc as decimal(18,2)
	DECLARE @FixedLimit as decimal(18,2)
	DECLARE @ProdAmountOwnF as decimal(18,2)
	DECLARE @ProdAmountOwnC as decimal(18,2)
	DECLARE @ProdCareType as Char
		
		
	DECLARE @LimitationType as Char(1)
	DECLARE @LimitationValue as decimal(18,2)	
	
	DECLARE @VisitType as CHAR(1)

	SELECT @VisitType = ISNULL(VisitType,'O') from tblClaim where ClaimId = @ClaimID and ValidityTo IS NULL

	BEGIN TRY
	
	--***** PREPARE PHASE *****
	
	SELECT @FamilyID = tblFamilies.FamilyID FROM tblFamilies INNER JOIN tblInsuree ON tblFamilies.FamilyID = tblInsuree.FamilyID  WHERE tblFamilies.ValidityTo IS NULL AND tblInsuree.InsureeID = @InsureeID AND tblInsuree.ValidityTo IS NULL 

	IF ISNULL(@FamilyID,0)=0 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimServices.RejectionReason = 0 
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimItems.RejectionReason = 0 
		GOTO UPDATECLAIMDETAILS 
	END	
	
	SELECT @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom) FROM TblClaim WHERE ClaimID = @ClaimID 
	IF @TargetDate IS NULL 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 9 WHERE ClaimID = @ClaimID AND tblClaimServices.RejectionReason = 0 
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 9 WHERE ClaimID = @ClaimID  AND tblClaimItems.RejectionReason = 0 
		GOTO UPDATECLAIMDETAILS 
	END	
		
		  
	SET @PatientMask = 0 
	SELECT @Gender = Gender FROm tblInsuree WHERE InsureeID = @InsureeID 
	IF @Gender = 'M' OR @Gender = 'O'
		SET @PatientMask = @PatientMask + 1 
	ELSE
		SET @PatientMask = @PatientMask + 2 
	
	SELECT @DOB = DOB FROM tblInsuree WHERE InsureeID = @InsureeID 
	IF @AdultChild = 'A' 
		SET @PatientMask = @PatientMask + 4 
	ELSE
		SET @PatientMask = @PatientMask + 8 
		
	/*PREPARE HISTORIC TABLE WITh RELEVANT ITEMS AND SERVICES*/

	DECLARE  @DTBL_ITEMS TABLE (
							[ItemID] [int] NOT NULL,
							[ItemCode] [nvarchar](6) NOT NULL,
							[ItemType] [char](1) NOT NULL,
							[ItemPrice] [decimal](18, 2) NOT NULL,
							[ItemCareType] [char](1) NOT NULL,
							[ItemFrequency] [smallint] NULL,
							[ItemPatCat] [tinyint] NOT NULL
							)

	INSERT INTO @DTBL_ITEMS (ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat) 
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ItemId ORDER BY ValidityFrom DESC)RNo,AllItems.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom, ValidityTo, LegacyID from tblitems Where (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom,ValidityTo, LegacyID  FROM tblItems Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimItems.ItemID
	FROM            tblClaimItems 
	WHERE        (tblClaimItems.ValidityTo IS NULL) AND tblClaimItems.ClaimID = @ClaimID
	) Sub2 ON Sub1.ItemID = Sub2.ItemID 
	)  AllItems 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate 
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))  	

	DECLARE  @DTBL_SERVICES TABLE (
							[ServiceID] [int] NOT NULL,
							[ServCode] [nvarchar](6) NOT NULL,
							[ServType] [char](1) NOT NULL,
							[ServLevel] [char](1) NOT NULL,
							[ServPrice] [decimal](18, 2) NOT NULL,
							[ServCareType] [char](1) NOT NULL,
							[ServFrequency] [smallint] NULL,
							[ServPatCat] [tinyint] NOT NULL,
							[ServCategory] [char](1) NULL
							)

	INSERT INTO @DTBL_SERVICES (ServiceID , ServCode, ServType , ServLevel, ServPrice, ServCaretype ,ServFrequency, ServPatCat, ServCategory ) 
	SELECT ServiceID , ServCode, ServType , ServLevel ,ServPrice, ServCaretype ,ServFrequency, ServPatCat,ServCategory FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ServiceId ORDER BY ValidityFrom DESC)RNo,AllServices.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory ,ValidityFrom, ValidityTo, LegacyID from tblServices WHere (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory , ValidityFrom, ValidityTo, LegacyID FROM tblServices Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimServices.ServiceID 
	FROM            tblClaim INNER JOIN
							 tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID
	WHERE        (tblClaimServices.ValidityTo IS NULL) AND tblClaim.ClaimID = @ClaimID
	) Sub2 ON Sub1.ServiceID = Sub2.ServiceID 
	)  AllServices 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))   

	--***** CHECK 1 ***** --> UPDATE to REJECTED for Items/Services not in registers   REJECTION REASON = 1
	
	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL AND tblClaimItems.RejectionReason = 0 AND tblClaimItems.ItemID NOT IN 
                      (
                      SELECT     ItemID FROM @DTBL_ITEMS
                      )
                      
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL AND tblClaimServices.RejectionReason = 0  AND tblClaimServices.ServiceID  NOT IN 
                      (
                      SELECT     ServiceID FROM @DTBL_SERVICES  
                      )
	
	--***** CHECK 2 ***** --> UPDATE to REJECTED for Items/Services not in Pricelists  REJECTION REASON = 2
	SELECT @HFID = HFID from tblClaim WHERE ClaimID = @ClaimID 
	
	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 2
	FROM dbo.tblClaimItems 
	LEFT OUTER JOIN 
	(SELECT     tblPLItemsDetail.ItemID
	FROM         tblHF INNER JOIN
						  tblPLItems ON tblHF.PLItemID = tblPLItems.PLItemID INNER JOIN
						  tblPLItemsDetail ON tblPLItems.PLItemID = tblPLItemsDetail.PLItemID
	WHERE     (tblHF.HfID = @HFID) AND (tblPLItems.ValidityTo IS NULL) AND (tblPLItemsDetail.ValidityTo IS NULL)) PLItems 
	ON tblClaimItems.ItemID = PLItems.ItemID 
	WHERE tblClaimItems.ClaimID = @ClaimID AND tblClaimItems.RejectionReason = 0 AND tblClaimItems.ValidityTo IS NULL AND PLItems.ItemID IS NULL
	
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 2 
	FROM dbo.tblClaimServices 
	LEFT OUTER JOIN 
	(SELECT     tblPLServicesDetail.ServiceID 
	FROM         tblHF INNER JOIN
						  tblPLServicesDetail ON tblHF.PLServiceID = tblPLServicesDetail.PLServiceID
	WHERE     (tblHF.HfID = @HFID) AND (tblPLServicesDetail.ValidityTo IS NULL) AND (tblPLServicesDetail.ValidityTo IS NULL)) PLServices 
	ON tblClaimServices.ServiceID = PLServices.ServiceID  
	WHERE tblClaimServices.ClaimID = @ClaimID AND  tblClaimServices.RejectionReason = 0  AND tblClaimServices.ValidityTo IS NULL AND PLServices.ServiceID  IS NULL
	
	
	-- ** !!!!! ITEMS LOOPING !!!!! ** 
	
	--now loop through all (remaining) items and determine what is the matching product within valid policies using the rule least cost sharing for Insuree 
	-- at this stage we only check if any valid product itemline is found --> will not yet assign the line. 
	
	DECLARE CLAIMITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT     tblClaimItems.ClaimItemID, tblClaimItems.PriceAsked, PriceApproved, Items.ItemPrice, Items.ItemCareType, Items.ItemPatCat, Items.ItemID
														FROM         tblClaimItems INNER JOIN
																			  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID 
														WHERE     (tblClaimItems.ClaimID = @ClaimID) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0) ORDER BY tblClaimItems.ClaimItemID ASC
	OPEN CLAIMITEMLOOP
	FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID, @PriceAsked, @PriceApproved, @ItemPrice ,@CareType, @ItemPatCat,@ItemID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @ProdItemID_C = 0 
		SET @ProdItemID_F = 0 
		
		IF ISNULL(@PriceAsked,0) > ISNULL(@PriceApproved,0)
			SET @ClaimPrice = @PriceAsked
		ELSE
			SET @ClaimPrice = @PriceApproved
		
		-- **** START CHECK 4 --> Item/Service Limitation Fail (4)*****
		IF (@ItemPatCat  & @PatientMask) <> @PatientMask 	
		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimItems SET RejectionReason = 4 WHERE ClaimItemID   = @ClaimItemID 
			GOTO NextItem
		END
		-- **** END CHECK 4 *****	
		
		---- **** START CHECK 10 --> Item Care type / HF caretype Fail (10)*****
		--IF (@CareType = 'I' AND @HFCareType = 'O') OR (@CareType = 'O' AND @HFCareType = 'I')	
		--BEGIN
		--	--inconsistant patient type check 
		--	UPDATE tblClaimItems SET RejectionReason = 10 WHERE ClaimItemID   = @ClaimItemID 
		--	GOTO NextItem
		--END
		---- **** END CHECK 10 *****	
		
		-- **** START ASSIGNING PROD ID to ClaimITEMS *****	
		IF @AdultChild = 'A'
		BEGIN
			--Try to find co-sharing product with the least co-sharing --> better for insuree
			
			IF @VisitType = 'O' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitAdult DESC

				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitAdult WHEN 0 THEN 1000000000000 ELSE LimitAdult END) DESC
			END

			IF @VisitType = 'E' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitAdultE DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitAdultE WHEN 0 THEN 1000000000000 ELSE LimitAdultE END) DESC
			END


			IF @VisitType = 'R' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitAdultR DESC
				
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
					FROM         tblFamilies INNER JOIN
										  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
										  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
										  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
					WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
										  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
										  AND LimitationTypeR = 'F'
										  ORDER BY (CASE LimitAdultR WHEN 0 THEN 1000000000000 ELSE LimitAdultR END) DESC
			END

		END
		ELSE
		BEGIN
			IF @VisitType = 'O' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitChild DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitChild WHEN 0 THEN 1000000000000 ELSE LimitChild END) DESC		
			END
			IF @VisitType = 'E' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitChildE DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitChildE WHEN 0 THEN 1000000000000 ELSE LimitChildE END) DESC	
			END

			IF @VisitType = 'R' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitChildR DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'F'
									  ORDER BY (CASE LimitChildR WHEN 0 THEN 1000000000000 ELSE LimitChildR END) DESC	
			END

		END



		IF ISNULL(@ProdItemID_C,0) = 0 AND ISNULL(@ProdItemID_F,0) = 0 
		BEGIN
			-- No suitable product is found for this specific claim item 
			UPDATE tblClaimItems SET RejectionReason = 3 WHERE ClaimItemID = @ClaimItemID
			GOTO NextItem
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdItemID_F,0) <> 0
			BEGIN
				IF @VisitType = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdult,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChild,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
				END
				IF @VisitType = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
				END
				IF @VisitType = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
				END
				
			END	
			IF ISNULL(@ProdItemID_C,0) <> 0
			BEGIN

				IF @VisitType = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdult,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChild,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
				END
				IF @VisitType = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
				END
				IF @VisitType = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
				END

				
			END
		END
		
		IF ISNULL(@ProdItemID_C,0) <> 0 AND ISNULL(@ProdItemID_F,0) <> 0 
		BEGIN
			--Need to check which product would be the best to choose CO-sharing or FIXED
			IF @FixedLimit = 0 OR @FixedLimit > @ClaimPrice 
			BEGIN --no limit or higher than claimed amount
				SET @ProdItemID = @ProdItemID_F
				SET @ProdItemID_C = 0 
			END
			ELSE  
			BEGIN
				SET @ProdAmountOwnF =  @ClaimPrice - @FixedLimit
				IF (100 - @CoSharingPerc) > 0 
				BEGIN
					--Insuree pays own part on co-sharing 
					SET @ProdAmountOwnF =  @ClaimPrice - @FixedLimit
					SET @ProdAmountOwnC = ((100 - @CoSharingPerc)/100) * @ClaimPrice 
					IF @ProdAmountOwnC > @ProdAmountOwnF 
					BEGIN
						SET @ProdItemID = @ProdItemID_F  
						SET @ProdItemID_C = 0 
					END
					ELSE
					BEGIN 
						SET @ProdItemID = @ProdItemID_C  	
						SET @ProdItemID_F = 0
					END
				END
				ELSE
				BEGIN
					SET @ProdItemID = @ProdItemID_C  
					SET @ProdItemID_F = 0
				END
			END
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdItemID_C,0) <> 0
			BEGIN
				-- Only Co-sharing 
				SET @ProdItemID = @ProdItemID_C
				SET @ProdItemID_F = 0 
			END
			ELSE
			BEGIN
				-- Only Fixed
				SET @ProdItemID = @ProdItemID_F 
				SET @ProdItemID_C = 0
			END 
		END
		
		
		SELECT @ProductID = tblProduct.ProdID FROM tblProduct INNER JOIN tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID WHERE tblProduct.ValidityTo IS NULL AND tblProductItems.ProdItemID = @ProdItemID 
		SELECT TOP 1 @PolicyID = tblPolicy.PolicyID 
			FROM         tblFamilies INNER JOIN
								  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
								  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
								  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
			WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
								  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ProdItemID = @ProdItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
								  
		-- **** END ASSIGNING PROD ID to CLAIM *****	
		
		-- **** START DETERMINE PRICE ITEM **** 
		SELECT @PriceOrigin = PriceOrigin FROM tblProductItems WHERE ProdItemID = @ProdItemID 
		
		IF @ProdItemID_C <> 0 
		BEGIN
			SET @LimitationType = 'C'
			SET @LimitationValue = @CoSharingPerc 		
		END
		ELSE
		BEGIN
			--FIXED LIMIT
			SET @LimitationType = 'F'
			SET @LimitationValue =@FixedLimit 
		END
		
		UPDATE tblClaimItems SET ProdID = @ProductID, PolicyID = @PolicyID , PriceAdjusted = @PriceAdjusted , PriceOrigin = @PriceOrigin, Limitation = @LimitationType , LimitationValue = @LimitationValue  WHERE ClaimItemID = @ClaimItemID 
		
		NextItem:
		FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID, @PriceAsked, @PriceApproved, @ItemPrice ,@CareType, @ItemPatCat,@ItemID
	END
	CLOSE CLAIMITEMLOOP
	DEALLOCATE CLAIMITEMLOOP
	
	-- ** !!!!! ITEMS LOOPING !!!!! ** 
	
	--now loop through all (remaining) Services and determine what is the matching product within valid policies using the rule least cost sharing for Insuree 
	-- at this stage we only check if any valid product Serviceline is found --> will not yet assign the line. 
	
	DECLARE CLAIMSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT     tblClaimServices.ClaimServiceID, tblClaimServices.PriceAsked, PriceApproved, Serv.ServPrice, Serv.ServCareType, Serv.ServPatCat, Serv.ServiceID
														FROM         tblClaimServices INNER JOIN
																			  @DTBL_SERVICES Serv
																			   ON tblClaimServices.ServiceID = Serv.ServiceID
														WHERE     (tblClaimServices.ClaimID = @ClaimID) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0) ORDER BY tblClaimServices.ClaimServiceID ASC
	OPEN CLAIMSERVICELOOP
	FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID, @PriceAsked, @PriceApproved, @ServicePrice ,@CareType, @ServicePatCat,@ServiceID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @ProdServiceID_C = 0 
		SET @ProdServiceID_F = 0 
		
		IF ISNULL(@PriceAsked,0) > ISNULL(@PriceApproved,0)
			SET @ClaimPrice = @PriceAsked
		ELSE
			SET @ClaimPrice = @PriceApproved
		
		-- **** START CHECK 4 --> Service/Service Limitation Fail (4)*****
		IF (@ServicePatCat  & @PatientMask) <> @PatientMask 	
		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimServices SET RejectionReason = 4 WHERE ClaimServiceID   = @ClaimServiceID 
			GOTO NextService
		END
		-- **** END CHECK 4 *****	
		
		-- **** START CHECK 10 --> Service Care type / HF caretype Fail (10)*****
		--IF (@CareType = 'I' AND @HFCareType = 'O') OR (@CareType = 'O' AND @HFCareType = 'I')	
		--BEGIN
		--	--inconsistant patient type check 
		--	UPDATE tblClaimServices SET RejectionReason = 10 WHERE ClaimServiceID   = @ClaimServiceID 
		--	GOTO NextService
		--END
		-- **** END CHECK 10 *****	
		
		-- **** START ASSIGNING PROD ID to ClaimServiceS *****	
		IF @AdultChild = 'A'
		BEGIN
			--Try to find co-sharing product with the least co-sharing --> better for insuree
			
			IF @VisitType = 'O'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitAdult DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitAdult WHEN 0 THEN 1000000000000 ELSE LimitAdult END) DESC
			END

			IF @VisitType = 'E'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitAdultE DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitAdultE WHEN 0 THEN 1000000000000 ELSE LimitAdultE END) DESC
			END
			
			
			IF @VisitType = 'R'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitAdultR DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'F'
									  ORDER BY (CASE LimitAdultR WHEN 0 THEN 1000000000000 ELSE LimitAdultR END) DESC
			END
			
		END
		ELSE
		BEGIN
			
			IF @VisitType = 'O'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitChild DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitChild WHEN 0 THEN 1000000000000 ELSE LimitChild END) DESC		
			END
			IF @VisitType = 'E'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitChildE DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitChildE WHEN 0 THEN 1000000000000 ELSE LimitChildE END) DESC		
			END


			IF @VisitType = 'R'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitChildR DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'F'
									  ORDER BY (CASE LimitChildR WHEN 0 THEN 1000000000000 ELSE LimitChildR END) DESC		
			END

		END
		
		
		
		IF ISNULL(@ProdServiceID_C,0) = 0 AND ISNULL(@ProdServiceID_F,0) = 0 
		BEGIN
			-- No suitable product is found for this specific claim Service 
			UPDATE tblClaimServices SET RejectionReason = 3 WHERE ClaimServiceID = @ClaimServiceID
			GOTO NextService
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdServiceID_F,0) <> 0
			BEGIN
				IF @VisitType = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdult,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChild,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F   
				END 
				IF @VisitType = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultE,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildE,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F   
				END
				IF @VisitType = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultR,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildR,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F   
				END
			END	
			IF ISNULL(@ProdServiceID_C,0) <> 0
			BEGIN
				IF @Visittype = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdult,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChild,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C 
				END
				IF @Visittype = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultE,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildE,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C 
				END 
				IF @Visittype = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultR,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildR,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C 
				END
			END

		END
		
		IF ISNULL(@ProdServiceID_C,0) <> 0 AND ISNULL(@ProdServiceID_F,0) <> 0 
		BEGIN
			--Need to check which product would be the best to choose CO-sharing or FIXED
			IF @FixedLimit = 0 OR @FixedLimit > @ClaimPrice 
			BEGIN --no limit or higher than claimed amount
				SET @ProdServiceID = @ProdServiceID_F
				SET @ProdServiceID_C = 0 
			END
			ELSE
			BEGIN
				SET @ProdAmountOwnF =  @ClaimPrice - ISNULL(@FixedLimit,0)
				IF (100 - @CoSharingPerc) > 0 
				BEGIN
					--Insuree pays own part on co-sharing 
					SET @ProdAmountOwnF =  @ClaimPrice - @FixedLimit
					SET @ProdAmountOwnC = ((100 - @CoSharingPerc)/100) * @ClaimPrice 
					IF @ProdAmountOwnC > @ProdAmountOwnF 
					BEGIN
						SET @ProdServiceID = @ProdServiceID_F  
						SET @ProdServiceID_C = 0 
					END
					ELSE
					BEGIN 
						SET @ProdServiceID = @ProdServiceID_C  	
						SET @ProdServiceID_F = 0
					END
				END
				ELSE
				BEGIN
					SET @ProdServiceID = @ProdServiceID_C  
					SET @ProdServiceID_F = 0
				END
			END
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdServiceID_C,0) <> 0
			BEGIN
				-- Only Co-sharing 
				SET @ProdServiceID = @ProdServiceID_C
				SET @ProdServiceID_F = 0 
			END
			ELSE
			BEGIN
				-- Only Fixed
				SET @ProdServiceID = @ProdServiceID_F 
				SET @ProdServiceID_C = 0
			END 
		END
		
		SELECT @ProductID = tblProduct.ProdID FROM tblProduct INNER JOIN tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID WHERE tblProduct.ValidityTo IS NULL AND tblProductServices.ProdServiceID = @ProdServiceID 
		SELECT TOP 1 @PolicyID = tblPolicy.PolicyID 
			FROM         tblFamilies INNER JOIN
								  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
								  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
								  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
			WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
								  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ProdServiceID = @ProdServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
								  
		-- **** END ASSIGNING PROD ID to CLAIM *****	
		
		-- **** START DETERMINE PRICE Service **** 
		SELECT @PriceOrigin = PriceOrigin FROM tblProductServices WHERE ProdServiceID = @ProdServiceID 
		
		IF @ProdServiceID_C <> 0 
		BEGIN
			SET @LimitationType = 'C'
			SET @LimitationValue = @CoSharingPerc 		
		END
		ELSE
		BEGIN
			--FIXED LIMIT
			SET @LimitationType = 'F'
			SET @LimitationValue =@FixedLimit 
		END
		
		UPDATE tblClaimServices SET ProdID = @ProductID, PolicyID = @PolicyID, PriceOrigin = @PriceOrigin, Limitation = @LimitationType , LimitationValue = @LimitationValue WHERE ClaimServiceID = @ClaimServiceID 
		
		NextService:
		FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID, @PriceAsked, @PriceApproved, @ServicePrice ,@CareType, @ServicePatCat,@ServiceID
	END
	CLOSE CLAIMSERVICELOOP
	DEALLOCATE CLAIMSERVICELOOP
	
	
	
	
	
UPDATECLAIMDETAILS:
	UPDATE tblClaimItems SET ClaimItemStatus = 2 WHERE ClaimID = @ClaimID AND RejectionReason <> 0 
	UPDATE tblClaimServices SET ClaimServiceStatus = 2 WHERE ClaimID = @ClaimID AND RejectionReason <> 0 
	
	SELECT @RtnItemsPassed = ISNULL(COUNT(ClaimItemID),0) FROM dbo.tblClaimItems WHERE ClaimID = @ClaimID AND ClaimItemStatus = 1 AND ValidityTo IS NULL
	SELECT @RtnServicesPassed  = ISNULL(COUNT(ClaimServiceID),0) FROM dbo.tblClaimServices  WHERE ClaimID = @ClaimID AND ClaimServiceStatus = 1  AND ValidityTo IS NULL
	
	IF @RtnItemsPassed <> 0  OR @RtnServicesPassed <> 0  --UPDATE CLAIM TO PASSED !! (default is not yet passed before checking procedure 
	BEGIN
		SET @RtnStatus = 1 
	END
	ELSE
	BEGIN
		UPDATE tblClaim SET ClaimStatus = 1 WHERE ClaimID = @ClaimID --> set rejected as all items ands services did not pass ! 
		SET @RtnStatus = 2 
	END
	
	
	
FINISH:
	RETURN @oReturnValue
	
	END TRY
	
	BEGIN CATCH
		SELECT 'Unexpected error encountered'
		SET @oReturnValue = 1 
		RETURN @oReturnValue
		
	END CATCH
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspProcessSingleClaimStep2]
		
	@AuditUser as int = 0,
	@ClaimID as int,
	@InsureeID as int,
	@HFLevel as Char(1),   --check later with Jiri --> will not be used anymore
	@RowID as BIGINT = 0,
	@AdultChild as Char(1),
	@Hospitalization as BIT,
	@IsProcess as BIT = 1,
	@RtnStatus as int = 0 OUTPUT
	
		
	/*
	Rejection reasons:
	0 = NOT REJECTED
	1 = Item/Service not in Registers
	2 = Item/Service not in HF Pricelist 
	3 = Item/Service not in Covering Product
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATD
	7 = CHFID Not valid / Family Not Valid 
	8 = ICD Code not in current ICD list 
	9 = Target date provision invalid
	10= Care type not consistant with Facility 
	11=
	12=
	*/
	
AS
BEGIN
	
	DECLARE @oReturnValue as int
	SET @oReturnValue = 0 
		
	DECLARE @ProductID as int   
	DECLARE @PolicyID as int 
	DECLARE @Ceiling as decimal(18,2)
	DECLARE @Deductable as decimal(18,2)
	DECLARE @PrevDeducted as Decimal(18,2)
	DECLARE @Deducted as decimal(18,2)
	DECLARE @PrevRemunerated as decimal(18,2)
	DECLARE @Remunerated as decimal(18,2)
	
	DECLARE @DeductableType as Char(1)
	DECLARE @CeilingType as Char(1)
	
	DECLARE @ClaimItemID as int 
	DECLARE @ClaimServiceID as int
	DECLARE @PriceAsked as decimal(18,2)
	DECLARE @PriceApproved as decimal(18,2)
	DECLARE @PriceAdjusted as decimal(18,2)
	DECLARE @PLPrice as decimal(18,2)
	DECLARE @PriceOrigin as Char(1)
	DECLARE @Limitation as Char(1)
	DECLARE @Limitationvalue as Decimal(18,2)
	DECLARE @ItemQty as decimal(18,2)
	DECLARE @ServiceQty as decimal(18,2)
	DECLARE @QtyProvided as decimal(18,2) 
	DECLARE @QtyApproved as decimal(18,2)
	DECLARE @SetPriceValuated as decimal(18,2)
	DECLARE @SetPriceAdjusted as decimal(18,2)
	DECLARE @SetPriceRemunerated as decimal(18,2)
	DECLARE @SetPriceDeducted as decimal(18,2)	
	DECLARE @ExceedCeilingAmount as decimal(18,2)
	
	DECLARE @ExceedCeilingAmountCategory as decimal(18,2)
	

	DECLARE @WorkValue as decimal(18,2)
	--declare all ceilings and deductables from the cursor on product
	DECLARE @DedInsuree as decimal(18,2) 
	DECLARE @DedOPInsuree as decimal(18,2) 
	DECLARE @DedIPInsuree as decimal(18,2) 
	DECLARE @MaxInsuree as decimal(18,2)  
	DECLARE @MaxOPInsuree as decimal(18,2) 
	DECLARE @MaxIPInsuree as decimal(18,2) 
	DECLARE @DedTreatment as decimal(18,2)  
	DECLARE @DedOPTreatment as decimal(18,2)  
	DECLARE @DedIPTreatment as decimal(18,2)  
	DECLARE @MaxIPTreatment as decimal(18,2) 
	DECLARE @MaxTreatment as decimal(18,2) 
	DECLARE @MaxOPTreatment as decimal(18,2) 
	DECLARE @DedPolicy as decimal(18,2) 
	DECLARE @DedOPPolicy as decimal(18,2) 
	DECLARE @DedIPPolicy as decimal(18,2) 
	DECLARE @MaxPolicy as decimal(18,2) 
	DECLARE @MaxOPPolicy as decimal(18,2) 
	DECLARE @MaxIPPolicy as decimal(18,2) 
	
	DECLARE @CeilingConsult as Decimal(18,2) = 0 
	DECLARE @CeilingSurgery as Decimal(18,2) = 0 
	DECLARE @CeilingHospitalization as Decimal(18,2) = 0 
	DECLARE @CeilingDelivery as Decimal(18,2) = 0 
	DECLARE @CeilingAntenatal as decimal(18,2) =0 

	DECLARE @PrevRemuneratedConsult as decimal(18,2) = 0 
	DECLARE @PrevRemuneratedSurgery as decimal(18,2) = 0 
	DECLARE @PrevRemuneratedHospitalization as decimal(18,2) = 0 
	DECLARE @PrevRemuneratedDelivery as decimal(18,2) = 0 
	DECLARE @PrevRemuneratedAntenatal as decimal(18,2) = 0 

	DECLARE @RemuneratedConsult as decimal(18,2) = 0 
	DECLARE @RemuneratedSurgery as decimal(18,2) = 0 
	DECLARE @RemuneratedHospitalization as decimal(18,2) = 0 
	DECLARE @RemuneratedDelivery as decimal(18,2) = 0 
	DECLARE @RemuneratedAntenatal as decimal(18,2) = 0

	DECLARE @Treshold as INT
	DECLARE @MaxPolicyExtraMember decimal(18,2) = 0 
	DECLARE @MaxPolicyExtraMemberIP decimal(18,2) = 0 
	DECLARE @MaxPolicyExtraMemberOP decimal(18,2) = 0 
	DECLARE @MaxCeilingPolicy decimal (18,2) = 0 
	DECLARE @MaxCeilingPolicyIP decimal (18,2) = 0 
	DECLARE @MaxCeilingPolicyOP decimal (18,2) = 0 
	
	DECLARE @ServCategory as CHAR
	DECLARE @ClaimDateFrom as datetime
	DECLARE @ClaimDateTo as datetime
	

	DECLARE @RelativePrices as int = 0 
	DECLARE @PolicyMembers as int = 0 
	
	DECLARE @BaseCategory as CHAR(1)  = 'V'
	DECLARE @CeilingInterpretation as Char

	BEGIN TRY 
	
	--check first if this is a hospital claim falling under the hospitalization category
	--check first if this is a hospital claim falling under the hospitalization category
	
	-- S = Surgery
	-- D = Delivery
	-- A = Antenatal care
	-- H = Hospitalization
	-- C = Consultation
	-- O = Other
	-- V = Visit 

	SELECT @ClaimDateFrom = DateFrom,  @ClaimDateTo = DateTo FROM tblClaim Where ClaimID = @ClaimID 

	IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
		WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'S') AND 
							 (tblServices.ValidityTo IS NULL))
	BEGIN
		SET @BaseCategory = 'S'
	END
	ELSE
	BEGIN
		IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
		WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'D') AND 
							 (tblServices.ValidityTo IS NULL))
		BEGIN
			SET @BaseCategory = 'D'
		END
		ELSE
		BEGIN
			IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
			WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'A') AND 
								 (tblServices.ValidityTo IS NULL))
			BEGIN
				SET @BaseCategory = 'A'
			END
			ELSE
			BEGIN
				
				
				IF ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom 
				BEGIN
					SET @BaseCategory = 'H'
				END
				ELSE
				BEGIN
					IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
					WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'C') AND 
										 (tblServices.ValidityTo IS NULL))
					BEGIN
						SET @BaseCategory = 'C'
					END
					ELSE
					BEGIN
						SET @BaseCategory = 'V'
					END
				END
			END
		END
	END

	/*PREPARE HISTORIC TABLE WITh RELEVANT ITEMS AND SERVICES*/

	DECLARE @TargetDate as Date

	
	SELECT @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom) FROM TblClaim WHERE ClaimID = @ClaimID 

	DECLARE @FamilyID INT 
	SELECT @FamilyID = FamilyID from tblInsuree where InsureeID = @InsureeID 
	


	DECLARE  @DTBL_ITEMS TABLE (
							[ItemID] [int] NOT NULL,
							[ItemCode] [nvarchar](6) NOT NULL,
							[ItemType] [char](1) NOT NULL,
							[ItemPrice] [decimal](18, 2) NOT NULL,
							[ItemCareType] [char](1) NOT NULL,
							[ItemFrequency] [smallint] NULL,
							[ItemPatCat] [tinyint] NOT NULL
							)

	INSERT INTO @DTBL_ITEMS (ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat) 
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ItemId ORDER BY ValidityFrom DESC)RNo,AllItems.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom, ValidityTo, LegacyID from tblitems Where (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom,ValidityTo, LegacyID  FROM tblItems Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimItems.ItemID
	FROM            tblClaimItems 
	WHERE        (tblClaimItems.ValidityTo IS NULL) AND tblClaimItems.ClaimID = @ClaimID
	) Sub2 ON Sub1.ItemID = Sub2.ItemID 
	)  AllItems 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate 
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))  	



	DECLARE  @DTBL_SERVICES TABLE (
							[ServiceID] [int] NOT NULL,
							[ServCode] [nvarchar](6) NOT NULL,
							[ServType] [char](1) NOT NULL,
							[ServLevel] [char](1) NOT NULL,
							[ServPrice] [decimal](18, 2) NOT NULL,
							[ServCareType] [char](1) NOT NULL,
							[ServFrequency] [smallint] NULL,
							[ServPatCat] [tinyint] NOT NULL,
							[ServCategory] [char](1) NULL
							)

	INSERT INTO @DTBL_SERVICES (ServiceID , ServCode, ServType , ServLevel, ServPrice, ServCaretype ,ServFrequency, ServPatCat, ServCategory ) 
	SELECT ServiceID , ServCode, ServType , ServLevel ,ServPrice, ServCaretype ,ServFrequency, ServPatCat,ServCategory FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ServiceId ORDER BY ValidityFrom DESC)RNo,AllServices.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory ,ValidityFrom, ValidityTo, LegacyID from tblServices WHere (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory , ValidityFrom, ValidityTo, LegacyID FROM tblServices Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimServices.ServiceID 
	FROM            tblClaim INNER JOIN
							 tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID
	WHERE        (tblClaimServices.ValidityTo IS NULL) AND tblClaim.ClaimID = @ClaimID
	) Sub2 ON Sub1.ServiceID = Sub2.ServiceID 
	)  AllServices 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))  
	
	DECLARE PRODUCTLOOP CURSOR LOCAL FORWARD_ONLY FOR	
													SELECT Policies.ProdID, Policies.PolicyID,	ISNULL(DedInsuree,0), ISNULL(DedOPInsuree,0), ISNULL(DedIPInsuree,0), ISNULL(MaxInsuree,0), ISNULL(MaxOPInsuree,0), 
																								ISNULL(MaxIPInsuree,0), ISNULL(DedTreatment,0), ISNULL(DedOPTreatment,0), ISNULL(DedIPTreatment,0), ISNULL(MaxIPTreatment,0), 
																								ISNULL(MaxTreatment,0), ISNULL(MaxOPTreatment,0), ISNULL(DedPolicy,0), ISNULL(DedOPPolicy,0), ISNULL(DedIPPolicy,0), 
																								ISNULL(MaxPolicy,0), ISNULL(MaxOPPolicy,0) , ISNULL(MaxIPPolicy,0),ISNULL(MaxAmountConsultation ,0),ISNULL(MaxAmountSurgery,0),ISNULL(MaxAmountHospitalization ,0),ISNULL(MaxAmountDelivery ,0), ISNULL(MaxAmountAntenatal  ,0),
																								ISNULL(Threshold,0), ISNULL(MaxPolicyExtraMember,0),ISNULL(MaxPolicyExtraMemberIP,0),ISNULL(MaxPolicyExtraMemberOP,0),ISNULL(MaxCeilingPolicy,0),ISNULL(MaxCeilingPolicyIP,0),ISNULL(MaxCeilingPolicyOP,0), ISNULL(CeilingInterpretation,'I')
																		  FROM 
													(
													SELECT     tblClaimItems.ProdID, tblClaimItems.PolicyID
													FROM         tblClaimItems INNER JOIN
																		  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID
													WHERE     (tblClaimItems.ClaimID = @ClaimID) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0)
																										
													UNION 
													SELECT     tblClaimServices.ProdID, tblClaimServices.PolicyID
													FROM         tblClaimServices INNER JOIN
																		  @DTBL_SERVICES Serv ON tblClaimServices.ServiceID = Serv.ServiceID
													WHERE     (tblClaimServices.ClaimID = @ClaimID) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0)
													) Policies 
													INNER JOIN 
													(
													SELECT     ProdID, DedInsuree, DedOPInsuree, DedIPInsuree, MaxInsuree, MaxOPInsuree, MaxIPInsuree, DedTreatment, DedOPTreatment, DedIPTreatment, MaxIPTreatment, 
																MaxTreatment, MaxOPTreatment, DedPolicy, DedOPPolicy, DedIPPolicy, MaxPolicy, MaxOPPolicy, MaxIPPolicy, MaxAmountConsultation ,MaxAmountSurgery ,MaxAmountHospitalization ,MaxAmountDelivery , MaxAmountAntenatal,
																Threshold, MaxPolicyExtraMember , MaxPolicyExtraMemberIP , MaxPolicyExtraMemberOP, MaxCeilingPolicy, MaxCeilingPolicyIP ,MaxCeilingPolicyOP ,ValidityTo, CeilingInterpretation  FROM tblProduct
													WHERE     (ValidityTo IS NULL)
													) Product ON Product.ProdID = Policies.ProdID
													
	OPEN PRODUCTLOOP
	FETCH NEXT FROM PRODUCTLOOP INTO	@ProductID, @PolicyID,@DedInsuree,@DedOPInsuree,@DedIPInsuree,@MaxInsuree,@MaxOPInsuree,@MaxIPInsuree,@DedTreatment,@DedOPTreatment,@DedIPTreatment,
										@MaxIPTreatment,@MaxTreatment,@MaxOPTreatment,@DedPolicy,@DedOPPolicy,@DedIPPolicy,@MaxPolicy,@MaxOPPolicy,@MaxIPPolicy,@CeilingConsult,@CeilingSurgery,@CeilingHospitalization,@CeilingDelivery,@CeilingAntenatal,
										@Treshold, @MaxPolicyExtraMember,@MaxPolicyExtraMemberIP,@MaxPolicyExtraMemberOP,@MaxCeilingPolicy,@MaxCeilingPolicyIP,@MaxCeilingPolicyOP,@CeilingInterpretation
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--FIRST CHECK GENERAL 
		
		--DECLARE @PrevDeducted as Decimal(18,2)
		--DECLARE @PrevRemunerated as decimal(18,2)
		--DECLARE @Deducted as decimal(18,2)
		
		SET @Ceiling = 0 
		SET @Deductable = 0 
		SET @Deducted = 0  --reset to zero 
		SET @Remunerated = 0 
		SET @RemuneratedConsult = 0 
		SET @RemuneratedDelivery = 0 
		SET @RemuneratedHospitalization = 0 
		SET @RemuneratedSurgery = 0 
		SET @RemuneratedAntenatal  = 0 

		SELECT @PolicyMembers =  COUNT(InsureeID) FROM tblInsureePolicy WHERE tblInsureePolicy.PolicyId = @PolicyID  AND  (NOT (EffectiveDate IS NULL)) AND  ( @ClaimDateTo BETWEEN EffectiveDate And ExpiryDate  )   AND   (ValidityTo IS NULL)

		IF ISNULL(@CeilingConsult,0) > 0 
		BEGIN
			SELECT @PrevRemuneratedConsult = 0 --SUM(RemConsult) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
		END
		IF ISNULL(@CeilingSurgery,0) > 0 
		BEGIN
			SELECT @PrevRemuneratedSurgery  = 0 -- SUM(RemSurgery ) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
		END
		IF ISNULL(@CeilingHospitalization,0)  > 0 
		BEGIN
			--check first if this is a hospital claim falling under the hospitalization category
			IF @Hospitalization = 1 

			--SELECT @ClaimDateFrom = DateFrom,  @ClaimDateTo = DateTo FROM tblClaim Where ClaimID = @ClaimID 
			--IF ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom 
			BEGIN
				--SET @Hospitalization = 1 
				SELECT @PrevRemuneratedHospitalization = 0 -- SUM(RemHospitalization) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
			END
		END

		IF ISNULL(@CeilingDelivery,0)  > 0 
		BEGIN
			SELECT @PrevRemuneratedDelivery  = 0 -- SUM(RemDelivery ) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
		END

		IF ISNULL(@PrevRemuneratedAntenatal ,0)  > 0 
		BEGIN
			SELECT @PrevRemuneratedAntenatal  = 0 --  SUM(RemAntenatal ) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
		END


		IF ISNULL(@DedTreatment,0) <> 0 
		BEGIN
			SET @Deductable = @DedTreatment
			SET @DeductableType = 'G'
			SET @PrevDeducted = 0 
		END
		
		IF ISNULL(@DedInsuree,0) <> 0
		BEGIN
			SET @Deductable = @DedInsuree
			SET @DeductableType = 'G'
			SELECT @PrevDeducted = SUM(DedG) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
		END
		
		IF ISNULL(@DedPolicy,0) <> 0
		BEGIN
			SET @Deductable = @DedPolicy
			SET @DeductableType = 'G'
			SELECT @PrevDeducted = SUM(DedG) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID And ClaimID <> @ClaimID 
		END
		
		IF ISNULL(@MaxTreatment,0) <> 0
		BEGIN
			SET @Ceiling = @MaxTreatment
			SET @CeilingType  = 'G'
			SET @PrevRemunerated = 0 
		END
		
		IF ISNULL(@MaxInsuree,0) <> 0
		BEGIN
			SET @Ceiling = @MaxInsuree
			SET @CeilingType  = 'G'
			SELECT @PrevRemunerated = SUM(RemG) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
		END
		IF ISNULL(@MaxPolicy,0) <> 0
		BEGIN
		    --check with the amount of members if we go over the treshold --> if so lets calculate 
			IF @PolicyMembers > @Treshold
			BEGIN
				SET @Ceiling = @MaxPolicy + ((@PolicyMembers - @Treshold) * @MaxPolicyExtraMember) 
				IF @Ceiling > @MaxCeilingPolicy
					SET @Ceiling = ISNULL(NULLIF(@MaxCeilingPolicy, 0), @Ceiling)
			END
			ELSE
			BEGIN
				SET @Ceiling = @MaxPolicy
			END

			SET @CeilingType  = 'G'
			SELECT @PrevRemunerated = SUM(RemG) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID And ClaimID <> @ClaimID  
		END
				
		--NOW CHECK FOR IP DEDUCTABLES --> if hospital
		IF @Deductable = 0 
		BEGIN 
			IF (@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ) --@HFLevel = 'H' This was a claim with a hospital stay 
			BEGIN
				--Hospital IP
				IF @DedIPTreatment <> 0 
				BEGIN
					SET @Deductable = @DedIPTreatment
					SET @DeductableType = 'I'
					SET @PrevDeducted = 0 
				END
				
				IF @DedIPInsuree  <> 0
				BEGIN
					SET @Deductable = @DedIPInsuree
					SET @DeductableType = 'I'
					SELECT @PrevDeducted = SUM(DedIP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
					
				END
				
				IF @DedIPPolicy <> 0
				BEGIN
					SET @Deductable = @DedIPPolicy
					SET @DeductableType = 'I'
					SELECT @PrevDeducted = SUM(DedIP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID And ClaimID <> @ClaimID 
				END	
			END
			ELSE
			BEGIN
				--Non hospital OP
				--Hospital IP
				IF @DedOPTreatment <> 0 
				BEGIN
					SET @Deductable = @DedOPTreatment
					SET @DeductableType = 'O'
					SET @PrevDeducted = 0 
				END
				
				IF @DedIPInsuree  <> 0
				BEGIN
					SET @Deductable = @DedOPInsuree
					SET @DeductableType = 'O'
					SELECT @PrevDeducted = SUM(DedOP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
					
				END
				
				IF @DedIPPolicy <> 0
				BEGIN
					SET @Deductable = @DedOPPolicy
					SET @DeductableType = 'O'
					SELECT @PrevDeducted = SUM(DedOP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID And ClaimID <> @ClaimID 
				END	
			END
		END
		
		--NOW CHECK FOR IP CEILINGS --> if hospital
		IF @Ceiling = 0  
		BEGIN
		--- HANS HERE CHANGE DEPENDING ON NEW FIELD IN PRODUCT
			IF (@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' )
			BEGIN
				--Hospital IP
				IF @MaxIPTreatment <> 0 
				BEGIN
					SET @Ceiling  = @MaxIPTreatment
					SET @CeilingType = 'I'
					SET @PrevRemunerated = 0 
				END
				
				IF @MaxIPInsuree  <> 0
				BEGIN
					SET @Ceiling  = @MaxIPInsuree 
					SET @CeilingType = 'I'
					SELECT @PrevRemunerated = SUM(RemIP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
					
				END
				
				IF @MaxIPPolicy <> 0
				BEGIN
					
					IF @PolicyMembers > @Treshold
					BEGIN
						SET @Ceiling = @MaxIPPolicy + ((@PolicyMembers - @Treshold) * @MaxPolicyExtraMemberIP ) 
						IF @Ceiling > @MaxCeilingPolicyIP 
							SET @Ceiling = ISNULL(NULLIF(@MaxCeilingPolicyIP, 0), @Ceiling)
					END
					ELSE
					BEGIN
						SET @Ceiling = @MaxIPPolicy 
					END
					SET @CeilingType = 'I'
					SELECT @PrevRemunerated = SUM(RemIP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID And ClaimID <> @ClaimID 
				END	
			END
			ELSE
			BEGIN
				--Non hospital OP
				IF @MaxOPTreatment <> 0 
				BEGIN
					SET @Ceiling  = @MaxOPTreatment
					SET @CeilingType = 'O'
					SET @PrevRemunerated = 0 
				END
				
				IF @MaxOPInsuree  <> 0
				BEGIN
					SET @Ceiling  = @MaxOPInsuree 
					SET @CeilingType = 'O'
					SELECT @PrevRemunerated = SUM(RemOP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID AND InsureeID = @InsureeID And ClaimID <> @ClaimID 
					
				END
				
				IF @MaxOPPolicy <> 0
				BEGIN
					IF @PolicyMembers > @Treshold
					BEGIN
						SET @Ceiling = @MaxOPPolicy + ((@PolicyMembers - @Treshold) * @MaxPolicyExtraMemberOP ) 
						IF @Ceiling > @MaxCeilingPolicyOP 
							SET @Ceiling = ISNULL(NULLIF(@MaxCeilingPolicyOP, 0), @Ceiling)
					END
					ELSE
					BEGIN
						SET @Ceiling = @MaxOPPolicy 
					END
					 
					SET @CeilingType = 'O'
					SELECT @PrevRemunerated = SUM(RemOP) FROM dbo.tblClaimDedRem WHERE PolicyID = @PolicyID And ClaimID <> @ClaimID 
				END	
			END
		END
		
		--Make sure that we have zero in case of NULL
		SET @PrevRemunerated = ISNULL(@PrevRemunerated,0)
		SET @PrevDeducted = ISNULL(@PrevDeducted,0)
		SET @PrevRemuneratedConsult = ISNULL(@PrevRemuneratedConsult,0)
		SET @PrevRemuneratedSurgery  = ISNULL(@PrevRemuneratedSurgery ,0)
		SET @PrevRemuneratedHospitalization  = ISNULL(@PrevRemuneratedHospitalization ,0)
		SET @PrevRemuneratedDelivery  = ISNULL(@PrevRemuneratedDelivery ,0)
		SET @PrevRemuneratedantenatal   = ISNULL(@PrevRemuneratedantenatal ,0)

		
		DECLARE @CeilingExclusionAdult NVARCHAR(1)
		DECLARE @CeilingExclusionChild NVARCHAR(1)
		

		--FIRST GET all items 
		DECLARE CLAIMITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR 
															SELECT     tblClaimItems.ClaimItemID, tblClaimItems.QtyProvided, tblClaimItems.QtyApproved, tblClaimItems.PriceAsked, tblClaimItems.PriceApproved,  
																		ISNULL(tblPLItemsDetail.PriceOverule,Items.ItemPrice) as PLPrice, tblClaimItems.PriceOrigin, tblClaimItems.Limitation, tblClaimItems.LimitationValue, tblProductItems.CeilingExclusionAdult, tblProductItems.CeilingExclusionChild 
															FROM         tblPLItemsDetail INNER JOIN
																		  @DTBL_ITEMS Items ON tblPLItemsDetail.ItemID = Items.ItemID INNER JOIN
																		  tblClaimItems INNER JOIN
																		  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID INNER JOIN
																		  tblHF ON tblClaim.HFID = tblHF.HfID INNER JOIN
																		  tblPLItems ON tblHF.PLItemID = tblPLItems.PLItemID ON tblPLItemsDetail.PLItemID = tblPLItems.PLItemID AND Items.ItemID = tblClaimItems.ItemID
																		  INNER JOIN tblProductItems ON tblClaimItems.ItemID = tblProductItems.ItemID AND tblProductItems.ProdID = tblClaimItems.ProdID 
															WHERE     (tblClaimItems.ClaimID = @ClaimID) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.ClaimItemStatus = 1) AND (tblClaimItems.ProdID = @ProductID) AND 
																		  (tblClaimItems.PolicyID = @PolicyID) AND (tblPLItems.ValidityTo IS NULL) AND (tblPLItemsDetail.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL)
															ORDER BY tblClaimItems.ClaimItemID
		OPEN CLAIMITEMLOOP
		FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemId, @QtyProvided, @QtyApproved ,@PriceAsked, @PriceApproved, @PLPrice, @PriceOrigin, @Limitation, @Limitationvalue,@CeilingExclusionAdult,@CeilingExclusionChild
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			--SET @Deductable = @DedOPTreatment
			--SET @DeductableType = 'O'
			--SET @PrevDeducted = 0 
			
			--DeductableAmount
			--RemuneratedAmount
			--ExceedCeilingAmount
			--ProcessingStatus
			
			--CHECK first if any amount is still to be deducted 
			--SELECT @ClaimExclusionAdult = CeilingEx FROM tblProductItems WHERE ProdID = @ProductID AND ItemID = @ItemID AND ValidityTo IS NULL

			
			SET @ItemQty = ISNULL(@QtyApproved,@QtyProvided) 
			SET @WorkValue = 0 
			SET @SetPriceDeducted = 0 
			SET @ExceedCeilingAmount = 0 
			SET @ExceedCeilingAmountCategory = 0 

			IF @PriceOrigin = 'O' 
				SET @SetPriceAdjusted = ISNULL(@PriceApproved,@PriceAsked)
			ELSE
				--HVH check if this is the case
				SET @SetPriceAdjusted = ISNULL(@PriceApproved,@PLPrice)
			
			SET @WorkValue = (@ItemQty * @SetPriceAdjusted)
			
			IF @Limitation = 'F' AND ((@ItemQty * @Limitationvalue) < @WorkValue)
				SET @WorkValue =(@ItemQty * @Limitationvalue)


			IF @Deductable - @PrevDeducted - @Deducted > 0 
			BEGIN
				IF (@Deductable - @PrevDeducted - @Deducted) >= ( @WorkValue)
				BEGIN
					SET @SetPriceDeducted = (@WorkValue)
					SET @Deducted = @Deducted + ( @WorkValue)
					SET @Remunerated = @Remunerated + 0 
					SET @SetPriceValuated = 0 
					SET @SetPriceRemunerated = 0 
					GOTO NextItem
				END
				ELSE
				BEGIN
					--partial coverage 
					SET @SetPriceDeducted = (@Deductable - @PrevDeducted - @Deducted)
					SET @WorkValue = (@WorkValue) - @SetPriceDeducted
					SET @Deducted = @Deducted + (@Deductable - @PrevDeducted - @Deducted)
					
					--go next stage --> valuation considering the ceilings 
				END
			END
			
			--DEDUCTABLES ARE ALREADY TAKEN OUT OF VALUE AND STORED IN VARS
			
			--IF @Limitation = 'F' AND ((@ItemQty * @Limitationvalue) < @WorkValue)
				--SET @WorkValue =(@ItemQty * @Limitationvalue)
			
			IF @Limitation = 'C' 
				SET @WorkValue = (@Limitationvalue/100) * @WorkValue  
				
			
			IF @BaseCategory <> 'V'
			BEGIN
				IF (ISNULL(@CeilingSurgery  ,0) > 0) AND @BaseCategory = 'S'  --  Ceiling check for Surgery
				BEGIN
					IF @WorkValue + @PrevRemuneratedSurgery  + @RemuneratedSurgery   <= @CeilingSurgery  
					BEGIN
						--we are still under the ceiling for hospitalization and can be fully covered 
						SET @RemuneratedSurgery   =  @RemuneratedSurgery   + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedSurgery  + @RemuneratedSurgery  >= @CeilingSurgery 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedSurgery  = @RemuneratedSurgery    + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedSurgery   + @RemuneratedSurgery    - @CeilingSurgery   
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedSurgery    =  @RemuneratedSurgery    + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

				IF (ISNULL(@CeilingDelivery  ,0) > 0) AND @BaseCategory = 'D'  --  Ceiling check for Delivery
				BEGIN
					IF @WorkValue + @PrevRemuneratedDelivery  + @RemuneratedDelivery   <= @CeilingDelivery  
					BEGIN
						--we are still under the ceiling for hospitalization and can be fully covered 
						SET @RemuneratedDelivery   =  @RemuneratedDelivery   + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedDelivery  + @RemuneratedDelivery  >= @CeilingDelivery 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedDelivery  = @RemuneratedDelivery    + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedDelivery   + @RemuneratedDelivery    - @CeilingDelivery   
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedDelivery    =  @RemuneratedDelivery    + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END
				
				IF (ISNULL(@CeilingAntenatal  ,0) > 0) AND @BaseCategory = 'A'  --  Ceiling check for Antenatal
				BEGIN
					IF @WorkValue + @PrevRemuneratedAntenatal  + @RemuneratedAntenatal   <= @CeilingAntenatal  
					BEGIN
						--we are still under the ceiling for hospitalization and can be fully covered 
						SET @RemuneratedAntenatal   =  @RemuneratedAntenatal   + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedAntenatal  + @RemuneratedAntenatal  >= @CeilingAntenatal 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedAntenatal  = @RemuneratedAntenatal    + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedAntenatal   + @RemuneratedAntenatal    - @CeilingAntenatal   
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedAntenatal    =  @RemuneratedAntenatal    + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

				IF (ISNULL(@CeilingHospitalization ,0) > 0) AND @BaseCategory = 'H'  --  Ceiling check for Hospital
				BEGIN
					IF @WorkValue + @PrevRemuneratedHospitalization + @RemuneratedHospitalization  <= @CeilingHospitalization 
					BEGIN
						--we are still under the ceiling for hospitalization and can be fully covered 
						SET @RemuneratedHospitalization  =  @RemuneratedHospitalization  + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedHospitalization  + @RemuneratedHospitalization  >= @CeilingHospitalization 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedHospitalization  = @RemuneratedHospitalization    + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedHospitalization   + @RemuneratedHospitalization    - @CeilingHospitalization   
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedHospitalization    =  @RemuneratedHospitalization    + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

				IF (ISNULL(@CeilingConsult   ,0) > 0) AND @BaseCategory = 'C'  --  Ceiling check for Consult
				BEGIN
					IF @WorkValue + @PrevRemuneratedConsult  + @RemuneratedConsult   <= @CeilingConsult  
					BEGIN
						--we are still under the ceiling for hospitalization and can be fully covered 
						SET @RemuneratedConsult   =  @RemuneratedConsult   + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedConsult  + @RemuneratedConsult  >= @CeilingConsult 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedConsult  = @RemuneratedConsult    + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedConsult   + @RemuneratedConsult    - @CeilingConsult   
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedConsult    =  @RemuneratedConsult    + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

			END 

		
			IF (@AdultChild = 'A' AND (((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionAdult = 'B' OR @CeilingExclusionAdult = 'H'))  OR
			   (@AdultChild = 'A' AND (NOT ((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionAdult = 'B' OR @CeilingExclusionAdult = 'N')) OR
			   (@AdultChild = 'C' AND (((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionChild = 'B' OR @CeilingExclusionChild  = 'H')) OR
			   (@AdultChild = 'C' AND (NOT ((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionChild = 'B' OR @CeilingExclusionChild  = 'N')) 
			BEGIN
				--NO CEILING WILL BE AFFECTED
				SET @ExceedCeilingAmount = 0
				SET @Remunerated = @Remunerated + 0 --here in this case we do notr add the amount to be added to the ceiling --> so exclude from the actual value to be entered against the insert into tblClaimDedRem in the end of the prod loop 
				SET @SetPriceValuated = @WorkValue
				SET @SetPriceRemunerated = @WorkValue
				GOTO NextItem
			END
			ELSE
			BEGIN
				IF @Ceiling > 0 --CEILING HAS BEEN DEFINED 
				BEGIN	
					IF (@Ceiling - @PrevRemunerated  - @Remunerated)  > 0
					BEGIN
						--we have not reached the ceiling
						IF (@Ceiling - @PrevRemunerated  - @Remunerated) >= @WorkValue
						BEGIN
							--full amount of workvalue can be paid out as it under the limit
							SET @ExceedCeilingAmount = 0
							SET @SetPriceValuated = @WorkValue
							SET @SetPriceRemunerated = @WorkValue
							SET @Remunerated = @Remunerated + @WorkValue
							GOTO NextItem
						END
						ELSE
						BEGIN
							SET @ExceedCeilingAmount = @WorkValue - (@Ceiling - @PrevRemunerated  - @Remunerated)			
							SET @SetPriceValuated = (@Ceiling - @PrevRemunerated  - @Remunerated)
							SET @SetPriceRemunerated = (@Ceiling - @PrevRemunerated  - @Remunerated)
							SET @Remunerated = @Remunerated + (@Ceiling - @PrevRemunerated  - @Remunerated)			
							GOTO NextItem
						END
					
					END
					ELSE
					BEGIN
						SET @ExceedCeilingAmount = @WorkValue
						SET @Remunerated = @Remunerated + 0
						SET @SetPriceValuated = 0
						SET @SetPriceRemunerated = 0
						GOTO NextItem
					END
				END
				ELSE
				BEGIN
					-->
					SET @ExceedCeilingAmount = 0
					SET @Remunerated = @Remunerated + @WorkValue
					SET @SetPriceValuated = @WorkValue
					SET @SetPriceRemunerated = @WorkValue
					GOTO NextItem
				END

			END
	
			
NextItem:
			IF @IsProcess = 1 
			BEGIN
				IF @PriceOrigin = 'R'
				BEGIN
					UPDATE tblClaimItems SET PriceAdjusted = @SetPriceAdjusted , PriceValuated = @SetPriceValuated , DeductableAmount = @SetPriceDeducted , ExceedCeilingAmount = @ExceedCeilingAmount , @ExceedCeilingAmountCategory  = @ExceedCeilingAmountCategory WHERE ClaimItemID = @ClaimItemID 
					SET @RelativePrices = 1 
				END
				ELSE
				BEGIN
					UPDATE tblClaimItems SET PriceAdjusted = @SetPriceAdjusted , PriceValuated = @SetPriceValuated , DeductableAmount = @SetPriceDeducted ,ExceedCeilingAmount = @ExceedCeilingAmount,  @ExceedCeilingAmountCategory  = @ExceedCeilingAmountCategory, RemuneratedAmount = @SetPriceRemunerated WHERE ClaimItemID = @ClaimItemID 
				END
			END
			
			FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemId, @QtyProvided, @QtyApproved ,@PriceAsked, @PriceApproved, @PLPrice, @PriceOrigin, @Limitation, @Limitationvalue,@CeilingExclusionAdult,@CeilingExclusionChild
		END
		CLOSE CLAIMITEMLOOP
		DEALLOCATE CLAIMITEMLOOP 
			
		-- !!!!!! SECONDLY GET all SERVICES !!!!!!!
			
		DECLARE CLAIMSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR 
															SELECT     tblClaimServices.ClaimServiceID, tblClaimServices.QtyProvided, tblClaimServices.QtyApproved, tblClaimServices.PriceAsked, tblClaimServices.PriceApproved,  
																		ISNULL(tblPLServicesDetail.PriceOverule,Serv.ServPrice) as PLPrice, tblClaimServices.PriceOrigin, tblClaimServices.Limitation, tblClaimServices.LimitationValue, Serv.ServCategory , tblProductServices.CeilingExclusionAdult, tblProductServices.CeilingExclusionChild 
															FROM         tblPLServicesDetail INNER JOIN
																		  @DTBL_Services Serv ON tblPLServicesDetail.ServiceID = Serv.ServiceID INNER JOIN
																		  tblClaimServices INNER JOIN
																		  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
																		  tblHF ON tblClaim.HFID = tblHF.HfID INNER JOIN
																		  tblPLServices ON tblHF.PLServiceID = tblPLServices.PLServiceID ON tblPLServicesDetail.PLServiceID = tblPLServices.PLServiceID AND Serv.ServiceID = tblClaimServices.ServiceID
																		  INNER JOIN tblProductServices ON tblClaimServices.ServiceID  = tblProductServices.ServiceID  AND tblProductServices.ProdID = tblClaimServices.ProdID 
															WHERE     (tblClaimServices.ClaimID = @ClaimID) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.ClaimServiceStatus = 1) AND (tblClaimServices.ProdID = @ProductID) AND 
																		  (tblClaimServices.PolicyID = @PolicyID) AND (tblPLServices.ValidityTo IS NULL) AND (tblPLServicesDetail.ValidityTo IS NULL)  AND (tblProductServices.ValidityTo IS NULL)
															ORDER BY tblClaimServices.ClaimServiceID
		OPEN CLAIMSERVICELOOP
		FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceId, @QtyProvided, @QtyApproved ,@PriceAsked, @PriceApproved, @PLPrice, @PriceOrigin, @Limitation, @Limitationvalue,@ServCategory,@CeilingExclusionAdult,@CeilingExclusionChild
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			--SET @Deductable = @DedOPTreatment
			--SET @DeductableType = 'O'
			--SET @PrevDeducted = 0 
			
			--DeductableAmount
			--RemuneratedAmount
			--ExceedCeilingAmount
			--ProcessingStatus
			
			--CHECK first if any amount is still to be deducted 
			SET @ServiceQty = ISNULL(@QtyApproved,@QtyProvided) 
			SET @WorkValue = 0 
			SET @SetPriceDeducted = 0 
			SET @ExceedCeilingAmount = 0 
			SET @ExceedCeilingAmountCategory = 0 
			


			IF @PriceOrigin = 'O' 
				SET @SetPriceAdjusted = ISNULL(@PriceApproved,@PriceAsked)
			ELSE
				--HVH check if this is the case
				SET @SetPriceAdjusted = ISNULL(@PriceApproved,@PLPrice)
			
			--FIRST GET THE NORMAL PRICING 
			SET @WorkValue = (@ServiceQty * @SetPriceAdjusted)
			

			IF @Limitation = 'F' AND ((@ServiceQty * @Limitationvalue) < @WorkValue)
				SET @WorkValue =(@ServiceQty * @Limitationvalue)

           

			IF @Deductable - @PrevDeducted - @Deducted > 0 
			BEGIN
				IF (@Deductable - @PrevDeducted - @Deducted) >= (@WorkValue)
				BEGIN
					SET @SetPriceDeducted = ( @WorkValue)
					SET @Deducted = @Deducted + ( @WorkValue)
					SET @Remunerated = @Remunerated + 0 
					SET @SetPriceValuated = 0 
					SET @SetPriceRemunerated = 0 
					GOTO NextService
				END
				ELSE
				BEGIN
					--partial coverage 
					SET @SetPriceDeducted = (@Deductable - @PrevDeducted - @Deducted)
					SET @WorkValue = (@WorkValue) - @SetPriceDeducted
					SET @Deducted = @Deducted + (@Deductable - @PrevDeducted - @Deducted)
					
					--go next stage --> valuation considering the ceilings 
				END
			END
			
			--DEDUCTABLES ARE ALREADY TAKEN OUT OF VALUE AND STORED IN VARS
			
			--IF @Limitation = 'F' AND ((@ServiceQty * @Limitationvalue) < @WorkValue)
				--SET @WorkValue =(@ServiceQty * @Limitationvalue)
			
			IF @Limitation = 'C' 
				SET @WorkValue = (@Limitationvalue/100) * @WorkValue  
				
			
			--now capping in case of category constraints
			
			IF @BaseCategory <> 'V'
			BEGIN
				IF @BaseCategory = 'S' AND (ISNULL(@CeilingSurgery ,0) > 0)  --  Ceiling check for category Surgery
				BEGIN
					IF @WorkValue + @PrevRemuneratedSurgery + @RemuneratedSurgery   <= @CeilingSurgery
					BEGIN
						--we are still under the ceiling for surgery and can be fully covered 
						SET @RemuneratedSurgery =  @RemuneratedSurgery + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedSurgery + @RemuneratedSurgery >= @CeilingSurgery 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedSurgery  = @RemuneratedSurgery  + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedSurgery  + @RemuneratedSurgery  - @CeilingSurgery 
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedSurgery  =  @RemuneratedSurgery  + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

				IF @BaseCategory = 'D' AND (ISNULL(@CeilingDelivery ,0) > 0)  --  Ceiling check for category Deliveries 
				BEGIN
					IF @WorkValue + @PrevRemuneratedDelivery  + @RemuneratedDelivery    <= @CeilingDelivery 
					BEGIN
						--we are still under the ceiling for Delivery and can be fully covered 
						SET @RemuneratedDelivery  =  @RemuneratedDelivery  + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedDelivery  + @RemuneratedDelivery  >= @CeilingDelivery 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedDelivery  = @RemuneratedDelivery   + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedDelivery   + @RemuneratedDelivery   - @CeilingDelivery  
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedDelivery   =  @RemuneratedDelivery   + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END
				
				IF @BaseCategory = 'A' AND (ISNULL(@CeilingAntenatal  ,0) > 0)  --  Ceiling check for category Antenatal 
				BEGIN
					IF @WorkValue + @PrevRemuneratedAntenatal  + @RemuneratedAntenatal    <= @CeilingAntenatal 
					BEGIN
						--we are still under the ceiling for Antenatal and can be fully covered 
						SET @RemuneratedAntenatal  =  @RemuneratedAntenatal  + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedAntenatal  + @RemuneratedAntenatal  >= @CeilingAntenatal 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedAntenatal  = @RemuneratedAntenatal   + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedAntenatal   + @RemuneratedAntenatal   - @CeilingAntenatal  
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedAntenatal   =  @RemuneratedAntenatal   + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

				IF  @BaseCategory  = 'H' AND (ISNULL(@CeilingHospitalization ,0) > 0)   --  Ceiling check for category Hospitalization 
				BEGIN
					IF @WorkValue + @PrevRemuneratedHospitalization + @RemuneratedHospitalization  <= @CeilingHospitalization 
					BEGIN
						--we are still under the ceiling for hospitalization and can be fully covered 
						SET @RemuneratedHospitalization  =  @RemuneratedHospitalization  + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedHospitalization  + @RemuneratedHospitalization  >= @CeilingHospitalization 
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedHospitalization  = @RemuneratedHospitalization    + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedHospitalization   + @RemuneratedHospitalization    - @CeilingHospitalization   
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedHospitalization    =  @RemuneratedHospitalization    + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
				END

				IF @BaseCategory  = 'C' AND (ISNULL(@CeilingConsult,0) > 0)  --  Ceiling check for category Consult 
				BEGIN
					IF @WorkValue + @PrevRemuneratedConsult + @RemuneratedConsult  <= @CeilingConsult 
					BEGIN
						--we are still under the ceiling for consult and can be fully covered 
						SET @RemuneratedConsult =  @RemuneratedConsult + @WorkValue
					END
					ELSE
					BEGIN
						IF @PrevRemuneratedConsult + @RemuneratedConsult >= @CeilingConsult
						BEGIN
							--Nothing can be covered already reached ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue
							SET @RemuneratedConsult  = @RemuneratedConsult + 0
							SET @WorkValue = 0 
						END
						ELSE
						BEGIN
							--claim service can partially be covered , we are over the ceiling
							SET @ExceedCeilingAmountCategory = @WorkValue + @PrevRemuneratedConsult + @RemuneratedConsult - @CeilingConsult
							SET @WorkValue = @WorkValue - @ExceedCeilingAmountCategory
							SET @RemuneratedConsult =  @RemuneratedConsult + @WorkValue   -- we only add the value that could be covered up to the ceiling
						END
					END
 				END


			END

			IF (@AdultChild = 'A' AND (((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionAdult = 'B' OR @CeilingExclusionAdult = 'H'))  OR
			   (@AdultChild = 'A' AND (NOT ((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionAdult = 'B' OR @CeilingExclusionAdult = 'N')) OR
			   (@AdultChild = 'C' AND (((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionChild = 'B' OR @CeilingExclusionChild  = 'H')) OR
			   (@AdultChild = 'C' AND (NOT ((@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' ))) AND (@CeilingExclusionChild = 'B' OR @CeilingExclusionChild  = 'N')) 
			BEGIN
				--NO CEILING WILL BE AFFECTED
				SET @ExceedCeilingAmount = 0
				SET @Remunerated = @Remunerated + 0  --(we do not add any value to the running sum for renumerated values as we do not coulnt this service for any ceiling calculation 
				SET @SetPriceValuated = @WorkValue
				SET @SetPriceRemunerated = @WorkValue
				GOTO NextService
				
			END
			ELSE
			BEGIN
				IF @Ceiling > 0 --CEILING HAS BEEN DEFINED 
				BEGIN	
					IF (@Ceiling - @PrevRemunerated  - @Remunerated)  > 0
					BEGIN
						--we have not reached the ceiling
						IF (@Ceiling - @PrevRemunerated  - @Remunerated) >= @WorkValue
						BEGIN
							--full amount of workvalue can be paid out as it under the limit
							SET @ExceedCeilingAmount = 0
							SET @SetPriceValuated = @WorkValue
							SET @SetPriceRemunerated = @WorkValue
							SET @Remunerated = @Remunerated + @WorkValue
							GOTO NextService
						END
						ELSE
						BEGIN
							SET @ExceedCeilingAmount = @WorkValue - (@Ceiling - @PrevRemunerated  - @Remunerated)			
							SET @SetPriceValuated = (@Ceiling - @PrevRemunerated  - @Remunerated)
							SET @SetPriceRemunerated = (@Ceiling - @PrevRemunerated  - @Remunerated)
							SET @Remunerated = @Remunerated + (@Ceiling - @PrevRemunerated  - @Remunerated)			
							GOTO NextService
						END
					
					END
					ELSE
					BEGIN
						SET @ExceedCeilingAmount = @WorkValue
						SET @Remunerated = @Remunerated + 0
						SET @SetPriceValuated = 0
						SET @SetPriceRemunerated = 0
						GOTO NextService
					END
				END
				ELSE
				BEGIN
					-->
					SET @ExceedCeilingAmount = 0
					SET @Remunerated = @Remunerated + @WorkValue
					SET @SetPriceValuated = @WorkValue
					SET @SetPriceRemunerated = @WorkValue
					GOTO NextService
				END

			END

NextService:
			IF @IsProcess = 1 
			BEGIN
				IF @PriceOrigin = 'R'
				BEGIN
					UPDATE tblClaimServices SET PriceAdjusted = @SetPriceAdjusted , PriceValuated = @SetPriceValuated , DeductableAmount = @SetPriceDeducted , ExceedCeilingAmount = @ExceedCeilingAmount , @ExceedCeilingAmountCategory  = @ExceedCeilingAmountCategory  WHERE ClaimServiceID = @ClaimServiceID 
					SET @RelativePrices = 1 
				END
				ELSE
				BEGIN
					UPDATE tblClaimServices SET PriceAdjusted = @SetPriceAdjusted , PriceValuated = @SetPriceValuated , DeductableAmount = @SetPriceDeducted ,ExceedCeilingAmount = @ExceedCeilingAmount, @ExceedCeilingAmountCategory  = @ExceedCeilingAmountCategory, RemuneratedAmount = @SetPriceRemunerated WHERE ClaimServiceID = @ClaimServiceID 
				END
			END
			
			FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceId, @QtyProvided, @QtyApproved ,@PriceAsked, @PriceApproved, @PLPrice, @PriceOrigin, @Limitation, @Limitationvalue,@ServCategory,@CeilingExclusionAdult,@CeilingExclusionChild
		END
		CLOSE CLAIMSERVICELOOP
		DEALLOCATE CLAIMSERVICELOOP 
		
		
		FETCH NEXT FROM PRODUCTLOOP INTO	@ProductID, @PolicyID,@DedInsuree,@DedOPInsuree,@DedIPInsuree,@MaxInsuree,@MaxOPInsuree,@MaxIPInsuree,@DedTreatment,@DedOPTreatment,@DedIPTreatment,
											@MaxIPTreatment,@MaxTreatment,@MaxOPTreatment,@DedPolicy,@DedOPPolicy,@DedIPPolicy,@MaxPolicy,@MaxOPPolicy,@MaxIPPolicy,@CeilingConsult,@CeilingSurgery,@CeilingHospitalization,@CeilingDelivery,@CeilingAntenatal,
											@Treshold, @MaxPolicyExtraMember,@MaxPolicyExtraMemberIP,@MaxPolicyExtraMemberOP,@MaxCeilingPolicy,@MaxCeilingPolicyIP,@MaxCeilingPolicyOP,@CeilingInterpretation
	
	END
	CLOSE PRODUCTLOOP
	DEALLOCATE PRODUCTLOOP 
	
	--Now insert the total renumerations and deductions on this claim 
	
	If @IsProcess = 1 
	BEGIN
		--delete first the policy entry in the table tblClaimDedRem as it was a temporary booking
		DELETE FROM tblClaimDedRem WHERE ClaimID = @ClaimID -- AND PolicyID = @PolicyID AND InsureeID = @InsureeID 
	END

	IF (@CeilingInterpretation = 'I' AND  @Hospitalization = 1) OR (@CeilingInterpretation = 'H' AND @HFLevel = 'H' )
	BEGIN 
		INSERT INTO tblClaimDedRem ([PolicyID],[InsureeID],[ClaimID],[DedG],[RemG],[DedIP],[RemIP],[RemConsult],[RemSurgery] ,[RemHospitalization] ,[RemDelivery] , [RemAntenatal] , [AuditUserID]) VALUES (@PolicyID,@InsureeID , @ClaimID , @Deducted ,@Remunerated ,@Deducted ,@Remunerated , @RemuneratedConsult  , @RemuneratedSurgery  ,@RemuneratedHospitalization , @RemuneratedDelivery  , @RemuneratedAntenatal,@AuditUser) 
	END
	ELSE
	BEGIN 
		INSERT INTO tblClaimDedRem ([PolicyID],[InsureeID],[ClaimID],[DedG],[RemG],[DedOP],[RemOP], [RemConsult],[RemSurgery] ,[RemHospitalization] ,[RemDelivery], [RemAntenatal] ,  [AuditUserID]) VALUES (@PolicyID,@InsureeID , @ClaimID , @Deducted ,@Remunerated ,@Deducted ,@Remunerated , @RemuneratedConsult  , @RemuneratedSurgery  ,@RemuneratedHospitalization , @RemuneratedDelivery , @RemuneratedAntenatal ,@AuditUser) 
	END
	
	If @IsProcess = 1 
	BEGIN
		IF @RelativePrices = 0
		BEGIN
			--update claim in total and set to Valuated
			UPDATE tblClaim SET ClaimStatus = 16, AuditUserIDProcess = @AuditUser, ProcessStamp = GETDATE(), DateProcessed = GETDATE() WHERE ClaimID = @ClaimID 
			SET @RtnStatus = 4
		END
		ELSE
		BEGIN
			--update claim in total and set to Processed --> awaiting one or more Services for relative prices
			UPDATE tblClaim SET ClaimStatus = 8, AuditUserIDProcess = @AuditUser, ProcessStamp = GETDATE(), DateProcessed = GETDATE() WHERE ClaimID = @ClaimID 
			SET @RtnStatus = 3
		END  
	
		UPDATE tblClaim SET FeedbackStatus = 16 WHERE ClaimID = @ClaimID AND FeedbackStatus = 4 
		UPDATE tblClaim SET ReviewStatus = 16 WHERE ClaimID = @ClaimID AND ReviewStatus = 4 
	END


	
FINISH:
	RETURN @oReturnValue
	
	END TRY
	
	BEGIN CATCH
		SELECT 'Unexpected error encountered'
		SET @oReturnValue = 1 
		RETURN @oReturnValue
		
	END CATCH
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspProcessClaims]
	
	@AuditUser as int = 0,
	@xtClaimSubmit dbo.xClaimSubmit READONLY,
	@Submitted as int = 0 OUTPUT  ,
	@Processed as int = 0 OUTPUT  ,
	@Valuated as int = 0 OUTPUT ,
	@Changed as int = 0 OUTPUT ,
	@Rejected as int = 0 OUTPUT  ,
	@Failed as int = 0 OUTPUT ,
	@oReturnValue as int = 0 OUTPUT
	
	
	/*  
	Rejection reasons:
	
	1 = Item/Service not in Registers
	2 = Item/Service not in Covering Product
	3 = Item/Service not in HF Pricelist 
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATD
	7 = 
	8 = 
	9 = 
	10=
	11=
	12=
	*/
	
AS
BEGIN
	SET @oReturnValue = 0 	
	SET @Processed = 0
	SET @Rejected = 0
	SET @Valuated = 0
	SET @Failed = 0
	SET @Changed = 0 

	SELECT @Submitted = COUNT(ClaimID) FROM @xtClaimSubmit

	DECLARE @InTopIsolation as bit 
	
	
	DECLARE @ClaimFailed BIT = 0 
	DECLARE @RtnStatus as int 
	DECLARE @CLAIMID as INT
	DECLARE @ROWID as BIGINT
	DECLARE @InsureeID as int 
	DECLARE @RowCurrent as BIGINT
	DECLARE @RtnItemsPassed as int 
	DECLARE @RtnServicesPassed as int 
	DECLARE @RtnItemsRejected as int 
	DECLARE @RtnServicesRejected as int 
	DECLARE @HFCareType as Char(1)
	DECLARE @HFLevel as Char(1)
	DECLARE @DOB as Date
	DECLARE @AdultChild as Char(1) 
	DECLARE @TargetDate as Date
	DECLARE @DateFrom as Date
	DECLARE @Hospitalization as BIT 

	DECLARE CLAIMLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT [ClaimID],[RowID] FROM @xtClaimSubmit ORDER BY ClaimID ASC
	OPEN CLAIMLOOP
	FETCH NEXT FROM CLAIMLOOP INTO @CLAIMID,@ROWID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		

		SELECT @RowCurrent = RowID FROM tblClaim WHERE ClaimID = @CLAIMID 
		IF @RowCurrent <> @ROWID 
		BEGIN
			SET @Changed = @Changed + 1 
			GOTO NextClaim
		END 
		--execute the single CLAIM and set the correct price 
		SELECT @HFCareType = HFCareType FROM tblClaim INNER JOIN tblHF ON tblHF.HfID = tblClaim.HFID WHERE tblClaim.ClaimID = @CLAIMID 
		SELECT @HFLevel = HFLevel FROM tblClaim INNER JOIN tblHF ON tblHF.HfID = tblClaim.HFID WHERE tblClaim.ClaimID = @CLAIMID  
		SELECT @InsureeID = InsureeID, @DateFrom = DateFrom , @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom)  FROM tblClaim WHERE ClaimID = @ClaimID 
		
		IF @DateFrom <> @TargetDate 
			SET @Hospitalization = 1 --hospitalization
		ELSE
			SET @Hospitalization = 0  --Day visit/treatment 

		SELECT @DOB = DOB FROM tblInsuree WHERE InsureeID = @InsureeID 
		IF DATEDIFF(YY  ,@DOB,@TargetDate ) >=18 
			SET @AdultChild = 'A'
		ELSE
			SET @AdultChild = 'C'

		SET @InTopIsolation = -1 
			
	
		IF @@TRANCOUNT = 0 	
			SET @InTopIsolation =0
		ELSE
			SET @InTopIsolation =1
		IF @InTopIsolation = 0
		BEGIN
			--SELECT 'SET ISOLATION TNX ON'
			SET TRANSACTION  ISOLATION LEVEL READ UNCOMMITTED
			BEGIN TRANSACTION PROCESSCLAIMS
		END

		BEGIN TRY 


			EXEC @oReturnValue = [uspProcessSingleClaimStep1] @AuditUser, @CLAIMID, @InsureeID , @HFCareType, @ROWID, @AdultChild, @RtnStatus OUTPUT
	
			IF @RtnStatus = 0 OR @oReturnValue <> 0 
			BEGIN
				SET @Failed = @Failed + 1 
				GOTO NextClaim
			END
		
			IF @RtnStatus = 2
			BEGIN
				SET @Rejected = @Rejected + 1 
				GOTO NextClaim
			END
			--apply to claims deductables and ceilings
			EXEC @oReturnValue = [uspProcessSingleClaimStep2] @AuditUser ,@CLAIMID, @InsureeID, @HFLevel, @ROWID, @AdultChild, @Hospitalization, 1 ,@RtnStatus OUTPUT
		

			IF @RtnStatus = 0 OR @oReturnValue <> 0 
			BEGIN
				SET @Failed = @Failed + 1 
				GOTO NextClaim
			END
		
			IF @RtnStatus = 3
			BEGIN
				SET @Processed  = @Processed  + 1 
				GOTO NextClaim
			END
		
			IF @RtnStatus = 4
			BEGIN
				SET @Valuated = @Valuated + 1 
				GOTO NextClaim
			END			
		
		END TRY
		BEGIN CATCH
			SET @Failed = @Failed + 1 
			--SELECT 'Unexpected error encountered'
			IF @InTopIsolation = 0 
				SET @ClaimFailed = 1
			GOTO NextClaim
		
		END CATCH

	FINISH:
	
	
NextClaim:
		IF @InTopIsolation = 0 
		BEGIN
			IF @ClaimFailed = 0 
				
				COMMIT TRANSACTION PROCESSCLAIMS	
				
			ELSE
				ROLLBACK TRANSACTION PROCESSCLAIMS
		
		END
		SET @ClaimFailed = 0
		FETCH NEXT FROM CLAIMLOOP INTO @CLAIMID,@ROWID
	END
	CLOSE CLAIMLOOP
	DEALLOCATE CLAIMLOOP
	
	
	SET @oReturnValue = 0 
	RETURN @oReturnValue

		
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspProcessClaimsTEST]
	
	@AuditUser as int = 0,
	@CLaimID as int = 21,
	@Submitted as bigint = 0 OUTPUT  ,
	@Processed as bigint = 0 OUTPUT  ,
	@Valuated as bigint = 0 OUTPUT ,
	@Changed as bigint = 0 OUTPUT ,
	@Rejected as bigint = 0 OUTPUT  ,
	@Failed as bigint = 0 OUTPUT ,
	@oReturnValue as int = 0 OUTPUT
	
	
	/*  
	Rejection reasons:
	
	1 = Item/Service not in Registers
	2 = Item/Service not in Covering Product
	3 = Item/Service not in HF Pricelist 
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATD
	7 = 
	8 = 
	9 = 
	10=
	11=
	12=
	*/
	
AS
BEGIN
	SET @oReturnValue = 0 	
	SET @Processed = 0
	SET @Rejected = 0
	SET @Valuated = 0
	SET @Failed = 0

	SET @Changed = 0 

	SELECT @Submitted = 1
	DECLARE @InTopIsolation as bit 
	
	SET @InTopIsolation = -1 
	
	BEGIN TRY 
	
	IF @@TRANCOUNT = 0 	
		SET @InTopIsolation =0
	ELSE
		SET @InTopIsolation =1
	IF @InTopIsolation = 0
	BEGIN
		--SELECT 'SET ISOLATION TNX ON'
		SET TRANSACTION  ISOLATION LEVEL SERIALIZABLE
		BEGIN TRANSACTION PROCESSCLAIMS
	END

	DECLARE @RtnStatus as int 

	DECLARE @ROWID as BIGINT = 1
	DECLARE @InsureeID as int 
	DECLARE @RowCurrent as BIGINT
	DECLARE @RtnItemsPassed as int 
	DECLARE @RtnServicesPassed as int 
	DECLARE @RtnItemsRejected as int 
	DECLARE @RtnServicesRejected as int 
	DECLARE @HFCareType as Char(1)
	DECLARE @HFLevel as Char(1)
	
	 DECLARE @DateFrom Date
	 DECLARE @DateTo Date
	 DECLARE @TargetDate Date
	DECLARE @Hospitalization BIT 
	DECLARE @AdultChild char(1)
		
		declare @DOB date 

		SELECT @RowCurrent = RowID FROM tblClaim WHERE ClaimID = @CLAIMID
		IF @RowCurrent <> @ROWID 
		BEGIN
			SET @Changed = @Changed + 1 
			--GOTO NextClaim
		END 
		--execute the single CLAIM and set the correct price 
		SELECT @HFCareType = HFCareType FROM tblClaim INNER JOIN tblHF ON tblHF.HfID = tblClaim.HFID WHERE tblClaim.ClaimID = @CLAIMID 
		SELECT @HFLevel = HFLevel FROM tblClaim INNER JOIN tblHF ON tblHF.HfID = tblClaim.HFID WHERE tblClaim.ClaimID = @CLAIMID  
		SELECT @InsureeID = InsureeID, @DateFrom = DateFrom , @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom)  FROM tblClaim WHERE ClaimID = @ClaimID 
		
		IF @DateFrom <> @TargetDate 
			SET @Hospitalization = 1 --hospitalization
		ELSE
			SET @Hospitalization = 0  --Day visit/treatment 

		SELECT @DOB = DOB FROM tblInsuree WHERE InsureeID = @InsureeID 
		IF DATEDIFF(YY  ,@DOB,@TargetDate ) >=18 
			SET @AdultChild = 'A'
		ELSE
			SET @AdultChild = 'C'

		EXEC @oReturnValue = [uspProcessSingleClaimStep1] @AuditUser, @CLAIMID, @InsureeID , @HFCareType, @ROWID, @AdultChild, @RtnStatus OUTPUT
	
		IF @RtnStatus = 0 OR @oReturnValue <> 0 
		BEGIN
			SET @Failed = @Failed + 1 
			--GOTO NextClaim
		END
		
		IF @RtnStatus = 2
		BEGIN
			SET @Rejected = @Rejected + 1 
			--GOTO NextClaim
		END
		--apply to claims deductables and ceilings
		EXEC @oReturnValue = [uspProcessSingleClaimStep2] @AuditUser ,@CLAIMID, @InsureeID, @HFLevel, @ROWID, @AdultChild, @Hospitalization, 1 ,@RtnStatus OUTPUT
		
		IF @RtnStatus = 0 OR @oReturnValue <> 0 
		BEGIN
			SET @Failed = @Failed + 1 
			--GOTO NextClaim
		END
		
		IF @RtnStatus = 3
		BEGIN
			SET @Processed  = @Processed  + 1 
			--GOTO NextClaim
		END
		
		IF @RtnStatus = 4
		BEGIN
			SET @Valuated = @Valuated + 1 
			--GOTO NextClaim
		END			

	ROLLBACK TRANSACTION PROCESSCLAIMS

	

FINISH:
	IF @InTopIsolation = 0 COMMIT TRANSACTION PROCESSCLAIMS
	SET @oReturnValue = 0 
	RETURN @oReturnValue

	END TRY
	BEGIN CATCH
		SET @oReturnValue = 1 
		SELECT 'Unexpected error encountered'
		IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
		RETURN @oReturnValue
		
	END CATCH
	
ERR_HANDLER:

	SELECT 'Unexpected error encountered'
	IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
	RETURN @oReturnValue

	
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspReceiveControlNumber]
(
	@PaymentID INT,
	@ControlNumber NVARCHAR(50),
	@ResponseOrigin NVARCHAR(50) = NULL,
	@Failed BIT = 0
)
AS
	BEGIN
		BEGIN TRY
			IF EXISTS(SELECT 1 FROM tblControlNumber  WHERE PaymentID = @PaymentID AND ValidityTo IS NULL )
			BEGIN
				IF @Failed = 0
				BEGIN
					UPDATE tblPayment SET PaymentStatus = 3 WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
					UPDATE tblControlNumber SET ReceivedDate = GETDATE(), ResponseOrigin = @ResponseOrigin,  ValidityFrom = GETDATE() ,AuditedUserID =-1,ControlNumber = @ControlNumber  WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
					RETURN 0 
				END
				ELSE
				BEGIN
					UPDATE tblPayment SET PaymentStatus = -3, RejectedReason ='8: Duplicated control number assigned' WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
					RETURN 2
				END
			END
			ELSE
			BEGIN
				RETURN 1
			END


				
		END TRY
		BEGIN CATCH
			RETURN -1
		END CATCH

	
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspReceivePayment]
(	
	@XML XML,
	@Payment_ID BIGINT =NULL OUTPUT
)
AS
BEGIN

	DECLARE
	@PaymentID BIGINT =NULL,
	@ControlNumberID BIGINT=NULL,
	@PaymentDate DATE,
	@ReceiveDate DATE,
    @ControlNumber NVARCHAR(50),
    @TransactionNo NVARCHAR(50),
    @ReceiptNo NVARCHAR(100),
    @PaymentOrigin NVARCHAR(50),
    @PayerPhoneNumber NVARCHAR(50),
    @OfficerCode NVARCHAR(50),
    @InsuranceNumber NVARCHAR(12),
    @productCode NVARCHAR(8),
    @Amount  DECIMAL(18,2),
    @isRenewal  BIT,
	@ExpectedAmount DECIMAL(18,2),
	@ErrorMsg NVARCHAR(50)
	
	BEGIN TRY

		DECLARE @tblDetail TABLE(InsuranceNumber nvarchar(12),productCode nvarchar(8), isRenewal BIT)

		SELECT @PaymentID = NULLIF(T.H.value('(PaymentID)[1]','INT'),''),
			   @PaymentDate = NULLIF(T.H.value('(PaymentDate)[1]','DATE'),''),
			   @ReceiveDate = NULLIF(T.H.value('(ReceiveDate)[1]','DATE'),''),
			   @ControlNumber = NULLIF(T.H.value('(ControlNumber)[1]','NVARCHAR(50)'),''),
			   @ReceiptNo = NULLIF(T.H.value('(ReceiptNo)[1]','NVARCHAR(100)'),''),
			   @TransactionNo = NULLIF(T.H.value('(TransactionNo)[1]','NVARCHAR(50)'),''),
			   @PaymentOrigin = NULLIF(T.H.value('(PaymentOrigin)[1]','NVARCHAR(50)'),''),
			   @PayerPhoneNumber = NULLIF(T.H.value('(PhoneNumber)[1]','NVARCHAR(25)'),''),
			   @OfficerCode = NULLIF(T.H.value('(OfficerCode)[1]','NVARCHAR(50)'),''),
			   @Amount = T.H.value('(Amount)[1]','DECIMAL(18,2)')
		FROM @XML.nodes('PaymentData') AS T(H)
	

		DECLARE @MyAmount Decimal(18,2)
		DECLARE @MyControlNumber nvarchar(50)
		DECLARE @MyReceivedAmount decimal(18,2) = 0 
		DECLARE @MyStatus INT = 0 
		DECLARE @ResultCode AS INT = 0 

		INSERT INTO @tblDetail(InsuranceNumber, productCode, isRenewal)
		SELECT 
		LEFT(NULLIF(T.D.value('(InsureeNumber)[1]','NVARCHAR(12)'),''),12),
		LEFT(NULLIF(T.D.value('(ProductCode)[1]','NVARCHAR(8)'),''),8),
		T.D.value('(IsRenewal)[1]','BIT')
		FROM @XML.nodes('PaymentData/Detail') AS T(D)
	
		--VERIFICATION START
		IF ISNULL(@PaymentID,'') <> ''
		BEGIN
			--lets see if all element are matching

			SELECT @MyControlNumber = ControlNumber , @MyAmount = P.ExpectedAmount, @MyReceivedAmount = ISNULL(ReceivedAmount,0) , @MyStatus = PaymentStatus  from tblPayment P left outer join tblControlNumber CN ON P.PaymentID = CN.PaymentID  WHERE CN.ValidityTo IS NULL and P.ValidityTo IS NULL AND P.PaymentID = @PaymentID 


			--CONTROl NUMBER CHECK
			IF ISNULL(@MyControlNumber,'') <> ISNULL(@ControlNumber,'') 
			BEGIN
				--Control Nr mismatch
				SET @ErrorMsg = 'Wrong Control Number'
				SET @ResultCode = 3
			END 

			--AMOUNT VALE CHECK
			IF ISNULL(@MyAmount,0) <> ISNULL(@Amount ,0) 
			BEGIN
				--Amount mismatch
				SET @ErrorMsg = 'Wrong Payment Amount'
				SET @ResultCode = 4
			END 

			--DUPLICATION OF PAYMENT
			IF @MyReceivedAmount = @Amount 
			BEGIN
				SET @ErrorMsg = 'Duplicated Payment'
				SET @ResultCode = 5
			END

			
		END
		--VERIFICATION END

		IF @ResultCode <> 0
		BEGIN
			--ERROR OCCURRED
	
			INSERT INTO [dbo].[tblPayment]
			(PaymentDate, ReceivedDate, ReceivedAmount, ReceiptNo, TransactionNo, PaymentOrigin, PayerPhoneNumber, PaymentStatus, OfficerCode, ValidityFrom, AuditedUSerID, RejectedReason) 
			VALUES (@PaymentDate, @ReceiveDate,  @Amount, @ReceiptNo, @TransactionNo, @PaymentOrigin, @PayerPhoneNumber, -3, @OfficerCode,  GETDATE(), -1,@ErrorMsg)
			SET @PaymentID= SCOPE_IDENTITY();

			INSERT INTO [dbo].[tblPaymentDetails]
				([PaymentID],[ProductCode],[InsuranceNumber],[PolicyStage],[ValidityFrom],[AuditedUserId]) SELECT
				@PaymentID, productCode, InsuranceNumber,  CASE isRenewal WHEN 0 THEN 'N' ELSE 'R' END, GETDATE(), -1
				FROM @tblDetail D

			SET @Payment_ID = @PaymentID
			SELECT @Payment_ID
			RETURN @ResultCode

		END
		ELSE
		BEGIN
			--ALL WENT OK SO FAR
		
		
			IF ISNULL(@PaymentID ,0) <> 0 
			BEGIN
				--REQUEST/INTEND WAS FOUND
				UPDATE tblPayment SET ReceivedAmount = @Amount, PaymentDate = @PaymentDate, ReceivedDate = GETDATE(), 
				PaymentStatus = 4, TransactionNo = @TransactionNo, ReceiptNo= @ReceiptNo, PaymentOrigin = @PaymentOrigin,
				PayerPhoneNumber=@PayerPhoneNumber, ValidityFrom = GETDATE(), AuditedUserID =-1 
				WHERE PaymentID = @PaymentID  AND ValidityTo IS NULL AND PaymentStatus = 3
				SET @Payment_ID = @PaymentID
				RETURN 0 
			END
			ELSE
			BEGIN
				--PAYMENT WITHOUT INTEND TP PAY
				INSERT INTO [dbo].[tblPayment]
					(PaymentDate, ReceivedDate, ReceivedAmount, ReceiptNo, TransactionNo, PaymentOrigin, PayerPhoneNumber, PaymentStatus, OfficerCode, ValidityFrom, AuditedUSerID) 
					VALUES (@PaymentDate, @ReceiveDate,  @Amount, @ReceiptNo, @TransactionNo, @PaymentOrigin, @PayerPhoneNumber, 4, @OfficerCode,  GETDATE(), -1)
				SET @PaymentID= SCOPE_IDENTITY();
							
				INSERT INTO [dbo].[tblPaymentDetails]
				([PaymentID],[ProductCode],[InsuranceNumber],[PolicyStage],[ValidityFrom],[AuditedUserId]) SELECT
				@PaymentID, productCode, InsuranceNumber,  CASE isRenewal WHEN 0 THEN 'N' ELSE 'R' END, GETDATE(), -1
				FROM @tblDetail D
				SET @Payment_ID = @PaymentID
				RETURN 0 

			END
			
		END

		RETURN 0

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRefreshAdmin]

AS
DECLARE @RoleName NVARCHAR(25) = 'AdminProfile',
		@LanguageId NVARCHAR(8) = 'en',
		@Phone NVARCHAR(8) = NULL,
		@RoleID INT = NULL,
		@IsSystem INT = -1,
		@IsBlocked INT = 0,
		@LastName NVARCHAR(50) = 'Admin',
		@OtherName NVARCHAR(50) ='Admin',
		@LoginName NVARCHAR(50) ='Admin',
		@HFID INT = 0, 
		@AuditUserID INT = -1,
		@password VARBINARY(256) = 123, 
		@EmailId NVARCHAR(200) = NULL,
		@PrivateKey NVARCHAR(256) = NULL,
		@StoredPassword NVARCHAR(256) = NULL,
		@LegacyID INT = NULL,
		@UserID INT = NULL

	--Assignment		

	SELECT @UserID = UserID FROM tblUsers WHERE LoginName = @LoginName AND ValidityTo IS NULL
	SELECT @RoleID = RoleID FROM tblRole WHERE RoleName = @RoleName AND ValidityTo IS NULL	

	/* tblUsers */
	IF @UserID IS NOT NULL  
		BEGIN
			SET	@UserID = (SELECT UserID FROM tblUsers WHERE LoginName = @LoginName AND ValidityTo IS NULL)		 
			INSERT INTO tblUsers (LanguageID, LastName, OtherNames, Phone, LoginName, RoleID, HFID, ValidityTo, LegacyID, AuditUserID, PrivateKey, StoredPassword)
			SELECT LanguageID, LastName, OtherNames, Phone, LoginName, RoleID, HFID, GETDATE(), UserID, AuditUserID, PrivateKey, StoredPassword
			
			
			 
			 FROM tblUsers 
				    WHERE LoginName = @LoginName AND ValidityTo IS NULL;
			UPDATE tblUsers SET ValidityFrom = GETDATE(), AuditUserID = @AuditUserID,  
			PrivateKey=
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2),
				StoredPassword=
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST(@LoginName AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2))),2)
			 WHERE LoginName = @LoginName			
		END
	ELSE
		BEGIN
			INSERT INTO tblUsers (LanguageID, LastName, OtherNames, Phone, LoginName, RoleID, HFID, ValidityFrom, LegacyID, AuditUserID, PrivateKey, StoredPassword) 
			VALUES(@LanguageId, @LastName, @OtherName, @Phone, @LoginName, @RoleID, @HFID, GETDATE(), @LegacyID, @AuditUserID, /*, @password, NULL, NULL, */
				--PrivateKey
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2),
				--StoredPassword
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST(@LoginName AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2))),2))
			SELECT @UserID = SCOPE_IDENTITY()		
		END   
	
		/* tblUsersDistricts */

	UPDATE tblUsersDistricts SET ValidityTo = GETDATE() WHERE UserId = @UserID AND ValidityTo IS NULL	
			
	DECLARE @LocationID AS TABLE(LocD INT)
	INSERT INTO @LocationID SELECT DISTINCT LocationID FROM tblLocations  WHERE LocationType ='D' AND  ValidityTo IS NULL
	INSERT INTO tblUsersDistricts ([UserId],[LocationId],[AuditUserID])	SELECT @UserId, LocD, @AuditUserID FROM @LocationID  
		
	/* tblrole */
	IF @RoleID IS NULL		
		BEGIN
			INSERT INTO tblRole (RoleName,IsSystem,isBlocked,ValidityFrom,LegacyID,AuditUserID)
			VALUES (@RoleName, @IsSystem, @IsBlocked, GETDATE(), @LegacyID, @AuditUserID)
			SELECT @RoleID = SCOPE_IDENTITY()
		END

	/* tblUserRole */
	UPDATE tblUserRole SET ValidityTo = GETDATE() WHERE UserId = @UserID AND ValidityTo IS NULL			
	INSERT INTO tblUserRole (UserID, RoleID,ValidityFrom) 
	VALUES (@UserID, @RoleID, GETDATE())
	
 	--Table variable
	DECLARE @Rights as TABLE(RightID INT NULL)

	-- User rights

	INSERT INTO @Rights VALUES('121702')
	
	-- Full access to Location
	INSERT INTO @Rights VALUES('121901')
	INSERT INTO @Rights VALUES('121902')
	INSERT INTO @Rights VALUES('121903')
	INSERT INTO @Rights VALUES('121904')

	-- User Profile rights
	INSERT INTO @Rights VALUES('122000')
	INSERT INTO @Rights VALUES('122001')
	INSERT INTO @Rights VALUES('122002')
	INSERT INTO @Rights VALUES('122003')
	INSERT INTO @Rights VALUES('122004')
	INSERT INTO @Rights VALUES('122005')

	-- Tool/Registers/Location 
	INSERT INTO @Rights VALUES('131005')
	INSERT INTO @Rights VALUES('131006') 

	--Delete exists Rights
	DELETE FROM tblRoleRight WHERE RightID NOT IN 
	(SELECT RightID FROM @Rights ) AND RoleID = @RoleID AND ValidityTo IS NULL

	INSERT INTO tblRoleRight (RoleID, RightID, ValidityFrom) 
			SELECT @RoleID, RightID, GETDATE() 
			FROM @Rights 
			WHERE RightID 
			NOT IN(SELECT ISNULL(RightID,0) RightID FROM tblRoleRight WHERE RoleID = @RoleID)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRequestGetControlNumber]
(
	
	@PaymentID INT= 0,
	@RequestOrigin NVARCHAR(50) = NULL,
	@Failed BIT = 0
)
AS
BEGIN

		IF NOT EXISTS(SELECT 1 FROM tblPayment WHERE PaymentID = @PaymentID)
		RETURN 1 --Payment Does not exists
	
	IF EXISTS(SELECT 1 FROM tblControlNumber  WHERE PaymentID = @PaymentID  AND [Status] = 0 AND ValidityTo IS NULL)
		RETURN 2 --Request Already exists

			BEGIN TRY
				BEGIN TRAN GETCONTROLNUMBER
						INSERT INTO [dbo].[tblControlNumber]
						 ([RequestedDate],[RequestOrigin],[Status],[ValidityFrom],[AuditedUserID],[PaymentID])
							 SELECT GETDATE(), @RequestOrigin,0, GETDATE(), -1, @PaymentID
							 IF @Failed = 0
							 UPDATE tblPayment SET PaymentStatus =1 WHERE PaymentID = @PaymentID
				COMMIT TRAN GETCONTROLNUMBER
				RETURN 0
			END TRY
			BEGIN CATCH
				ROLLBACK TRAN GETCONTROLNUMBER
				SELECT ERROR_MESSAGE()
				RETURN -1
			END CATCH
	

	
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspS_LRV]

	(
		
		@LRV bigint OUTPUT
	)

AS
		
	set @LRV = @@DBTS 
	RETURN 

GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspServiceItemEnquiry]
(
	@CHFID NVARCHAR(36),
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


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSDerivedIndicators1]
	(
		@ProductID INT = 0,
		@LocationId INT = 0,
		@Month INT,
		@Year INT
	)
	AS
	BEGIN
		IF NOT OBJECT_ID('tempdb..#tmpResult') IS NULL DROP TABLE #tmpResult
	
		CREATE TABLE #tmpResult(
				NameOfTheMonth VARCHAR(15),
				DistrictName NVARCHAR(50),
				ProductCode NVARCHAR(8),
				ProductName NVARCHAR(100),
				IncurredClaimRatio DECIMAL(18,2),
				RenewalRatio DECIMAL(18,2),
				GrowthRatio DECIMAL(18,2),
				Promptness DECIMAL(18,2),
				InsureePerClaim DECIMAL(18,2)
		)

		DECLARE @LastDay DATE
		DECLARE @PreMonth INT
		DECLARE @PreYear INT 

		DECLARE @Counter INT = 1
		DECLARE @MaxCount INT = 12

        IF @Month > 0
		BEGIN
			SET @Counter = @Month
			SET @MaxCount = @Month
		END
	
        WHILE @Counter <> @MaxCount + 1
        BEGIN
	        SET @LastDay = DATEADD(DAY,-1,DATEADD(MONTH,1,CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-01'))
	        SET @PreMonth = MONTH(DATEADD(MONTH,-1,@LastDay))
	        SET @PreYear = YEAR(DATEADD(MONTH,-1,@LastDay))

        	INSERT INTO #tmpResult
	        SELECT CAST(YEAR(@LastDay) AS VARCHAR(4)) + ' ' + DATENAME(MONTH,@LastDay)NameOfTheMonth,Promptness.DistrictName,MainInfo.ProductCode,MainInfo.ProductName
	        ,CAST(SUM(ISNULL(R.Remunerated,0))AS FLOAT)/ISNULL(AP.Allocated,1) IncurredClaimRatio
	        ,CAST(ISNULL(PR.Renewals,0) AS FLOAT)/ISNULL(EP.ExpiredPolicies,1)RenewalRatio
	        ,CAST((ISNULL(NP.Male,0) + ISNULL(NP.Female,0)) AS FLOAT)/ISNULL(TP.Male + TP.Female,1)GrowthRatio
	        ,Promptness.AverageDays AS Promptness --Still to come
	        ,SUM(TC.TotalClaims)/ISNULL(PIn.Male + PIn.Female,1)InsureePerClaim
	        FROM
	        (SELECT PR.ProdID,PR.ProductCode,PR.ProductName
	        FROM tblProduct PR 
	        WHERE PR.ValidityTo IS NULL	
	        AND (PR.ProdID = @ProductID OR @ProductID = 0)
	        )MainInfo INNER JOIN
	        dbo.udfRemunerated(0,@ProductID,@LocationId,@Counter,@Year) R ON MainInfo.ProdID = R.ProdID LEFT OUTER JOIN
	        dbo.udfAvailablePremium(@ProductID,@LocationId,@Counter,@Year,1)AP ON MainInfo.ProdID = AP.ProdID LEFT OUTER JOIN
	        dbo.udfPolicyRenewal(@ProductID,@LocationId,@Counter,@Year,1) PR ON MainInfo.ProdID = PR.ProdID LEFT OUTER JOIN
	        dbo.udfExpiredPolicies(@ProductID,@LocationId,@Counter,@Year,1)EP ON MainInfo.ProdID = EP.ProdID LEFT OUTER JOIN
	        dbo.udfNewPolicies(@ProductID,@LocationId,@PreMonth,@PreYear,1)NP ON MainInfo.ProdID = NP.ProdID LEFT OUTER JOIN
	        dbo.udfTotalPolicies(@ProductID,@LocationId,DATEADD(MONTH,-1,@LastDay),1)TP ON MainInfo.ProdID = TP.ProdID LEFT OUTER JOIN
	        --dbo.udfRejectedClaims(@ProductID,@LocationId,0,@Counter,@Year)RC ON MainInfo.ProdID = RC.ProdID LEFT OUTER JOIN
	        dbo.udfTotalClaims(@ProductId,0,@LocationId,@Counter,@Year) TC ON MainInfo.ProdID = TC.ProdID LEFT OUTER JOIN
	        dbo.udfPolicyInsuree(@ProductID,@LocationId,@LastDay,1) PIn ON MainInfo.ProdID = PIn.ProdID LEFT OUTER JOIN
	        (SELECT Base.ProdID,AVG(DATEDIFF(dd,Base.DateClaimed,Base.RunDate))AverageDays,Base.DistrictName
		        FROM
		        (SELECT C.ClaimID,C.DateClaimed,CI.ProdID,B.RunDate,D.DistrictName
		        FROM tblClaim C INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
		        INNER JOIN tblInsuree I ON C.InsureeId = I.InsureeId 
		        INNER JOIN tblFamilies F ON I.familyId = F.FamilyId
		        INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		        INNER JOIN tblWards W ON W.WardId = V.WardId
		        INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		        INNER JOIN tblBatchRun B ON C.RunID = B.RunID
		        WHERE C.ValidityTo IS NULL AND CI.ValidityTo IS NULL AND I.ValidityTo IS NULL AND F.ValidityTo IS NULL
		        AND (CI.ProdID = @ProductID OR @ProductID = 0)
		        AND (D.DistrictId = @LocationId OR @LocationId = 0)
		        AND C.RunID IN (SELECT  RunID FROM tblBatchRun WHERE ValidityTo IS NULL AND MONTH(RunDate) =@Counter AND YEAR(RunDate) = @Year)
		        GROUP BY C.ClaimID,C.DateClaimed,CI.ProdID,B.RunDate,D.DistrictName
		        UNION 
		        SELECT C.ClaimID,C.DateClaimed,CS.ProdID,B.RunDate, D.DistrictName
		        FROM tblClaim C INNER JOIN tblClaimItems CS ON C.ClaimID = CS.ClaimID
		        INNER JOIN tblInsuree I ON C.InsureeId = I.InsureeId 
		        INNER JOIN tblFamilies F ON I.familyId = F.FamilyId
		        INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		        INNER JOIN tblWards W ON W.WardId = V.WardId
		        INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		        INNER JOIN tblBatchRun B ON C.RunID = B.RunID
		        WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL AND I.ValidityTo IS NULL AND F.ValidityTo IS NULL
		        AND (CS.ProdID = @ProductID OR @ProductID = 0)
		        AND (D.DistrictId = @LocationId OR @LocationId = 0)
		        AND C.RunID IN (SELECT  RunDate FROM tblBatchRun WHERE ValidityTo IS NULL AND MONTH(RunDate) =@Counter AND YEAR(RunDate) = @Year)
		        GROUP BY C.ClaimID,C.DateClaimed,CS.ProdID,B.RunDate, D.DistrictName)Base
		        GROUP BY Base.ProdID,Base.DistrictName)Promptness ON MainInfo.ProdID = Promptness.ProdID
	
	        GROUP BY Promptness.DistrictName,MainInfo.ProductCode,MainInfo.ProductName,AP.Allocated,PR.Renewals,EP.ExpiredPolicies,NP.Male,NP.Female,TP.Male,TP.Female,Promptness.AverageDays,PIn.Male,Pin.Female
	
	        SET @Counter = @Counter + 1
		
        END
	    SELECT * FROM #tmpResult
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSDerivedIndicators2]
	(
		@LocationId INT = 0,
		@ProductID INT = 0,
		@HFID INT = 0,
		@Month INT,
		@Year INT
	)	
	AS
	BEGIN
		DECLARE @LastDay DATE
	
		IF NOT OBJECT_ID('tempdb..#tmpResult') IS NULL DROP TABLE #tmpResult

		CREATE TABLE #tmpResult(
			NameOfTheMonth VARCHAR(15),
			DistrictName NVARCHAR(50),
			HFCode NVARCHAR(8),
			HFName NVARCHAR(100) ,
			ProductCode NVARCHAR(8), 
			ProductName NVARCHAR(100),
			SettlementRatio DECIMAL(18,2),
			AverageCostPerClaim DECIMAL(18,2),
			Asessment DECIMAL(18,2),
			FeedbackResponseRatio DECIMAL(18,2)
	
	        )

        DECLARE @Counter INT = 1
        DECLARE @MaxCount INT = 12

        IF @Month > 0
	        BEGIN
		        SET @Counter = @Month
		        SET @MaxCount = @Month
	        END
	
        WHILE @Counter <> @MaxCount + 1
        BEGIN

	        SET @LastDay = DATEADD(DAY,-1,DATEADD(MONTH,1,CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-01'))
	
	        INSERT INTO #tmpResult
	        SELECT CAST(YEAR(@LastDay) AS VARCHAR(4)) + ' ' + DATENAME(MONTH,@LastDay)NameOfTheMonth,MainInfo.DistrictName,MainInfo.HFCode,MainInfo.HFName ,MainInfo.ProductCode , MainInfo.ProductName
	        ,(TC.TotalClaims - ISNULL(RC.RejectedClaims,0))/TC.TotalClaims SettlementRatio
	        --,CAST(SUM(ISNULL(R.Remunerated,0))/CAST(ISNULL(NULLIF(COUNT(TC.TotalClaims),0),1) AS NUMERIC) AS FLOAT)AverageCostPerClaim
	        ,CAST(SUM(ISNULL(R.Remunerated,0))/TC.TotalClaims AS FLOAT)AverageCostPerClaim
	        ,Satisfaction.Asessment
	        ,FeedbackResponse.FeedbackResponseRatio
	        FROM

	        (SELECT tblDistricts.DistrictName,tblHF.HfID  ,tblHF.HFCode ,tblHF.HFName ,tblProduct.ProdID , tblProduct.ProductCode ,tblProduct.ProductName FROM tblDistricts INNER JOIN tblHF ON tblDistricts.DistrictID = tblHF.LocationId 
	        INNER JOIN tblProduct ON tblProduct.LocationId = tblDistricts.DistrictID 
	        WHERE tblDistricts.ValidityTo IS NULL AND tblHF.ValidityTo IS NULL AND tblproduct.ValidityTo IS NULL 
				        AND (tblDistricts.DistrictID = @LocationId OR @LocationId = 0) 
				        AND (tblProduct.ProdID = @ProductID OR @ProductID = 0)
				        AND (tblHF.HFID = @HFID OR @HFID = 0)
	        ) MainInfo LEFT OUTER JOIN
	        dbo.udfRejectedClaims(@ProductID,@LocationId,0,@Counter,@Year)RC ON MainInfo.ProdID = RC.ProdID AND MainInfo.HfID = RC.HFID LEFT OUTER JOIN
	        dbo.udfTotalClaims(@ProductID,@HFID,@LocationId,@Counter,@Year) TC ON MainInfo.ProdID = TC.ProdID AND MainInfo.hfid = TC.HFID LEFT OUTER JOIN
	        dbo.udfRemunerated(@HFID,@ProductID,@LocationId,@Counter,@Year) R ON MainInfo.ProdID = R.ProdID AND MainInfo.HfID = R.HFID LEFT OUTER JOIN
	        (SELECT C.LocationId,C.HFID,C.ProdID,AVG(CAST(F.Asessment AS DECIMAL(3, 1)))Asessment 
	        FROM tblFeedback F INNER JOIN
	        (SELECT CI.ClaimID,CI.ProdID,C.HFID,PR.LocationId
	        FROM tblClaim C INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
	        INNER JOIN tblProduct PR ON CI.ProdID = PR.ProdID
	        WHERE C.ValidityTo IS NULL AND CI.ValidityTo IS NULL AND PR.ValidityTo IS NULL
	        GROUP BY CI.ClaimID,CI.ProdID,C.HFID,PR.LocationId
	        UNION 
	        SELECT CS.ClaimID,CS.ProdID,C.HFID,PR.LocationId
	        FROM tblClaim C INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
	        INNER JOIN tblProduct PR ON CS.ProdID = PR.ProdID
	        WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL AND PR.ValidityTo IS NULL
	        GROUP BY CS.ClaimID,CS.ProdID,C.HFID,PR.LocationId
	        )C ON F.ClaimID = C.ClaimID
	        WHERE MONTH(F.FeedbackDate) = @Counter AND YEAR(F.FeedbackDate) = @Year
	        GROUP BY C.LocationId,C.HFID,C.ProdID)Satisfaction ON MainInfo.ProdID = Satisfaction.ProdID AND MainInfo.HfID = Satisfaction.HFID
	        LEFT OUTER JOIN
	        (SELECT PR.LocationId, C.HFID, PR.ProdId, COUNT(F.FeedbackID) / COUNT(C.ClaimID) FeedbackResponseRatio
	        FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimId = CI.ClaimID
	        LEFT OUTER JOIN tblClaimServices CS ON CS.ClaimID = C.ClaimID
	        LEFT OUTER JOIN tblFeedback F ON C.ClaimId = F.ClaimID
	        LEFT OUTER JOIN tblFeedbackPrompt FP ON FP.ClaimID =C.ClaimID
	        INNER JOIN tblProduct PR ON PR.ProdId = CI.ProdID OR PR.ProdID = CS.ProdID
	        WHERE C.ValidityTo IS NULL
	        AND C.FeedbackStatus >= 4
	        AND F.ValidityTo IS NULL
	        AND MONTH(FP.FeedbackPromptDate) = @Counter
	        AND YEAR(FP.FeedbackPromptDate) = @Year
	        GROUP BY PR.LocationId, C.HFID, PR.ProdId)FeedbackResponse ON MainInfo.ProdID = FeedbackResponse.ProdID AND MainInfo.HfID = FeedbackResponse.HFID
	
	        GROUP BY MainInfo.DistrictName,MainInfo.HFCode,MainInfo.HFName,MainInfo.ProductCode,MainInfo.ProductName,RC.RejectedClaims,Satisfaction.Asessment,FeedbackResponse.FeedbackResponseRatio, TC.TotalClaims
	        SET @Counter = @Counter + 1

        END

	        SELECT * FROM #tmpResult
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspSSRSEnroledFamilies]
	(
		@LocationId INT,
		@StartDate DATE,
		@EndDate DATE,
		@PolicyStatus INT =NULL,
		@dtPolicyStatus xAttribute READONLY
	)
	AS
	BEGIN
		;WITH MainDetails AS
		(
			SELECT F.FamilyID, F.LocationId,R.RegionName, D.DistrictName,W.WardName,V.VillageName,I.IsHead,I.CHFID, I.LastName, I.OtherNames, CONVERT(DATE,I.ValidityFrom) EnrolDate
			FROM tblFamilies F 
			INNER JOIN tblInsuree I ON F.FamilyID = I.FamilyID
			INNER JOIN tblVillages V ON V.VillageId = F.LocationId
			INNER JOIN tblWards W ON W.WardId = V.WardId
			INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
			INNER JOIN tblRegions R ON R.RegionId = D.Region
			WHERE F.ValidityTo IS NULL
			AND I.ValidityTo IS NULL
			AND R.ValidityTo IS NULL
			AND D.ValidityTo IS  NULL
			AND W.ValidityTo IS NULL
			AND V.ValidityTo IS NULL
			AND CAST(I.ValidityFrom AS DATE) BETWEEN @StartDate AND @EndDate
			
		),Locations AS(
			SELECT LocationId, ParentLocationId FROM tblLocations WHERE ValidityTo IS NULL AND (LocationId = @LocationId OR CASE WHEN @LocationId IS NULL THEN ISNULL(ParentLocationId, 0) ELSE 0 END = ISNULL(@LocationId, 0))
			UNION ALL
			SELECT L.LocationId, L.ParentLocationId
			FROM tblLocations L 
			INNER JOIN Locations ON Locations.LocationId = L.ParentLocationId
			WHERE L.ValidityTo IS NULL
		),Policies AS
		(
			SELECT ROW_NUMBER() OVER(PARTITION BY PL.FamilyId ORDER BY PL.FamilyId, PL.PolicyStatus)RNo,PL.FamilyId,PL.PolicyStatus
			FROM tblPolicy PL
			WHERE PL.ValidityTo IS NULL
			--AND (PL.PolicyStatus = @PolicyStatus OR @PolicyStatus IS NULL)
			GROUP BY PL.FamilyId, PL.PolicyStatus
		) 
		SELECT MainDetails.*, Policies.PolicyStatus, 
		--CASE Policies.PolicyStatus WHEN 1 THEN N'Idle' WHEN 2 THEN N'Active' WHEN 4 THEN N'Suspended' WHEN 8 THEN N'Expired' ELSE N'No Policy' END 
		PS.Name PolicyStatusDesc
		FROM  MainDetails 
		INNER JOIN Locations ON Locations.LocationId = MainDetails.LocationId
		LEFT OUTER JOIN Policies ON MainDetails.FamilyID = Policies.FamilyID
		LEFT OUTER JOIN @dtPolicyStatus PS ON PS.ID = ISNULL(Policies.PolicyStatus, 0)
		WHERE (Policies.RNo = 1 OR Policies.PolicyStatus IS NULL) 
		AND (Policies.PolicyStatus = @PolicyStatus OR @PolicyStatus IS NULL)
		ORDER BY MainDetails.LocationId;
	END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspSSRSFeedbackPrompt]
	(
		@SMSStatus INT = 0,
		@LocationId INT = 0,
		@WardID INT = 0,
		@VillageID INT = 0,
		@OfficerID INT = 0,
		@RangeFrom DATE = '',
		@RangeTo DATE = ''
	)
	AS
	BEGIN	
		IF @RangeFrom = '' SET @RangeFrom = GETDATE()
		IF @RangeTo = '' SET @RangeTo = GETDATE()
		SELECT D.DistrictName,W.WardName, V.VillageName,ISNULL(NULLIF(O.VEOLastName, ''), O.LastName) + ' ' + ISNULL(NULLIF(O.VEOOtherNames, ''), O.OtherNames) AS Officer, ISNULL(NULLIF(O.VEOPhone, ''), O.Phone)VEOPhone,
		FP.FeedbackPromptDate,FP.ClaimID,C.ClaimCode, HF.HFCode, HF.HFName, I.CHFID, I.OtherNames, I.LastName, ICD.ICDName, C.DateFrom, ISNULL(C.DateTo,C.DateFrom) DateTo,FP.SMSStatus,C.Claimed
		FROM tblFeedbackPrompt FP INNER JOIN tblClaim C ON FP.ClaimID = C.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN tblICDCodes ICD ON C.ICDID = ICD.ICDID
		INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID
		INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID
		INNER JOIN tblVillages V ON V.VillageID = F.LocationId
		INNER JOIN tblWards W ON W.WardID = V.WardID
		INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
		LEFT OUTER JOIN tblPolicy PL ON F.FamilyID = PL.FamilyId
		LEFT OUTER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
		WHERE FP.ValidityTo IS NULL 
		AND C.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL 
		AND I.ValidityTo IS NULL 
		AND F.ValidityTo IS NULL 
		AND D.ValidityTo IS NULL 
		AND W.ValidityTo IS NULL 
		AND V.ValidityTo IS NULL 
		AND PL.ValidityTo IS NULL 
		AND O.ValidityTo IS NULL 
		AND ICD.ValidityTo IS NULL
		AND C.FeedbackStatus = 4
		AND (FP.SMSStatus = @SMSStatus OR @SMSStatus = 0)
		AND (D.DistrictID  = @LocationId OR @LocationId = 0)
		AND (W.WardID = @WardID OR @WardID = 0)
		AND (V.VillageID = @VillageID OR @VillageId = 0)
		AND (O.OfficerID = @OfficerID OR @OfficerId = 0)
		AND FP.FeedbackPromptDate BETWEEN @RangeFrom AND @RangeTo
		GROUP BY D.DistrictName,W.WardName, V.VillageName,O.VEOLastName, O.LastName, O.VEOOtherNames, O.OtherNames, O.VEOPhone, O.Phone,
		FP.FeedbackPromptDate,FP.ClaimID,C.ClaimCode, HF.HFCode, HF.HFName, I.CHFID, I.OtherNames, I.LastName, ICD.ICDName, C.DateFrom, C.DateTo,FP.SMSStatus,C.Claimed
	END

GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspSSRSGetMatchingFunds]
	(
		@LocationId INT = NULL, 
		@ProdId INT = NULL,
		@PayerId INT = NULL,
		@StartDate DATE = NULL,
		@EndDate DATE = NULL,
		@ReportingId INT = NULL,
		@ErrorMessage NVARCHAR(200) = N'' OUTPUT
	)
	AS
	BEGIN
		DECLARE @RecordFound INT = 0

	    --Create new entries only if reportingId is not provided

	    IF @ReportingId IS NULL
	    BEGIN

		    IF @LocationId IS NULL RETURN 1;
		    IF @ProdId IS NULL RETURN 2;
		    IF @StartDate IS NULL RETURN 3;
		    IF @EndDate IS NULL RETURN 4;
		
		    BEGIN TRY
			    BEGIN TRAN
				    --Insert the entry into the reporting table
				    INSERT INTO tblReporting(ReportingDate,LocationId, ProdId, PayerId, StartDate, EndDate, RecordFound,OfficerID,ReportType)
				    SELECT GETDATE(),@LocationId, @ProdId, @PayerId, @StartDate, @EndDate, 0,null,1;

				    --Get the last inserted reporting Id
				    SELECT @ReportingId =  SCOPE_IDENTITY();

	
				    --Update the premium table with the new reportingid

				    UPDATE tblPremium SET ReportingId = @ReportingId
				    WHERE PremiumId IN (
				    SELECT Pr.PremiumId--,Prod.ProductCode, Prod.ProductName, D.DistrictName, W.WardName, V.VillageName, Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName, 
				    --Ins.DOB, Ins.IsHead, PL.EnrollDate, Pr.Paydate, Pr.Receipt,CASE WHEN Ins.IsHead = 1 THEN Pr.Amount ELSE 0 END Amount, Payer.PayerName
				    FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID
				    INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
				    INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
				    INNER JOIN tblVillages V ON V.VillageId = F.LocationId
				    INNER JOIN tblWards W ON W.WardId = V.WardId
				    INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
				    LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID 
				    left join tblReporting ON PR.ReportingId =tblReporting.ReportingId AND tblReporting.ReportType=1
				    WHERE Pr.ValidityTo IS NULL 
				    AND PL.ValidityTo IS NULL
				    AND Prod.ValidityTo IS NULL
				    AND F.ValidityTo IS NULL
				    AND D.ValidityTo IS NULL
				    AND W.ValidityTo IS NULL
				    AND V.ValidityTo IS NULL
				    AND Payer.ValidityTo IS NULL

				    AND D.DistrictID = @LocationId
				    AND PayDate BETWEEN @StartDate AND @EndDate
				    AND Prod.ProdID = @ProdId
				    AND (ISNULL(Payer.PayerID,0) = ISNULL(@PayerId,0) OR @PayerId IS NULL)
				    AND Pr.ReportingId IS NULL
				    AND PR.PayType <> N'F'
				    )

				    SELECT @RecordFound = @@ROWCOUNT;

				    UPDATE tblReporting SET RecordFound = @RecordFound WHERE ReportingId = @ReportingId;

			    COMMIT TRAN;
		    END TRY
		    BEGIN CATCH
			    --SELECT @ErrorMessage = ERROR_MESSAGE(); ERROR MESSAGE WAS COMMENTED BY SALUMU ON 12-11-2019
			    ROLLBACK;
			    --RETURN -1 RETURN WAS COMMENTED BY SALUMU ON 12-11-2019
		    END CATCH
	    END
	
	    SELECT Pr.PremiumId,Prod.ProductCode, Prod.ProductName,F.FamilyID, D.DistrictName, W.WardName, V.VillageName, Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName, 
	    Ins.DOB, Ins.IsHead, PL.EnrollDate, Pr.Paydate, Pr.Receipt,CASE WHEN Ins.IsHead = 1 THEN Pr.Amount ELSE 0 END Amount, Payer.PayerName
	    FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID
	    INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	    INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
	    INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	    INNER JOIN tblWards W ON W.WardId = V.WardId
	    INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	    INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL
	    LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID 
	    WHERE Pr.ReportingId = @ReportingId
	    ORDER BY PremiumId DESC, IsHead DESC;

	    SET @ErrorMessage = N''
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSPaymentCategoryOverview]
	(
		@DateFrom DATE,
		@DateTo DATE,
		@LocationId INT = 0,
		@ProductId INT= 0
	)
	AS
	BEGIN	
		;WITH InsureePolicy AS
	    (
		    SELECT COUNT(IP.InsureeId) TotalMembers, IP.PolicyId
		    FROM tblInsureePolicy IP
		    WHERE IP.ValidityTo IS NULL
		    GROUP BY IP.PolicyId
	    ), [Main] AS
	    (
		    SELECT PL.PolicyId, Prod.ProdID, PL.FamilyId, SUM(CASE WHEN PR.isPhotoFee = 0 THEN PR.Amount ELSE 0 END)TotalPaid,
		    SUM(CASE WHEN PR.isPhotoFee = 1 THEN PR.Amount ELSE 0 END)PhotoFee,
		    COALESCE(Prod.RegistrationLumpsum, IP.TotalMembers * Prod.RegistrationFee, 0)[Registration],
		    COALESCE(Prod.GeneralAssemblyLumpsum, IP.TotalMembers * Prod.GeneralAssemblyFee, 0)[Assembly]

		    FROM tblPremium PR
		    INNER JOIN tblPolicy PL ON PL.PolicyId = PR.PolicyID
		    INNER JOIN InsureePolicy IP ON IP.PolicyId = PL.PolicyID
		    INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
	
		    WHERE PR.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND Prod.ValidityTo IS NULL
		    AND PR.PayTYpe <> 'F'
		    AND PR.PayDate BETWEEN @DateFrom AND @DateTo
		    AND (Prod.ProdID = @ProductId OR @ProductId = 0)
	

		    GROUP BY PL.PolicyId, Prod.ProdID, PL.FamilyId, IP.TotalMembers, Prod.GeneralAssemblyLumpsum, Prod.GeneralAssemblyFee, Prod.RegistrationLumpsum, Prod.RegistrationFee
	    ), RegistrationAndAssembly AS
	    (
		    SELECT PolicyId, 
		    CASE WHEN TotalPaid - Registration >= 0 THEN Registration ELSE TotalPaid END R,
		    CASE WHEN TotalPaid - Registration > 0 THEN CASE WHEN TotalPaid - Registration - [Assembly] >= 0 THEN [Assembly] ELSE TotalPaid - Registration END ELSE 0 END A
		    FROM [Main]
	    ), Overview AS
	    (
		    SELECT Main.ProdId, Main.PolicyId, Main.FamilyId, RA.R, RA.A,
		    CASE WHEN TotalPaid - RA.R - Main.[Assembly] >= 0 THEN TotalPaid - RA.R - Main.[Assembly] ELSE Main.TotalPaid - RA.R - RA.A END C,
		    Main.PhotoFee
		    FROM [Main] 
		    INNER JOIN RegistrationAndAssembly RA ON Main.PolicyId = RA.PolicyID
	    )

	    SELECT Prod.ProdId, Prod.ProductCode, Prod.ProductName, D.DistrictName, SUM(O.R) R, SUM(O.A)A, SUM(O.C)C, SUM(PhotoFee)P
	    FROM Overview O
	    INNER JOIN tblProduct Prod ON Prod.ProdID = O.ProdId
	    INNER JOIN tblFamilies F ON F.FamilyId = O.FamilyID
	    INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	    INNER JOIN tblWards W ON W.WardId = V.WardId
	    INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId

	    WHERE Prod.ValidityTo IS NULL
	    AND F.ValidityTo IS NULL
	    AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)

	    GROUP BY Prod.ProdId, Prod.ProductCode, Prod.ProductName, D.DistrictName
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSPolicyRenewalPromptJournal]
	
	@RangeFrom date = NULL,
	@RangeTo date = NULL,
	@IntervalType as tinyint = 1 ,     -- 1 = Prompt Date in prompting table ; 2 = Expiry Date search in prompting table
	@OfficerID int = 0,
	@LocationId as int = 0,
	@VillageID as int = 0, 
	@WardID as int = 0 ,
	@SMSStatus as int = 0 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF @RangeFrom IS NULL 
		SET @RangeFrom = GetDate()
	IF @RangeTo  IS NULL 
		SET @RangeTo = GetDate()
	
	
	IF @IntervalType = 1 --Prompting date
	BEGIN 
		SELECT     tblPolicyRenewals.RenewalID,tblPolicyRenewals.RenewalPromptDate , tblPolicyRenewals.RenewalDate, tblPolicyRenewals.PhoneNumber, tblDistricts.DistrictName, tblVillages.VillageName, 
							  tblWards.WardName, tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames, tblProduct.ProductCode, tblProduct.ProductName, 
							  tblPolicyRenewals.RenewalWarnings, tblInsuree_1.CHFID AS PhotoCHFID, tblInsuree_1.LastName AS PhotoLastName, tblInsuree_1.OtherNames AS PhotoOtherNames, tblPolicyRenewals.SMSStatus 
							  
		FROM         tblInsuree AS tblInsuree_1 RIGHT OUTER JOIN
							  tblPolicyRenewalDetails ON tblInsuree_1.InsureeID = tblPolicyRenewalDetails.InsureeID RIGHT OUTER JOIN
							  tblPolicyRenewals INNER JOIN
							  tblInsuree ON tblPolicyRenewals.InsureeID = tblInsuree.InsureeID INNER JOIN
							  tblPolicy ON tblPolicyRenewals.PolicyID = tblPolicy.PolicyID INNER JOIN
							  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID INNER JOIN
							  tblVillages ON tblFamilies.LocationId = tblVillages.VillageID INNER JOIN
							  tblWards ON tblVillages.WardID = tblWards.WardID INNER JOIN
							  tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID INNER JOIN
							  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID ON tblPolicyRenewalDetails.RenewalID = tblPolicyRenewals.RenewalID
		WHERE     (tblPolicyRenewals.RenewalPromptDate BETWEEN @RangeFrom AND @RangeTo) 
				AND CASE @LocationId WHEN 0 THEN 0 ELSE tblDistricts.DistrictID  END = @LocationId
				AND CASE @WardID WHEN 0 THEN 0 ELSE tblWards.WardID  END = @WardID
				AND CASE @VillageID WHEN 0 THEN 0 ELSE tblVillages.VillageID  END = @VillageID
				AND CASE @OfficerID WHEN 0 THEN 0 ELSE tblPolicy.OfficerID   END = @OfficerID
				AND CASE @SMSStatus WHEN 0 THEN 0 ELSE tblPolicyRenewals.SMSStatus END = @SMSStatus
				
	END
	IF @IntervalType = 2 --Expiry/Renewal date
	BEGIN 
		SELECT     tblPolicyRenewals.RenewalID,tblPolicyRenewals.RenewalPromptDate , tblPolicyRenewals.RenewalDate, tblPolicyRenewals.PhoneNumber, tblDistricts.DistrictName, tblVillages.VillageName, 
							  tblWards.WardName, tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames, tblProduct.ProductCode, tblProduct.ProductName, 
							  tblPolicyRenewals.RenewalWarnings, tblInsuree_1.CHFID AS PhotoCHFID, tblInsuree_1.LastName AS PhotoLastName, tblInsuree_1.OtherNames AS PhotoOtherNames, tblPolicyRenewals.SMSStatus 
							  
		FROM         tblInsuree AS tblInsuree_1 RIGHT OUTER JOIN
							  tblPolicyRenewalDetails ON tblInsuree_1.InsureeID = tblPolicyRenewalDetails.InsureeID RIGHT OUTER JOIN
							  tblPolicyRenewals INNER JOIN
							  tblInsuree ON tblPolicyRenewals.InsureeID = tblInsuree.InsureeID INNER JOIN
							  tblPolicy ON tblPolicyRenewals.PolicyID = tblPolicy.PolicyID INNER JOIN
							  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID INNER JOIN
							  tblVillages ON tblFamilies.LocationId = tblVillages.VillageID INNER JOIN
							  tblWards ON tblVillages.WardID = tblWards.WardID INNER JOIN
							  tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID INNER JOIN
							  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID ON tblPolicyRenewalDetails.RenewalID = tblPolicyRenewals.RenewalID
		WHERE     (tblPolicyRenewals.RenewalDate  BETWEEN @RangeFrom AND @RangeTo) 
				AND tblPolicyRenewals.ResponseStatus = 0
				AND CASE @LocationId WHEN 0 THEN 0 ELSE tblDistricts.DistrictID  END = @LocationId
				AND CASE @WardID WHEN 0 THEN 0 ELSE tblWards.WardID  END = @WardID
				AND CASE @VillageID WHEN 0 THEN 0 ELSE tblVillages.VillageID  END = @VillageID
				AND CASE @OfficerID WHEN 0 THEN 0 ELSE tblPolicy.OfficerID   END = @OfficerID
				AND CASE @SMSStatus WHEN 0 THEN 0 ELSE tblPolicyRenewals.SMSStatus END = @SMSStatus

	END
	
											  
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspSSRSPolicyStatus]
	@RangeFrom datetime, --= getdate ,
	@RangeTo datetime, --= getdate ,
	@OfficerID int = 0,
	@RegionId INT = 0,
	@DistrictID as int = 0,
	@VillageID as int = 0, 
	@WardID as int = 0 ,
	@PolicyStatus as int = 0 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	DECLARE @RenewalID int
	DECLARE @PolicyID as int 
	DECLARE @FamilyID as int 
	DECLARE @RenewalDate as date
	DECLARE @InsureeID as int
	DECLARE @ProductID as int 
	DECLARE @ProductCode as nvarchar(8)
	DECLARE @ProductName as nvarchar(100)
	DECLARE @ProductFromDate as date 
	DECLARE @ProductToDate as date
	DECLARE @DistrictName as nvarchar(50)
	DECLARE @VillageName as nvarchar(50) 
	DECLARE @WardName as nvarchar(50)  
	DECLARE @CHFID as nvarchar(12)
	DECLARE @InsLastName as nvarchar(100)
	DECLARE @InsOtherNames as nvarchar(100)
	DECLARE @InsDOB as date
	DECLARE @ConvProdID as int    
	DECLARE @OffCode as nvarchar(15)
	DECLARE @OffLastName as nvarchar(50)
	DECLARE @OffOtherNames as nvarchar(50)
	DECLARE @OffPhone as nvarchar(50)
	DECLARE @OffSubstID as int 
	DECLARE @OffWorkTo as date 
	DECLARE @PolicyValue DECIMAL(18,4) = 0
	DECLARE @OfficerId1 INT


	DECLARE @SMSStatus as tinyint 
	DECLARE @iCount as int 


	DECLARE @tblResult TABLE(PolicyId INT, 
							FamilyId INT,
							RenewalDate DATE,
							PolicyValue DECIMAL(18,4),
							InsureeId INT,
							ProdId INT,
							ProductCode NVARCHAR(8),
							ProductName NVARCHAR(100),
							DateFrom DATE,
							DateTo DATE,
							DistrictName NVARCHAR(50),
							VillageName NVARCHAR(50),
							WardName NVARCHAR(50),
							CHFID NVARCHAR(12),
							LastName NVARCHAR(100),
							OtherNames NVARCHAR(100),
							DOB DATE,
							ConversionProdId INT,
							OfficerId INT,
							Code NVARCHAR(15),
							OffLastName NVARCHAR(50),
							OffOtherNames NVARCHAR(50),
							Phone NVARCHAR(50),
							OfficerIdSubst INT,
							WorksTo DATE)



	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR
	SELECT PL.PolicyID, PL.FamilyID, DATEADD(DAY, 1, PL.ExpiryDate) AS RenewalDate, 
			F.InsureeID, Prod.ProdID, Prod.ProductCode, Prod.ProductName,
			Prod.DateFrom, Prod.DateTo, D.DistrictName, V.VillageName, W.WardName, I.CHFID, I.LastName, I.OtherNames, I.DOB, Prod.ConversionProdID, 
			O.OfficerID, O.Code, O.LastName OffLastName, O.OtherNames OffOtherNames, O.Phone, O.OfficerIDSubst, O.WorksTo,
			PL.PolicyValue

			FROM tblPolicy PL INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
			INNER JOIN tblInsuree I ON F.InsureeId = I.InsureeID
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdID
			INNER JOIN tblVillages V ON V.VillageId = F.LocationId
			INNER JOIN tblWards W ON W.WardId = V.WardId
			INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
			INNER JOIN tblRegions R ON R.RegionId = D.Region
			INNER JOIN tblOfficer O ON PL.OfficerId = O.OfficerID
			AND PL.ExpiryDate BETWEEN @RangeFrom AND @RangeTo
			WHERE PL.ValidityTo IS NULL
			AND F.ValidityTo IS NULL
			AND R.ValidityTo IS NULL
			AND D.ValidityTo IS NULL
			AND V.ValidityTo IS NULL
			AND W.ValidityTo IS NULL
			AND I.ValidityTo IS NULL
			AND O.ValidityTo IS NULL

			AND PL.ExpiryDate BETWEEN @RangeFrom AND @RangeTo
			--AND (O.OfficerId = @OfficerId OR @OfficerId = 0)
			AND (R.RegionId = @RegionId OR @RegionId = 0)
			AND (D.DistrictID = @DistrictID OR @DistrictID = 0)
			AND (V.VillageId = @VillageId  OR @VillageId = 0)
			AND (W.WardId = @WardId OR @WardId = 0)
			AND (PL.PolicyStatus = @PolicyStatus OR @PolicyStatus = 0)
			AND (PL.PolicyStatus > 1)	--Do not renew Idle policies
		ORDER BY RenewalDate DESC  --Added by Rogers


		OPEN LOOP1
		FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
								  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID1, @OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo,
								  @PolicyValue
	
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			
			--GET ProductCode or the substitution
			IF ISNULL(@ConvProdID,0) > 0 
			BEGIN
				SET @iCount = 0 
				WHILE @ConvProdID <> 0 AND @iCount < 20   --this to prevent a recursive loop by wrong datra entries 
				BEGIN
					--get new product info 
					SET @ProductID = @ConvProdID
					SELECT @ConvProdID = ConversionProdID FROM tblProduct WHERE ProdID = @ProductID
					IF ISNULL(@ConvProdID,0) = 0 
					BEGIN
						SELECT @ProductCode = ProductCode from tblProduct WHERE ProdID = @ProductID
						SELECT @ProductName = ProductName  from tblProduct WHERE ProdID = @ProductID
						SELECT @ProductFromDate = DateFrom from tblProduct WHERE ProdID = @ProductID
						SELECT @ProductToDate = DateTo  from tblProduct WHERE ProdID = @ProductID
					
					
					END
					SET @iCount = @iCount + 1
				END
			END 
		
			IF ISNULL(@OfficerID1 ,0) > 0 
			BEGIN
				--GET OfficerCode or the substitution
				IF ISNULL(@OffSubstID,0) > 0 
				BEGIN
					SET @iCount = 0 
					WHILE @OffSubstID <> 0 AND @iCount < 20 AND @OffWorkTo < @RenewalDate  --this to prevent a recursive loop by wrong datra entries 
					BEGIN
						--get new product info 
						SET @OfficerID1 = @OffSubstID
						SELECT @OffSubstID = OfficerIDSubst FROM tblOfficer  WHERE OfficerID  = @OfficerID1
						IF ISNULL(@OffSubstID,0) = 0 
						BEGIN
							SELECT @OffCode = Code from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffLastName = LastName  from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffOtherNames = OtherNames  from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffPhone = Phone  from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffWorkTo = WorksTo  from tblOfficer  WHERE OfficerID  = @OfficerID1
						
						
							
						END
						SET @iCount = @iCount + 1
					END
				END 
			END
		

			--Code added by Hiren to check if the policy has another following policy
			IF EXISTS(SELECT 1 FROM tblPolicy 
								WHERE FamilyId = @FamilyId 
								AND (ProdId = @ProductID OR ProdId = @ConvProdID) 
								AND StartDate >= @RenewalDate
								AND ValidityTo IS NULL
								)
					GOTO NextPolicy;
		--Added by Rogers to check if the policy is alread in a family
		IF EXISTS(SELECT 1 FROM @tblResult WHERE FamilyId = @FamilyID AND ProdId = @ProductID OR ProdId = @ConvProdID)
		GOTO NextPolicy;

		
		EXEC @PolicyValue = uspPolicyValue
							@FamilyId = @FamilyID,
							@ProdId = @ProductID,
							@EnrollDate = @RenewalDate,
							@PreviousPolicyId = @PolicyID,
							@PolicyStage = 'R';


		
		INSERT INTO @tblResult(PolicyId, FamilyId, RenewalDate, Policyvalue, InsureeId, ProdId,
		ProductCode, ProductName, DateFrom, DateTo, DistrictName, VillageName,
		WardName, CHFID, LastName, OtherNames, DOB, ConversionProdId,OfficerId,
		Code, OffLastName, OffOtherNames, Phone, OfficerIdSubst, WorksTo)
		SELECT @PolicyID PolicyId, @FamilyId FamilyId, @RenewalDate RenewalDate, @PolicyValue PolicyValue, @InsureeID InsureeId, @ProductID ProdId,
		@ProductCode ProductCode, @ProductName ProductName, @ProductFromDate DateFrom, @ProductToDate DateTo, @DistrictName DistrictName, @VillageName VillageName,
		@WardName WardName, @CHFID CHFID, @InsLastName LastName, @InsOtherNames OtherNames, @InsDOB DOB, @ConvProdID ConversionProdId, @OfficerID1 OfficerId,
		@OffCode Code, @OffLastName OffLastName, @OffOtherNames OffOtherNames, @OffPhone Phone, @OffSubstID OfficerIdSubst, @OffWorkTo WorksTo
	

           
	NextPolicy:
			FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
								  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID1,@OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo,
								  @PolicyValue
	
		END
		CLOSE LOOP1
		DEALLOCATE LOOP1

		SELECT PolicyId, FamilyId, RenewalDate, PolicyValue, InsureeId, ProdId, ProductCode, ProductName, DateFrom, DateTo, DistrictName,
		VillageName, WardName, CHFID, LastName, OtherNames, DOB, ConversionProdId, OfficerId, Code, OffLastName, OffOtherNames, Phone, OfficerIdSubst, WorksTo
		FROM @tblResult
		WHERE (OfficerId = @OfficerId OR @OfficerId = 0);


END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspSSRSPremiumCollection]
	(
		@LocationId INT = 0,
		@Product INT = 0,
		@PaymentType VARCHAR(2) = '',
		@FromDate DATE,
		@ToDate DATE,
		@dtPaymentType xCareType READONLY
	)
	AS
	BEGIN
			IF @LocationId=-1
	            SET @LocationId = 0
	        SELECT LF.RegionName, LF.DistrictName
	        ,Prod.ProductCode,Prod.ProductName,SUM(Pr.Amount) Amount, 
	        PT.Name PayType,Pr.PayDate,Prod.AccCodePremiums 

	        FROM tblPremium PR 
	        INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
	        INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	        INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyID
	        INNER JOIN uvwLocations LF ON LF.VillageId = F.LocationId
	        INNER JOIN @dtPaymentType PT ON PT.Code = PR.PayType

	        WHERE Prod.ValidityTo IS NULL 
	        AND PR.ValidityTo IS NULL 
	        AND F.ValidityTo  IS NULL
	
	        AND (Prod.ProdId = @Product OR @Product = 0)
	        AND (Pr.PayType = @PaymentType OR @PaymentType = '')
	        AND Pr.PayDate BETWEEN @FromDate AND @ToDate
	        AND (LF.RegionId = @LocationId OR LF.DistrictId = @LocationId OR    @LocationId =0 ) --OR ISNULL(Prod.LocationId, 0) = ISNULL(@LocationId, 0) BY Rogers
	
	        GROUP BY LF.RegionName, LF.DistrictName, Prod.ProductCode,Prod.ProductName,Pr.PayDate,Pr.PayType,Prod.AccCodePremiums, PT.Name
	END
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSPrimaryIndicators1] 
	(
		@LocationId INT = 0,
		@ProductID INT = 0,
		@MonthFrom INT,
		@MonthTo INT = 0,
		@Year INT,
		@Mode INT = 1
	)
	AS
	BEGIN
DECLARE @LastDay DATE
	
	    IF @LocationId=-1
	    	SET @LocationId=NULL
	    IF NOT OBJECT_ID('tempdb..#tmpResult') IS NULL DROP TABLE #tmpResult
	
	    CREATE TABLE #tmpResult(
		    [Quarter] INT,
		    NameOfTheMonth VARCHAR(15),
		    OfficerCode VARCHAR(8),
		    LastName NVARCHAR(50),
		    OtherNames NVARCHAR(50),
		    ProductCode NVARCHAR(8),
		    ProductName NVARCHAR(100),
		    NoOfPolicyMale INT,
		    NoOfPolicyFemale INT,
		    NoOfPolicyOther INT, -- bY Ruzo
		    NoOfNewPolicyMale INT,
		    NoOfNewPolicyFemale INT,
		    NoOfNewPolicyOther INT, -- bY Ruzo
		    NoOfSuspendedPolicy INT,
		    NoOfExpiredPolicy INT,
		    NoOfRenewPolicy INT,
		    NoOfInsureeMale INT,
		    NoOfInsureeFemale INT,
		    NoOfInsureeOther INT, -- bY Ruzo
		    NoOfNewInsureeMale INT,
		    NoOfNewInsureeFemale INT,
		    NoOfNewInsureeOther INT, -- bY Ruzo
		    PremiumCollected DECIMAL(18,2),
		    PremiumAvailable DECIMAL(18,2),
		    MonthId INT,
		    OfficerStatus CHAR(1)
	    )	
	
		DECLARE @Counter INT = 1
		DECLARE @MaxCount INT = 12

		IF @MonthFrom > 0
			BEGIN
				SET @Counter = @MonthFrom
				SET @MaxCount = @MonthTo
			END
		
		WHILE @Counter <> @MaxCount + 1
		BEGIN
		
			SET @LastDay = DATEADD(DAY,-1,DATEADD(MONTH,1,CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-01'))
			IF @Mode = 1
				INSERT INTO #tmpResult
				SELECT DATEPART(QQ,@LastDay) [Quarter],
				CAST(YEAR(@LastDay) AS VARCHAR(4)) + ' ' + DATENAME(MONTH,@LastDay)NameOfTheMonth,NULL,NULL,NULL,MainInfo.ProductCode,MainInfo.ProductName,
				TP.Male AS NoOfPolicyMale,
				TP.Female AS NoOfPolicyFemale,
				TP.Other AS NoOfPolicyOther,
				NP.Male AS NoOfNewPolicyMale,
				NP.Female AS NoOfNewPolicyFemale,
				NP.Other AS NoOfNewPolicyOther,
				SP.SuspendedPolicies NoOfSuspendedPolicy,
				EP.ExpiredPolicies NoOfExpiredPolicy,
				PR.Renewals NoOfRenewPolicy,
				PIn.Male NoOfInsureeMale,Pin.Female NoOfInsureeFemale, PIn.Other NoOfInsureeOther,
				NPI.Male NoOfNewInsureeMale, NPI.Female NoOfNewInsureeFemale, NPI.Other NoOfNewInsureeOther,
				NPC.PremiumCollection PremiumCollected,
				AP.Allocated PremiumAvailable,
				@Counter MonthId,
				NULL OfficerStatus

				FROM 
				(SELECT PR.ProdID,PR.ProductCode,PR.ProductName
				FROM tblProduct PR 
				--INNER JOIN uvwLocations L ON L.LocationId = ISNULL(PR.LocationId, 0) OR L.RegionId = PR.LocationId OR L.DistrictId= PR.LocationId
				WHERE PR.ValidityTo IS NULL
				--AND (PR.LocationId = @LocationId OR @LocationId = 0 OR PR.LocationId IS NULL)
				AND (PR.ProdID = @ProductID OR @ProductID = 0)
				--AND (L.LocationId = ISNULL(@LocationId, 0) OR ISNULL(@LocationId, 0) = 0)
				)MainInfo LEFT OUTER JOIN
				dbo.udfTotalPolicies(@ProductID,@LocationId,@LastDay,@Mode) TP ON MainInfo.ProdID = TP.ProdID LEFT OUTER JOIN
				dbo.udfNewPolicies(@ProductID,@LocationId,@Counter,@Year,@Mode) NP ON MainInfo.ProdID = NP.ProdID LEFT OUTER JOIN
				dbo.udfSuspendedPolicies(@ProductID,@LocationId,@Counter,@Year,@Mode)SP ON MainInfo.ProdID = SP.ProdID LEFT OUTER JOIN
				dbo.udfExpiredPolicies(@ProductID,@LocationId,@Counter,@Year,@Mode)EP ON MainInfo.ProdID = EP.ProdID LEFT OUTER JOIN
				dbo.udfPolicyRenewal(@ProductID,@LocationId,@Counter,@Year,@Mode) PR ON MainInfo.ProdID = PR.ProdID LEFT OUTER JOIN
				dbo.udfPolicyInsuree(@ProductID,@LocationId,@lastDay,@Mode)PIn ON MainInfo.ProdID = PIn.ProdID LEFT OUTER JOIN
				dbo.udfNewPolicyInsuree(@ProductID,@LocationId,@Counter,@Year,@Mode)NPI ON MainInfo.ProdID = NPI.ProdID LEFT OUTER JOIN
				dbo.udfNewlyPremiumCollected(@ProductID,@LocationId,@Counter,@Year,@Mode)NPC ON MainInfo.ProdID = NPC.ProdID  LEFT OUTER JOIN
				dbo.udfAvailablePremium(@ProductID,@LocationId,@Counter,@Year,@Mode)AP ON MainInfo.ProdID = AP.ProdID 
			ELSE
				INSERT INTO #tmpResult
		
				SELECT DATEPART(QQ,@LastDay) [Quarter],
				CAST(YEAR(@LastDay) AS VARCHAR(4)) + ' ' + DATENAME(MONTH,@LastDay)NameOfTheMonth,MainInfo.Code,MainInfo.LastName,MainInfo.OtherNames,MainInfo.ProductCode,MainInfo.ProductName,
				TP.Male AS NoOfPolicyMale,
				TP.Female AS NoOfPolicyFemale,
				TP.Other AS NoOfPolicyOther,
				NP.Male AS NoOfNewPolicyMale,
				NP.Female AS NoOfNewPolicyFemale,
				NP.Other AS NoOfNewPolicyOther,
				SP.SuspendedPolicies NoOfSuspendedPolicy,
				EP.ExpiredPolicies NoOfExpiredPolicy,
				PR.Renewals NoOfRenewPolicy,
				PIn.Male NoOfInsureeMale,Pin.Female NoOfInsureeFemale, PIn.Other NoOfInsureeOther,
				NPI.Male NoOfNewInsureeMale, NPI.Female NoOfNewInsureeFemale, NPI.Other NoOfNewInsureeOther,
				NPC.PremiumCollection PremiumCollected,
				AP.Allocated PremiumAvailable,
				@Counter MonthId,
				IIF(ISNULL(CAST(WorksTo AS DATE) , DATEADD(DAY, 1, GETDATE())) <= CAST(GETDATE() AS DATE), 'N', 'A')OfficerStatus

				FROM 
				(SELECT PR.ProdID,PR.ProductCode,PR.ProductName, o.code,O.LastName,O.OtherNames, O.WorksTo
				FROM tblProduct PR 
				INNER JOIN tblPolicy PL ON PR.ProdID = PL.ProdID
				INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
				INNER JOIN tblVillages V ON V.VillageId = F.LocationId
				INNER JOIN tblWards W ON W.WardId = V.WardId
				INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
				INNER JOIN (select OfficerID,code,LastName,OtherNames,LocationId,ValidityTo, WorksTo from tblOfficer) O on PL.OfficerID = O.OfficerID
				WHERE pr.ValidityTo is null and o.ValidityTo is null
				--AND (PR.LocationId = @LocationId OR @LocationId = 0 OR PR.LocationId IS NULL)
				--AND (D.DistrictID = @LocationId OR @LocationId IS NULL)
				AND (PR.ProdID = @ProductID OR @ProductID = 0)
				AND PL.ValidityTo IS NULL --AND F.ValidityTo IS NULL
				AND V.ValidityTO IS NULL
				AND W.ValidityTo IS NULL
				AND D.ValidityTo IS NULL
				AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
				)MainInfo LEFT OUTER JOIN
				dbo.udfTotalPolicies(@ProductID,@LocationId,@LastDay,@Mode) TP ON MainInfo.ProdID = TP.ProdID and (maininfo.Code = tp.Officer OR maininfo.Code = ISNULL(TP.Officer,0))  LEFT OUTER JOIN
				dbo.udfNewPolicies(@ProductID,@LocationId,@Counter,@Year,@Mode) NP ON MainInfo.ProdID = NP.ProdID  and (maininfo.Code = np.Officer OR maininfo.Code = ISNULL(NP.Officer,0)) LEFT OUTER JOIN
				dbo.udfSuspendedPolicies(@ProductID,@LocationId,@Counter,@Year,@Mode)SP ON MainInfo.ProdID = SP.ProdID  and (maininfo.Code = sp.Officer OR maininfo.Code = ISNULL(SP.Officer,0))LEFT OUTER JOIN
				dbo.udfExpiredPolicies(@ProductID,@LocationId,@Counter,@Year,@Mode)EP ON MainInfo.ProdID = EP.ProdID and (maininfo.Code = ep.Officer OR maininfo.Code = ISNULL(EP.Officer,0)) LEFT OUTER JOIN
				dbo.udfPolicyRenewal(@ProductID,@LocationId,@Counter,@Year,@Mode) PR ON MainInfo.ProdID = PR.ProdID and (maininfo.Code = pr.Officer OR maininfo.Code = ISNULL(PR.Officer,0)) LEFT OUTER JOIN
				dbo.udfPolicyInsuree(@ProductID,@LocationId,@lastDay,@Mode)PIn ON MainInfo.ProdID = PIn.ProdID and (maininfo.Code = pin.Officer OR maininfo.Code = ISNULL(PIn.Officer,0)) LEFT OUTER JOIN
				dbo.udfNewPolicyInsuree(@ProductID,@LocationId,@Counter,@Year,@Mode)NPI ON MainInfo.ProdID = NPI.ProdID and (maininfo.Code = npi.Officer OR maininfo.Code = ISNULL(NPI.Officer,0))LEFT OUTER JOIN
				dbo.udfNewlyPremiumCollected(@ProductID,@LocationId,@Counter,@Year,@Mode)NPC ON MainInfo.ProdID = NPC.ProdID and (maininfo.Code = npc.Officer OR maininfo.Code = ISNULL(NPC.Officer,0)) LEFT OUTER JOIN
				dbo.udfAvailablePremium(@ProductID,@LocationId,@Counter,@Year,@Mode)AP ON MainInfo.ProdID = AP.ProdID and (maininfo.Code = ap.Officer OR maininfo.Code = ISNULL(AP.Officer,0))

			SET @Counter = @Counter + 1

		END

	    SELECT * FROM #tmpResult
	    GROUP BY [Quarter], NameOfTheMonth, OfficerCode, LastName, OtherNames,ProductCode, ProductName, NoOfPolicyMale, NoOfPolicyFemale,NoOfPolicyOther, NoOfNewPolicyMale,
	    NoOfNewPolicyFemale,NoOfNewPolicyOther, NoOfSuspendedPolicy, NoOfExpiredPolicy, NoOfRenewPolicy, NoOfInsureeMale, NoOfInsureeFemale,NoOfInsureeOther, NoOfNewInsureeMale,
	    NoOfNewInsureeFemale,NoOfNewInsureeOther, PremiumCollected, PremiumAvailable, MonthId, OfficerStatus
      	ORDER BY MonthId

	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspSSRSPrimaryIndicators2]
	(
		@LocationId INT = 0,
		@ProductID INT = 0,
		@HFID INT = 0,
		@MonthFrom INT,
		@MonthTo INT,
		@Year INT
	)
	AS
	BEGIN
		IF NOT OBJECT_ID('tempdb..#tmpResult') IS NULL DROP TABLE #tmpResult
		CREATE TABLE #tmpResult(
			NameOfTheMonth VARCHAR(20),
			DistrictName NVARCHAR(50),
			HFCode NVARCHAR(8),
			HFName NVARCHAR(100),
			ProductCode NVARCHAR(8), 
			ProductName NVARCHAR(100), 
			TotalClaims INT,
			Remunerated DECIMAL(18,2),
			RejectedClaims INT,
			MonthNo INT
		)

        DECLARE @Counter INT = 1
        DECLARE @MaxCount INT = 12

        IF @MonthFrom > 0
	        BEGIN
		        SET @Counter = @MonthFrom
		        SET @MaxCount = @MonthTo
	        END
	
        IF @LocationId = -1
        SET @LocationId = NULL
        WHILE @Counter <> @MaxCount + 1
        BEGIN
		        DECLARE @LastDay DATE = DATEADD(DAY,-1,DATEADD(MONTH,1,CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-01'))
			
		        INSERT INTO #tmpResult
		        SELECT CAST(YEAR(@LastDay) AS VARCHAR(4)) + ' ' + DATENAME(MONTH,@LastDay),MainInfo.DistrictName,
		        MainInfo.HFCode,MainInfo.HFName ,MainInfo.ProductCode , MainInfo.ProductName , 
		        TC.TotalClaims TotalClaims,
		        R.Remunerated Remunerated,
		        RC.RejectedClaims RejectedClaims,
		        DATEPART(MM,@LastDay) MonthNo --Added by Rogers On 19092017
	        FROM
	        (SELECT  DistrictName DistrictName,HF.HFID,HF.HFCode,HF.HFName,Prod.ProdID,Prod.ProductCode,Prod.ProductName
	        FROM tblClaim C 
	        INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID
	        INNER JOIN tblHF HF ON C.HFID = HF.HFID 
	        INNER JOIN tblDistricts D ON D.DistrictId = HF.LocationId
	        LEFT JOIN tblLocations L ON HF.LocationId = L.LocationId
	        LEFT OUTER JOIN 
	        (SELECT ClaimId,ProdId FROM tblClaimItems WHERE ValidityTo IS NULL
	        UNION 
	        SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL
	        )CProd ON CProd.ClaimId = C.ClaimID
	        LEFT OUTER JOIN tblProduct Prod ON Prod.ProdId = CProd.ProdID
	        WHERE C.ValidityTo IS NULL 
	        AND I.ValidityTo IS NULL 
	        AND D.ValidityTo IS NULL 
	        AND HF.ValidityTo IS NULL 
	        AND Prod.ValidityTo IS NULL
	        AND  (HF.LocationId  = @LocationId OR L.ParentLocationId = @LocationId) --Changed From LocationId to HFLocationId	On 29062017
	        AND (Prod.ProdID = @ProductId OR @ProductId = 0)
	        AND (HF.HfID = @HFID OR @HFID = 0)
	        GROUP BY DistrictName,HF.HFID,HF.HFCode,HF.HFName,Prod.ProdID,Prod.ProductCode,Prod.ProductName
	        ) MainInfo 
	        LEFT OUTER JOIN dbo.udfTotalClaims(@ProductID,@HFID,@LocationId,@Counter,@Year) TC ON ISNULL(MainInfo.ProdID, 0) = ISNULL(TC.ProdID, 0) AND MainInfo.HfID = TC.HFID 
	        LEFT OUTER JOIN dbo.udfRemunerated(@HFID,@ProductID,@LocationId,@Counter,@Year) R ON ISNULL(MainInfo.ProdID, 0) = ISNULL(R.ProdID, 0) AND MainInfo.HfID = R.HFID 
	        LEFT OUTER JOIN dbo.udfRejectedClaims(@ProductID,@HFID,@LocationId,@Counter,@Year) RC ON ISNULL(MainInfo.ProdID, 0) = ISNULL(RC.ProdID, 0) AND MainInfo.HfID = RC.HFID

	        SET @Counter = @Counter + 1
	
        END
	
		SELECT NameOfTheMonth,MonthNo,DistrictName,HFCode ,HFName,ProductCode,ProductName ,ISNULL(TotalClaims,0) TotalClaims ,ISNULL(Remunerated,0) Remunerated ,ISNULL(RejectedClaims,0) RejectedClaims FROM #tmpResult
		ORDER BY MonthNo
	END
GO



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSProductSales]
	(
		@LocationId INT = 0,
		@Product INT = 0,
		@FromDate DATE,
		@ToDate DATE
	)
	AS
	BEGIN
		IF @LocationId = -1
		    SET @LocationId=NULL
		SELECT L.DistrictName,Prod.ProductCode,Prod.ProductName,PL.EffectiveDate, SUM(PL.PolicyValue) PolicyValue
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
		INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
		INNER JOIN uvwLocations L ON L.VillageId = F.LocationId
		WHERE PL.ValidityTo IS NULL 
		AND Prod.ValidityTo IS NULL 
		AND F.validityTo IS NULL
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND (Prod.ProdID = @Product OR @Product = 0)
		AND PL.EffectiveDate BETWEEN @FromDate AND @ToDate
		GROUP BY L.DistrictName,Prod.ProductCode,Prod.ProductName,PL.EffectiveDate
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSStatusRegister]
	(
		@LocationId INT = 0
	)
	AS
	BEGIN
		SET ARITHABORT OFF;

	    IF @LocationId = -1
		    SET @LocationId = NULL;

	    DECLARE @tblResult TABLE(
		    LocationId INT,
		    ParentLocationId INT,
		    LocationType NVARCHAR(1),
		    LocationName NVARCHAR(100),
		    TotalActiveOfficers INT,
		    TotalNonActiveOfficers INT,
		    TotalUsers INT,
		    TotalProducts INT,
		    TotalHealthFacilities INT,
		    TotalItemPriceLists INT,
		    TotalServicePriceLists INT,
		    TotalItems INT,
		    TotalServices INT,
		    TotalPayers INT
	    );

	    ;WITH LocationsAll AS
		    (
		    SELECT -1 LocationId, N'National' LocationName, NULL ParentLocationId, NULL LocationType
		    UNION
		    SELECT LocationId,LocationName, ISNULL(ParentLocationId, -1)ParentLocationId, LocationType FROM tblLocations WHERE LocationType IN ('D', 'R') AND ValidityTo IS NULL AND (LocationId = @LocationId OR CASE WHEN @LocationId IS NULL THEN ISNULL(ParentLocationId, 0) ELSE 0 END = ISNULL(@LocationId, 0))
		    UNION ALL
		    SELECT L.LocationId, L.LocationName, L.ParentLocationId, L.LocationType
		    FROM tblLocations L 
		    INNER JOIN LocationsAll ON LocationsAll.LocationId = L.ParentLocationId
		    WHERE L.ValidityTo IS NULL
		    AND L.LocationType = N'D'
		    ),Locations AS(
			    SELECT Locationid, LocationName, ParentLocationId, LocationType
			    FROM LocationsAll
			    GROUP BY LocationID, LocationName, ParentLocationId, LocationType
		    )


		    INSERT INTO @tblResult(LocationId, ParentLocationId, LocationType, LocationName, TotalActiveOfficers, TotalNonActiveOfficers, TotalUsers, TotalProducts, TotalHealthFacilities, TotalItemPriceLists, TotalServicePriceLists, TotalItems, TotalServices, TotalPayers)
	
		    SELECT Locations.LocationId, NULLIF(Locations.ParentLocationId, -1)ParentLocationId, Locations.LocationType ,Locations.LocationName,ActiveOfficers.TotalEnrollmentOfficers TotalActiveOfficers
		    , NonActiveOfficers.TotalEnrollmentOfficers TotalNonActiveOfficers 
		    ,Users.TotalUsers,TotalProducts ,HF.TotalHealthFacilities ,PLItems.TotalItemPriceLists,PLServices.TotalServicePriceLists ,
		    PLItemDetails.TotalItems,PLServiceDetails.TotalServices,Payers.TotalPayers
		    FROM
		    (SELECT COUNT(O.OfficerId)TotalEnrollmentOfficers,ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L
		    LEFT OUTER JOIN tblOfficer O ON ISNULL(O.LocationId, -1) = L.LocationId AND O.ValidityTo IS NULL
		    WHERE ISNULL(CAST(WorksTo AS DATE) , DATEADD(DAY, 1, GETDATE())) > CAST(GETDATE() AS DATE) 
		    GROUP BY L.LocationId) ActiveOfficers INNER JOIN Locations ON Locations.LocationId = ActiveOfficers.LocationId 

		    LEFT OUTER JOIN
		    (SELECT COUNT(O.OfficerId)TotalEnrollmentOfficers,ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L
		    LEFT OUTER JOIN tblOfficer O ON ISNULL(O.LocationId, -1) = L.LocationId AND O.ValidityTo IS NULL
		    WHERE CAST(WorksTo AS DATE) <= CAST(GETDATE() AS DATE) 
		    GROUP BY L.LocationId
		    ) NonActiveOfficers ON Locations.LocationId = NonActiveOfficers.LocationId

		    LEFT OUTER JOIN
		    (SELECT COUNT(U.UserID) TotalUsers,ISNULL(L.LocationId, -1)LocationId 
		    FROM tblUsers U 
		    INNER JOIN tblUsersDistricts UD ON U.UserID = UD.UserID AND U.ValidityTo IS NULL AND UD.ValidityTo IS NULL
		    RIGHT OUTER JOIN Locations L ON L.LocationId = UD.LocationId
		    GROUP BY L.LocationId)Users ON Locations.LocationId = Users.LocationId

		    LEFT OUTER JOIN 
		    (SELECT COUNT(Prod.ProdId)TotalProducts, ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L
		    LEFT OUTER JOIN tblProduct Prod ON ISNULL(Prod.Locationid, -1) = L.LocationId AND Prod.ValidityTo IS NULL 
		    GROUP BY L.LocationId) Products ON Locations.LocationId = Products.LocationId

		    LEFT OUTER JOIN 
		    (SELECT COUNT(HF.HfID)TotalHealthFacilities, ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L
		    LEFT OUTER JOIN tblHF HF ON ISNULL(HF.LocationId, -1) = L.LocationId AND HF.ValidityTo IS NULL
		    GROUP BY L.LocationId) HF ON Locations.LocationId = HF.LocationId

		    LEFT OUTER JOIN 
		    (SELECT COUNT(PLI.PLItemID) TotalItemPriceLists, ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L
		    LEFT OUTER JOIN tblPLItems PLI ON ISNULL(PLI.LocationId, -1) = L.LocationId AND PLI.ValidityTo IS NULL
		    GROUP BY L.LocationId) PLItems ON Locations.LocationId = PLItems.LocationId

		    LEFT OUTER JOIN
		    (SELECT COUNT(PLS.PLServiceID) TotalServicePriceLists,ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L
		    LEFT OUTER JOIN tblPLServices PLS ON ISNULL(PLS.LocationId, -1) = L.LocationId AND PLS.ValidityTo IS NULL 
		    GROUP BY L.LocationId) PLServices ON Locations.LocationId = PLServices.LocationId

		    LEFT OUTER JOIN
		    (SELECT COUNT(ItemId)TotalItems, LocationId
		    FROM (
			    SELECT I.ItemID, ISNULL(L.LocationId, -1)LocationId
			    FROM Locations L
			    LEFT OUTER JOIN tblPLItems PL ON ISNULL(PL.LocationId, -1) = L.LocationId AND PL.ValidityTo IS NULL
			    LEFT OUTER JOIN tblPLItemsDetail I ON I.PLItemID = PL.PLItemID
			    GROUP BY I.ItemId, L.LocationId
		    )x
		    GROUP BY LocationId)PLItemDetails ON Locations.LocationId = PLItemDetails.LocationId

		    LEFT OUTER JOIN
		    (SELECT COUNT(ServiceID)TotalServices, LocationId
		    FROM (
			    SELECT S.ServiceId, ISNULL(L.LocationId, -1)LocationId
			    FROM Locations L
			    LEFT OUTER JOIN tblPLServices PL ON ISNULL(PL.LocationId, -1) = L.LocationId AND PL.ValidityTo IS NULL
			    LEFT OUTER JOIN tblPLServicesDetail S ON S.PLServiceID = PL.PLServiceID 
			    GROUP BY S.ServiceID, L.LocationId
		    )x
		    GROUP BY LocationId)PLServiceDetails ON Locations.LocationId = PLServiceDetails.LocationId

		    LEFT OUTER JOIN
		    (SELECT COUNT(P.PayerId)TotalPayers,ISNULL(L.LocationId, -1)LocationId 
		    FROM Locations L 
		    LEFT OUTER JOIN tblPayer P ON ISNULL(P.LocationId, -1) = L.LocationId AND P.ValidityTo IS NULL 
		    GROUP BY L.LocationId)Payers ON Locations.LocationId = Payers.LocationId

	    IF @LocationId = 0
	    BEGIN
		    ;WITH Results AS
		    (
			    SELECT 0 [Level],LocationId, ParentLocationId, Locationname, LocationType,
			    TotalActiveOfficers, TotalNonActiveOfficers, TotalUsers, TotalProducts, TotalHealthFacilities, TotalItemPriceLists, TotalServicePriceLists, TotalItems, TotalServices, TotalPayers
			    FROM @tblResult 
			    UNION ALL
			    SELECT Results.[Level] + 1, R.LocationId, R.ParentLocationId, R.LocationName, R.LocationType,
			    Results.TotalActiveOfficers, Results.TotalNonActiveOfficers, Results.TotalUsers, Results.TotalProducts, Results.TotalHealthFacilities, Results.TotalItemPriceLists, Results.TotalServicePriceLists, Results.TotalItems, Results.TotalServices, Results.TotalPayers
			    FROM @tblResult R
			    INNER JOIN Results ON R.LocationId = Results.ParentLocationId
		    )
		    SELECT LocationId, LocationName
		    , NULLIF(SUM(TotalActiveOfficers), 0) TotalActiveOfficers
		    , NULLIF(SUM(TotalNonActiveOfficers), 0)TotalNonActiveOfficers
		    , NULLIF(SUM(TotalUsers), 0)TotalUsers
		    , NULLIF(SUM(TotalProducts), 0)TotalProducts
		    , NULLIF(SUM(TotalHealthFacilities), 0) TotalHealthFacilities
		    , NULLIF(SUM(TotalItemPriceLists) , 0)TotalItemPriceLists
		    , NULLIF(SUM(TotalServicePriceLists), 0) TotalServicePriceLists
		    , NULLIF(SUM(TotalItems), 0)TotalItems
		    , NULLIF(SUM(TotalServices), 0) TotalServices
		    , NULLIF(SUM(TotalPayers), 0)TotalPayers

		    FROM Results
		    WHERE LocationType = 'R' OR LocationType IS NULL
		    GROUP BY LocationId, LocationName
		    ORDER BY LocationId
	    END
	    ELSE
	    BEGIN
		    SELECT LocationId, LocationName, NULLIF(TotalActiveOfficers, 0)TotalActiveOfficers, NULLIF(TotalNonActiveOfficers, 0)TotalNonActiveOfficers, NULLIF(TotalUsers, 0)TotalUsers, NULLIF(TotalProducts, 0)TotalProducts, NULLIF(TotalHealthFacilities, 0)TotalHealthFacilities, NULLIF(TotalItemPriceLists, 0)TotalItemPriceLists, NULLIF(TotalServicePriceLists, 0)TotalServicePriceLists, NULLIF(TotalItems, 0)TotalItems, NULLIF(TotalServices, 0)TotalServices, NULLIF(TotalPayers, 0)TotalPayers  
		    FROM @tblResult
		    WHERE LocationId <> -1;
	    END
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSUserLogReport]
	(
		@UserId INT = NULL,
		@FromDate DATETIME,
		@ToDate DATETIME,
		@EntityId NVARCHAR(5) = N'',
		@Action NVARCHAR(20) = N''
	)
	AS
	BEGIN
		SET @UserId = NULLIF(@UserId, 0);

		SET @ToDate = DATEADD(SECOND,-1,DATEADD(DAY,1,@ToDate))

		DECLARE @tblLogs TABLE(UserId INT,UserName NVARCHAR(20),EntityId NVARCHAR(5),RecordType NVARCHAR(50),ActionType NVARCHAR(50),RecordIdentity NVARCHAR(500),ValidityFrom DATETIME,ValidityTo DATETIME, LegacyId INT, VF DATETIME,HistoryLegacyId INT)
		--DECLARE @UserId INT = 149
		
		--Line below is commented because UserId is made optional now
		DECLARE @UserName NVARCHAR(50) --= (SELECT LoginName FROM tblUsers WHERE (UserID = @UserId OR @Userid IS NULL))
		
		--DECLARE @FromDate DATETIME = '2013-04-29'
		--DECLARE @ToDate DATETIME = '2013-10-29'

		SET @ToDate = DATEADD(S,-1,DATEADD(D,1,@ToDate))

		INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
		--LOGIN INFORMATION
		SELECT L.UserId UserId,NULL UserName,CASE LogAction WHEN 1 THEN N'LI' ELSE N'LO' END,'Login' RecordType ,CASE LogAction WHEN 1 THEN N'Logged In' ELSE N'Logged Out' END ActionType,CAST(LogAction as NVARCHAR(10)) RecordIdentity,LogTime,NULL,NULL,NULL VF,NULL HistoryLegacyId
		FROM tblLogins L
		WHERE (L.UserId = @UserId OR @UserId IS NULL)
		AND LogTime BETWEEN @FromDate AND @ToDate

		--BATCH RUN INFORMATION
		--UNION ALL
		IF @EntityId = N'BR' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT B.AuditUserID UserId, NULL UserName, N'BR' EntityId,'Batch Run' RecordType,'Executed Batch' ActionType,
			'Batch Run For the District:' + D.DistrictName + ' For the month of ' + DATENAME(MONTH,'2000-' + CAST(B.RunMonth AS NVARCHAR(2)) + '-01') RecordIdentity,B.ValidityFrom,B.ValidityTo,B.LegacyID, NULL VF,NULL HistoryLegacyId
			FROM tblBatchRun B INNER JOIN tblDistricts D ON B.LocationId = D.DistrictID
			WHERE (B.AuditUserID = @UserId OR @UserId IS NULL)
			AND B.ValidityFrom BETWEEN @FromDate AND @ToDate

		--CLAIM INFORMATION
		--UNION ALL

		IF @EntityId = N'C' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT C.AuditUserID UserId, NULL UserName,N'C' EntityId, 'Claim' RecordType,
			NULL,'Claim Code: '+ ClaimCode + ' For Health Facility:' + HF.HFCode RecordIdentity,
			C.ValidityFrom,C.ValidityTo,C.LegacyID,VF,Hist.LegacyID
			FROM tblClaim C INNER JOIN tblHF HF ON C.HFID = HF.HfID
			LEFT OUTER JOIN
			(SELECT MIN(ValidityFrom) VF FROM tblClaim WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Ins ON Ins.VF = C.ValidityFrom
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblClaim WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON C.ClaimID = Hist.LegacyID
			WHERE (C.AuditUserID = @UserId OR @UserId IS NULL)
			AND C.ValidityFrom BETWEEN @FromDate AND @ToDate

		--CLAIM ADMINISTRATOR INFORMATION
		--UNION ALL
		IF @EntityId = N'CA' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT A.AuditUserID UserId, NULL UserName, N'CA' EntityId,'Claim Administrator' RecordType,NULL ActionType,
			'Name:' + A.OtherNames + ' ' + A.LastName + ' in the Health Facility:' + HF.HFName RecordIdentity, 
			A.ValidityFrom, A.ValidityTo,A.LegacyID,VF,Hist.LegacyId
			FROM tblClaimAdmin A INNER JOIN tblHF HF ON A.HFID = HF.HFID
			LEFT OUTER JOIN
			(SELECT MIN(ValidityFrom) VF FROM tblClaimAdmin WHERE LegacyId IS NOT NULL GROUP BY LegacyId) Ins ON Ins.VF = A.ValidityFrom
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblClaimAdmin WHERE LegacyId IS NOT NULL GROUP BY LegacyId) Hist ON A.ClaimAdminId = Hist.LegacyId
			WHERE (A.AuditUserID = @UserId AND @UserId IS NULL)
			AND A.ValidityFrom BETWEEN @FromDate AND @ToDate

		--DISTRICT INFORMATION
		--UNION ALL
		IF @EntityId = N'D' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT D.AuditUserID UserId, NULL UserName, N'D' EntityId,'District' RecordType,NULL ActionType,
			DistrictName RecordIdentity, D.ValidityFrom, D.ValidityTo,D.LegacyID, VF,Hist.LegacyID
			FROM tblDistricts D 
			LEFT OUTER JOIN
			(SELECT MIN(ValidityFrom) VF FROM tblDistricts WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Ins ON D.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyID FROM tblDistricts WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Hist ON D.DistrictID = Hist.LegacyID
			WHERE (D.AuditUserID = @UserId OR @UserId IS  NULL)
			AND D.ValidityFrom BETWEEN @FromDate AND @ToDate

		--EXTRACT INFORMATION
		--UNION ALL
		IF @EntityId  = N'E' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT E.AuditUserID UserId, NULL UserName, N'E' EntityId,'Extracts' RecordType,NULL ActionType,
			'For the District:' + D.DistrictName + ' File:' + E.ExtractFileName RecordIdentity, E.ValidityFrom, E.ValidityTo,E.LegacyID,VF,Hist.LegacyID
			FROM tblExtracts E INNER JOIN tblDistricts D ON E.LocationId = D.DistrictID
			LEFT OUTER JOIN
			(SELECT MIN(ValidityFrom) VF FROM tblExtracts WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Ins ON E.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblExtracts WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON E.ExtractID = Hist.LegacyID
			WHERE (E.AuditUserID = @UserId OR @UserId IS NULL)
			AND E.ValidityFrom BETWEEN @FromDate AND @ToDate

		--FAMILY INFORMATION
		--UNION ALL
		IF @EntityId = N'F' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT F.AuditUserID UserId, NULL UserName, N'F' EntityId,'Family/Group' RecordType,NULL ActionType,
			'Insurance No.:' + I.CHFID + ' In District:' + D.DistrictName  RecordIdentity, 
			F.ValidityFrom, F.ValidityTo,F.LegacyID,VF,Hist.LegacyID
			FROM tblFamilies F INNER JOIN tblDistricts D ON F.LocationId = D.DistrictID
			INNER JOIN tblInsuree I ON F.InsureeID = I.InsureeID
			LEFT OUTER JOIN(
			SELECT MIN(ValidityFrom) VF from tblFamilies WHERE LegacyID is not null group by LegacyID) Ins ON F.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblFamilies WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON F.FamilyID = Hist.LegacyID
			WHERE (F.AuditUserID = @UserId OR @UserId IS NULL)
			AND f.ValidityFrom BETWEEN @FromDate AND @ToDate

		--FEEDBACK INFORMATION
		--UNION ALL
		IF @EntityId = N'FB' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT F.AuditUserID UserId, NULL UserName, N'FB' EntityId,'Feedback' RecordType,NULL ActionType,
			'Feedback For the claim:' + C.ClaimCode  RecordIdentity, 
			F.ValidityFrom, F.ValidityTo,F.LegacyID,VF,Hist.LegacyID
			FROM tblFeedback F INNER JOIN tblClaim C ON F.ClaimID = C.ClaimID
			LEFT OUTER JOIN(
			SELECT MIN(ValidityFrom) VF FROM tblFeedback WHERE LegacyID is not null group by LegacyID) Ins On F.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblFeedback WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Hist ON F.FeedbackID = Hist.LegacyID
			WHERE (F.AuditUserID = @UserId OR @UserId IS NULL)
			AND F.ValidityFrom BETWEEN @FromDate AND @ToDate

		--HEALTH FACILITY INFORMATION
		--UNION ALL
		IF @EntityId = N'HF' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT HF.AuditUserID UserId, NULL UserName, N'HF' EntityId,'Health Facility' RecordType,NULL ActionType,
			'Code:' + HF.HFCode + ' Name:' + HF.HFName RecordIdentity, 
			HF.ValidityFrom, HF.ValidityTo,HF.LegacyID,VF,Hist.LegacyId
			FROM tblHF HF 
			LEFT OUTER JOIN(
			SELECT MIN(ValidityFrom) VF FROM tblHF WHERE LegacyID is not null group by LegacyID) Ins ON HF.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblHF WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Hist ON HF.HfID = Hist.LegacyID
			WHERE (HF.AuditUserID = @UserId OR @UserId IS NULL)
			AND HF.ValidityFrom BETWEEN @FromDate AND @ToDate

		--ICD CODE INFORMATION
		--UNION ALL
		IF @EntityId = N'ICD' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT ICD.AuditUserID UserId, NULL UserName, N'ICD' EntityId,'Main Dg.' RecordType,NULL ActionType,
			'Code:' + ICD.ICDCode + ' Name:' + ICD.ICDName RecordIdentity,
			ICD.ValidityFrom, ICD.ValidityTo,ICD.LegacyID,VF, Hist.LegacyId
			FROM tblICDCodes ICD 
			LEFT OUTER JOIN(
			SELECT MIN(ValidityFrom) VF FROM tblICDCodes WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Ins ON ICD.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblICDCodes WHERE LegacyID IS NOT NULL GROUP BY LegacyId)Hist ON ICD.ICDID = Hist.LegacyId
			WHERE (ICD.AuditUserID = @UserId OR @UserId IS NULL)
			AND ICD.ValidityFrom BETWEEN @FromDate AND @ToDate

		--INSUREE INFORMATION
		--UNION ALL
		IF @EntityId = N'Ins' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT I.AuditUserID UserId, @UserName UserName, N'Ins' EntityId,'Insuree' RecordType,NULL ActionType,
			'Insurance No.:' + I.CHFID RecordIdentity, 
			I.ValidityFrom, I.ValidityTo,I.LegacyID,vf,Hist.LegacyID
			FROM tblInsuree I
			LEFT OUTER JOIN(
			SELECT MIN(validityfrom) vf from tblInsuree where LegacyID is not null group by LegacyID) Ins ON I.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblInsuree WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON I.InsureeID = Hist.LegacyID
			WHERE (I.AuditUserID = @UserId OR @UserId IS NULL)
			AND I.ValidityFrom BETWEEN @FromDate AND @ToDate

		--MEDICAL ITEM INFORMATION
		--UNION ALL
		IF @EntityId = N'I' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT I.AuditUserID UserId, @UserName UserName, N'I' EntityId,'Medical Items' RecordType,NULL ActionType,
			'Code:' + I.ItemCode + ' Name:' + I.ItemName RecordIdentity, 
			I.ValidityFrom, I.ValidityTo,I.LegacyID,vf,Hist.LegacyID
			FROM tblItems I
			LEFT OUTER JOIN(
			SELECT MIN(ValidityFrom) vf from tblItems WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Ins on I.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblItems WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON I.ItemID = Hist.LegacyID
			WHERE (I.AuditUserID = @UserId OR @UserId IS NULL)
			AND I.ValidityFrom BETWEEN @FromDate AND @ToDate

		--OFFICER INFORMATION
		--UNION ALL
		IF @EntityId = N'O' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT O.AuditUserID UserId, @UserName UserName, N'O' EntityId,'Enrolment Officer' RecordType,NULL ActionType,
			'Code:' + O.Code + ' Name:' + O.OtherNames RecordIdentity, 
			O.ValidityFrom, O.ValidityTo,O.LegacyID,vf,Hist.LegacyID
			FROM tblOfficer O
			left outer join(
			select MIN(ValidityFrom) vf from tblOfficer where LegacyID is not null group by LegacyID) Ins ON O.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblOfficer WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON O.OfficerID = Hist.LegacyID
			WHERE (O.AuditUserID = @UserId OR @UserId IS NULL)
			AND O.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PAYER INFORMATION
		--UNION ALL
		IF @EntityId = N'P' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT P.AuditUserID UserId, @UserName UserName, N'P' EntityId,'Payer' RecordType,NULL ActionType,
			'Name:' + P.PayerName RecordIdentity, 
			P.ValidityFrom, P.ValidityTo,P.LegacyID,VF,Hist.LegacyID
			FROM tblPayer P
			left outer join(
			select MIN(ValidityFrom) VF from tblPayer where LegacyID is not null group by LegacyID) Ins ON P.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblPayer WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON P.PayerID = Hist.LegacyID
			WHERE (P.AuditUserID = @UserId OR @UserId IS NULL)
			AND P.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PHOTO INFORMATION
		--UNION ALL
		IF @EntityId = N'Ph' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT P.AuditUserID UserId, @UserName UserName, N'Ph' EntityId,'Photo' RecordType,NULL ActionType,
			'Assign to Insurance No.:' + I.CHFID RecordIdentity, 
			P.ValidityFrom, P.ValidityTo,NULL LegacyID,NULL VF,NULL HistoryLegacyId
			FROM tblPhotos P INNER JOIN tblInsuree I ON P.InsureeID = I.InsureeID
			WHERE (P.AuditUserID = @UserId OR @UserId IS NULL)
			AND ISNULL(P.PhotoFileName,'') <> ''
			AND P.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRICE LIST ITEM INFORMATION
		--UNION ALL
		IF @EntityId = N'PLI' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT I.AuditUserID UserId, @UserName UserName, N'PLI' EntityId,'Price List Items' RecordType,NULL ActionType,
			'Name:' + I.PLItemName + ' In the District:' + D.DistrictName RecordIdentity, 
			I.ValidityFrom, I.ValidityTo,I.LegacyID,VF,Hist.LegacyID
			FROM tblPLItems I INNER JOIN tblDistricts D ON I.LocationId = D.DistrictID
			left outer join(
			select MIN(validityFrom) VF From tblPLItems where LegacyID is not null group by LegacyID) Ins On I.ValidityFrom = Ins.VF
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblPLItems WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON I.PLItemID = Hist.LegacyID
			WHERE (I.AuditUserID = @UserId OR @UserId IS NULL)
			AND I.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRICE LIST ITEM DETAILS INFORMATION
		--UNION ALL
		IF @EntityId = N'PLID' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT I.AuditUserID UserId, @UserName UserName, N'PLID' EntityId,'Price List Items Details' RecordType,NULL ActionType,
			'Item:' + I.ItemName + ' In the Price List:' + PL.PLItemName RecordIdentity, 
			D.ValidityFrom, D.ValidityTo,D.LegacyID,vf,Hist.LegacyID
			FROM tblPLItemsDetail D INNER JOIN tblPLItems PL ON D.PLItemID = PL.PLItemID
			INNER JOIN tblItems I ON D.ItemID = I.ItemID
			left outer join(
			select MIN(validityfrom) vf from tblPLItemsDetail where LegacyID is not null group by LegacyID) Ins On D.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblPLItemsDetail WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON D.PLItemDetailID = Hist.LegacyID
			WHERE (I.AuditUserID = @UserId OR @UserId IS NULL)
			AND D.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRICE LIST SERVICE INFORMATION
		--UNION ALL
		IF @EntityId = N'PLS' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT S.AuditUserID UserId, @UserName UserName, N'PLS' EntityId,'Price List Service' RecordType,NULL ActionType,
			'Name:' + S.PLServName + ' In the District:' + D.DistrictName RecordIdentity, 
			S.ValidityFrom, S.ValidityTo,S.LegacyID,vf,Hist.LegacyID
			FROM tblPLServices S INNER JOIN tblDistricts D ON S.LocationId = D.DistrictID
			left outer join(
			select MIN(validityfrom) vf from tblPLServices where LegacyID is not null group by LegacyID) Ins On S.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblPLServices WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON S.PLServiceID = Hist.LegacyID
			WHERE (S.AuditUserID = @UserId OR @UserId IS NULL)
			AND S.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRICE LIST SERVICE DETAILS INFORMATION
		--UNION ALL
		IF @EntityId = N'PLSD' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT D.AuditUserID UserId, @UserName UserName, N'PLSD' EntityId,'Price List Service Details' RecordType,NULL ActionType,
			'Service:' + S.ServName + ' In the Price List:' + PL.PLServName RecordIdentity, 
			D.ValidityFrom, D.ValidityTo,D.LegacyID,vf,Hist.LegacyID
			FROM tblPLServicesDetail D INNER JOIN tblPLServices PL ON D.PLServiceID = PL.PLServiceID
			INNER JOIN tblServices S ON D.ServiceID = S.ServiceID
			left outer join(
			select MIN(validityfrom) vf from tblPLServicesDetail where LegacyID is not null group by LegacyID) Ins ON D.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblPLServicesDetail WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON D.PLServiceID = Hist.LegacyID
			WHERE (D.AuditUserID = @UserId OR @UserId IS NULL)
			AND D.ValidityFrom BETWEEN @FromDate AND @ToDate

		--POLICY INFORMATION
		--UNION ALL
		IF @EntityId =N'PL' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT P.AuditUserID UserId, @UserName UserName, N'PL' EntityId,'Policy' RecordType,NULL ActionType,
			'To the Family/Group Head:' + I.CHFID RecordIdentity, 
			P.ValidityFrom, P.ValidityTo,P.LegacyID,vf,Hist.LegacyID
			FROM tblPolicy P INNER JOIN tblFamilies F ON P.FamilyID = F.FamilyID
			INNER JOIN tblInsuree I ON F.InsureeID = I.InsureeID
			left outer join(
			select MIN(validityfrom) vf from tblPolicy where LegacyID is not null group by LegacyID) Ins on P.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblPolicy WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON P.PolicyID = Hist.LegacyID
			WHERE (P.AuditUserID = @UserId OR @UserId IS NULL)
			AND P.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PREMIUM INFORMATION
		--UNION ALL
		IF @EntityId = N'PR' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT PR.AuditUserID UserId, @UserName UserName, N'PR' EntityId,'Contribution' RecordType,NULL ActionType,
			CAST(PR.Amount AS NVARCHAR(20)) + ' Paid for the policy started on ' + CONVERT(NVARCHAR(10),P.StartDate,103) + ' For the Family/Group Head:' + I.CHFID RecordIdentity, 
			PR.ValidityFrom, PR.ValidityTo,PR.LegacyID,vf,Hist.LegacyID
			FROM tblPremium PR INNER JOIN tblPolicy P ON PR.PolicyID = P.PolicyID
			INNER JOIN tblFamilies F ON P.FamilyID = F.FamilyID
			INNER JOIN tblInsuree I ON F.InsureeID = I.InsureeID
			left outer join(
			select MIN(validityfrom) vf from tblPremium where LegacyID is not null group by LegacyID) Ins on PR.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyID FROM tblPremium WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON PR.PremiumId = Hist.LegacyID
			WHERE (PR.AuditUserID = @UserId OR @UserId IS NULL)
			AND PR.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRODUCT INFORMATION
		--UNION ALL
		IF @EntityId = N'PRD' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT PR.AuditUserID UserId, @UserName UserName, N'PRD' EntityId,'Product' RecordType,NULL ActionType,
			'Code:' + PR.ProductCode + ' Name:' + PR.ProductName RecordIdentity, 
			PR.ValidityFrom, PR.ValidityTo,PR.LegacyID,vf,Hist.LegacyID
			FROM tblProduct PR
			left outer join(
			select MIN(validityfrom) vf from tblProduct where LegacyID is not null group by LegacyID) Ins ON PR.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT legacyId FROM tblProduct WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON PR.ProdId = Hist.LegacyID
			WHERE (PR.AuditUserID = @UserId OR @UserId IS NULL)
			AND PR.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRODUCT ITEM INFORMATION
		--UNION ALL
		IF @EntityId = N'PRDI' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT ProdI.AuditUserID UserId, @UserName UserName, N'PRDI' EntityId,'Product Item' RecordType,NULL ActionType,
			'Item:' + I.ItemCode + ' in the product: ' + P.ProductCode RecordIdentity, 
			ProdI.ValidityFrom, ProdI.ValidityTo,ProdI.LegacyID,vf,Hist.LegacyID
			FROM tblProductItems ProdI INNER JOIN tblItems I ON ProdI.ItemID = I.ItemID
			INNER JOIN tblProduct P ON ProdI.ProdID = P.ProdID
			left outer join(
			select MIN(validityfrom) vf from tblProductItems where LegacyID is not null group by LegacyID) Ins ON ProdI.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblProductItems WHERE LegacyID IS NOT NULL GROUP BY LegacyID) Hist ON Prodi.ProdItemID = Hist.LegacyID
			WHERE (ProdI.AuditUserID = @UserId OR @UserId IS NULL)
			AND ProdI.ValidityFrom BETWEEN @FromDate AND @ToDate

		--PRODUCT SERVICE INFORMATION
		--UNION ALL
		IF @EntityId = N'PRDS' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT ProdS.AuditUserID UserId, @UserName UserName, N'PRDS' EntityId,'Product Service' RecordType,NULL ActionType,
			'Service:' + S.ServCode + ' in the product: ' + P.ProductCode RecordIdentity, 
			ProdS.ValidityFrom, ProdS.ValidityTo,ProdS.LegacyID,vf,Hist.LegacyID
			FROM tblProductServices ProdS INNER JOIN tblServices S ON ProdS.ServiceID = S.ServiceID
			INNER JOIN tblProduct P ON ProdS.ProdID = P.ProdID
			left outer join(
			select MIN(validityfrom) vf from tblProductServices where LegacyID is not null group by LegacyID) Ins ON ProdS.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblProductServices WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON ProdS.ProdServiceID = Hist.LegacyID
			WHERE (ProdS.AuditUserID = @UserId OR @UserId IS NULL)
			AND ProdS.ValidityFrom BETWEEN @FromDate AND @ToDate

		--RELATIVE DISTRIBUTION INFROMATION
		--UNION ALL
		IF @EntityId = N'RD' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT RD.AuditUserID UserId, @UserName UserName, N'RD' EntityId,'Relative Distribution' RecordType,NULL ActionType,
			'In the Product:' + Prod.ProductCode RecordIdentity, 
			RD.ValidityFrom, RD.ValidityTo,RD.LegacyID,vf,Hist.LegacyID
			FROM tblRelDistr RD INNER JOIN tblProduct Prod ON RD.ProdId = Prod.ProdId
			left outer join(
			select MIN(validityfrom) vf from tblRelDistr where LegacyID is not null group by LegacyID) Ins ON RD.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblRelDistr WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON RD.DistrID = Hist.LegacyID
			WHERE (RD.AuditUserID = @UserId OR @UserId IS NULL)
			AND RD.ValidityFrom BETWEEN @FromDate AND @ToDate

		--MEDICAL SERVICE INFORMATION 
		--UNION ALL
		IF @EntityId = N'S' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT S.AuditUserID UserId, @UserName UserName, N'S' EntityId,'Medical Services' RecordType,NULL ActionType,
			'Code:' + S.ServCode + ' Name:' + S.ServName RecordIdentity, 
			S.ValidityFrom, S.ValidityTo,S.LegacyID,vf,Hist.LegacyID
			FROM tblServices S
			left outer join(
			select MIN(validityfrom) vf from tblServices where LegacyID is not null group by LegacyID) Ins ON S.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblServices WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON S.ServiceID = Hist.LegacyID
			WHERE (S.AuditUserID = @UserId OR @UserId IS NULL)
			AND S.ValidityFrom BETWEEN @FromDate AND @ToDate

		--USERS INFORMATION
		--UNION ALL
		IF @EntityId = N'U' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT U.AuditUserID UserId, @UserName UserName, N'U' EntityId,'Users' RecordType,NULL ActionType,
			'Login:' + U.LoginName RecordIdentity, 
			U.ValidityFrom, U.ValidityTo,U.LegacyID,vf,Hist.LegacyID
			FROM tblUsers U
			left outer join(
			select MIN(validityfrom) vf from tblUsers where LegacyID is not null group by LegacyID) Ins ON U.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblUsers WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON U.UserID = Hist.LegacyID
			WHERE (U.AuditUserID = @UserId OR @UserId IS NULL)
			AND U.ValidityFrom BETWEEN @FromDate AND @ToDate

		--USER DISTRICTS INFORMATION
		--UNION ALL
		IF @EntityId = N'UD' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT UD.AuditUserID UserId, @UserName UserName, N'UD' EntityId,'User Districts' RecordType,NULL ActionType,
			'User:' + U.LoginName + ' Assigned to the District:' + D.DistrictName RecordIdentity, 
			UD.ValidityFrom, UD.ValidityTo,UD.LegacyID,vf,Hist.LegacyID
			FROM tblUsersDistricts UD INNER JOIN tblUsers U ON UD.UserID = U.UserID
			INNER JOIN tblDistricts D ON D.DistrictID = UD.LocationId
			left outer join(
			select MIN(validityfrom) vf from tblUsersDistricts where LegacyID is not null group by LegacyID) Ins ON UD.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyID FROM tblUsersDistricts WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON UD.UserDistrictID = Hist.LegacyID
			WHERE (UD.AuditUserID = @UserId OR @UserId IS NULL)
			AND UD.ValidityFrom BETWEEN @FromDate AND @ToDate

		--VILLAGE INFORMATION
		--UNION ALL
		IF @EntityId = N'V' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT V.AuditUserID UserId, @UserName UserName, N'V' EntityId,'Village' RecordType,NULL ActionType,
			'Village:' + V.VillageName + ' in Municipality:' + W.WardName + ' in District:' + D.DistrictName RecordIdentity, 
			V.ValidityFrom, V.ValidityTo,V.LegacyID,vf,Hist.LegacyID
			FROM tblVillages V INNER JOIN tblWards W ON V.WardID = W.WardID
			INNER JOIN tblDistricts D ON W.DistrictID = D.DistrictID
			left outer join(
			select MIN(validityfrom) vf from tblVillages where LegacyID is not null group by LegacyID) Ins ON V.ValidityFrom = Ins.vf
			LEFT OUTER JOIN
			(SELECT LegacyId FROM tblVillages WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON V.VillageID = Hist.LegacyID
			WHERE (V.AuditUserID = @UserId OR @UserId IS NULL)
			AND V.ValidityFrom BETWEEN @FromDate AND @ToDate

		--WARD INFORMATION
		--UNION ALL
		IF @EntityId = N'W' OR @EntityId = N''
			INSERT INTO @tblLogs(UserId,UserName,EntityId,RecordType,ActionType,RecordIdentity,ValidityFrom,ValidityTo,LegacyId,VF,HistoryLegacyId)
			SELECT W.AuditUserID UserId, @UserName UserName, N'W' EntityId,'Municipality' RecordType,NULL ActionType,
			'Municipality:' + W.WardName + ' in District:' + D.DistrictName RecordIdentity, 
			W.ValidityFrom, W.ValidityTo,W.LegacyID,vf,Hist.LegacyID
			FROM tblWards W INNER JOIN tblDistricts D ON W.DistrictID = D.DistrictID
			left outer join(
			select MIN(validityfrom) vf from tblWards where LegacyID is not null group by LegacyID) Ins ON W.ValidityFrom = Ins.vf
			LEFT OUTER JOIN 
			(SELECT LegacyId FROM tblWards WHERE LegacyID IS NOT NULL GROUP BY LegacyID)Hist ON W.WardID = Hist.LegacyID
			WHERE (W.AuditUserID = @UserId OR @UserId IS NULL)
			AND W.ValidityFrom BETWEEN @FromDate AND @ToDate

		;WITH Result AS
		(
			SELECT UserId,UserName,EntityId,RecordType,
			CASE WHEN ActionType IS NULL AND ( (VF IS NOT NULL OR ((ValidityTo IS  NULL) AND LegacyId IS NULL AND VF IS NULL AND HistoryLegacyId IS NULL))) THEN N'Inserted'      --Inserts (new and updated inserts) 
				WHEN ((ValidityTo IS NOT NULL) AND LegacyId IS NOT NULL AND VF IS NULL AND HistoryLegacyId IS NULL) THEN N'Modified'
				WHEN ((ValidityTo IS  NULL) AND LegacyId IS  NULL AND VF IS NULL AND HistoryLegacyId IS NOT NULL) THEN N'Modified'
				WHEN ((ValidityTo IS NOT NULL) AND LegacyId IS NULL AND VF IS NULL) Then 'Deleted'
				ELSE ActionType
			END ActionType , RecordIdentity, 
			CASE WHEN ValidityTo IS NOT NULL AND LegacyId IS NULL AND VF IS NULL THEN ValidityTo ELSE ValidityFrom END ActionTime
			FROM @tblLogs
		)SELECT Result.UserId, ISNULL(CASE WHEN Result.UserId <> -1 THEN  U.LoginName ELSE N'Mobile/Offline System' END,N'Unknown') UserName, EntityId, RecordType, ActionType, RecordIdentity, ActionTime 
		FROM Result	LEFT OUTER JOIN tblUsers U ON Result.userId = U.UserID
		WHERE (EntityId = @EntityId OR @EntityId = N'')
		AND (ActionType = @Action OR @Action = N'')
		ORDER BY ActionTime
	END


GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSubmitClaims]
	
	@AuditUser as int = 0,
	@xtClaimSubmit dbo.xClaimSubmit READONLY,
	@Submitted as int = 0 OUTPUT  ,
	@Checked as int = 0 OUTPUT  ,
	@Rejected as int = 0 OUTPUT  ,
	@Changed as int = 0 OUTPUT  ,
	@Failed as int = 0 OUTPUT ,
	@ItemsPassed as int = 0 OUTPUT,
	@ServicesPassed as int = 0 OUTPUT,
	@ItemsRejected as int = 0 OUTPUT,
	@ServicesRejected as int = 0 OUTPUT,
	@oReturnValue as int = 0 OUTPUT
	
	
	/*
	Rejection reasons:
	
	1 = Item/Service not in Registers
	2 = Item/Service not in Covering Product
	3 = Item/Service not in HF Pricelist 
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATD
	7 = 
	8 = 
	9 = 
	10=
	11=
	12=
	*/
	
AS
BEGIN
	
	 
	
	SET @Checked = 0
	SET @Rejected = 0
	SET @Changed = 0
	SET @Failed = 0
	SET @ItemsPassed = 0 
	SET @ServicesPassed = 0 
	SET @ItemsRejected = 0 
	SET @ServicesRejected = 0 
	
	DECLARE @InTopIsolation as bit 
	
	DECLARE @RtnStatus as int 
	DECLARE @CLAIMID as INT
	DECLARE @ROWID as BIGINT
	DECLARE @RowCurrent as BIGINT
	DECLARE @RtnItemsPassed as int 
	DECLARE @RtnServicesPassed as int 
	DECLARE @RtnItemsRejected as int 
	DECLARE @RtnServicesRejected as int 
	DECLARE @ClaimFailed BIT = 0 
	
	
	SELECT @Submitted = COUNT(ClaimID) FROM @xtClaimSubmit
	
	DECLARE CLAIMLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT [ClaimID],[RowID] FROM @xtClaimSubmit ORDER BY ClaimID ASC
	OPEN CLAIMLOOP
	FETCH NEXT FROM CLAIMLOOP INTO @CLAIMID,@ROWID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		SELECT @RowCurrent = RowID FROM tblClaim WHERE ClaimID = @CLAIMID
		IF @RowCurrent <> @ROWID 
		BEGIN
			SET @Changed = @Changed + 1 
			GOTO NextClaim
		END 
		
		IF @@TRANCOUNT = 0 	
			SET @InTopIsolation =0
		ELSE
			SET @InTopIsolation =1
		
		IF @InTopIsolation = 0
		BEGIN
			SET TRANSACTION  ISOLATION LEVEL REPEATABLE READ
			BEGIN TRANSACTION SUBMITCLAIMS
		END

		BEGIN TRY
			--execute the single CLAIM
			EXEC @oReturnValue = [uspSubmitSingleClaim] @AuditUser, @CLAIMID, @ROWID, @RtnStatus OUTPUT,@RtnItemsPassed OUTPUT,@RtnServicesPassed OUTPUT,@RtnItemsRejected OUTPUT,@RtnServicesRejected OUTPUT
		
			IF @oReturnValue <> 0 
			BEGIN
				SET @Failed = @Failed + 1 
				IF @InTopIsolation = 0 
					SET @ClaimFailed = 1
				GOTO NextClaim
			END


			IF @RtnStatus = 0
				SET @Failed = @Failed + 1 
			IF @RtnStatus = 1
				SET @Checked = @Checked + 1 
			IF @RtnStatus = 2
				SET @Rejected = @Rejected + 1 
					
			SET @ItemsPassed = @ItemsPassed + ISNULL(@RtnItemsPassed,0)
			SET @ServicesPassed = @ServicesPassed + ISNULL(@RtnServicesPassed,0)
			SET @ItemsRejected = @ItemsRejected + ISNULL(@RtnItemsRejected ,0)
			SET @ServicesRejected = @ServicesRejected + ISNULL(@RtnServicesRejected ,0)
		
		END TRY
		BEGIN CATCH
			SET @Failed = @Failed + 1 
			--SELECT 'Unexpected error encountered'
			IF @InTopIsolation = 0 
				SET @ClaimFailed = 1
			GOTO NextClaim
		
		END CATCH

NextClaim:
		IF @InTopIsolation = 0 
		BEGIN
			IF @ClaimFailed = 0 
				
				COMMIT TRANSACTION SUBMITCLAIMS	
				
			ELSE
				ROLLBACK TRANSACTION SUBMITCLAIMS
		
		END
		SET @ClaimFailed = 0
		FETCH NEXT FROM CLAIMLOOP INTO @CLAIMID,@ROWID
	END
	CLOSE CLAIMLOOP
	DEALLOCATE CLAIMLOOP
	
FINISH:
	
	SET @oReturnValue = 0 
	RETURN @oReturnValue
	
END

GO

/****** Object:  StoredProcedure [dbo].[uspUpdateClaimFromPhone]    Script Date: 10/29/2021 4:09:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspUpdateClaimFromPhone]
(
	--@FileName NVARCHAR(255),
	@XML XML,
	@ByPassSubmit BIT = 0
)

/*
-1	-- Fatal Error
0	-- All OK
1	--Invalid HF CODe
2	--Duplicate Claim Code
3	--Invald CHFID
4	--End date is smaller than start date
5	--Invalid ICDCode
6	--Claimed amount is 0
7	--Invalid ItemCode
8	--Invalid ServiceCode
9	--Invalid Claim Admin
*/


AS
BEGIN
	
	SET XACT_ABORT ON

	--DECLARE @XML XML
	
	DECLARE @Query NVARCHAR(3000)

	DECLARE @ClaimID INT
	DECLARE @ClaimDate DATE
	DECLARE @HFCode NVARCHAR(8)
	DECLARE @ClaimAdmin NVARCHAR(8)
	DECLARE @ClaimCode NVARCHAR(8)
	DECLARE @CHFID NVARCHAR(12)
	DECLARE @StartDate DATE
	DECLARE @EndDate DATE
	DECLARE @ICDCode NVARCHAR(6)
	DECLARE @Comment NVARCHAR(MAX)
	DECLARE @Total DECIMAL(18,2)
	DECLARE @ICDCode1 NVARCHAR(6)
	DECLARE @ICDCode2 NVARCHAR(6)
	DECLARE @ICDCode3 NVARCHAR(6)
	DECLARE @ICDCode4 NVARCHAR(6)
	DECLARE @VisitType CHAR(1)
	DECLARE @GuaranteeId NVARCHAR(50)
	

	DECLARE @HFID INT
	DECLARE @ClaimAdminId INT
	DECLARE @InsureeID INT
	DECLARE @ICDID INT
	DECLARE @ICDID1 INT
	DECLARE @ICDID2 INT
	DECLARE @ICDID3 INT
	DECLARE @ICDID4 INT
	DECLARE @TotalItems DECIMAL(18,2) = 0
	DECLARE @TotalServices DECIMAL(18,2) = 0

	DECLARE @isClaimAdminRequired BIT = (SELECT CASE Adjustibility WHEN N'M' THEN 1 ELSE 0 END FROM tblControls WHERE FieldName = N'ClaimAdministrator')
	DECLARE @isClaimAdminOptional BIT = (SELECT CASE Adjustibility WHEN N'O' THEN 1 ELSE 0 END FROM tblControls WHERE FieldName = N'ClaimAdministrator')
	
	BEGIN TRY
		
			IF NOT OBJECT_ID('tempdb..#tblItem') IS NULL DROP TABLE #tblItem
			CREATE TABLE #tblItem(ItemCode NVARCHAR(6),ItemPrice DECIMAL(18,2), ItemQuantity INT)

			IF NOT OBJECT_ID('tempdb..#tblService') IS NULL DROP TABLE #tblService
			CREATE TABLE #tblService(ServiceCode NVARCHAR(6),ServicePrice DECIMAL(18,2), ServiceQuantity INT)

			--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK '''+ @FileName +''',SINGLE_BLOB) AS T(X)')
			
			--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

			SELECT
			@ClaimDate = CONVERT(DATE,Claim.value('(ClaimDate)[1]','NVARCHAR(10)'),103),
			@HFCode = Claim.value('(HFCode)[1]','NVARCHAR(8)'),
			@ClaimAdmin = Claim.value('(ClaimAdmin)[1]','NVARCHAR(8)'),
			@ClaimCode = Claim.value('(ClaimCode)[1]','NVARCHAR(8)'),
			@CHFID = Claim.value('(CHFID)[1]','NVARCHAR(12)'),
			@StartDate = CONVERT(DATE,Claim.value('(StartDate)[1]','NVARCHAR(10)'),103),
			@EndDate = CONVERT(DATE,Claim.value('(EndDate)[1]','NVARCHAR(10)'),103),
			@ICDCode = Claim.value('(ICDCode)[1]','NVARCHAR(6)'),
			@Comment = Claim.value('(Comment)[1]','NVARCHAR(MAX)'),
			@Total = CASE Claim.value('(Total)[1]','VARCHAR(10)') WHEN '' THEN 0 ELSE CONVERT(DECIMAL(18,2),ISNULL(Claim.value('(Total)[1]','VARCHAR(10)'),0)) END,
			@ICDCode1 = Claim.value('(ICDCode1)[1]','NVARCHAR(6)'),
			@ICDCode2 = Claim.value('(ICDCode2)[1]','NVARCHAR(6)'),
			@ICDCode3 = Claim.value('(ICDCode3)[1]','NVARCHAR(6)'),
			@ICDCode4 = Claim.value('(ICDCode4)[1]','NVARCHAR(6)'),
			@VisitType = Claim.value('(VisitType)[1]','CHAR(1)'),
			@GuaranteeId = Claim.value('(GuaranteeNo)[1]','NVARCHAR(50)')
			FROM @XML.nodes('Claim/Details')AS T(Claim)


			INSERT INTO #tblItem(ItemCode,ItemPrice,ItemQuantity)
			SELECT
			T.Items.value('(ItemCode)[1]','NVARCHAR(6)'),
			CONVERT(DECIMAL(18,2),T.Items.value('(ItemPrice)[1]','DECIMAL(18,2)')),
			CONVERT(DECIMAL(18,2),T.Items.value('(ItemQuantity)[1]','NVARCHAR(15)'))
			FROM @XML.nodes('Claim/Items/Item') AS T(Items)



			INSERT INTO #tblService(ServiceCode,ServicePrice,ServiceQuantity)
			SELECT
			T.[Services].value('(ServiceCode)[1]','NVARCHAR(6)'),
			CONVERT(DECIMAL(18,2),T.[Services].value('(ServicePrice)[1]','DECIMAL(18,2)')),
			CONVERT(DECIMAL(18,2),T.[Services].value('(ServiceQuantity)[1]','NVARCHAR(15)'))
			FROM @XML.nodes('Claim/Services/Service') AS T([Services])

			--isValid HFCode

			SELECT @HFID = HFID FROM tblHF WHERE HFCode = @HFCode AND ValidityTo IS NULL
			IF @HFID IS NULL
				RETURN 1
				
			--isDuplicate ClaimCode
			IF EXISTS(SELECT ClaimCode FROM tblClaim WHERE ClaimCode = @ClaimCode AND HFID = @HFID AND ValidityTo IS NULL)
				RETURN 2

			--isValid CHFID
			SELECT @InsureeID = InsureeID FROM tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL
			IF @InsureeID IS NULL
				RETURN 3

			--isValid EndDate
			IF DATEDIFF(DD,@ENDDATE,@STARTDATE) > 0
				RETURN 4
				
			--isValid ICDCode
			SELECT @ICDID = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode AND ValidityTo IS NULL
			IF @ICDID IS NULL
				RETURN 5
			
			IF NOT NULLIF(@ICDCode1, '')IS NULL
			BEGIN
				SELECT @ICDID1 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode1 AND ValidityTo IS NULL
				IF @ICDID1 IS NULL
					RETURN 5
			END
			
			IF NOT NULLIF(@ICDCode2, '') IS NULL
			BEGIN
				SELECT @ICDID2 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode2 AND ValidityTo IS NULL
				IF @ICDID2 IS NULL
					RETURN 5
			END
			
			IF NOT NULLIF(@ICDCode3, '') IS NULL
			BEGIN
				SELECT @ICDID3 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode3 AND ValidityTo IS NULL
				IF @ICDID3 IS NULL
					RETURN 5
			END
			
			IF NOT NULLIF(@ICDCode4, '') IS NULL
			BEGIN
				SELECT @ICDID4 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode4 AND ValidityTo IS NULL
				IF @ICDID4 IS NULL
					RETURN 5
			END		
			--isValid Claimed Amount
			--THIS CONDITION CAN BE PUT BACK
			--IF @Total <= 0
			--	RETURN 6
				
			--isValid ItemCode
			IF EXISTS (SELECT I.ItemCode
			FROM tblItems I FULL OUTER JOIN #tblItem TI ON I.ItemCode COLLATE DATABASE_DEFAULT = TI.ItemCode COLLATE DATABASE_DEFAULT
			WHERE I.ItemCode IS NULL AND I.ValidityTo IS NULL)
				RETURN 7
				
			--isValid ServiceCode
			IF EXISTS(SELECT S.ServCode
			FROM tblServices S FULL OUTER JOIN #tblService TS ON S.ServCode COLLATE DATABASE_DEFAULT = TS.ServiceCode COLLATE DATABASE_DEFAULT
			WHERE S.ServCode IS NULL AND S.ValidityTo IS NULL)
				RETURN 8
			
			--isValid Claim Admin
			IF @isClaimAdminRequired = 1
				BEGIN	
					SELECT @ClaimAdminId = ClaimAdminId FROM tblClaimAdmin WHERE ClaimAdminCode = @ClaimAdmin AND ValidityTo IS NULL
					IF @ClaimAdmin IS NULL
						RETURN 9
				END
			ELSE
				IF @isClaimAdminOptional = 1
					BEGIN	
						SELECT @ClaimAdminId = ClaimAdminId FROM tblClaimAdmin WHERE ClaimAdminCode = @ClaimAdmin AND ValidityTo IS NULL
					END

		BEGIN TRAN CLAIM
			INSERT INTO tblClaim(InsureeID,ClaimCode,DateFrom,DateTo,ICDID,ClaimStatus,Claimed,DateClaimed,Explanation,AuditUserID,HFID,ClaimAdminId,ICDID1,ICDID2,ICDID3,ICDID4,VisitType,GuaranteeId)
						VALUES(@InsureeID,@ClaimCode,@StartDate,@EndDate,@ICDID,2,@Total,@ClaimDate,@Comment,-1,@HFID,@ClaimAdminId,@ICDID1,@ICDID2,@ICDID3,@ICDID4,@VisitType,@GuaranteeId);

			SELECT @ClaimID = SCOPE_IDENTITY();
			
			;WITH PLID AS
			(
				SELECT PLID.ItemId, PLID.PriceOverule
				FROM tblHF HF
				INNER JOIN tblPLItems PLI ON PLI.PLItemId = HF.PLItemID
				INNER JOIN tblPLItemsDetail PLID ON PLID.PLItemId = PLI.PLItemId
				WHERE HF.ValidityTo IS NULL
				AND PLI.ValidityTo IS NULL
				AND PLID.ValidityTo IS NULL
				AND HF.HFID = @HFID
			)
			INSERT INTO tblClaimItems(ClaimID,ItemID,QtyProvided,PriceAsked,AuditUserID)
			SELECT @ClaimID, I.ItemId, T.ItemQuantity, COALESCE(NULLIF(T.ItemPrice,0),PLID.PriceOverule,I.ItemPrice)ItemPrice, -1
			FROM #tblItem T 
			INNER JOIN tblItems I  ON T.ItemCode COLLATE DATABASE_DEFAULT = I.ItemCode COLLATE DATABASE_DEFAULT AND I.ValidityTo IS NULL
			LEFT OUTER JOIN PLID ON PLID.ItemID = I.ItemID
			
			SELECT @TotalItems = SUM(PriceAsked * QtyProvided) FROM tblClaimItems 
						WHERE ClaimID = @ClaimID
						GROUP BY ClaimID

			;WITH PLSD AS
			(
				SELECT PLSD.ServiceId, PLSD.PriceOverule
				FROM tblHF HF
				INNER JOIN tblPLServices PLS ON PLS.PLServiceId = HF.PLServiceID
				INNER JOIN tblPLServicesDetail PLSD ON PLSD.PLServiceId = PLS.PLServiceId
				WHERE HF.ValidityTo IS NULL
				AND PLS.ValidityTo IS NULL
				AND PLSD.ValidityTo IS NULL
				AND HF.HFID = @HFID
			)
			INSERT INTO tblClaimServices(ClaimId, ServiceID, QtyProvided, PriceAsked, AuditUserID)
			SELECT @ClaimID, S.ServiceID, T.ServiceQuantity,COALESCE(NULLIF(T.ServicePrice,0),PLSD.PriceOverule,S.ServPrice)ServicePrice , -1
			FROM #tblService T 
			INNER JOIN tblServices S ON T.ServiceCode COLLATE DATABASE_DEFAULT = S.ServCode COLLATE DATABASE_DEFAULT AND S.ValidityTo IS NULL
			LEFT OUTER JOIN PLSD ON PLSD.ServiceId = S.ServiceId
						
						SELECT @TotalServices = SUM(PriceAsked * QtyProvided) FROM tblClaimServices 
						WHERE ClaimID = @ClaimID
						GROUP BY ClaimID
					
						UPDATE tblClaim SET Claimed = ISNULL(@TotalItems,0) + ISNULL(@TotalServices,0)
						WHERE ClaimID = @ClaimID
						
		COMMIT TRAN CLAIM
		
		
		SELECT @ClaimID  = IDENT_CURRENT('tblClaim')
		
		IF @ByPassSubmit = 0
			EXEC uspSubmitSingleClaim -1, @ClaimID,0 
		
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN CLAIM
			SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspUploadDiagnosisXML]
(
	--@File NVARCHAR(300),
	@XML XML,
	@StrategyId INT,	--1	: Insert Only,	2: Update Only	3: Insert & Update	7: Insert, Update & Delete
	@AuditUserID INT = -1,
	@DryRun BIT=0,
	@DiagnosisSent INT = 0 OUTPUT,
	@Inserts INT  = 0 OUTPUT,
	@Updates INT  = 0 OUTPUT,
	@Deletes INT = 0 OUTPUT
)
AS
BEGIN

	/* Result type in @tblResults
	-------------------------------
		E	:	Error
		C	:	Conflict
		FE	:	Fatal Error

	Return Values
	------------------------------
		0	:	All Okay
		-1	:	Fatal error
	*/
	

	DECLARE @InsertOnly INT = 1,
			@UpdateOnly INT = 2,
			@Delete INT= 4

	SET @Inserts = 0;
	SET @Updates = 0;
	SET @Deletes = 0;

	DECLARE @Query NVARCHAR(500)
	--DECLARE @XML XML
	DECLARE @tblDiagnosis TABLE(ICDCode nvarchar(50),  ICDName NVARCHAR(255), IsValid BIT)
	DECLARE @tblDeleted TABLE(Id INT, Code NVARCHAR(8));
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))

	BEGIN TRY

		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

		IF ( @XML.exist('(Diagnoses/Diagnosis/DiagnosisCode)')=1)
			BEGIN
				--GET ALL THE DIAGNOSES	 FROM THE XML
				INSERT INTO @tblDiagnosis(ICDCode,ICDName, IsValid)
				SELECT 
				T.F.value('(DiagnosisCode)[1]','NVARCHAR(12)'),
				T.F.value('(DiagnosisName)[1]','NVARCHAR(255)'),
				1 IsValid
				FROM @XML.nodes('Diagnoses/Diagnosis') AS T(F)

				SELECT @DiagnosisSent=@@ROWCOUNT
			END
		ELSE
			BEGIN
				RAISERROR (N'-200', 16, 1);
			END
	

	
		/*========================================================================================================
		VALIDATION STARTS
		========================================================================================================*/	

			--Invalidate empty code or empty name 
			IF EXISTS(
				SELECT 1
				FROM @tblDiagnosis D 
				WHERE LEN(ISNULL(D.ICDCode, '')) = 0
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT CONVERT(NVARCHAR(3), COUNT(D.ICDCode)) + N' Diagnosis have empty Diagnosis code', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Diagnosis Code ' + QUOTENAME(D.ICDCode) + N' has empty name field', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDName, '')) = 0


			UPDATE D SET IsValid = 0
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0 OR LEN(ISNULL(D.ICDName, '')) = 0

			--Check if any ICD Code is greater than 6 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the Diagnosis Code ' + QUOTENAME(D.ICDCode) + ' is greater than 6 characters', N'E'
			FROM @tblDiagnosis D
			WHERE LEN(D.ICDCode) > 6;

			UPDATE D SET IsValid = 0
			FROM @tblDiagnosis D
			WHERE LEN(D.ICDCode) > 6;

			--Check if any ICD code is duplicated in the file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT QUOTENAME(D.ICDCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(D.ICDCode)) + ' times in the file', N'C'
			FROM @tblDiagnosis D
			GROUP BY D.ICDCode
			HAVING COUNT(D.ICDCode) > 1;
	
			UPDATE D SET IsValid = 0
			FROM @tblDiagnosis D
			WHERE D.ICDCode IN (
				SELECT ICDCode FROM @tblDiagnosis GROUP BY ICDCode HAVING COUNT(ICDCode) > 1
			)

		
		--Get the counts
		--To be deleted
		IF (@StrategyId & @Delete) > 0
		BEGIN
			--Get the list of ICDs which can't be deleted
			INSERT INTO @tblResult(Result, ResultType)
			SELECT QUOTENAME(D.ICDCode) + ' is used in claim. Can''t delete' Result, N'E' ResultType
			FROM tblClaim C
			INNER JOIN (
					SELECT D.ICDID Id, D.ICDCode
					FROM tblICDCodes D
					LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode
					WHERE D.ValidityTo IS NULL
					AND temp.ICDCode IS NULL
					
			) D ON C.ICDID = D.Id OR C.ICDID1 = D.Id OR C.ICDID2 = D.Id OR C.ICDID3 = D.Id OR C.ICDID4 = D.Id
			GROUP BY D.ICDCode;

			SELECT @Deletes = COUNT(1)
			FROM tblICDCodes D
			LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode AND temp.IsValid = 1
			LEFT OUTER JOIN tblClaim C ON C.ICDID = D.ICDID OR C.ICDID1 = D.ICDID OR C.ICDID2 = D.ICDID OR C.ICDID3 = D.ICDID OR C.ICDID4 = D.ICDID
			WHERE D.ValidityTo IS NULL
			AND temp.ICDCode IS NULL
			AND C.ClaimId IS NULL;
		END	
		
		--To be udpated
		IF (@StrategyId & @UpdateOnly) > 0
		BEGIN

			--Failed ICD
			IF @StrategyId=@UpdateOnly
				BEGIN
					INSERT INTO @tblResult(Result, ResultType)
					SELECT N'Diagnosis Code ' + QUOTENAME(D.ICDCode) + N' does not exists in Database', N'FI'
					FROM  @tblDiagnosis D
					LEFT OUTER JOIN tblICDCodes ICD ON ICD.ICDCode = D.ICDCode
					WHERE 
					ICD.ValidityTo IS NULL
					AND D.IsValid = 1
					AND ICD.ICDCode IS NULL
				END
			SELECT @Updates = COUNT(1)
			FROM tblICDCodes ICD
			INNER JOIN @tblDiagnosis D ON ICD.ICDCode = D.ICDCode
			WHERE ICD.ValidityTo IS NULL
			AND D.IsValid = 1
		END
		
		--To be  Inserted
		IF (@StrategyId & @InsertOnly) > 0
		BEGIN
			--Failed ICD
			IF(@StrategyId=@InsertOnly)
				BEGIN
					INSERT INTO @tblResult(Result, ResultType)
					SELECT 'Diagnosis Code '+  QUOTENAME(D.ICDCode) +' already exists in Database',N'FI' FROM @tblDiagnosis D
					INNER JOIN tblICDCodes ICD ON D.ICDCode=ICD.ICDCode WHERE ICD.ValidityTo IS NULL AND  D.IsValid=1
				END
			SELECT @Inserts = COUNT(1)
			FROM @tblDiagnosis D
			LEFT OUTER JOIN tblICDCodes ICD ON D.ICDCode = ICD.ICDCode AND ICD.ValidityTo IS NULL
			WHERE D.IsValid = 1
			AND ICD.ICDCode IS NULL
		END
		/*========================================================================================================
		VALIDATION ENDS
		========================================================================================================*/	

		IF @DryRun = 0
		BEGIN
			BEGIN TRAN UPLOAD

			/*========================================================================================================
			DELETE STARTS
			========================================================================================================*/	
				IF (@StrategyId & @Delete) > 0
				BEGIN
					
					
					INSERT INTO @tblDeleted(Id, Code)
					SELECT D.ICDID, D.ICDCode
					FROM tblICDCodes D
					LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode
					WHERE D.ValidityTo IS NULL
					AND temp.ICDCode IS NULL;


					--Check if any of the ICDCodes are used in Claims and remove them from the temporory table
					DELETE D
					FROM tblClaim C
					INNER JOIN @tblDeleted D ON C.ICDID = D.Id OR C.ICDID1 = D.Id OR C.ICDID2 = D.Id OR C.ICDID3 = D.Id OR C.ICDID4 = D.Id
	


					--Insert a copy of the to be deleted records
					INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, ValidityTo, LegacyId, AuditUserId)
					OUTPUT QUOTENAME(inserted.ICDCode), N'D' INTO @tblResult
					SELECT ICD.ICDCode, ICD.ICDName, ICD.ValidityFrom, GETDATE() ValidityTo, ICD.ICDID LegacyId, @AuditUserID AuditUserId 
					FROM tblICDCodes ICD
					INNER JOIN @tblDeleted D ON ICD.ICDID = D.Id

					--Update the ValidtyFrom Flag to mark as deleted
					UPDATE ICD SET ValidityTo = GETDATE()
					FROM tblICDCodes ICD
					INNER JOIN @tblDeleted D ON ICD.ICDID = D.Id;
					
					SELECT @Deletes=@@ROWCOUNT;
				END
								
			/*========================================================================================================
			DELETE ENDS
			========================================================================================================*/	



			/*========================================================================================================
			UDPATE STARTS
			========================================================================================================*/	

				IF  (@StrategyId & @UpdateOnly) > 0
				BEGIN

				--Make a copy of the original record
					INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, ValidityTo, LegacyId, AuditUserId)
					SELECT ICD.ICDCode, ICD.ICDName, ICD.ValidityFrom, GETDATE() ValidityTo, ICD.ICDID LegacyId, @AuditUserID AuditUserId 
					FROM tblICDCodes ICD
					INNER JOIN @tblDiagnosis D ON ICD.ICDCode = D.ICDCode
					WHERE ICD.ValidityTo IS NULL
					AND D.IsValid = 1;

					SELECT @Updates = @@ROWCOUNT;

				--Upadte the record
					UPDATE ICD SET ICDName = D.ICDName, ValidityFrom = GETDATE(), AuditUserID = @AuditUserID
					OUTPUT QUOTENAME(deleted.ICDCode), N'U' INTO @tblResult
					FROM tblICDCodes ICD
					INNER JOIN @tblDiagnosis D ON ICD.ICDCode = D.ICDCode
					WHERE ICD.ValidityTo IS NULL
					AND D.IsValid = 1;


				END

			/*========================================================================================================
			UPDATE ENDS
			========================================================================================================*/	

			/*========================================================================================================
			INSERT STARTS
			========================================================================================================*/	

				IF (@StrategyId & @InsertOnly) > 0
				BEGIN
					INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, AuditUserId)
					OUTPUT QUOTENAME(inserted.ICDCode), N'I' INTO @tblResult
					SELECT D.ICDCode, D.ICDName, GETDATE() ValidityFrom, @AuditUserId AuditUserId
					FROM @tblDiagnosis D
					LEFT OUTER JOIN tblICDCodes ICD ON D.ICDCode = ICD.ICDCode AND ICD.ValidityTo IS NULL
					WHERE D.IsValid = 1
					AND ICD.ICDCode IS NULL;
	
					SELECT @Inserts = @@ROWCOUNT;
				END

			/*========================================================================================================
			INSERT ENDS
			========================================================================================================*/	


			COMMIT TRAN UPLOAD
			
		END
	END TRY
	BEGIN CATCH
		DECLARE @InvalidXML NVARCHAR(100)
		IF ERROR_NUMBER()=9436
			BEGIN 
				SET @InvalidXML='Invalid XML file, end tag does not match start tag'
				INSERT INTO @tblResult(Result, ResultType)
				SELECT @InvalidXML, N'FE';
			END
		ELSE IF  ERROR_MESSAGE()=N'-200'
			BEGIN
				INSERT INTO @tblResult(Result, ResultType)
			SELECT'Invalid Diagnosis XML file', N'FE';
			END
		ELSE
				INSERT INTO @tblResult(Result, ResultType)
				SELECT'Invalid XML file', N'FE';
			
		IF @@TRANCOUNT > 0 ROLLBACK TRAN UPLOAD;
		SELECT * FROM @tblResult;
		RETURN -1;
	END CATCH

	SELECT * FROM @tblResult;
	RETURN 0;
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
(
	@xml XML,
	@OfficerId INT,
	@AuditUserId INT,
	@ErrorMessage NVARCHAR(300) = N'' OUTPUT
)
AS
BEGIN
    
	/*=========ERROR CODES==========
	-400	:Uncaught exception
	0	:	All okay
	-1	:	Given family has no HOF
	-2	:	Insurance number of the HOF already exists
	-3	:	Duplicate Insurance number found
	-4	:	Duplicate receipt found

	

	*/
TRY --THE MAIN TRY
		--Create table variables
		--DECLARE @Result TABLE(ErrorMessage NVARCHAR(500))
		DECLARE @Family TABLE(FamilyId INT,InsureeId INT,LocationId INT, HOFCHFID nvarchar(12),Poverty BIT NULL,FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), ConfirmationType NVARCHAR(3),isOffline INT)
		DECLARE @Insuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT, CurrentAddress NVARCHAR(200), GeoLocation NVARCHAR(250), CurrentVillage INT, PhotoPath NVARCHAR(100), IdentificationNumber NVARCHAR(50),isOffline INT,EffectiveDate DATE)
		DECLARE @Policy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1),isOffline INT)
		DECLARE @Premium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT,isOffline INT)
		--DECLARE @InsureePolicy TABLE(InsureePolicyId INT, InsureeId INT,PolicyId INT, EnrollmentDate DATE,StartDate DATE, EffectiveDate DATE, ExpiryDate DATE,isOffline INT)
		--Insert data into table variable from XML
		INSERT INTO @Family(FamilyId, InsureeId, LocationId,HOFCHFID, Poverty, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo, ConfirmationType,isOffline)
		SELECT 
		T.F.value('(FamilyId)[1]', 'INT'),
		T.F.value('(InsureeId)[1]', 'INT'),
		T.F.value('(LocationId)[1]', 'INT'),
		T.F.value('(HOFCHFID)[1]', 'NVARCHAR(12)'),
		T.F.value('(Poverty)[1]', 'BIT'),
		NULLIF(T.F.value('(FamilyType)[1]', 'NVARCHAR(2)'), ''),
		NULLIF(T.F.value('(FamilyAddress)[1]', 'NVARCHAR(200)'), ''),
		NULLIF(T.F.value('(Ethnicity)[1]', 'NVARCHAR(1)'), ''),
		NULLIF(T.F.value('(ConfirmationNo)[1]', 'NVARCHAR(12)'), ''),
		NULLIF(NULLIF(T.F.value('(ConfirmationType)[1]', 'NVARCHAR(4)'), 'null'), ''),
		T.F.value('(isOffline)[1]','INT')
		FROM @xml.nodes('Enrollment/Family') AS T(F);

	
		INSERT INTO @Insuree(InsureeId, FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, Phone, CardIssued, Relationship, 
		Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage, PhotoPath, Passport,isOffline,EffectiveDate)
		SELECT 
		T.I.value('(InsureeId)[1]', 'INT'),
		T.I.value('(FamilyId)[1]', 'INT'),
		T.I.value('(CHFID)[1]', 'NVARCHAR(12)'),
		T.I.value('(LastName)[1]', 'NVARCHAR(100)'),
		T.I.value('(OtherNames)[1]', 'NVARCHAR(100)'),
		T.I.value('(DOB)[1]', 'DATE'),
		T.I.value('(Gender)[1]', 'CHAR(1)'),
		NULLIF(T.I.value('(Marital)[1]', 'CHAR(1)'), ''),
		T.I.value('(isHead)[1]', 'BIT'),
		NULLIF(T.I.value('(Phone)[1]', 'NVARCHAR(50)'), ''),
		ISNULL(NULLIF(T.I.value('(CardIssued)[1]', 'BIT'), ''), 0),
		NULLIF(T.I.value('(Relationship)[1]', 'INT'), ''),
		NULLIF(T.I.value('(Profession)[1]', 'INT'), ''),
		NULLIF(T.I.value('(Education)[1]', 'INT'), ''),
		NULLIF(T.I.value('(Email)[1]', 'NVARCHAR(100)'), ''),
		NULLIF(T.I.value('(TypeOfId)[1]', 'NVARCHAR(1)'), ''),
		NULLIF(T.I.value('(HFID)[1]', 'INT'), ''),
		NULLIF(T.I.value('(CurrentAddress)[1]', 'NVARCHAR(200)'), ''),
		NULLIF(T.I.value('(GeoLocation)[1]', 'NVARCHAR(250)'), ''),
		NULLIF(T.I.value('(CurVillage)[1]', 'INT'), ''),
		NULLIF(T.I.value('(PhotoPath )[1]', 'NVARCHAR(100)'), ''),
		NULLIF(T.I.value('(IdentificationNumber)[1]', 'NVARCHAR(50)'), ''),
		T.I.value('(isOffline)[1]','INT'),
		CASE WHEN T.I.value('(EffectiveDate)[1]', 'DATE')='1900-01-01' THEN NULL ELSE T.I.value('(EffectiveDate)[1]', 'DATE') END
		FROM @xml.nodes('Enrollment/Insuree') AS T(I)

		
		INSERT INTO @Policy(PolicyId, FamilyId, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdId, OfficerId, PolicyStage,isOffline)
		SELECT 
		T.P.value('(PolicyId)[1]', 'INT'),
		T.P.value('(FamilyId)[1]', 'INT'),
		T.P.value('(EnrollDate)[1]', 'DATE'),
		NULLIF(T.P.value('(StartDate)[1]', 'DATE'), ''),
		NULLIF(T.P.value('(EffectiveDate)[1]', 'DATE'), ''),
		NULLIF(T.P.value('(ExpiryDate)[1]', 'DATE'), ''),
		T.P.value('(PolicyStatus)[1]', 'INT'),
		NULLIF(T.P.value('(PolicyValue)[1]', 'DECIMAL'), 0),
		T.P.value('(ProdId)[1]', 'INT'),
		T.P.value('(OfficerId)[1]', 'INT'),
		ISNULL(NULLIF(T.P.value('(PolicyStage)[1]', 'CHAR(1)'), ''), N'N'),
		T.P.value('(isOffline)[1]','INT')
		FROM @xml.nodes('Enrollment/Policy') AS T(P)

		INSERT INTO @Premium(PremiumId, PolicyId, PayerId, Amount, Receipt, PayDate, PayType, isPhotoFee,isOffline)
		SELECT 
		T.PR.value('(PremiumId)[1]', 'INT'),
		T.PR.value('(PolicyId)[1]', 'INT'),
		NULLIF(T.PR.value('(PayerId)[1]', 'INT'), 0),
		T.PR.value('(Amount)[1]', 'DECIMAL'),
		T.PR.value('(Receipt)[1]', 'NVARCHAR(50)'),
		T.PR.value('(PayDate)[1]', 'DATE'),
		T.PR.value('(PayType)[1]', 'CHAR(1)'),
		T.PR.value('(isPhotoFee)[1]', 'BIT'),
		T.PR.value('(isOffline)[1]','INT')
		FROM @xml.nodes('Enrollment/Premium') AS T(PR)

		
		

		DECLARE @FamilyId INT = 0,
				@HOFId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@ProdId INT,
				@PolicyStage CHAR(1),
				@EnrollDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId INT,
				
				@CurInsureeId INT,
				@CurIsOffline INT,
				@CurHFID NVARCHAR(12),
				@CurFamilyId INT,
				
				@GivenPolicyValue DECIMAL(18, 4),
				@NewPolicyId INT,
				@ReturnValue INT = 0;
		DECLARE @isOffline INT,
				@CHFID NVARCHAR(12)
			--PREMIUM
			DECLARE @PremiumID INT,
					@Contribution DECIMAL(18,2) ,
					@EffectiveDate DATE,
					@AssociatedPhotoFolder NVARCHAR(255)

	SET @AssociatedPhotoFolder=(SELECT AssociatedPhotoFolder FROM tblIMISDefaults)
		--TEMP tables
		--IF NOT  OBJECT_ID('TempFamily') IS NULL
		--DROP TABLE TempFamily
		--SELECT * INTO TempFamily FROM @Family
		--IF NOT OBJECT_ID('TempInsuree') IS NULL
		--DROP TABLE TempInsuree
		--SELECT * INTO TempInsuree FROM @Insuree
		--IF NOT OBJECT_ID('TempPolicy') IS NULL
		--DROP TABLE TempPolicy
		--SELECT * INTO TempPolicy FROM @Policy
		--IF NOT OBJECT_ID('TempPremium') IS NULL
		--DROP TABLE TempPremium
		--SELECT * INTO TempPremium FROM @Premium
		--RETURN
		--end temp tables
	--CHFID for HOF, Amani 14.12.2017
	DECLARE @HOFCHFID NVARCHAR(12) =''
			
		---Added by Amani to Grab CHFID of HED
		SELECT @HOFCHFID =HOFCHFID FROM @Family F 
		--END
		--<newchanges>
		--Validations
		IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE IsHead=1 AND CHFID=@HOFCHFID AND ValidityTo IS NULL)
		BEGIN--NEW FAMILY BEGIN
		---NEW FAMILY HERE
		BEGIN TRY

		--Amani Added 25.01.2018
		IF NOT EXISTS(SELECT 1 FROM @Insuree  WHERE IsHead = 1)
			BEGIN
			--RETURN -1;
			--Make the first insuree to be head if there is no HOF by Amani & Hiren 19/02/2018
			UPDATE @Insuree SET IsHead =1 WHERE InsureeId=(SELECT TOP 1 InsureeId FROM @Insuree)
			END
			
		--end added by Amani
		IF EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID AND ABS(dt.InsureeId) <> I.InsureeID
				  WHERE I.ValidityTo IS NULL AND dt.IsHead = 1 AND I.IsHead = 1)
			RETURN -2;

		IF EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID  AND dt.InsureeId <> I.InsureeID
				  WHERE I.ValidityTo IS NULL AND dt.isOffline = 1)
			RETURN -3;

		IF EXISTS(SELECT 1
					FROM @Premium dtPR
					INNER JOIN tblPremium PR ON PR.Receipt = dtPR.Receipt 
					INNER JOIN @Policy dtPL ON dtPL.PolicyId = dtPR.PolicyId
					INNER JOIN @Family dtF ON dtF.FamilyId = dtPL.FamilyID
					INNER JOIN tblVillages V ON V.VillageId = dtF.LocationId
					INNER JOIN tblWards W ON W.WardId = V.WardId
					INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId

					WHERE   dtPR.isOffline = 1
					AND PR.ValidityTo IS NULL)
			RETURN -4;
			--DROP TABLE Premium
			--SELECT * INTO Insuree FROM @Insuree
			--SELECT * INTO Policy FROM @Policy
			--SELECT * INTO Premium FROM @Premium
		BEGIN TRAN ENROLLFAMILY
		/****************************************************START INSERT FAMILY**********************************/


					
			SELECT @isOffline =F.isOffline, @CHFID=CHFID FROM @Family F
			INNER JOIN @Insuree I ON I.FamilyId =F.FamilyId
				
				IF EXISTS(SELECT 1 FROM @Family WHERE isOffline =1)
					BEGIN
						INSERT INTO tblFamilies(InsureeId, LocationId, Poverty, ValidityFrom, AuditUserId, isOffline, FamilyType,
						FamilyAddress, Ethnicity, ConfirmationNo, ConfirmationType)
						SELECT 0 InsureeId, LocationId, Poverty, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, FamilyType,
						FamilyAddress, Ethnicity, ConfirmationNo, ConfirmationType
						FROM @Family;
						SELECT @FamilyId = SCOPE_IDENTITY();
						UPDATE @Insuree SET FamilyId = @FamilyId
						UPDATE @Policy SET FamilyId =  @FamilyId
					END
			
				

		/****************************************************START INSERT INSUREE**********************************/
				SELECT @isOffline =I.isOffline, @CHFID=CHFID FROM @Insuree I
				
				--Insert insurees
				IF EXISTS(SELECT 1 FROM @Insuree WHERE isOffline = 1  )
						BEGIN
							DECLARE CurInsuree CURSOR FOR SELECT InsureeId, CHFID, isOffline,FamilyId FROM @Insuree WHERE isOffline = 1 --OR CHFID NOT IN (SELECT CHFID FROM tblInsuree WHERE ValidityTo IS NULL);
							OPEN CurInsuree
							FETCH NEXT FROM CurInsuree INTO @CurInsureeId, @CurHFID, @CurIsOffline, @CurFamilyId;
							WHILE @@FETCH_STATUS = 0
							BEGIN
							INSERT INTO tblInsuree(FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, ValidityFrom,
							AuditUserId, isOffline, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage)
							SELECT @CurFamilyId FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, GETDATE() ValidityFrom,
							@AuditUserId AuditUserId, 0 isOffline, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage
							FROM @Insuree WHERE InsureeId = @CurInsureeId;
							DECLARE @NewInsureeId  INT  =0
							SELECT @NewInsureeId = SCOPE_IDENTITY();
							IF @isOffline <> 1 AND @ReturnValue = 0 SET @ReturnValue = @NewInsureeId
							UPDATE @Insuree SET InsureeId = @NewInsureeId WHERE InsureeId = @CurInsureeId
							--Insert photo entry
							INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
							SELECT I.InsureeId, I.CHFID, @AssociatedPhotoFolder + '\\' PhotoFolder, dt.PhotoPath, @OfficerId OfficerId, GETDATE() PhotoDate, GETDATE() ValidityFrom, @AuditUserId AuditUserId
							FROM tblInsuree I 
							INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID
							--WHERE I.FamilyId = @CurFamilyId
							WHERE dt.InsureeId=@NewInsureeId
							AND ValidityTo IS NULL;

							--Update photoId in Insuree
							UPDATE I SET PhotoId = PH.PhotoId, I.PhotoDate = PH.PhotoDate
							FROM tblInsuree I
							INNER JOIN tblPhotos PH ON PH.InsureeId = I.InsureeId
							WHERE I.FamilyId = @CurFamilyId;
					FETCH NEXT FROM CurInsuree INTO @CurInsureeId, @CurHFID, @CurIsOffline, @CurFamilyId;
					END
					CLOSE CurInsuree
					DEALLOCATE CurInsuree;	
				
			
				
					
					
					--Get the id of the HOF and update Family
					--SELECT @HOFId = InsureeId FROM tblInsuree WHERE FamilyId = @FamilyId AND IsHead = 1
					SELECT @HOFId = InsureeId FROM @Insuree WHERE FamilyId = @FamilyId AND IsHead = 1
					UPDATE tblFamilies SET InsureeId = @HOFId WHERE Familyid = @FamilyId 
					
						END
				/****************************************************END INSERT INSUREE**********************************/



				/****************************************************END INSERT POLICIES**********************************/
				
				SELECT TOP 1 @isOffline = P.isOffline FROM @Policy P
				IF EXISTS(SELECT 1 FROM @Policy WHERE isOffline = 1)
				BEGIN		
					--INSERT POLICIES
						DECLARE CurOfflinePolicy CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, EnrollDate,FamilyId FROM @Policy WHERE isOffline = 1 OR PolicyId NOT IN (SELECT PolicyId FROM tblPolicy WHERE ValidityTo	 IS NULL);
						OPEN CurOfflinePolicy
							FETCH NEXT FROM CurOfflinePolicy INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate,@FamilyId;
							WHILE @@FETCH_STATUS = 0
							BEGIN

								EXEC @PolicyValue = uspPolicyValue @FamilyId,
																	@ProdId,
																	0,
																	@PolicyStage,
																	@EnrollDate,
																	0,
																	@ErrorCode OUTPUT;


								SELECT @GivenPolicyValue = PolicyValue, @PolicyStatus = PolicyStatus FROM @Policy WHERE PolicyId = @PolicyId;
								INSERT INTO tblPolicy(FamilyId, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, 
								ProdId, OfficerId, ValidityFrom, AuditUserId, isOffline, PolicyStage)
								SELECT @FamilyId FamilyId, EnrollDate, StartDate, EffectiveDate, ExpiryDate, @PolicyStatus PolicyStatus, @PolicyValue PolicyValue, 
								ProdId, OfficerId, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, @PolicyStage PolicyStage
								FROM @Policy
								WHERE PolicyId = @PolicyId;

								SELECT @NewPolicyId = SCOPE_IDENTITY();
								UPDATE @Premium SET PolicyId = @NewPolicyId WHERE PolicyId = @PolicyId 
								IF @isOffline <> 1 AND @ReturnValue = 0  
									BEGIN
										SET @ReturnValue = @NewPolicyId;
										--AND isOffline = 0
									END
								--Insert policy Insuree
														
								;WITH IP AS
								(
								SELECT ROW_NUMBER() OVER(ORDER BY InsureeId)RNo,
								Prod.MemberCount,  I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,PL.ExpiryDate,PL.AuditUserID,I.isOffline
								FROM tblInsuree I
								INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
								INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdID
								WHERE(I.ValidityTo Is NULL)
								AND PL.ValidityTo IS NULL
								AND Prod.ValidityTo IS NULL
								AND PL.PolicyID = @NewPolicyId
								)
								INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,ExpiryDate,AuditUserId,isOffline)
								SELECT InsureeId, PolicyId, EnrollDate, StartDate, ExpiryDate, AuditUserId, @IsOffLine
								FROM IP
								WHERE RNo <= MemberCount;
								

								IF   EXISTS(SELECT 1 FROM @Premium WHERE isOffline = 1)
								BEGIN
									INSERT INTO tblPremium(PolicyId, PayerId, Amount, Receipt, PayDate, PayType, ValidityFrom, AuditUserId, isOffline, isPhotoFee)
									SELECT  PolicyId, PayerId, Amount, Receipt, PayDate, PayType, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, isPhotoFee 
									FROM @Premium
									WHERE PolicyId = @NewPolicyId;

									IF(@GivenPolicyValue >= @PolicyValue)
									BEGIN
										UPDATE tblInsureePolicy SET EffectiveDate = PL.EffectiveDate,StartDate = PL.StartDate, ExpiryDate = PL.ExpiryDate 
										FROM tblInsureePolicy I 
										INNER JOIN tblPolicy PL ON I.PolicyId = PL.PolicyId 
										WHERE I.ValidityTo IS NULL 
										AND PL.ValidityTo IS NULL 
										AND PL.PolicyId = @NewPolicyId;
									END
								END

		
								FETCH NEXT FROM CurOfflinePolicy INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @FamilyId;
						END
					CLOSE CurOfflinePolicy
					DEALLOCATE CurOfflinePolicy;
				END
	/****************************************************END INSERT POLICIES**********************************/
			
	/****************************************************START UPDATE PREMIUM**********************************/
		
		
						IF  EXISTS(SELECT 1 FROM @Premium dt 
									  LEFT JOIN tblPremium P ON P.PremiumId = dt.PremiumId 
										WHERE P.ValidityTo IS NULL AND dt.isOffline <> 1 AND P.PremiumId IS NULL)
							BEGIN
								--INSERTPREMIMIUN
									INSERT INTO tblPremium(PolicyId, PayerId, Amount, Receipt, PayDate, PayType, ValidityFrom, AuditUserId, isOffline, isPhotoFee)
												SELECT     PolicyId, PayerId, Amount, Receipt, PayDate, PayType, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, isPhotoFee 
												FROM @Premium
												WHERE @isOffline <> 1;
												SELECT @PremiumId = SCOPE_IDENTITY();
								IF @isOffline <> 1 AND ISNULL(@PremiumId,0) >0 AND @ReturnValue =0 SET @ReturnValue = @PremiumId
							END
						

	/****************************************************END INSERT PREMIUM**********************************/

		COMMIT TRAN ENROLLFAMILY;
		SET @ErrorMessage = '';
		RETURN @ReturnValue;
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK TRAN ENROLLFAMILY;
		RETURN -400;
	END CATCH
		SELECT 1
		END
		ELSE
		BEGIN---BEGIN EXISTING  FAMILY
	BEGIN TRY
	
		
		--IF   EXISTS(SELECT 1 FROM @Insuree WHERE IsHead = 0 AND isOffline = 1)
		--BEGIN
		--	UPDATE @Insuree SET IsHead = 1 WHERE InsureeId = (SELECT TOP 1 InsureeId FROM @Insuree ORDER BY InsureeId)
		--END

		--Amani Added 25.01.2018
		--IF NOT EXISTS(SELECT 1 FROM tblInsuree I 
		--		  INNER JOIN @Insuree dt ON dt.FamilyId = I.FamilyId
		--		  WHERE I.ValidityTo IS NULL AND I.IsHead = 1)
		--	RETURN -1;
		--end added by Amani
		IF EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID AND ABS(dt.InsureeId) <> I.InsureeID
				  WHERE I.ValidityTo IS NULL AND dt.IsHead = 1 AND I.IsHead = 1)
			RETURN -2;

		IF EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID  AND dt.InsureeId <> I.InsureeID
				  WHERE I.ValidityTo IS NULL AND dt.isOffline = 1)
			RETURN -3;

		IF EXISTS(SELECT 1
					FROM @Premium dtPR
					INNER JOIN tblPremium PR ON PR.Receipt = dtPR.Receipt 
					INNER JOIN @Policy dtPL ON dtPL.PolicyId = dtPR.PolicyId
					INNER JOIN @Family dtF ON dtF.FamilyId = dtPL.FamilyID
					INNER JOIN tblVillages V ON V.VillageId = dtF.LocationId
					INNER JOIN tblWards W ON W.WardId = V.WardId
					INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
					WHERE   dtPR.isOffline = 1)
			RETURN -4;
			--DROP TABLE Premium
			--SELECT * INTO Insuree FROM @Insuree
			--SELECT * INTO Policy FROM @Policy
			--SELECT * INTO Premium FROM @Premium
		BEGIN TRAN UPDATEFAMILY
		/****************************************************START INSERT FAMILY**********************************/

			SELECT @FamilyId = FamilyID FROM tblInsuree WHERE IsHead=1 AND CHFID=@HOFCHFID AND ValidityTo IS NULL		
			SELECT @isOffline =F.isOffline, @CHFID=CHFID FROM @Family F
			INNER JOIN @Insuree I ON I.FamilyId =F.FamilyId
				
				IF EXISTS(SELECT 1 FROM @Family WHERE isOffline =1)
					BEGIN
						INSERT INTO tblFamilies(InsureeId, LocationId, Poverty, ValidityFrom, AuditUserId, isOffline, FamilyType,
						FamilyAddress, Ethnicity, ConfirmationNo, ConfirmationType)
						SELECT 0 InsureeId, LocationId, Poverty, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, FamilyType,
						FamilyAddress, Ethnicity, ConfirmationNo, ConfirmationType
						FROM @Family;
						SELECT @FamilyId = SCOPE_IDENTITY();
						UPDATE @Insuree SET FamilyId = @FamilyId
						UPDATE @Policy SET FamilyId =  @FamilyId
					END
				ELSE
					BEGIN
						
						--Insert History Record
						INSERT INTO tblFamilies ([insureeid],[Poverty],[ConfirmationType],isOffline,[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],FamilyType, FamilyAddress,Ethnicity,ConfirmationNo, LocationId) 
						SELECT [insureeid],[Poverty],[ConfirmationType],isOffline,[ValidityFrom],getdate(),@FamilyID, @AuditUserID,FamilyType, FamilyAddress,Ethnicity,ConfirmationNo,LocationId FROM tblFamilies where FamilyID = @FamilyID;
						

						
						--Update Family
						UPDATE @Family SET FamilyId = @FamilyId
						UPDATE @Policy SET FamilyId =  @FamilyId
						 UPDATE  dst  SET dst.[Poverty] = src.Poverty,  dst.[ConfirmationType] = src.ConfirmationType, isOffline=0, dst.[ValidityFrom]=GETDATE(), dst.[AuditUserID] = @AuditUserID, dst.FamilyType = src.FamilyType,  dst.FamilyAddress = src.FamilyAddress,
										   dst.Ethnicity = src.Ethnicity,  dst.ConfirmationNo = src.ConfirmationNo,  dst.LocationId = src.LocationId
						 FROM tblFamilies dst
						 INNER JOIN @Family src ON src.FamilyID = dst.FamilyID
					--	 WHERE  dst.FamilyID = @FamilyID;
					
					END
		/*******************************************************END INSERT FAMILY**********************************/		
				

		/****************************************************START INSERT INSUREE**********************************/
				SELECT @isOffline =I.isOffline, @CHFID=CHFID FROM @Insuree I
				
				--Insert insurees
				IF EXISTS(SELECT 1 FROM @Insuree WHERE isOffline = 1  )
						BEGIN
INSERTINSUREE:
								DECLARE CurInsuree CURSOR FOR SELECT InsureeId, CHFID, isOffline FROM @Insuree WHERE isOffline = 1 OR CHFID NOT IN (SELECT CHFID FROM tblInsuree WHERE ValidityTo IS NULL);
								OPEN CurInsuree
									FETCH NEXT FROM CurInsuree INTO @CurInsureeId, @CurHFID, @CurIsOffline;
									WHILE @@FETCH_STATUS = 0
									BEGIN
									INSERT INTO tblInsuree(FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, ValidityFrom,
									AuditUserId, isOffline, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage)
									SELECT @FamilyId FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, GETDATE() ValidityFrom,
									@AuditUserId AuditUserId, 0 isOffline, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage
									FROM @Insuree WHERE InsureeId = @CurInsureeId;
									DECLARE @NewExistingInsureeId  INT  =0
									SELECT @NewExistingInsureeId= SCOPE_IDENTITY();


									--Now we will insert new insuree in the table tblInsureePolicy
									 EXEC uspAddInsureePolicy @NewExistingInsureeId	


									IF @isOffline <> 1 AND @ReturnValue = 0 SET @ReturnValue = @NewExistingInsureeId
									UPDATE @Insuree SET InsureeId = @NewExistingInsureeId WHERE InsureeId = @CurInsureeId
									--Insert photo entry
									INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
									--SELECT I.InsureeId, I.CHFID, @AssociatedPhotoFolder+'\'PhotoFolder, dt.PhotoPath, @OfficerId OfficerId, GETDATE() PhotoDate, GETDATE() ValidityFrom, @AuditUserId AuditUserId
									--FROM tblInsuree I 
									--INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID
									----WHERE I.FamilyId = @FamilyId
									--WHERE dt.InsureeId=@NewInsureeId
									--AND ValidityTo IS NULL;

									SELECT @NewExistingInsureeId InsureeId, @CHFID CHFID, @AssociatedPhotoFolder photoFolder, PhotoPath photoFileName, @OfficerId OfficerID, getdate() photoDate, getdate() ValidityFrom,@AuditUserId AuditUserId
									FROM @Insuree WHERE InsureeId=@NewExistingInsureeId 

									--Update photoId in Insuree
									UPDATE I SET PhotoId = PH.PhotoId, I.PhotoDate = PH.PhotoDate
									FROM tblInsuree I
									INNER JOIN tblPhotos PH ON PH.InsureeId = I.InsureeId
									WHERE I.FamilyId = @FamilyId;
									FETCH NEXT FROM CurInsuree INTO @CurInsureeId, @CurHFID, @CurIsOffline;
									END
							CLOSE CurInsuree
							DEALLOCATE CurInsuree;
					
					
							--Get the id of the HOF and update Family
							SELECT @HOFId = InsureeId FROM tblInsuree WHERE FamilyId = @FamilyId AND IsHead = 1
							UPDATE tblFamilies SET InsureeId = @HOFId WHERE Familyid = @FamilyId 
					
					END
				ELSE
					BEGIN
						IF EXISTS (
								SELECT 1 FROM @Insuree dt 
								LEFT JOIN tblInsuree I ON I.CHFID = dt.CHFID AND I.ValidityTo IS NULL 
								WHERE  I.InsureeID IS NULL AND dt.isOffline =0 
									)
							BEGIN
								--SET @FamilyId = (SELECT TOP 1 FamilyId FROM @Family)
								GOTO INSERTINSUREE;
							END
									
						ELSE
						BEGIN
							DECLARE CurUpdateInsuree CURSOR FOR SELECT  TI.CHFID FROM @Insuree TI INNER JOIN tblInsuree I ON TI.CHFID=I.CHFID WHERE  I.ValidityTo IS NULL;
							OPEN CurUpdateInsuree
							FETCH NEXT FROM CurUpdateInsuree INTO  @CHFID;
								WHILE @@FETCH_STATUS = 0
								BEGIN
									DECLARE @InsureeId INT,
											@PhotoFileName NVARCHAR(200)
									
									update @Insuree set InsureeId = (select TOP 1 InsureeId from tblInsuree where CHFID = @CHFID and ValidityTo is null)
									where CHFID = @CHFID;

									SELECT @InsureeId = InsureeId, @PhotoFileName = PhotoPath FROM @Insuree WHERE CHFID = @CHFID;
									--Insert Insuree History
									INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],						[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
									SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,GETDATE(),InsureeID,[Relationship],[Profession],[Education],[Email] ,[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage] 
									FROM tblInsuree WHERE InsureeID = @InsureeId; 

									

									UPDATE dst SET dst.[CHFID] = @CHFID, dst.[LastName] = src.LastName,dst.[OtherNames] = src.OtherNames,dst.[DOB] = src.DOB,dst.[Gender] = src.Gender ,dst.[Marital] = src.Marital,dst.[passport] = src.passport,dst.[Phone] = src.Phone,dst.[PhotoDate] = GETDATE(),dst.[CardIssued] = src.CardIssued,dst.isOffline=0,dst.[ValidityFrom] = GetDate(),dst.[AuditUserID] = @AuditUserID ,dst.[Relationship] = src.Relationship, dst.[Profession] = src.Profession, dst.[Education] = src.Education,dst.[Email] = src.Email ,dst.TypeOfId = src.TypeOfId,dst.HFID = src.HFID, dst.CurrentAddress = src.CurrentAddress, dst.CurrentVillage = src.CurrentVillage, dst.GeoLocation = src.GeoLocation 
									FROM tblInsuree dst
									LEFT JOIN @Insuree src ON src.InsureeId = dst.InsureeID
									WHERE dst.InsureeId = @InsureeId;

									--Insert Photo  History
									DECLARE @PhotoId INT =  (SELECT PhotoID from tblInsuree where CHFID = @CHFID AND LegacyID is NULL and ValidityTo is NULL) 
									INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,PhotoDate,OfficerID,ValidityFrom,ValidityTo,AuditUserID) 
									SELECT InsureeID,CHFID,PhotoFolder,PhotoFileName,PhotoDate,OfficerID,ValidityFrom,GETDATE(),AuditUserID 
									FROM tblPhotos WHERE PhotoID = @PhotoID;

									--Update Photo
								
									UPDATE tblPhotos SET PhotoFolder = @AssociatedPhotoFolder+'\\',PhotoFileName = @PhotoFileName, OfficerID = @OfficerID, ValidityFrom = GETDATE(), AuditUserID = @AuditUserID 
									WHERE PhotoID = @PhotoID
								FETCH NEXT FROM CurUpdateInsuree INTO  @CHFID;
								END
							CLOSE CurUpdateInsuree
							DEALLOCATE CurUpdateInsuree;

						END
						
						END
				/****************************************************END INSERT INSUREE**********************************/



				/****************************************************END INSERT POLICIES**********************************/
				
				SELECT TOP 1 @isOffline = P.isOffline FROM @Policy P
				IF EXISTS(SELECT 1 FROM @Policy WHERE isOffline = 1)
				BEGIN

		INSERTPOLICY:
		DECLARE @isOfflinePolicy bit=0;
		
					--INSERT POLICIES
						DECLARE CurPolicy CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, EnrollDate,FamilyId,isOffline FROM @Policy WHERE isOffline = 1 OR PolicyId NOT IN (SELECT PolicyId FROM tblPolicy WHERE ValidityTo	 IS NULL);
						OPEN CurPolicy
							FETCH NEXT FROM CurPolicy INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate,@FamilyId,@isOfflinePolicy;
							WHILE @@FETCH_STATUS = 0
							BEGIN

								EXEC @PolicyValue = uspPolicyValue @FamilyId,
																	@ProdId,
																	0,
																	@PolicyStage,
																	@EnrollDate,
																	0,
																	@ErrorCode OUTPUT;


								SELECT @GivenPolicyValue = PolicyValue, @PolicyStatus = PolicyStatus FROM @Policy WHERE PolicyId = @PolicyId;
								IF @GivenPolicyValue < @PolicyValue

								--amani 17/12/2017
								if NOT @isOfflinePolicy =1
									SET @PolicyStatus = 1
								ELSE
									SET @PolicyStatus=2

								INSERT INTO tblPolicy(FamilyId, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, 
								ProdId, OfficerId, ValidityFrom, AuditUserId, isOffline, PolicyStage)
								SELECT @FamilyId FamilyId, EnrollDate, StartDate, EffectiveDate, ExpiryDate, @PolicyStatus PolicyStatus, @PolicyValue PolicyValue, 
								ProdId, OfficerId, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, @PolicyStage PolicyStage
								FROM @Policy
								WHERE PolicyId = @PolicyId;

								SELECT @NewPolicyId = SCOPE_IDENTITY();
								UPDATE @Premium SET PolicyId = @NewPolicyId WHERE PolicyId = @PolicyId 



								IF @isOffline <> 1 AND @ReturnValue = 0  
									BEGIN
										SET @ReturnValue = @NewPolicyId;
										--AND isOffline = 0
									END
								--Insert policy Insuree
								
								----Amani added for Only New Family
								--IF EXISTS(SELECT 1 FROM tblFamilies F INNER JOIN tblInsuree I ON I.FamilyID=F.FamilyID
								--WHERE F.ValidityTo IS NULL AND I.ValidityTo IS NULL AND I.CHFID=@HOFCHFID)

				
								IF   EXISTS(SELECT 1 FROM @Premium WHERE isOffline = 1)
								BEGIN
									INSERT INTO tblPremium(PolicyId, PayerId, Amount, Receipt, PayDate, PayType, ValidityFrom, AuditUserId, isOffline, isPhotoFee)
									SELECT  PolicyId, PayerId, Amount, Receipt, PayDate, PayType, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, isPhotoFee 
									FROM @Premium
									WHERE PolicyId = @NewPolicyId;
								END


								BEGIN--Existing Family


								--SELECT InsureeID FROM tblInsuree WHERE FamilyID IN (SELECT FamilyID FROM tblPolicy WHERE PolicyID=@NewPolicyId AND ValidityTo IS NULL) AND ValidityTo IS NULL ORDER BY InsureeID ASC


										--DECLARE @NewCurrentInsureeId INT =0
										--DECLARE CurNewCurrentInsuree CURSOR FOR 	
										--SELECT InsureeID FROM tblInsuree WHERE FamilyID IN (SELECT FamilyID FROM tblPolicy WHERE PolicyID=@NewPolicyId AND ValidityTo IS NULL) AND ValidityTo IS NULL 
										--AND InsureeID NOT IN (SELECT InsureeID FROM tblInsureePolicy WHERE PolicyID=@NewPolicyId AND ValidityTo IS NULL)
										--ORDER BY InsureeID ASC
													--OPEN CurNewCurrentInsuree
														--FETCH NEXT FROM CurNewCurrentInsuree INTO @NewCurrentInsureeId
														--WHILE @@FETCH_STATUS = 0
														--BEGIN
														--Now we will insert new insuree in the table tblInsureePolicy
															EXEC uspAddInsureePolicyOffline  @NewPolicyId
															--FETCH NEXT FROM CurNewCurrentInsuree INTO @NewCurrentInsureeId
														--END
														
													--CLOSE CurNewCurrentInsuree
													--DEALLOCATE CurNewCurrentInsuree						
								END 

					
								FETCH NEXT FROM CurPolicy INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @FamilyId,@isOfflinePolicy;
						END
					CLOSE CurPolicy
					DEALLOCATE CurPolicy;
				END
			ELSE
				BEGIN 
					IF EXISTS (SELECT 1 FROM @Policy dt 
								WHERE   dt.IsOffline = 0 
								AND		dt.PolicyId NOT IN(SELECT PolicyId FROM tblPolicy WHERE ValidityTo IS NULL ) 
									 
							)
					BEGIN
						GOTO INSERTPOLICY;
					END
					--ELSE
					-- BEGIN
					----	SELECT TOP 1 @PolicyId = PolicyId  FROM @Policy 
					--	--INSERT Policy History
					--	INSERT INTO tblPolicy (FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStage,PolicyStatus,PolicyValue,isOffline, ValidityTo, LegacyID, AuditUserID)
					--	SELECT FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStage,PolicyStatus,PolicyValue,isOffline, GETDATE(), @PolicyID, AuditUserID FROM tblPolicy WHERE PolicyID = @PolicyID;
					--	--Update Policy Record
					--	UPDATE dst SET OfficerID= src.OfficerID, ValidityFrom=GETDATE(), AuditUserID = @AuditUserID 
					--	FROM tblPolicy dst
					--	INNER JOIN @Policy src ON src.PolicyId = dst.PolicyID
					----	WHERE src.PolicyID=@PolicyID
					--END
				END

	/****************************************************END INSERT POLICIES**********************************/
			
	/****************************************************START UPDATE PREMIUM**********************************/


			
			--SELECT TOP 1 @isOffline =  P.isOffline,  @PolicyId = PolicyId,@PremiumID=PremiumId FROM @Premium P WHERE isOffline   <> 1
			--IF @isOffline != 1
			--	BEGIN
				 
			--			IF  EXISTS(SELECT 1 FROM @Premium dt 
			--						  LEFT JOIN tblPremium P ON P.PremiumId = dt.PremiumId 
			--							WHERE P.ValidityTo IS NULL AND dt.isOffline <> 1 AND P.PremiumId IS NULL)
			--				BEGIN
			--					--INSERTPREMIMIUN
			--						INSERT INTO tblPremium(PolicyId, PayerId, Amount, Receipt, PayDate, PayType, ValidityFrom, AuditUserId, isOffline, isPhotoFee)
			--									SELECT     PolicyId, PayerId, Amount, Receipt, PayDate, PayType, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, isPhotoFee 
			--									FROM @Premium
			--									WHERE @isOffline <> 1;
			--									SELECT @PremiumId = SCOPE_IDENTITY();
			--					IF @isOffline <> 1 AND ISNULL(@PremiumId,0) >0 AND @ReturnValue =0 SET @ReturnValue = @PremiumId
			--				END
			--			ELSE
			--				BEGIN
			--					INSERT INTO tblPremium (PolicyID, PayerID, Amount, Receipt, PayDate, PayType,isOffline, ValidityTo, LegacyID, AuditUserID,isPhotoFee) 
			--					SELECT PolicyID, PayerID, Amount, Receipt, PayDate, PayType,isOffline, GETDATE(), @PremiumID, AuditUserID,isPhotoFee FROM tblPremium where PremiumID = @PremiumID;
				
			--					UPDATE dst set dst.PolicyID= src.PolicyID, dst.PayerID = src.PayerID, dst.Amount = src.Amount, dst.Receipt = src.Receipt, dst.PayDate =  src.PayDate, dst.PayType = src.PayType, 
			--											dst.ValidityFrom=GETDATE(), dst.LegacyID = @PremiumID, dst.AuditUserID = @AuditUserID,dst.isPhotoFee = src.isPhotoFee 
			--					FROM tblPremium dst
			--					INNER JOIN @Premium src ON src.PremiumId = dst.PremiumId
			--					--WHERE dst.PremiumID=@PremiumID;
													
			--				END
			--	 --Update InsureePolicy and Policy Table
			--	 SELECT TOP 1  @PremiumID= PremiumId , @FamilyId = FamilyId, @ProdId = Po.ProdId, @PolicyStage = PolicyStage,@EnrollDate = EnrollDate, @EffectiveDate = PayDate, @PolicyStatus = PolicyStatus
			--				FROM tblPremium P
			--				INNER JOIN tblPolicy Po ON Po.PolicyId = P.PolicyId
			--				WHERE PremiumId = @PremiumID 
			--	 EXEC @PolicyValue = uspPolicyValue		@FamilyId,
			--											@ProdId,
			--											0,
			--											@PolicyStage,
			--											@EnrollDate,
			--											0,
			--											@ErrorCode OUTPUT;
			--		SELECT @Contribution = SUM(AMOUNT) FROM tblPremium where PolicyID =@PolicyId AND ValidityTo IS NULL AND isPhotoFee = 0;
				  
			--		IF @PolicyValue <= @Contribution
			--		BEGIN
			--			UPDATE tblPolicy SET PolicyStatus = 2,EffectiveDate = @EffectiveDate   WHERE PolicyID =  @PolicyId AND ValidityTo IS NULL 
			--			UPDATE tblInsureePolicy SET EffectiveDate = @EffectiveDate WHERE ValidityTo IS NULL AND EffectiveDate IS NULL AND PolicyId = @PolicyId
			--		END
			--	END
	/****************************************************END INSERT PREMIUM**********************************/

		COMMIT TRAN UPDATEFAMILY;
		SET @ErrorMessage = '';
		RETURN @ReturnValue;
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK TRAN UPDATEFAMILY;
		RETURN -400;
	END CATCH
		END

END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE();
		--INSERT INTO @Result(ErrorMessage) values (@ErrorMessage)
		--IF NOT OBJECT_ID('TempResult') IS NULL
		--DROP TABLE TempResult
		--SELECT * INTO TempResult FROM @Result
		--IF @@TRANCOUNT > 0 ROLLBACK TRAN ENROLLFAMILY;
		RETURN -400;
	END CATCH

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspUploadEnrolments](
	--@File NVARCHAR(300),
	@XML XML,
	@FamilySent INT = 0 OUTPUT,
	@InsureeSent INT = 0 OUTPUT,
	@PolicySent INT = 0 OUTPUT,
	@PremiumSent INT = 0 OUTPUT,
	@FamilyImported INT = 0 OUTPUT,
	@InsureeImported INT = 0 OUTPUT,
	@PolicyImported INT = 0 OUTPUT,
	@PremiumImported INT = 0 OUTPUT 
)
AS
BEGIN
	DECLARE @Query NVARCHAR(500)
	--DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,EffectiveDate DATE, NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)

	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)
	DECLARE @AuditUserId INT =-1

	BEGIN TRY

		--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE FAMILY FROM THE XML
		INSERT INTO @tblFamilies(FamilyId,InsureeId,CHFID, LocationId,Poverty,FamilyType,FamilyAddress,Ethnicity, ConfirmationNo)
		SELECT 
		T.F.value('(FamilyId)[1]','INT'),
		T.F.value('(InsureeId)[1]','INT'),
		T.F.value('(CHFID)[1]','NVARCHAR(12)'),
		T.F.value('(LocationId)[1]','INT'),
		T.F.value('(Poverty)[1]','BIT'),
		T.F.value('(FamilyType)[1]','NVARCHAR(2)'),
		T.F.value('(FamilyAddress)[1]','NVARCHAR(200)'),
		T.F.value('(Ethnicity)[1]','NVARCHAR(1)'),
		T.F.value('(ConfirmationNo)[1]','NVARCHAR(12)')
		FROM @XML.nodes('Enrolment/Families/Family') AS T(F)
		
		--Get total number of families sent via XML
		SELECT @FamilySent = COUNT(*) FROM @tblFamilies

		--GET ALL THE INSUREES FROM XML
		INSERT INTO @tblInsuree(InsureeId,FamilyId,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Passport,Phone,CardIssued,Relationship,Profession,Education,Email, TypeOfId, HFID,EffectiveDate)
		SELECT
		T.I.value('(InsureeID)[1]','INT'),
		T.I.value('(FamilyID)[1]','INT'),
		T.I.value('(CHFID)[1]','NVARCHAR(12)'),
		T.I.value('(LastName)[1]','NVARCHAR(100)'),
		T.I.value('(OtherNames)[1]','NVARCHAR(100)'),
		T.I.value('(DOB)[1]','DATE'),
		T.I.value('(Gender)[1]','CHAR(1)'),
		T.I.value('(Marital)[1]','CHAR(1)'),
		T.I.value('(IsHead)[1]','BIT'),
		T.I.value('(passport)[1]','NVARCHAR(25)'),
		T.I.value('(Phone)[1]','NVARCHAR(50)'),
		T.I.value('(CardIssued)[1]','BIT'),
		T.I.value('(Relationship)[1]','SMALLINT'),
		T.I.value('(Profession)[1]','SMALLINT'),
		T.I.value('(Education)[1]','SMALLINT'),
		T.I.value('(Email)[1]','NVARCHAR(100)'),
		T.I.value('(TypeOfId)[1]','NVARCHAR(1)'),
		T.I.value('(HFID)[1]','INT'),
		T.I.value('(EffectiveDate)[1]','DATE')  
		FROM @XML.nodes('Enrolment/Insurees/Insuree') AS T(I)

		--Get total number of Insurees sent via XML
		SELECT @InsureeSent = COUNT(*) FROM @tblInsuree

		--GET ALL THE POLICIES FROM XML
		INSERT INTO @tblPolicy(PolicyId,FamilyId,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdId,OfficerId,PolicyStage)
		SELECT 
		T.P.value('(PolicyID)[1]','INT'),
		T.P.value('(FamilyID)[1]','INT'),
		T.P.value('(EnrollDate)[1]','DATE'),
		T.P.value('(StartDate)[1]','DATE'),
		T.P.value('(EffectiveDate)[1]','DATE'),
		T.P.value('(ExpiryDate)[1]','DATE'),
		T.P.value('(PolicyStatus)[1]','TINYINT'),
		T.P.value('(PolicyValue)[1]','DECIMAL(18,2)'),
		T.P.value('(ProdID)[1]','INT'),
		T.P.value('(OfficerID)[1]','INT'),
		T.P.value('(PolicyStage)[1]','CHAR(1)')
		FROM @XML.nodes('Enrolment/Policies/Policy') AS T(P)

		--Get total number of Policies sent via XML
		SELECT @PolicySent = COUNT(*) FROM @tblPolicy
			
		--GET ALL THE PREMIUMS FROM XML
		INSERT INTO @tblPremium(PremiumId,PolicyId,PayerId,Amount,Receipt,PayDate,PayType,isPhotoFee)
		SELECT
		T.PR.value('(PremiumId)[1]','INT'),
		T.PR.value('(PolicyID)[1]','INT'),
		T.PR.value('(PayerID)[1]','INT'),
		T.PR.value('(Amount)[1]','DECIMAL(18,2)'),
		T.PR.value('(Receipt)[1]','NVARCHAR(50)'),
		T.PR.value('(PayDate)[1]','DATE'),
		T.PR.value('(PayType)[1]','CHAR(1)'),
		T.PR.value('(isPhotoFee)[1]','BIT')
		FROM @XML.nodes('Enrolment/Premiums/Premium') AS T(PR)

		--Get total number of premium sent via XML
		SELECT @PremiumSent = COUNT(*) FROM @tblPremium;

		--Get total number of premium sent via XML
		--SELECT @PremiumSent = COUNT(*) FROM @tblPremium;

		--IF NOT OBJECT_ID('tempFamilies') IS NULL DROP TABLE tempFamilies
		--SELECT * INTO tempFamilies FROM @tblFamilies
		
		--IF NOT OBJECT_ID('tempInsuree') IS NULL DROP TABLE tempInsuree
		--SELECT * INTO tempInsuree FROM @tblInsuree
		
		--IF NOT OBJECT_ID('tempPolicy') IS NULL DROP TABLE tempPolicy
		--SELECT * INTO tempPolicy FROM @tblPolicy
		
		--IF NOT OBJECT_ID('tempPremium') IS NULL DROP TABLE tempPremium
		--SELECT * INTO tempPremium FROM @tblPremium
		--RETURN
		--DECLARE @AuditUserId INT 
		--	IF ( @XML.exist('(Enrolment/UserId)')=1 )
		--		SET	@AuditUserId= (SELECT T.PR.value('(UserId)[1]','INT') FROM @XML.nodes('Enrolment/UserId') AS T(PR))
		--	ELSE
		--		SET @AuditUserId=-1
		

		--DELETE ALL INSUREE WITH EFFECTIVE DATE
		SELECT 1 FROM @tblInsuree I
			LEFT OUTER JOIN (SELECT  CHFID  FROM @tblInsuree GROUP BY CHFID HAVING COUNT(CHFID) > 1) TI ON I.CHFID =TI.CHFID
			WHERE  TI.CHFID IS NOT NULL AND EffectiveDate IS NOT NULL
			


		IF EXISTS(
		--Insuree without family
		SELECT 1 
		FROM @tblInsuree I LEFT OUTER JOIN @tblFamilies F ON I.FamilyId = F.FamilyID
		WHERE F.FamilyID IS NULL

		UNION ALL

		--Policy without family
		SELECT 1 FROM
		@tblPolicy PL LEFT OUTER JOIN @tblFamilies F ON PL.FamilyId = F.FamilyId
		WHERE F.FamilyId IS NULL

		UNION ALL

		--Premium without policy
		SELECT 1
		FROM @tblPremium PR LEFT OUTER JOIN @tblPolicy P ON PR.PolicyId = P.PolicyId
		WHERE P.PolicyId  IS NULL
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h1 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h1>')
		
			RAISERROR (N'<h1 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h1>', 16, 1);
		END


		BEGIN TRAN ENROLL;

			DELETE F
			OUTPUT N'Insuree information is missing for Family with Insurance Number ' + QUOTENAME(deleted.CHFID) INTO @tblResult
			FROM @tblFamilies F
			LEFT OUTER JOIN @tblInsuree I ON F.CHFID = I.CHFID
			WHERE I.InsureeId IS NULL;

			INSERT INTO @tblResult(Result)
			SELECT N'Family with Insurance Number : ' + QUOTENAME(I.CHFID) + ' already exists' 
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL
			AND I.IsHead = 1;

			--Get the new FamilyId frmo DB and udpate @tblFamilies, @tblInsuree and @tblPolicy
			UPDATE TF SET NewFamilyId = I.FamilyID
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL
			AND I.IsHead = 1;

		
			UPDATE TI SET NewFamilyId = TF.NewFamilyId
			FROM @tblFamilies TF 
			INNER JOIN @tblInsuree TI ON TF.FamilyId = TI.FamilyId;

			UPDATE TP SET TP.NewFamilyId = TF.NewFamilyId
			FROM @tblFamilies TF
			INNER JOIN @tblPolicy TP ON TF.FamilyId = TP.FamilyId;

		
			--Insert new Families
			MERGE INTO tblFamilies 
			USING @tblFamilies AS TF ON 1 = 0 
			WHEN NOT MATCHED THEN 
				INSERT (InsureeId, LocationId, Poverty, ValidityFrom, AuditUserId, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo) 
				VALUES(0 , TF.LocationId, TF.Poverty, GETDATE() , @AuditUserId , TF.FamilyType, TF.FamilyAddress, TF.Ethnicity, TF.ConfirmationNo)
				OUTPUT TF.FamilyId, inserted.FamilyId INTO @tblIds;
		

			SELECT @FamilyImported = ISNULL(@@ROWCOUNT,0);

			--Update Family, Insuree and Policy with newly inserted FamilyId
			UPDATE TF SET NewFamilyId = ID.[NewId]
			FROM @tblFamilies TF
			INNER JOIN @tblIds ID ON TF.FamilyId = ID.OldId;

			UPDATE TI SET NewFamilyId = ID.[NewId]
			FROM @tblInsuree TI
			INNER JOIN @tblIds ID ON TI.FamilyId = ID.OldId;

			UPDATE TP SET NewFamilyId = ID.[NewId]
			FROM @tblPolicy TP
			INNER JOIN @tblIds ID ON TP.FamilyId = ID.OldId;

			--Clear the Ids table
			DELETE FROM @tblIds;

			--Delete duplicate insurees from table
			DELETE TI
			OUTPUT 'Insurance Number ' + QUOTENAME(deleted.CHFID) + ' already exists' INTO @tblResult
			FROM @tblInsuree TI 
			INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL;

			--Insert new insurees 
			MERGE tblInsuree
			USING (SELECT DISTINCT InsureeId, NewFamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, Passport, Phone, CardIssued, Relationship, Profession, Education, Email, TypeOfId, HFID FROM @tblInsuree ) TI ON 1 = 0
			WHEN NOT MATCHED THEN
				INSERT(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,passport,Phone,CardIssued,ValidityFrom,AuditUserID,Relationship,Profession,Education,Email,TypeOfId, HFID)
				VALUES(TI.NewFamilyId, TI.CHFID, TI.LastName, TI.OtherNames, TI.DOB, TI.Gender, TI.Marital, TI.IsHead, TI.Passport, TI.Phone, TI.CardIssued, GETDATE(), @AuditUserId, TI.Relationship, TI.Profession, TI.Education, TI.Email, TI.TypeOfId, TI.HFID)
				OUTPUT TI.InsureeId, inserted.InsureeId INTO @tblIds;


			SELECT @InsureeImported = ISNULL(@@ROWCOUNT,0);

			--Update Ids of newly inserted insurees 
			UPDATE TI SET NewInsureeId = Id.[NewId]
			FROM @tblInsuree TI 
			INNER JOIN @tblIds Id ON TI.InsureeId = Id.OldId;

			--Insert Photos
			INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
			SELECT NewInsureeId,CHFID,'','',0,GETDATE(),GETDATE() ValidityFrom, @AuditUserId AuditUserID 
			FROM @tblInsuree TI; 
		
			--Update tblInsuree with newly inserted PhotoId
			UPDATE I SET PhotoId = PH.PhotoId
			FROM @tblInsuree TI
			INNER JOIN tblPhotos PH ON TI.NewInsureeId = PH.InsureeID
			INNER JOIN tblInsuree I ON TI.NewInsureeId = I.InsureeID;


			--Update new InsureeId in tblFamilies
			UPDATE F SET InsureeId = TI.NewInsureeId
			FROM @tblInsuree TI 
			INNER JOIN tblInsuree I ON TI.NewInsureeId = I.InsureeId
			INNER JOIN tblFamilies F ON TI.NewFamilyId = F.FamilyID
			WHERE TI.IsHead = 1;

			--Clear the Ids table
			DELETE FROM @tblIds;

			INSERT INTO @tblIds
			SELECT TP.PolicyId, PL.PolicyID
			FROM tblPolicy PL 
			INNER JOIN @tblPolicy TP ON PL.FamilyID = TP.NewFamilyId 
									AND PL.EnrollDate = TP.EnrollDate 
									AND PL.StartDate = TP.StartDate 
									AND PL.ProdID = TP.ProdId 
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
			INNER JOIN tblInsuree I ON PL.FamilyId = I.FamilyId
			WHERE PL.ValidityTo IS NULL
			AND I.IsHead = 1;

		
			--Delete duplicate policies
			DELETE TP
			OUTPUT 'Policy for the family : ' + QUOTENAME(I.CHFID) + ' with Product Code:' + QUOTENAME(Prod.ProductCode) + ' already exists' INTO @tblResult
			FROM tblPolicy PL 
			INNER JOIN @tblPolicy TP ON PL.FamilyID = TP.NewFamilyId 
									AND PL.EnrollDate = TP.EnrollDate 
									AND PL.StartDate = TP.StartDate 
									AND PL.ProdID = TP.ProdId 
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
			INNER JOIN tblInsuree I ON PL.FamilyId = I.FamilyId
			WHERE PL.ValidityTo IS NULL
			AND I.IsHead = 1;

			--Update Premium table 
			UPDATE TPR SET NewPolicyId = Id.[NewId]
			FROM @tblPremium TPR 
			INNER JOIN @tblIds Id ON TPR.PolicyId = Id.OldId;
		
	
			--Clear the Ids table
			DELETE FROM @tblIds;

			--Insert new policies
			MERGE tblPolicy
			USING @tblPolicy TP ON 1 = 0
			WHEN NOT MATCHED THEN
				INSERT(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID)
				VALUES(TP.NewFamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),@AuditUserId)
			OUTPUT TP.PolicyId, inserted.PolicyId INTO @tblIds;
		
			SELECT @PolicyImported = ISNULL(@@ROWCOUNT,0);


			--Update new PolicyId
			UPDATE TP SET NewPolicyId = Id.[NewId]
			FROM @tblPolicy TP
			INNER JOIN @tblIds Id ON TP.PolicyId = Id.OldId;

			UPDATE TPR SET NewPolicyId = TP.NewPolicyId
			FROM @tblPremium TPR
			INNER JOIN @tblPolicy TP ON TPR.PolicyId = TP.PolicyId;
		
	

			--Delete duplicate Premiums
			DELETE TPR
			OUTPUT 'Premium on receipt number ' + QUOTENAME(PR.Receipt) + ' already exists.' INTO @tblResult
			--OUTPUT deleted.*
			FROM tblPremium PR
			INNER JOIN @tblPremium TPR ON PR.Amount = TPR.Amount 
										AND PR.Receipt = TPR.Receipt 
										AND PR.PolicyID = TPR.NewPolicyId
			WHERE PR.ValidityTo IS NULL
		
			--Insert Premium
			INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee)
			SELECT NewPolicyId,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),@AuditUserId,isPhotoFee 
			FROM @tblPremium
		
			SELECT @PremiumImported = ISNULL(@@ROWCOUNT,0);


			--TODO: Insert the InsureePolicy Table 
			--Create a cursor and loop through each new insuree 
	
			DECLARE @InsureeId INT
			DECLARE CurIns CURSOR FOR SELECT NewInsureeId FROM @tblInsuree;
			OPEN CurIns;
			FETCH NEXT FROM CurIns INTO @InsureeId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC uspAddInsureePolicy @InsureeId;
				FETCH NEXT FROM CurIns INTO @InsureeId;
			END
			CLOSE CurIns;
			DEALLOCATE CurIns; 
	
	IF EXISTS(SELECT COUNT(1) 
			FROM tblInsuree 
			WHERE ValidityTo IS NULL
			AND IsHead = 1
			GROUP BY FamilyID
			HAVING COUNT(1) > 1)
	
			
			--Added by Amani
			BEGIN
					DELETE FROM @tblResult;
					SET @FamilyImported = 0;
					SET @InsureeImported  = 0;
					SET @PolicyImported  = 0;
					SET @PremiumImported  = 0 
					INSERT INTO @tblResult VALUES
						(N'<h3 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h3>')
						--GOTO EndOfTheProcess;
						RAISERROR(N'Double HOF Found',16,1)	
					END


		COMMIT TRAN ENROLL;

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK TRAN ENROLL;
	END CATCH

	SELECT Result FROM @tblResult;
	RETURN 0;
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone](
	--@File NVARCHAR(300),
	@XML XML,
	@FamilySent INT = 0 OUTPUT,
	@InsureeSent INT = 0 OUTPUT,
	@PolicySent INT = 0 OUTPUT,
	@PremiumSent INT = 0 OUTPUT,
	@FamilyImported INT = 0 OUTPUT,
	@InsureeImported INT = 0 OUTPUT,
	@PolicyImported INT = 0 OUTPUT,
	@PremiumImported INT = 0 OUTPUT 
	)
	AS
	BEGIN

	DECLARE @Query NVARCHAR(500)
	--DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT,PhotoPath NVARCHAR(100), NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblInureePolicy TABLE(PolicyId INT,InsureeId INT,EffectiveDate DATE, NewInsureeId INT, NewPolicyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)

	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)

	BEGIN TRY

		--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE FAMILY FROM THE XML
		INSERT INTO @tblFamilies(FamilyId,InsureeId,CHFID, LocationId,Poverty,FamilyType,FamilyAddress,Ethnicity, ConfirmationNo)
		SELECT 
		T.F.value('(FamilyId)[1]','INT'),
		T.F.value('(InsureeId)[1]','INT'),
		T.F.value('(HOFCHFID)[1]','NVARCHAR(12)'),
		T.F.value('(LocationId)[1]','INT'),
		T.F.value('(Poverty)[1]','BIT'),
		NULLIF(T.F.value('(FamilyType)[1]','NVARCHAR(2)'),''),
		T.F.value('(FamilyAddress)[1]','NVARCHAR(200)'),
		T.F.value('(Ethnicity)[1]','NVARCHAR(1)'),
		T.F.value('(ConfirmationNo)[1]','NVARCHAR(12)')
		FROM @XML.nodes('Enrolment/Families/Family') AS T(F)


		--Get total number of families sent via XML
		SELECT @FamilySent = COUNT(*) FROM @tblFamilies

		--GET ALL THE INSUREES FROM XML
		INSERT INTO @tblInsuree(InsureeId,FamilyId,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Passport,Phone,CardIssued,Relationship,Profession,Education,Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurVillage, isOffline,PhotoPath)
		SELECT
		T.I.value('(InsureeId)[1]','INT'),
		T.I.value('(FamilyId)[1]','INT'),
		T.I.value('(CHFID)[1]','NVARCHAR(12)'),
		T.I.value('(LastName)[1]','NVARCHAR(100)'),
		T.I.value('(OtherNames)[1]','NVARCHAR(100)'),
		T.I.value('(DOB)[1]','DATE'),
		T.I.value('(Gender)[1]','CHAR(1)'),
		T.I.value('(Marital)[1]','CHAR(1)'),
		T.I.value('(isHead)[1]','BIT'),
		T.I.value('(IdentificationNumber)[1]','NVARCHAR(25)'),
		T.I.value('(Phone)[1]','NVARCHAR(50)'),
		T.I.value('(CardIssued)[1]','BIT'),
		NULLIF(T.I.value('(Relationship)[1]','SMALLINT'),''),
		NULLIF(T.I.value('(Profession)[1]','SMALLINT'),''),
		NULLIF(T.I.value('(Education)[1]','SMALLINT'),''),
		T.I.value('(Email)[1]','NVARCHAR(100)'),
		NULLIF(T.I.value('(TypeOfId)[1]','NVARCHAR(1)'),''),
		NULLIF(T.I.value('(HFID)[1]','INT'),''),
		T.I.value('(CurrentAddress)[1]','NVARCHAR(200)'),
		T.I.value('(GeoLocation)[1]','NVARCHAR(200)'),
		NULLIF(T.I.value('(CurVillage)[1]','INT'),''),
		T.I.value('(isOffline)[1]','BIT'),
		T.I.value('(PhotoPath)[1]','NVARCHAR(100)')
		FROM @XML.nodes('Enrolment/Insurees/Insuree') AS T(I)

		--Get total number of Insurees sent via XML
		SELECT @InsureeSent = COUNT(*) FROM @tblInsuree

		--GET ALL THE POLICIES FROM XML
		INSERT INTO @tblPolicy(PolicyId,FamilyId,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdId,OfficerId,PolicyStage)
		SELECT 
		T.P.value('(PolicyId)[1]','INT'),
		T.P.value('(FamilyId)[1]','INT'),
		T.P.value('(EnrollDate)[1]','DATE'),
		T.P.value('(StartDate)[1]','DATE'),
		T.P.value('(EffectiveDate)[1]','DATE'),
		T.P.value('(ExpiryDate)[1]','DATE'),
		T.P.value('(PolicyStatus)[1]','TINYINT'),
		T.P.value('(PolicyValue)[1]','DECIMAL(18,2)'),
		T.P.value('(ProdId)[1]','INT'),
		T.P.value('(OfficerId)[1]','INT'),
		T.P.value('(PolicyStage)[1]','CHAR(1)')
		FROM @XML.nodes('Enrolment/Policies/Policy') AS T(P)

		--Get total number of Policies sent via XML
		SELECT @PolicySent = COUNT(*) FROM @tblPolicy
			
		--GET INSUREEPOLICY
		INSERT INTO @tblInureePolicy(PolicyId,InsureeId,EffectiveDate)
		SELECT 
		T.P.value('(PolicyId)[1]','INT'),
		T.P.value('(InsureeId)[1]','INT'),
		NULLIF(T.P.value('(EffectiveDate)[1]','DATE'),'')
		FROM @XML.nodes('Enrolment/InsureePolicies/InsureePolicy') AS T(P)

		--GET ALL THE PREMIUMS FROM XML
		INSERT INTO @tblPremium(PremiumId,PolicyId,PayerId,Amount,Receipt,PayDate,PayType,isPhotoFee)
		SELECT
		T.PR.value('(PremiumId)[1]','INT'),
		T.PR.value('(PolicyId)[1]','INT'),
		NULLIF(T.PR.value('(PayerId)[1]','INT'),0),
		T.PR.value('(Amount)[1]','DECIMAL(18,2)'),
		T.PR.value('(Receipt)[1]','NVARCHAR(50)'),
		T.PR.value('(PayDate)[1]','DATE'),
		T.PR.value('(PayType)[1]','CHAR(1)'),
		T.PR.value('(isPhotoFee)[1]','BIT')
		FROM @XML.nodes('Enrolment/Premiums/Premium') AS T(PR)

		--Get total number of premium sent via XML
		SELECT @PremiumSent = COUNT(*) FROM @tblPremium;

			DECLARE @AuditUserId INT =-1,@AssociatedPhotoFolder NVARCHAR(255)
			IF ( @XML.exist('(Enrolment/FileInfo)')=1 )
				SET	@AuditUserId= (SELECT T.PR.value('(UserId)[1]','INT') FROM @XML.nodes('Enrolment/FileInfo') AS T(PR))
				SET @AssociatedPhotoFolder=(SELECT FTPEnrollmentFolder FROM tblIMISDefaults)

		/********************************************************************************************************
										VALIDATING FILE				
		********************************************************************************************************/
		IF EXISTS(
		--Insuree without family
		SELECT 1 
		FROM @tblInsuree I LEFT OUTER JOIN @tblFamilies F ON I.FamilyId = F.FamilyID
		WHERE F.FamilyID IS NULL

		UNION ALL

		--Policy without family
		SELECT 1 FROM
		@tblPolicy PL LEFT OUTER JOIN @tblFamilies F ON PL.FamilyId = F.FamilyId
		WHERE F.FamilyId IS NULL

		UNION ALL

		--Premium without policy
		SELECT 1
		FROM @tblPremium PR LEFT OUTER JOIN @tblPolicy P ON PR.PolicyId = P.PolicyId
		WHERE P.PolicyId  IS NULL

		UNION ALL

		---Invalid Family type field
		SELECT 1 FROM @tblFamilies F 
		LEFT OUTER JOIN tblFamilyTypes FT ON F.FamilyType=FT.FamilyTypeCode
		WHERE FT.FamilyType IS NULL AND F.FamilyType IS NOT NULL

		UNION ALL

		---Invalid IdentificationType
		SELECT 1 FROM @tblInsuree I
		LEFT OUTER JOIN tblIdentificationTypes IT ON I.TypeOfId = IT.IdentificationCode
		WHERE IT.IdentificationCode IS NULL AND I.TypeOfId IS NOT NULL
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h1 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h1>')
		
			RAISERROR (N'<h1 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h1>', 16, 1);
		END

		--SELECT * INTO tempFamilies FROM @tblFamilies
		--SELECT * INTO tempInsuree FROM @tblInsuree
		--SELECT * INTO tempPolicy FROM @tblPolicy
		--SELECT * INTO tempInsureePolicy FROM @tblInureePolicy
		--SELECT * INTO tempPolicy FROM @tblPolicy
		--RETURN

		BEGIN TRAN ENROLL;

			DELETE F
			OUTPUT N'Insuree information is missing for Family with Insurance Number ' + QUOTENAME(deleted.CHFID) INTO @tblResult
			FROM @tblFamilies F
			LEFT OUTER JOIN @tblInsuree I ON F.CHFID = I.CHFID
			WHERE I.InsureeId IS NULL;

			INSERT INTO @tblResult(Result)
			SELECT N'Family with Insurance Number : ' + QUOTENAME(I.CHFID) + ' already exists' 
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL
			AND I.IsHead = 1;

			--Get the new FamilyId frmo DB and udpate @tblFamilies, @tblInsuree and @tblPolicy
			UPDATE TF SET NewFamilyId = I.FamilyID
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL
			AND I.IsHead = 1;

		
			UPDATE TI SET NewFamilyId = TF.NewFamilyId
			FROM @tblFamilies TF 
			INNER JOIN @tblInsuree TI ON TF.FamilyId = TI.FamilyId;

			UPDATE TP SET TP.NewFamilyId = TF.NewFamilyId
			FROM @tblFamilies TF
			INNER JOIN @tblPolicy TP ON TF.FamilyId = TP.FamilyId;

			--Delete existing families from temp table, we don't need them anymore
			DELETE FROM @tblFamilies WHERE NewFamilyId IS NOT NULL;


			--Insert new Families
			MERGE INTO tblFamilies 
			USING @tblFamilies AS TF ON 1 = 0 
			WHEN NOT MATCHED THEN 
				INSERT (InsureeId, LocationId, Poverty, ValidityFrom, AuditUserId, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo) 
				VALUES(0 , TF.LocationId, TF.Poverty, GETDATE() , @AuditUserId , TF.FamilyType, TF.FamilyAddress, TF.Ethnicity, TF.ConfirmationNo)
				OUTPUT TF.FamilyId, inserted.FamilyId INTO @tblIds;
		

			SELECT @FamilyImported = @@ROWCOUNT;

			--Update Family, Insuree and Policy with newly inserted FamilyId
			UPDATE TF SET NewFamilyId = ID.[NewId]
			FROM @tblFamilies TF
			INNER JOIN @tblIds ID ON TF.FamilyId = ID.OldId;

			UPDATE TI SET NewFamilyId = ID.[NewId]
			FROM @tblInsuree TI
			INNER JOIN @tblIds ID ON TI.FamilyId = ID.OldId;

			UPDATE TP SET NewFamilyId = ID.[NewId]
			FROM @tblPolicy TP
			INNER JOIN @tblIds ID ON TP.FamilyId = ID.OldId;

			--Clear the Ids table
			DELETE FROM @tblIds;

			--Delete duplicate insurees from table
			DELETE TI
			OUTPUT 'Insurance Number ' + QUOTENAME(deleted.CHFID) + ' already exists' INTO @tblResult
			FROM @tblInsuree TI 
			INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL;

			--Delete duplicate insurees from insureePolicy Also
			DELETE IP FROM @tblInureePolicy IP
			LEFT OUTER JOIN @tblInsuree I ON IP.InsureeId=I.InsureeId
			WHERE I.InsureeId IS NULL

			--Insert new insurees 
			MERGE tblInsuree
			USING @tblInsuree TI ON 1 = 0
			WHEN NOT MATCHED THEN
				INSERT(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,passport,Phone,CardIssued,ValidityFrom,AuditUserID,Relationship,Profession,Education,Email,TypeOfId, HFID)
				VALUES(TI.NewFamilyId, TI.CHFID, TI.LastName, TI.OtherNames, TI.DOB, TI.Gender, TI.Marital, TI.IsHead, TI.Passport, TI.Phone, TI.CardIssued, GETDATE(), @AuditUserId, TI.Relationship, TI.Profession, TI.Education, TI.Email, TI.TypeOfId, TI.HFID)
				OUTPUT TI.InsureeId, inserted.InsureeId INTO @tblIds;


			SELECT @InsureeImported = @@ROWCOUNT;

			--Update Ids of newly inserted insurees 
			UPDATE TI SET NewInsureeId = Id.[NewId]
			FROM @tblInsuree TI 
			INNER JOIN @tblIds Id ON TI.InsureeId = Id.OldId;

			--Update insureeId in @tbltempInsuree 
			UPDATE IP SET IP.NewInsureeId=I.NewInsureeId 
			FROM @tblInureePolicy IP 
			INNER JOIN @tblInsuree I ON IP.InsureeId=I.InsureeId

			--Insert Photos
			INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
			SELECT NewInsureeId,CHFID,@AssociatedPhotoFolder + '\\' PhotoFolder, PhotoPath,0,GETDATE(),GETDATE() ValidityFrom, @AuditUserId AuditUserID 
			FROM @tblInsuree TI; 
		
			--Update tblInsuree with newly inserted PhotoId
			UPDATE I SET PhotoId = PH.PhotoId
			FROM @tblInsuree TI
			INNER JOIN tblPhotos PH ON TI.NewInsureeId = PH.InsureeID
			INNER JOIN tblInsuree I ON TI.NewInsureeId = I.InsureeID;


			--Update new InsureeId in tblFamilies
			UPDATE F SET InsureeId = TI.NewInsureeId
			FROM @tblInsuree TI 
			INNER JOIN tblInsuree I ON TI.NewInsureeId = I.InsureeId
			INNER JOIN tblFamilies F ON TI.NewFamilyId = F.FamilyID
			WHERE TI.IsHead = 1;

			--Clear the Ids table
			DELETE FROM @tblIds;

			INSERT INTO @tblIds
			SELECT TP.PolicyId, PL.PolicyID
			FROM tblPolicy PL 
			INNER JOIN @tblPolicy TP ON PL.FamilyID = TP.NewFamilyId 
									AND PL.EnrollDate = TP.EnrollDate 
									AND PL.StartDate = TP.StartDate 
									AND PL.ProdID = TP.ProdId 
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
			INNER JOIN tblInsuree I ON PL.FamilyId = I.FamilyId
			WHERE PL.ValidityTo IS NULL
			AND I.IsHead = 1;

		
			--Delete duplicate policies
			DELETE TP
			OUTPUT 'Policy for the family : ' + QUOTENAME(I.CHFID) + ' with Product Code:' + QUOTENAME(Prod.ProductCode) + ' already exists' INTO @tblResult
			FROM tblPolicy PL 
			INNER JOIN @tblPolicy TP ON PL.FamilyID = TP.NewFamilyId 
									AND PL.EnrollDate = TP.EnrollDate 
									AND PL.StartDate = TP.StartDate 
									AND PL.ProdID = TP.ProdId 
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
			INNER JOIN tblInsuree I ON PL.FamilyId = I.FamilyId
			WHERE PL.ValidityTo IS NULL
			AND I.IsHead = 1;

			--Update Premium table 
			UPDATE TPR SET NewPolicyId = Id.[NewId]
			FROM @tblPremium TPR 
			INNER JOIN @tblIds Id ON TPR.PolicyId = Id.OldId;
		
	
			--Clear the Ids table
			DELETE FROM @tblIds;

			--Insert new policies
				DECLARE @FamilyId INT = 0,
				@HOFId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@ProdId INT,
				@PolicyStage CHAR(1),
				@StartDate DATE,
				@ExpiryDate DATE,
				@EnrollDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId TINYINT,
				@PolicyValueFromPhone DECIMAL(18, 4),
				@ContributionAmount DECIMAL(18, 4),
				@Active TINYINT=2,
				@Idle TINYINT=1,
				@NewPolicyId INT


			DECLARE CurPolicies CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, StartDate, EnrollDate,ExpiryDate, PolicyStatus, PolicyValue, NewFamilyId FROM @tblPolicy 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @StartDate, @EnrollDate, @ExpiryDate,  @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollDate, 0, @ErrorCode OUTPUT;
				SELECT @ContributionAmount = SUM(Amount) FROM @tblPremium WHERE PolicyId = @PolicyId
					IF ((@PolicyValueFromPhone = @PolicyValue))
						BEGIN
							SELECT @PolicyStatus = PolicyStatus FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @EffectiveDate=EffectiveDate FROM @tblPolicy WHERE PolicyId=@PolicyId

							INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID)
							SELECT	 NewFamilyID,EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,@PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),@AuditUserId FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @NewPolicyId = SCOPE_IDENTITY()
							INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, @NewPolicyId)
							
							IF @@ROWCOUNT > 0
							SET @PolicyImported = ISNULL(@PolicyImported,0) +1

							UPDATE @tblInureePolicy SET NewPolicyId = @NewPolicyId WHERE PolicyId=@PolicyId
							
							INSERT INTO tblInsureePolicy
								([InsureeId],[PolicyId],[EnrollmentDate],[StartDate],[EffectiveDate],[ExpiryDate],[ValidityFrom],[AuditUserId]) 
							SELECT
								 NewInsureeId,IP.NewPolicyId,@EnrollDate,@StartDate,IP.[EffectiveDate],@ExpiryDate,GETDATE(),@AuditUserId FROM @tblInureePolicy IP
							     WHERE IP.PolicyId=@PolicyId
						END
					ELSE
						BEGIN
							IF @ContributionAmount >= @PolicyValue
								BEGIN
									SELECT @PolicyStatus = @Active
									--Checking the Effectice Date
										DECLARE @Amount DECIMAL(10,0), @TotalAmount DECIMAL(10,0), @PaymentDate DATE 
										DECLARE CurPremiumPayment CURSOR FOR SELECT PayDate, Amount FROM @tblPremium WHERE PolicyId = @PolicyId;
										OPEN CurPremiumPayment;
										FETCH NEXT FROM CurPremiumPayment INTO @PaymentDate,@Amount;
										WHILE @@FETCH_STATUS = 0
										BEGIN
											SELECT @TotalAmount = ISNULL(@TotalAmount,0) + @Amount;
												IF(@TotalAmount >= @PolicyValue)
													BEGIN
														SELECT @EffectiveDate = @PaymentDate
														BREAK;
													END
												ELSE
														SELECT @EffectiveDate = NULL
											FETCH NEXT FROM CurPremiumPayment INTO @PaymentDate,@Amount;
										END
										CLOSE CurPremiumPayment;
										DEALLOCATE CurPremiumPayment; 
								END
							ELSE
								BEGIN
									SELECT @PolicyStatus = @Idle
									SELECT @EffectiveDate = NULL
								END
							
							INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID)
							SELECT	 NewFamilyID,EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,@PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),@AuditUserId FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @NewPolicyId = SCOPE_IDENTITY()
							INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, @NewPolicyId)
							
							IF @@ROWCOUNT > 0
							SET @PolicyImported = ISNULL(@PolicyImported,0) +1

							UPDATE @tblInureePolicy SET NewPolicyId = @NewPolicyId WHERE PolicyId=@PolicyId

							DECLARE @InsureeId INT
							DECLARE CurIns CURSOR FOR SELECT NewInsureeId FROM @tblInureePolicy WHERE PolicyId = @PolicyId
							OPEN CurIns;
							FETCH NEXT FROM CurIns INTO @InsureeId;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								EXEC uspAddInsureePolicy @InsureeId;
								FETCH NEXT FROM CurIns INTO @InsureeId;
							END
							CLOSE CurIns;
							DEALLOCATE CurIns; 

						END

				

				FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @StartDate, @EnrollDate, @ExpiryDate,  @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
			END
			CLOSE CurPolicies;
			DEALLOCATE CurPolicies; 
			

			--Update new PolicyId
			UPDATE TP SET NewPolicyId = Id.[NewId]
			FROM @tblPolicy TP
			INNER JOIN @tblIds Id ON TP.PolicyId = Id.OldId;

			UPDATE TPR SET NewPolicyId = TP.NewPolicyId
			FROM @tblPremium TPR
			INNER JOIN @tblPolicy TP ON TPR.PolicyId = TP.PolicyId;
		
	

			--Delete duplicate Premiums
			DELETE TPR
			OUTPUT 'Premium on receipt number ' + QUOTENAME(PR.Receipt) + ' already exists.' INTO @tblResult
			--OUTPUT deleted.*
			FROM tblPremium PR
			INNER JOIN @tblPremium TPR ON PR.Amount = TPR.Amount 
										AND PR.Receipt = TPR.Receipt 
										AND PR.PolicyID = TPR.NewPolicyId
			WHERE PR.ValidityTo IS NULL
		
			--Insert Premium
			INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee)
			SELECT NewPolicyId,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),@AuditUserId,isPhotoFee 
			FROM @tblPremium
		
			SELECT @PremiumImported = @@ROWCOUNT;

	
	IF EXISTS(SELECT COUNT(1) 
			FROM tblInsuree 
			WHERE ValidityTo IS NULL
			AND IsHead = 1
			GROUP BY FamilyID
			HAVING COUNT(1) > 1)
			
			--Added by Amani
			BEGIN
					DELETE FROM @tblResult;
					SET @FamilyImported = 0;
					SET @InsureeImported  = 0;
					SET @PolicyImported  = 0;
					SET @PremiumImported  = 0 
					INSERT INTO @tblResult VALUES
						(N'<h3 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h3>')
						--GOTO EndOfTheProcess;
						RAISERROR(N'Double HOF Found',16,1)	
					END


		COMMIT TRAN ENROLL;

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK TRAN ENROLL;
	END CATCH

	SELECT Result FROM @tblResult;
	RETURN 0;
END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspUploadHFXML]
(
	--@File NVARCHAR(300),
	@XML XML,
	@StrategyId INT,	--1	: Insert Only,	2: Update Only	3: Insert & Update	7: Insert, Update & Delete
	@AuditUserID INT = -1,
	@DryRun BIT=0,
	@SentHF INT = 0 OUTPUT,
	@Inserts INT  = 0 OUTPUT,
	@Updates INT  = 0 OUTPUT,
	@sentCatchment INT =0 OUTPUT,
	@InsertCatchment INT =0 OUTPUT,
	@UpdateCatchment INT =0 OUTPUT
)
AS
BEGIN

	/* Result type in @tblResults
	-------------------------------
		E	:	Error
		C	:	Conflict
		FE	:	Fatal Error

	Return Values
	------------------------------
		0	:	All Okay
		-1	:	Fatal error
	*/
	
	DECLARE @InsertOnly INT = 1,
			@UpdateOnly INT = 2,
			@Delete INT= 4

	SET @Inserts = 0;
	SET @Updates = 0;
	SET @InsertCatchment=0;
	SET @UpdateCatchment =0;
	
	DECLARE @Query NVARCHAR(500)
	--DECLARE @XML XML
	DECLARE @tblHF TABLE(LegalForms NVARCHAR(15), [Level] NVARCHAR(15)  NULL, SubLevel NVARCHAR(15), Code NVARCHAR (50) NULL, Name NVARCHAR (101) NULL, [Address] NVARCHAR (101), DistrictCode NVARCHAR (50) NULL,Phone NVARCHAR (51), Fax NVARCHAR (51), Email NVARCHAR (51), CareType CHAR (15) NULL, AccountCode NVARCHAR (26),ItemPriceListName NVARCHAR(120),ServicePriceListName NVARCHAR(120), IsValid BIT )
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
	DECLARE @tblCatchment TABLE(HFCode NVARCHAR(50), VillageCode NVARCHAR(50),Percentage INT, IsValid BIT )

	BEGIN TRY
		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

		IF ( @XML.exist('(HealthFacilities/HealthFacilityDetails)')=1 AND @XML.exist('(HealthFacilities/CatchmentDetails)')=1 )
			BEGIN
				--GET ALL THE HF FROM THE XML
				INSERT INTO @tblHF(LegalForms,[Level],SubLevel,Code,Name,[Address],DistrictCode,Phone,Fax,Email,CareType,AccountCode, ItemPriceListName, ServicePriceListName, IsValid)
				SELECT 
				NULLIF(T.F.value('(LegalForm)[1]','NVARCHAR(15)'),''),
				NULLIF(T.F.value('(Level)[1]','NVARCHAR(15)'),''),
				NULLIF(T.F.value('(SubLevel)[1]','NVARCHAR(15)'),''),
				T.F.value('(Code)[1]','NVARCHAR(50)'),
				T.F.value('(Name)[1]','NVARCHAR(101)'),
				T.F.value('(Address)[1]','NVARCHAR(101)'),
				NULLIF(T.F.value('(DistrictCode)[1]','NVARCHAR(50)'),''),
				T.F.value('(Phone)[1]','NVARCHAR(51)'),
				T.F.value('(Fax)[1]','NVARCHAR(51)'),
				T.F.value('(Email)[1]','NVARCHAR(51)'),
				NULLIF(T.F.value('(CareType)[1]','NVARCHAR(15)'),''),
				T.F.value('(AccountCode)[1]','NVARCHAR(26)'),
				NULLIF(T.F.value('(ItemPriceListName)[1]','NVARCHAR(26)'), ''),
				NULLIF(T.F.value('(ServicePriceListName)[1]','NVARCHAR(26)'), ''),
				1
				FROM @XML.nodes('HealthFacilities/HealthFacilityDetails/HealthFacility') AS T(F)

				SELECT @SentHF=@@ROWCOUNT


				INSERT INTO @tblCatchment(HFCode,VillageCode,Percentage,IsValid)
				SELECT 
				C.CT.value('(HFCode)[1]','NVARCHAR(50)'),
				C.CT.value('(VillageCode)[1]','NVARCHAR(50)'),
				C.CT.value('(Percentage)[1]','FLOAT'),
				1
				FROM @XML.nodes('HealthFacilities/CatchmentDetails/Catchment') AS C(CT)

				SELECT @sentCatchment=@@ROWCOUNT
			END
		ELSE
			BEGIN
				RAISERROR (N'-200', 16, 1);
			END
			
			
		--SELECT * INTO tempHF FROM @tblHF;
		--SELECT * INTO tempCatchment FROM @tblCatchment;

		--RETURN;

		/*========================================================================================================
		VALIDATION STARTS
		========================================================================================================*/	
		--Invalidate empty code or empty name 
			IF EXISTS(
				SELECT 1
				FROM @tblHF HF 
				WHERE LEN(ISNULL(HF.Code, '')) = 0
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT CONVERT(NVARCHAR(3), COUNT(HF.Code)) + N' HF(s) have empty code', N'E'
			FROM @tblHF HF 
			WHERE LEN(ISNULL(HF.Code, '')) = 0

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty name field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Name, '')) = 0


			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Name, '')) = 0 OR LEN(ISNULL(HF.Code, '')) = 0

			--Ivalidate empty Legal Forms
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty LegaForms field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.LegalForms, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.LegalForms, '')) = 0 


			--Ivalidate empty Level
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty Level field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Level, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.Level, '')) = 0 

			--Ivalidate empty District Code
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty District Code field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.DistrictCode, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.DistrictCode, '')) = 0 OR LEN(ISNULL(HF.Code, '')) = 0

				--Ivalidate empty Care Type
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has empty Care Type field', N'E'
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.CareType, '')) = 0

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(ISNULL(HF.CareType, '')) = 0 OR LEN(ISNULL(HF.Code, '')) = 0


			--Invalidate HF with duplicate Codes
			IF EXISTS(SELECT 1 FROM @tblHF  GROUP BY Code HAVING COUNT(Code) >1)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT QUOTENAME(Code) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(Code)) + ' times in the file', N'C'
			FROM @tblHF  GROUP BY Code HAVING COUNT(Code) >1

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE code in (SELECT code from @tblHF GROUP BY Code HAVING COUNT(Code) >1)

			--Invalidate HF with invalid Legal Forms
			INSERT INTO @tblResult(Result,ResultType)
			SELECT 'HF Code '+QUOTENAME(Code) +' has invalid Legal Form', N'E'  FROM @tblHF HF LEFT OUTER JOIN tblLegalForms LF ON HF.LegalForms = LF.LegalFormCode 	WHERE LF.LegalFormCode IS NULL AND NOT HF.LegalForms IS NULL
			
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN tblLegalForms LF ON HF.LegalForms = LF.LegalFormCode 	WHERE LF.LegalFormCode IS NULL AND NOT HF.LegalForms IS NULL)


			--Ivalidate HF with invalid Disrict Code
			IF EXISTS(SELECT 1  FROM @tblHF HF 	LEFT OUTER JOIN tblLocations L ON L.LocationCode=HF.DistrictCode AND L.ValidityTo IS NULL	WHERE	L.LocationCode IS NULL AND NOT HF.DistrictCode IS NULL)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'HF Code ' + QUOTENAME(HF.Code) + N' has invalid District Code', N'E'
			FROM @tblHF HF 	LEFT OUTER JOIN tblLocations L ON L.LocationCode=HF.DistrictCode AND L.ValidityTo IS NULL	WHERE L.LocationCode IS NULL AND NOT HF.DistrictCode IS NULL
	
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE HF.DistrictCode IN (SELECT HF.DistrictCode  FROM @tblHF HF 	LEFT OUTER JOIN tblLocations L ON L.LocationCode=HF.DistrictCode AND L.ValidityTo IS NULL WHERE  L.LocationCode IS NULL)

			--Invalidate HF with invalid Level
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+ QUOTENAME(HF.Code)+' has invalid Level', N'E'   FROM @tblHF HF LEFT OUTER JOIN (SELECT HFLevel FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFLevel) L ON HF.Level = L.HFLevel WHERE L.HFLevel IS NULL AND NOT HF.Level IS NULL
			
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF 
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN (SELECT HFLevel FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFLevel) L ON HF.Level = L.HFLevel WHERE L.HFLevel IS NULL AND NOT HF.Level IS NULL)
			
			--Invalidate HF with invalid SubLevel
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+QUOTENAME(HF.Code) +' has invalid SubLevel' ,N'E'  FROM @tblHF HF LEFT OUTER JOIN tblHFSublevel HSL ON HSL.HFSublevel= HF.SubLevel WHERE HSL.HFSublevel IS NULL AND NOT HF.SubLevel IS NULL
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF 
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN tblHFSublevel HSL ON HSL.HFSublevel= HF.SubLevel WHERE HSL.HFSublevel IS NULL AND NOT HF.SubLevel IS NULL)

			--Remove HF with invalid CareType
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+QUOTENAME(HF.Code) +' has invalid CareType',N'E'   FROM @tblHF HF LEFT OUTER JOIN (SELECT HFCareType FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFCareType) CT ON HF.CareType = CT.HFCareType WHERE CT.HFCareType IS NULL AND NOT HF.CareType IS NULL
			UPDATE HF SET IsValid = 0
			FROM @tblHF HF 
			WHERE Code IN (SELECT Code FROM @tblHF HF LEFT OUTER JOIN (SELECT HFCareType FROM tblHF WHERE ValidityTo IS NULL GROUP BY HFCareType) CT ON HF.CareType = CT.HFCareType WHERE CT.HFCareType IS NULL)


			--Check if any HF Code is greater than 8 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Code ' + QUOTENAME(HF.Code) + ' is greater than 8 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Code) > 8;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Code) > 8;

			--Check if any HF Name is greater than 100 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Name ' + QUOTENAME(HF.Code) + ' is greater than 100 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Name) > 100;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Name) > 100;


			--Check if any HF Address is greater than 100 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Address ' + QUOTENAME(HF.Code) + ' is greater than 100 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Address) > 100;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Address) > 100;

			--Check if any HF Phone is greater than 50 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Phone ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Phone) > 50;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Phone) > 50;

			--Check if any HF Fax is greater than 50 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Fax ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Fax) > 50;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Fax) > 50;

			--Check if any HF Email is greater than 50 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Email ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.Email) > 50;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.Email) > 50;

			--Check if any HF AccountCode is greater than 25 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the HF Account Code ' + QUOTENAME(HF.Code) + ' is greater than 50 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.AccountCode) > 25;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.AccountCode) > 25;

			--Invalidate HF with invalid Item Price List Name
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+QUOTENAME(HF.Code) +' has invalid Item Price List Name' ,N'E'  
			FROM @tblHF HF
			INNER JOIN tblDistricts D ON HF.DistrictCode = D.DistrictCode
			LEFT OUTER JOIN tblPLItems PLI ON HF.ItemPriceListName = PLI.PLItemName 
			WHERE PLI.ValidityTo IS NULL 
			AND NOT(PLI.LocationId = D.DistrictId OR PLI.LocationId = D.Region)
			AND HF.ItemPriceListName IS NOT NULL;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			INNER JOIN tblDistricts D ON HF.DistrictCode = D.DistrictCode
			LEFT OUTER JOIN tblPLItems PLI ON HF.ItemPriceListName = PLI.PLItemName 
			WHERE PLI.ValidityTo IS NULL 
			AND NOT(PLI.LocationId = D.DistrictId OR PLI.LocationId = D.Region)
			AND HF.ItemPriceListName IS NOT NULL;

			--Invalidate HF with invalid Service Price List Name
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code '+QUOTENAME(HF.Code) +' has invalid Service Price List Name' ,N'E'  
			FROM @tblHF HF
			INNER JOIN tblDistricts D ON HF.DistrictCode = D.DistrictCode
			LEFT OUTER JOIN tblPLServices PLS ON HF.ServicePriceListName = PLS.PLServName 
			WHERE PLS.ValidityTo IS NULL 
			AND NOT(PLS.LocationId = D.DistrictId OR PLS.LocationId = D.Region)
			AND HF.ServicePriceListName IS NOT NULL;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			INNER JOIN tblDistricts D ON HF.DistrictCode = D.DistrictCode
			LEFT OUTER JOIN tblPLServices PLS ON HF.ServicePriceListName = PLS.PLServName 
			WHERE PLS.ValidityTo IS NULL 
			AND NOT(PLS.LocationId = D.DistrictId OR PLS.LocationId = D.Region)
			AND HF.ServicePriceListName IS NOT NULL;

			--Check if any ItemPriceList is greater than 100 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the ItemPriceListName ' + QUOTENAME(HF.Code) + ' is greater than 100 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.ItemPriceListName) > 100;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.ItemPriceListName) > 100;

			--Check if any ServicePriceListName is greater than 100 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the ServicePriceListName ' + QUOTENAME(HF.Code) + ' is greater than 100 characters', N'E'
			FROM @tblHF HF
			WHERE LEN(HF.ServicePriceListName) > 100;

			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			WHERE LEN(HF.ServicePriceListName) > 100;

			--Invalidate Catchment with empy HFCode
			IF EXISTS(SELECT  1 FROM @tblCatchment WHERE LEN(ISNULL(HFCode,''))=0)
			INSERT INTO @tblResult(Result,ResultType)
			SELECT  CONVERT(NVARCHAR(3), COUNT(HFCode)) + N' Catchment(s) have empty HFcode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(HFCode,''))=0
			UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(HFCode,''))=0

			--Invalidate Catchment with invalid HFCode
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'Invalid HF Code ' + QUOTENAME(C.HFCode) + N' in catchment section', N'E' FROM @tblCatchment C 
			LEFT OUTER JOIN @tblHF tempHF ON C.HFCode=tempHF.Code
			LEFT OUTER JOIN tblHF HF ON C.HFCode=HF.HFCode 
			WHERE (tempHF.Code IS NULL AND HF.HFCode IS NULL)
			AND HF.ValidityTo IS NULL
			--AND tempHF.IsValid=1

			UPDATE C SET C.IsValid =0 FROM @tblCatchment C 
			LEFT OUTER JOIN @tblHF tempHF ON C.HFCode=tempHF.Code
			LEFT OUTER JOIN tblHF HF ON C.HFCode=HF.HFCode 
			WHERE (tempHF.Code IS NULL AND HF.HFCode IS NULL)
			AND HF.ValidityTo IS NULL
			--AND tempHF.IsValid=1
		
			--Invalidate Catchment with empy VillageCode
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has an empty VillageCode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(VillageCode,''))=0
			UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(VillageCode,''))=0

			--Invalidate Catchment with invalid VillageCode
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'Invalid Village Code ' + QUOTENAME(C.VillageCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL AND LEN(ISNULL(VillageCode,''))>0
			UPDATE C SET IsValid=0 FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL
		
			--Invalidate Catchment with empty percentage
			INSERT INTO @tblResult(Result,ResultType)
			SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has an empty or invalid percentage', N'E' FROM @tblCatchment WHERE Percentage=0
			UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage=0

			--Invalidate Catchment with invalid percentage
			INSERT INTO @tblResult(Result,ResultType)
			SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has invalid percentage', N'E' FROM @tblCatchment WHERE Percentage < 0 OR Percentage > 100
			UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage<0 OR Percentage >100

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(C.VillageCode) + ' found ' + CAST(COUNT(C.VillageCode) AS NVARCHAR(4)) + ' time(s) in the Catchement for the HF Code ' + QUOTENAME(C.HFCode), 'C'
			FROM @tblCatchment C
			GROUP BY C.HFCode, C.VillageCode
			HAVING COUNT(C.VillageCode) > 1;

			UPDATE C SET IsValid = 0
			FROM @tblCatchment C
			 WHERE C.VillageCode IN (
			SELECT C.VillageCode
			FROM @tblCatchment C
			GROUP BY C.HFCode, C.VillageCode
			HAVING COUNT(C.VillageCode) > 1
			 )

			--UPDATE HF SET IsValid = 0
			--FROM @tblHF HF
			--INNER JOIN @tblCatchment C ON HF.Code = C.HFCode
			-- WHERE C.HFCode IN (
			--SELECT C.HFCode
			--FROM @tblCatchment C
			--GROUP BY C.HFCode, C.VillageCode
			--HAVING COUNT(C.VillageCode) > 1
			-- )

			


			--Get the counts
			--To be udpated
			IF (@StrategyId & @UpdateOnly) > 0
				BEGIN
					
					--Failed HF
					IF (@StrategyId=@UpdateOnly)
						BEGIN
							INSERT INTO @tblResult(Result,ResultType)
							SELECT 'HF Code '+  QUOTENAME(tempHF.Code) +' does not exists in Database',N'FH'  FROM @tblHF tempHF
							LEFT OUTER JOIN tblHF HF ON HF.HFCode=tempHF.Code
							WHERE 
							--tempHF.IsValid=1 AND
							HF.ValidityTo IS NULL
							AND HF.HFCode IS NULL
						END

					SELECT @Updates=COUNT(1) FROM @tblHF TempHF
					INNER JOIN tblHF HF ON HF.HFCode=TempHF.Code 
					WHERE TempHF.IsValid=1 AND
					 HF.ValidityTo IS NULL

					SELECT @UpdateCatchment =COUNT(1) 
					FROM @tblCatchment C 
					INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					INNER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					WHERE 
					C.IsValid =1
					AND L.ValidityTo IS NULL
					AND HF.ValidityTo IS NULL
					AND HFC.ValidityTo IS NULL
				END
			
			--To be Inserted
			IF (@StrategyId & @InsertOnly) > 0
				BEGIN
				
				--Failed HF
					IF(@StrategyId=@InsertOnly)
						BEGIN
							INSERT INTO @tblResult(Result,ResultType)
							SELECT 'HF Code '+  QUOTENAME(tempHF.Code) +' already exists in Database',N'FH' 
							FROM @tblHF tempHF
							INNER JOIN tblHF HF ON tempHF.Code=HF.HFCode 
							WHERE HF.ValidityTo IS NULL 
							--AND  tempHF.IsValid=1
						END

					SELECT @Inserts=COUNT(1) FROM @tblHF TempHF
					LEFT OUTER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
					WHERE TempHF.IsValid=1
					AND HF.HFCode IS NULL

					SELECT @InsertCatchment=COUNT(1) FROM @tblCatchment C 
					LEFT OUTER JOIN tblHF HF ON C.HFCode=HF.HFCode
					LEFT OUTER JOIN @tblHF tempHF ON tempHF.Code=C.HFCode
					INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					LEFT OUTER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					WHERE 
					C.IsValid =1
					AND L.ValidityTo IS NULL
					AND HF.ValidityTo IS NULL
					AND HFC.ValidityTo IS NULL
					AND HFC.LocationId IS NULL
					AND HFC.HFID IS NULL
					AND (tempHF.Code IS NOT NULL OR HF.HFCode IS NOT NULL)
				END
			
		/*========================================================================================================
		VALIDATION ENDS
		========================================================================================================*/	
		IF @DryRun=0
		BEGIN
			BEGIN TRAN UPLOAD
				
			/*========================================================================================================
			UDPATE HF  STARTS
			========================================================================================================*/	
			IF  (@StrategyId & @UpdateOnly) > 0
				BEGIN

					--HF
					--Make a copy of the original record
					INSERT INTO tblHF(HFCode, HFName,[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[PLServiceID],[PLItemID],[AccCode],[OffLine],[ValidityFrom],[ValidityTo],LegacyID, AuditUserId)
					SELECT HF.[HFCode] ,HF.[HFName],HF.[LegalForm],HF.[HFLevel],HF.[HFSublevel],HF.[HFAddress],HF.[LocationId],HF.[Phone],HF.[Fax],HF.[eMail],HF.[HFCareType],HF.[PLServiceID],HF.[PLItemID],HF.[AccCode],HF.[OffLine],[ValidityFrom],GETDATE()[ValidityTo],HF.HfID, @AuditUserID AuditUserId 
					FROM tblHF HF
					INNER JOIN @tblHF TempHF  ON TempHF.Code=HF.HFCode
					WHERE HF.ValidityTo IS NULL
					AND TempHF.IsValid = 1;

					SELECT @Updates = @@ROWCOUNT;
				--Upadte the record
					UPDATE HF SET HF.HFName = TempHF.Name, HF.LegalForm=TempHF.LegalForms,HF.HFLevel=TempHF.Level, HF.HFSublevel=TempHF.SubLevel,HF.HFAddress=TempHF.Address,HF.LocationId=L.LocationId, HF.Phone=TempHF.Phone, HF.Fax=TempHF.Fax, HF.eMail=TempHF.Email,HF.HFCareType=TempHF.CareType, HF.AccCode=TempHF.AccountCode, HF.PLItemID=PLI.PLItemID, HF.PLServiceID=PLS.PLServiceID, HF.OffLine=0, HF.ValidityFrom=GETDATE(), AuditUserID = @AuditUserID
					OUTPUT QUOTENAME(deleted.HFCode), N'U' INTO @tblResult
					FROM tblHF HF
					INNER JOIN @tblHF TempHF  ON HF.HFCode=TempHF.Code
					INNER JOIN tblLocations L ON L.LocationCode=TempHF.DistrictCode
					LEFT OUTER JOIN tblPLItems PLI ON PLI.PLItemName= tempHF.ItemPriceListName AND (PLI.LocationId = L.LocationId OR PLI.LocationId = L.ParentLocationId)
					LEFT OUTER JOIN tblPLServices PLS ON PLS.PLServName=tempHF.ServicePriceListName  AND (PLS.LocationId = L.LocationId OR PLS.LocationId = L.ParentLocationId)
					WHERE HF.ValidityTo IS NULL
					AND L.ValidityTo IS NULL
					AND PLI.ValidityTo IS NULL
					AND PLS.ValidityTo IS NULL
					AND TempHF.IsValid = 1;

				END
			/*========================================================================================================
			UPDATE HF ENDS
			========================================================================================================*/	



			/*========================================================================================================
			INSERT HF STARTS
			========================================================================================================*/	

			--INSERT HF
			IF (@StrategyId & @InsertOnly) > 0
				BEGIN
					
					INSERT INTO tblHF(HFCode, HFName,[LegalForm],[HFLevel],[HFSublevel],[HFAddress],[LocationId],[Phone],[Fax],[eMail],[HFCareType],[AccCode],[PLItemID],[PLServiceID], [OffLine],[ValidityFrom],AuditUserId)
					OUTPUT QUOTENAME(inserted.HFCode), N'I' INTO @tblResult
					SELECT TempHF.[Code] ,TempHF.[Name],TempHF.[LegalForms],TempHF.[Level],TempHF.[Sublevel],TempHF.[Address],L.LocationId,TempHF.[Phone],TempHF.[Fax],TempHF.[Email],TempHF.[CareType],TempHF.[AccountCode], PLI.PLItemID, PLS.PLServiceID,0 [OffLine],GETDATE()[ValidityFrom], @AuditUserID AuditUserId 
					FROM @tblHF TempHF 
					LEFT OUTER JOIN tblHF HF  ON TempHF.Code=HF.HFCode
					INNER JOIN tblLocations L ON L.LocationCode=TempHF.DistrictCode
					LEFT OUTER JOIN tblPLItems PLI ON PLI.PLItemName= tempHF.ItemPriceListName  AND (PLI.LocationId = L.LocationId OR PLI.LocationId = L.ParentLocationId)
					LEFT OUTER JOIN tblPLServices PLS ON PLS.PLServName=tempHF.ServicePriceListName  AND (PLS.LocationId = L.LocationId OR PLS.LocationId = L.ParentLocationId)
					WHERE HF.ValidityTo IS NULL
					AND L.ValidityTo IS NULL
					AND HF.HFCode IS NULL
					AND PLI.ValidityTo IS NULL AND PLS.ValidityTo IS NULL
					AND TempHF.IsValid = 1;
	
					SELECT @Inserts = @@ROWCOUNT;

				END
				

			/*========================================================================================================
			INSERT HF ENDS
			========================================================================================================*/	

			
			/*========================================================================================================
			UDPATE CATCHMENT  STARTS
			========================================================================================================*/	
			IF  (@StrategyId & @UpdateOnly) > 0
				BEGIN

			--CATCHMENT
					--Make a copy of the original record
					INSERT INTO [tblHFCatchment]([HFID],[LocationId],[Catchment],[ValidityFrom],ValidityTo,[LegacyId],AuditUserId)		
					SELECT HFC.HfID,HFC.LocationId, HFC.Catchment,HFC.ValidityFrom, GETDATE() ValidityTo,HFC.HFCatchmentId, HFC.AuditUserId FROM @tblCatchment C 
					INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					INNER JOIN @tblHF tempHF ON tempHF.Code=C.HFCode
					INNER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					WHERE 
					C.IsValid =1
					AND tempHF.IsValid=1
					AND L.ValidityTo IS NULL
					AND HF.ValidityTo IS NULL
					AND HFC.ValidityTo IS NULL

					SELECT @UpdateCatchment =@@ROWCOUNT
					
					INSERT INTO @tblResult(Result,ResultType)
					SELECT CONVERT(NVARCHAR(3), @UpdateCatchment) , N'UC'

					--Upadte the record
					UPDATE HFC SET HFC.HFID= HF.HfID,HFC.LocationId= L.LocationId, HFC.Catchment =C.Percentage,HFC.ValidityFrom=GETDATE(),  HFC.AuditUserId=@AuditUserID FROM @tblCatchment C 
					INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					INNER JOIN @tblHF tempHF ON tempHF.Code=C.HFCode
					INNER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					WHERE 
					C.IsValid =1
					AND tempHF.IsValid=1
					AND L.ValidityTo IS NULL
					AND HF.ValidityTo IS NULL
					AND HFC.ValidityTo IS NULL
				END
			/*========================================================================================================
			UDPATE CATCHMENT  STARTS
			========================================================================================================*/	

			/*========================================================================================================
			INSERT CATCHMENT  STARTS
			========================================================================================================*/	
				--INSERT HF
			IF (@StrategyId & @InsertOnly) > 0
				BEGIN
					
					--INSERT CATCHMENT
					INSERT INTO [tblHFCatchment]([HFID],[LocationId],[Catchment],[ValidityFrom],[AuditUserId])
					SELECT HF.HfID,L.LocationId, C.Percentage, GETDATE() ValidityFrom, @AuditUserId FROM @tblCatchment C 
					INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					INNER JOIN @tblHF tempHF ON tempHF.Code=C.HFCode
					LEFT OUTER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					WHERE 
					C.IsValid =1
					AND tempHF.IsValid=1
					AND L.ValidityTo IS NULL
					AND HF.ValidityTo IS NULL
					AND HFC.ValidityTo IS NULL
					AND HFC.LocationId IS NULL
					AND HFC.HFID IS NULL
				
					SELECT @InsertCatchment=@@ROWCOUNT

					INSERT INTO @tblResult(Result,ResultType)
					SELECT CONVERT(NVARCHAR(3), @InsertCatchment) , N'IC'
				END
			/*========================================================================================================
			INSERT CATCHMENT  STARTS
			========================================================================================================*/	

			COMMIT TRAN UPLOAD
		END

		
	END TRY
	BEGIN CATCH
		DECLARE @InvalidXML NVARCHAR(100)
		IF ERROR_NUMBER()=9436 
		BEGIN
			SET @InvalidXML='Invalid XML file, end tag does not match start tag'
			INSERT INTO @tblResult(Result, ResultType)
			SELECT @InvalidXML, N'FE';
		END
		ELSE IF ERROR_NUMBER()=8114 
			BEGIN
				SET @InvalidXML='Invalid input in percentage '
				INSERT INTO @tblResult(Result, ResultType)
				SELECT @InvalidXML, N'FE';
			END
		ELSE IF  ERROR_MESSAGE()=N'-200'
			BEGIN
				INSERT INTO @tblResult(Result, ResultType)
			SELECT'Invalid HF XML file', N'FE';
			END
		ELSE
			INSERT INTO @tblResult(Result, ResultType)
			SELECT'Invalid XML file', N'FE';

		IF @@TRANCOUNT > 0 ROLLBACK TRAN UPLOAD;
		SELECT * FROM @tblResult;
		RETURN -1;
	END CATCH

	SELECT * FROM @tblResult;
	RETURN 0;
END





GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspUploadICDList]
(
	@FilePath NVARCHAR(255),
	@AuditUserID INT,
	@DeleteRecord BIT = 0
)
AS
BEGIN
	
	DECLARE @BulkInsert NVARCHAR(2000)
	
	IF NOT OBJECT_ID('tempdb..#tempICD') IS NULL DROP TABLE #tempICD
	CREATE TABLE #tempICD(ICDCode NVARCHAR(6) ,ICDName NVARCHAR(255))
	
	SET @BulkInsert = N'BULK INSERT #tempICD FROM ''' + @FilePath + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	
	EXEC SP_EXECUTESQL @BulkInsert
	
	DECLARE @ICDCode NVARCHAR(6)
	DECLARE @ICDName NVARCHAR(255)
	DECLARE C CURSOR LOCAL FORWARD_ONLY FOR SELECT ICDCode,ICDName FROM #tempICD
	
	OPEN C
	FETCH NEXT FROM C INTO @ICDCode,@ICDName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF EXISTS(SELECT ICDCode FROM tblICDCodes WHERE ICDCode COLLATE DATABASE_DEFAULT = @ICDCode  COLLATE DATABASE_DEFAULT AND ValidityTo IS NULL)
			BEGIN
				INSERT INTO tblICDCodes(ICDCode,ICDName,LegacyID,ValidityTo,AuditUserID)
				SELECT ICDCode,ICDName,ICDID,GETDATE(),@AuditUserID FROM tblICDCodes WHERE ICDCode  COLLATE DATABASE_DEFAULT = @ICDCode  COLLATE DATABASE_DEFAULT AND ValidityTo IS NULL;
				
				UPDATE tblICDCodes SET ICDName = @ICDName,ValidityFrom = GETDATE(),AuditUserID = @AuditUserID WHERE ICDCode  COLLATE DATABASE_DEFAULT = @ICDCode  COLLATE DATABASE_DEFAULT AND ValidityTo IS NULL
			END
		ELSE
			BEGIN
				INSERT INTO tblICDCodes(ICDCode,ICDName,AuditUserID)
				VALUES(@ICDCode,@ICDName,@AuditUserID)
			END		
			
		FETCH NEXT FROM C INTO @ICDCode,@ICDName
	END

	IF @DeleteRecord = 1
	BEGIN
		INSERT INTO tblICDCodes (ICDCode,ICDName,LegacyID,ValidityTo,AuditUserID)
		SELECT I.ICDCode,I.ICDName,I.ICDID,GETDATE(),@AuditUserID
		FROM tblICDCodes I FULL OUTER JOIN #tempICD t ON I.ICDCode COLLATE DATABASE_DEFAULT = t.ICDCode COLLATE DATABASE_DEFAULT
		WHERE t.ICDCode IS NULL AND I.ValidityTo IS NULL

		UPDATE tblICDCodes SET ValidityTo = GETDATE(), AuditUserID = @AuditUserID 
		FROM tblICDCodes I FULL OUTER JOIN #tempICD t ON I.ICDCode COLLATE DATABASE_DEFAULT = t.ICDCode COLLATE DATABASE_DEFAULT
		WHERE t.ICDCode IS NULL AND I.ValidityTo IS NULL
	END
	
	CLOSE C
	DEALLOCATE C
	

END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspUploadLocationsXML]
(
		--@File NVARCHAR(500),
		@XML XML,
		@StrategyId INT,	--1	: Insert Only,	2: Update Only	3: Insert & Update	7: Insert, Update & Delete
		@DryRun BIT,
		@AuditUserId INT,
		@SentRegion INT =0 OUTPUT,  
		@SentDistrict INT =0  OUTPUT, 
		@SentWard INT =0  OUTPUT, 
		@SentVillage INT =0  OUTPUT, 
		@InsertRegion INT =0  OUTPUT, 
		@InsertDistrict INT =0  OUTPUT, 
		@InsertWard INT =0  OUTPUT, 
		@InsertVillage INT =0 OUTPUT, 
		@UpdateRegion INT =0  OUTPUT, 
		@UpdateDistrict INT =0  OUTPUT, 
		@UpdateWard INT =0  OUTPUT, 
		@UpdateVillage INT =0  OUTPUT
)
AS 
	BEGIN

		/* Result type in @tblResults
		-------------------------------
			E	:	Error
			C	:	Conflict
			FE	:	Fatal Error

		Return Values
		------------------------------
			0	:	All Okay
			-1	:	Fatal error
		*/

		DECLARE @InsertOnly INT = 1,
				@UpdateOnly INT = 2,
				@Delete INT= 4

		SET @SentRegion = 0
		SET @SentDistrict = 0
		SET @SentWard = 0
		SET @SentVillage = 0
		SET @InsertRegion = 0
		SET @InsertDistrict = 0
		SET @InsertWard = 0
		SET @InsertVillage = 0
		SET @UpdateRegion = 0
		SET @UpdateDistrict = 0
		SET @UpdateWard = 0
		SET @UpdateVillage = 0

		DECLARE @Query NVARCHAR(500)
		--DECLARE @XML XML
		DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
		DECLARE @tempRegion TABLE(RegionCode NVARCHAR(100), RegionName NVARCHAR(100), IsValid BIT )
		DECLARE @tempLocation TABLE(LocationCode NVARCHAR(100))
		DECLARE @tempDistricts TABLE(RegionCode NVARCHAR(100),DistrictCode NVARCHAR(100),DistrictName NVARCHAR(100), IsValid BIT )
		DECLARE @tempWards TABLE(DistrictCode NVARCHAR(100),WardCode NVARCHAR(100),WardName NVARCHAR(100), IsValid BIT )
		DECLARE @tempVillages TABLE(WardCode NVARCHAR(100),VillageCode NVARCHAR(100), VillageName NVARCHAR(100),MalePopulation INT,FemalePopulation INT, OtherPopulation INT, Families INT, IsValid BIT )

		BEGIN TRY
	
			--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

			--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT
			
			
			IF ( @XML.exist('(Locations/Regions/Region)')=1 AND  @XML.exist('(Locations/Districts/District)')=1 AND  @XML.exist('(Locations/Municipalities/Municipality)')=1 AND  @XML.exist('(Locations/Villages/Village)')=1)
				BEGIN
					--GET ALL THE REGIONS FROM THE XML
					INSERT INTO @tempRegion(RegionCode,RegionName,IsValid)
					SELECT 
					NULLIF(T.R.value('(RegionCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(RegionName)[1]','NVARCHAR(100)'),''),
					1
					FROM @XML.nodes('Locations/Regions/Region') AS T(R)
		
					SELECT @SentRegion=@@ROWCOUNT

					--GET ALL THE DISTRICTS FROM THE XML
					INSERT INTO @tempDistricts(RegionCode, DistrictCode, DistrictName,IsValid)
					SELECT 
					NULLIF(T.R.value('(RegionCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(DistrictCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(DistrictName)[1]','NVARCHAR(100)'),''),
					1
					FROM @XML.nodes('Locations/Districts/District') AS T(R)

					SELECT @SentDistrict=@@ROWCOUNT

					--GET ALL THE WARDS FROM THE XML
					INSERT INTO @tempWards(DistrictCode,WardCode, WardName,IsValid)
					SELECT 
					NULLIF(T.R.value('(DistrictCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(MunicipalityCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(MunicipalityName)[1]','NVARCHAR(100)'),''),
					1
					FROM @XML.nodes('Locations/Municipalities/Municipality') AS T(R)
		
					SELECT @SentWard = @@ROWCOUNT

					--GET ALL THE VILLAGES FROM THE XML
					INSERT INTO @tempVillages(WardCode, VillageCode, VillageName, MalePopulation, FemalePopulation, OtherPopulation, Families, IsValid)
					SELECT 
					NULLIF(T.R.value('(MunicipalityCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(VillageCode)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(VillageName)[1]','NVARCHAR(100)'),''),
					NULLIF(T.R.value('(MalePopulation)[1]','INT'),0),
					NULLIF(T.R.value('(FemalePopulation)[1]','INT'),0),
					NULLIF(T.R.value('(OtherPopulation)[1]','INT'),0),
					NULLIF(T.R.value('(Families)[1]','INT'),0),
					1
					FROM @XML.nodes('Locations/Villages/Village') AS T(R)
		
					SELECT @SentVillage=@@ROWCOUNT
				END
			ELSE
				BEGIN
					RAISERROR (N'-200', 16, 1);
				END


			--SELECT * INTO tempRegion from @tempRegion
			--SELECT * INTO tempDistricts from @tempDistricts
			--SELECT * INTO tempWards from @tempWards
			--SELECT * INTO tempVillages from @tempVillages

			--RETURN

			/*========================================================================================================
			VALIDATION STARTS
			========================================================================================================*/	
			/********************************CHECK THE DUPLICATE LOCATION CODE******************************/
				INSERT INTO @tempLocation(LocationCode)
				SELECT RegionCode FROM @tempRegion
				INSERT INTO @tempLocation(LocationCode)
				SELECT DistrictCode FROM @tempDistricts
				INSERT INTO @tempLocation(LocationCode)
				SELECT WardCode FROM @tempWards
				INSERT INTO @tempLocation(LocationCode)
				SELECT VillageCode FROM @tempVillages
			
				INSERT INTO @tblResult(Result, ResultType)
				SELECT N'Location Code ' + QUOTENAME(LocationCode) + '  has already being used in a file ', N'C' FROM @tempLocation GROUP BY LocationCode HAVING COUNT(LocationCode)>1

				UPDATE @tempRegion  SET IsValid=0 WHERE RegionCode IN (SELECT LocationCode FROM @tempLocation GROUP BY LocationCode HAVING COUNT(LocationCode)>1)
				UPDATE @tempDistricts  SET IsValid=0 WHERE DistrictCode IN (SELECT LocationCode FROM @tempLocation GROUP BY LocationCode HAVING COUNT(LocationCode)>1)
				UPDATE @tempWards  SET IsValid=0 WHERE WardCode IN (SELECT LocationCode FROM @tempLocation GROUP BY LocationCode HAVING COUNT(LocationCode)>1)
				UPDATE @tempVillages  SET IsValid=0 WHERE VillageCode IN (SELECT LocationCode FROM @tempLocation GROUP BY LocationCode HAVING COUNT(LocationCode)>1)


			/********************************REGION STARTS******************************/
			--check if the regioncode is null 
			IF EXISTS(
			SELECT 1 FROM @tempRegion WHERE  LEN(ISNULL(RegionCode,''))=0 
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT  CONVERT(NVARCHAR(3), COUNT(1)) + N' Region(s) have empty code', N'E' FROM @tempRegion WHERE  LEN(ISNULL(RegionCode,''))=0 
		
			UPDATE @tempRegion SET IsValid=0  WHERE  LEN(ISNULL(RegionCode,''))=0 
		
			--check if the regionname is null 
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Region Code ' + QUOTENAME(RegionCode) + N' has empty name', N'E' FROM @tempRegion WHERE  LEN(ISNULL(RegionName,''))=0 
		
			UPDATE @tempRegion SET IsValid=0  WHERE RegionName  IS NULL OR LEN(ISNULL(RegionName,''))=0 

			--Check for Duplicates in file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Region Code ' + QUOTENAME(RegionCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(RegionCode)) + ' times in the file', N'C'  FROM @tempRegion GROUP BY RegionCode HAVING COUNT(RegionCode) >1 
		
			UPDATE R SET IsValid = 0 FROM @tempRegion R
			WHERE RegionCode in (SELECT RegionCode from @tempRegion GROUP BY RegionCode HAVING COUNT(RegionCode) >1)
		
			--check the length of the regionCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Region Code ' + QUOTENAME(RegionCode) + N' is greater than 50', N'E' FROM @tempRegion WHERE  LEN(ISNULL(RegionCode,''))>50
		
			UPDATE @tempRegion SET IsValid=0  WHERE LEN(ISNULL(RegionCode,''))>50

			--check the length of the regionname
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Region Name ' + QUOTENAME(RegionCode) + N' is greater than 50', N'E' FROM @tempRegion WHERE  LEN(ISNULL(RegionName,''))>50
		
			UPDATE @tempRegion SET IsValid=0  WHERE LEN(ISNULL(RegionName,''))>50
		
		

			/********************************REGION ENDS******************************/

			/********************************DISTRICT STARTS******************************/
			--check if the district has regioncode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'District Code ' + QUOTENAME(DistrictCode) + N' has empty Region Code', N'E' FROM @tempDistricts WHERE  LEN(ISNULL(RegionCode,''))=0 
		
			UPDATE @tempDistricts SET IsValid=0  WHERE  LEN(ISNULL(RegionCode,''))=0 

			--check if the district has valid regioncode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'District Code ' + QUOTENAME(DistrictCode) + N' has invalid Region Code', N'E' FROM @tempDistricts TD
			LEFT OUTER JOIN @tempRegion TR ON TR.RegionCode=TD.RegionCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TD.RegionCode AND L.LocationType='R' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TR.RegionCode IS NULL
			AND LEN(TD.RegionCode)>0

			UPDATE TD SET TD.IsValid=0 FROM @tempDistricts TD
			LEFT OUTER JOIN @tempRegion TR ON TR.RegionCode=TD.RegionCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TD.RegionCode AND L.LocationType='R' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TR.RegionCode IS NULL
			AND LEN(TD.RegionCode)>0

			--check if the districtcode is null 
			IF EXISTS(
			SELECT  1 FROM @tempDistricts WHERE  LEN(ISNULL(DistrictCode,''))=0 
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT  CONVERT(NVARCHAR(3), COUNT(1)) + N' District(s) have empty District code', N'E' FROM @tempDistricts WHERE  LEN(ISNULL(DistrictCode,''))=0 
		
			UPDATE @tempDistricts SET IsValid=0  WHERE  LEN(ISNULL(DistrictCode,''))=0 
		
			--check if the districtname is null 
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'District Code ' + QUOTENAME(DistrictCode) + N' has empty name', N'E' FROM @tempDistricts WHERE  LEN(ISNULL(DistrictName,''))=0 
		
			UPDATE @tempDistricts SET IsValid=0  WHERE  LEN(ISNULL(DistrictName,''))=0 
		
			--Check for Duplicates in file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'District Code ' + QUOTENAME(DistrictCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(DistrictCode)) + ' times in the file', N'C'  FROM @tempDistricts GROUP BY DistrictCode HAVING COUNT(DistrictCode) >1 
		
			UPDATE D SET IsValid = 0 FROM @tempDistricts D
			WHERE DistrictCode in (SELECT DistrictCode from @tempDistricts GROUP BY DistrictCode HAVING COUNT(DistrictCode) >1)

			--check the length of the DistrictCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the District Code ' + QUOTENAME(DistrictCode) + N' is greater than 50', N'E' FROM @tempDistricts WHERE  LEN(ISNULL(DistrictCode,''))>50
		
			UPDATE @tempDistricts SET IsValid=0  WHERE LEN(ISNULL(DistrictCode,''))>50

			--check the length of the regionname
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the District Name ' + QUOTENAME(DistrictName) + N' is greater than 50', N'E' FROM @tempDistricts WHERE  LEN(ISNULL(DistrictName,''))>50
		
			UPDATE @tempDistricts SET IsValid=0  WHERE LEN(ISNULL(DistrictName,''))>50

			--Validate Parent Location
			IF (@StrategyId & @UpdateOnly) > 0
				BEGIN
					INSERT INTO @tblResult(Result, ResultType)
					SELECT N'Region Code ' + QUOTENAME(TD.RegionCode) + ' for the District Code ' + QUOTENAME(TD.DistrictCode) + ' does not match with the database', N'FD'
					FROM @tempDistricts TD
					INNER JOIN tblDistricts D ON TD.DistrictCode = D.DistrictCode
					LEFT OUTER JOIN tblRegions R ON TD.RegionCode = R.RegionCode
					WHERE D.ValidityTo IS NULL
					AND R.ValidityTo IS NULL
					AND D.Region != R.RegionId;

					UPDATE TD SET IsValid = 0
					FROM @tempDistricts TD
					INNER JOIN tblDistricts D ON TD.DistrictCode = D.DistrictCode
					LEFT OUTER JOIN tblRegions R ON TD.RegionCode = R.RegionCode
					WHERE D.ValidityTo IS NULL
					AND R.ValidityTo IS NULL
					AND D.Region != R.RegionId;

				END
		
			/********************************DISTRICT ENDS******************************/

			/********************************WARDS STARTS******************************/
			--check if the ward has districtcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Municipality Code ' + QUOTENAME(WardCode) + N' has empty District Code', N'E' FROM @tempWards WHERE  LEN(ISNULL(DistrictCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(DistrictCode,''))=0 

			--check if the ward has valid districtCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Municipality Code ' + QUOTENAME(WardCode) + N' has invalid District Code', N'E' 
			FROM @tempWards TW
			LEFT OUTER JOIN @tempDistricts TD ON  TD.DistrictCode=TW.DistrictCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.DistrictCode AND L.LocationType='D' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TD.DistrictCode IS NULL
			AND LEN(TW.DistrictCode)>0

			UPDATE TW SET TW.IsValid=0 FROM @tempWards TW
			LEFT OUTER JOIN @tempDistricts TD ON  TD.DistrictCode=TW.DistrictCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.DistrictCode AND L.LocationType='D' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TD.DistrictCode IS NULL
			AND LEN(TW.DistrictCode)>0

			--check if the wardcode is null 
			IF EXISTS(
			SELECT  1 FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))=0 
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT  CONVERT(NVARCHAR(3), COUNT(1)) + N' Ward(s) have empty Municipality Code', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 
		
			--check if the wardname is null 
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Municipality Code ' + QUOTENAME(WardCode) + N' has empty name', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardName,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(WardName,''))=0 
		
			--Check for Duplicates in file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Municipality Code ' + QUOTENAME(WardCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(WardCode)) + ' times in the file', N'C'  FROM @tempWards GROUP BY WardCode HAVING COUNT(WardCode) >1 
		
			UPDATE W SET IsValid = 0 FROM @tempWards W
			WHERE WardCode in (SELECT WardCode from @tempWards GROUP BY WardCode HAVING COUNT(WardCode) >1)

			--check the length of the wardcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Municipality Code ' + QUOTENAME(WardCode) + N' is greater than 50', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))>50
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardCode,''))>50

			--check the length of the wardname
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Municipality Name ' + QUOTENAME(WardName) + N' is greater than 50', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardName,''))>50
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardName,''))>50;

			--Validate the parent location
			IF (@StrategyId & @UpdateOnly) > 0
				BEGIN
					INSERT INTO @tblResult(Result, ResultType)
					SELECT N'District Code ' + QUOTENAME(TW.DistrictCode) + ' for the Municipality Code ' + QUOTENAME(TW.WardCode) + ' does not match with the database', N'FM'
					FROM @tempWards TW
					INNER JOIN tblWards W ON TW.WardCode = W.WardCode
					LEFT OUTER JOIN tblDistricts D ON TW.DistrictCode = D.DistrictCode
					WHERE W.ValidityTo IS NULL
					AND D.ValidityTo IS NULL
					AND W.DistrictId != D.DistrictId;

					UPDATE TW SET IsValid = 0
					FROM @tempWards TW
					INNER JOIN tblWards W ON TW.WardCode = W.WardCode
					LEFT OUTER JOIN tblDistricts D ON TW.DistrictCode = D.DistrictCode
					WHERE W.ValidityTo IS NULL
					AND D.ValidityTo IS NULL
					AND W.DistrictId != D.DistrictId;

				END

		
			/********************************WARDS ENDS******************************/

			/********************************VILLAGE STARTS******************************/
			--check if the village has Wardcoce
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has empty Municipality Code', N'E' FROM @tempVillages WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempVillages SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 

			--check if the village has valid wardcode

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has invalid Municipality Code', N'E' 
			FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON TV.WardCode = TW.WardCode
			LEFT OUTER JOIN tblWards W ON TV.WardCode = W.WardCode
			WHERE W.ValidityTo IS NULL
			AND TW.WardCode IS NULL 
			AND W.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0;

			UPDATE TV SET TV.IsValid=0 
			FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON TV.WardCode = TW.WardCode
			LEFT OUTER JOIN tblWards W ON TV.WardCode = W.WardCode
			WHERE W.ValidityTo IS NULL
			AND TW.WardCode IS NULL 
			AND W.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0;

			--check if the villagecode is null 
			IF EXISTS(
			SELECT  1 FROM @tempVillages WHERE  LEN(ISNULL(VillageCode,''))=0 
			)
			INSERT INTO @tblResult(Result, ResultType)
			SELECT  CONVERT(NVARCHAR(3), COUNT(1)) + N' Village(s) have empty Village code', N'E' FROM @tempVillages WHERE  LEN(ISNULL(VillageCode,''))=0 
		
			UPDATE @tempVillages SET IsValid=0  WHERE  LEN(ISNULL(VillageCode,''))=0 
		
			--check if the villageName is null 
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has empty name', N'E' FROM @tempVillages WHERE  LEN(ISNULL(VillageName,''))=0 
		
			UPDATE @tempVillages SET IsValid=0  WHERE  LEN(ISNULL(VillageName,''))=0 
		
			--Check for Duplicates in file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(VillageCode)) + ' times in the file', N'C'  FROM @tempVillages GROUP BY VillageCode HAVING COUNT(VillageCode) >1 
		
			UPDATE V SET IsValid = 0 FROM @tempVillages V
			WHERE VillageCode in (SELECT VillageCode from @tempVillages GROUP BY VillageCode HAVING COUNT(VillageCode) >1)

			--check the length of the VillageCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Village Code ' + QUOTENAME(VillageCode) + N' is greater than 50', N'E' FROM @tempVillages WHERE  LEN(ISNULL(VillageCode,''))>50
		
			UPDATE @tempVillages SET IsValid=0  WHERE LEN(ISNULL(VillageCode,''))>50

			--check the length of the VillageName
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Village Name ' + QUOTENAME(VillageName) + N' is greater than 50', N'E' FROM @tempVillages WHERE  LEN(ISNULL(VillageName,''))>50
		
			UPDATE @tempVillages SET IsValid=0  WHERE LEN(ISNULL(VillageName,''))>50

			--check the validity of the malepopulation
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'The Village Code' + QUOTENAME(VillageCode) + N' has invalid Male polulation', N'E' FROM @tempVillages WHERE  MalePopulation<0
		
			UPDATE @tempVillages SET IsValid=0  WHERE MalePopulation<0

			--check the validity of the female population
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'The Village Code' + QUOTENAME(VillageCode) + N' has invalid Female polulation', N'E' FROM @tempVillages WHERE  FemalePopulation<0
		
			UPDATE @tempVillages SET IsValid=0  WHERE FemalePopulation<0

			--check the validity of the OtherPopulation
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'The Village Code' + QUOTENAME(VillageCode) + N' has invalid Others polulation', N'E' FROM @tempVillages WHERE  OtherPopulation<0
		
			UPDATE @tempVillages SET IsValid=0  WHERE OtherPopulation<0

			--check the validity of the number of families
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'The Village Code' + QUOTENAME(VillageCode) + N' has invalid Number of  Families', N'E' FROM @tempVillages WHERE  Families<0
		
			UPDATE @tempVillages SET IsValid=0  WHERE Families < 0;

			--Validate the parent location
			IF (@StrategyId & @UpdateOnly) > 0
				BEGIN
					INSERT INTO @tblResult(Result, ResultType)
					SELECT N'Municipality Code ' + QUOTENAME(TV.WardCode) + ' for the Village Code ' + QUOTENAME(TV.VillageCode) + ' does not match with the database', N'FV'
					FROM @tempVillages TV
					INNER JOIN tblVillages V ON TV.VillageCode = V.VillageCode
					LEFT OUTER JOIN tblWards W ON TV.WardCode = W.WardCode
					WHERE V.ValidityTo IS NULL
					AND W.ValidityTo IS NULL
					AND V.WardId != W.WardId;

					UPDATE TV SET IsValid = 0
					FROM @tempVillages TV
					INNER JOIN tblVillages V ON TV.VillageCode = V.VillageCode
					LEFT OUTER JOIN tblWards W ON TV.WardCode = W.WardCode
					WHERE V.ValidityTo IS NULL
					AND W.ValidityTo IS NULL
					AND V.WardId != W.WardId;

				END

		
			/********************************VILLAGE ENDS******************************/
			/*========================================================================================================
			VALIDATION ENDS
			========================================================================================================*/	
	
			/*========================================================================================================
			COUNTS START
			========================================================================================================*/	
					--updates counts	
					IF (@StrategyId & @UpdateOnly) > 0
					BEGIN
							--Failed Locations
							IF (@StrategyId = @UpdateOnly)
							BEGIN
								--Failed Regions
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'Region Code ' + QUOTENAME(TR.RegionCode) + ' does not exists in database', N'FR'
								FROM @tempRegion TR
								LEFT OUTER JOIN tblRegions R ON TR.RegionCode = R.RegionCode
								WHERE R.ValidityTo IS NULL 
								--AND TR.IsValid=1
								AND R.RegionCode IS NULL;

								--Failed District
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'District Code ' + QUOTENAME(TD.DistrictCode) + ' does not exists in database', N'FD'
								FROM @tempDistricts TD
								LEFT OUTER JOIN tblDistricts D ON TD.DistrictCode = D.DistrictCode
								WHERE D.ValidityTo IS NULL 
								--AND TD.IsValid=1
								AND D.DistrictCode IS NULL;

								--Failed Municipality
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'Municipality Code ' + QUOTENAME(TM.WardCode) + ' does not exists in database', N'FM'
								FROM @tempWards TM
								LEFT OUTER JOIN tblWards W ON TM.WardCode= W.WardCode
								WHERE W.ValidityTo IS NULL 
								--AND TM.IsValid=1
								AND W.WardCode IS NULL;

								--Failed Villages
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'Village Code ' + QUOTENAME(TV.VillageCode) + ' does not exists in database', N'FV'
								FROM @tempVillages TV
								LEFT OUTER JOIN tblVillages V ON TV.VillageCode=V.VillageCode
								WHERE V.ValidityTo IS NULL 
								--AND TV.IsValid=1
								AND V.VillageCode IS NULL;


							END
						--Regions updates
							SELECT @UpdateRegion=COUNT(1) FROM @tempRegion TR 
							INNER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
							WHERE
							TR.IsValid=1
							AND L.ValidityTo IS NULL
							
						--Districts updates
							SELECT @UpdateDistrict=COUNT(1) FROM @tempDistricts TD 
							INNER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
							WHERE
							TD.IsValid=1
							AND L.ValidityTo IS NULL

						--Wards updates
							SELECT @UpdateWard=COUNT(1) FROM @tempWards TW 
							INNER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
							WHERE
							TW.IsValid=1
							AND L.ValidityTo IS NULL

						--Villages updates
							SELECT @UpdateVillage=COUNT(1) FROM @tempVillages TV 
							INNER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
							WHERE
							TV.IsValid=1
							AND L.ValidityTo IS NULL
					END

					--To be inserted
					IF (@StrategyId & @InsertOnly) > 0
						BEGIN
							
							--Failed Region
							IF (@StrategyId = @InsertOnly)
							BEGIN
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'Region Code' + QUOTENAME(TR.RegionCode) + ' is already exists in database', N'FR'
								FROM @tempRegion TR
								INNER JOIN tblLocations L ON TR.RegionCode = L.LocationCode
								WHERE L.ValidityTo IS NULL 
								--AND TR.IsValid=1;
							END
							--Regions insert
							SELECT @InsertRegion=COUNT(1) FROM @tempRegion TR 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
							WHERE
							TR.IsValid=1 AND
							L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

							--Failed Districts
							IF (@StrategyId = @InsertOnly)
							BEGIN
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'District Code' + QUOTENAME(TD.DistrictCode) + ' is already exists in database', N'FD'
								FROM @tempDistricts TD
								INNER JOIN tblLocations L ON TD.DistrictCode = L.LocationCode
								WHERE L.ValidityTo IS NULL 
								--AND TD.IsValid=1;
							END
							--Districts insert
							SELECT @InsertDistrict=COUNT(1) FROM @tempDistricts TD 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
							LEFT  OUTER JOIN tblRegions R ON TD.RegionCode = R.RegionCode AND R.ValidityTo IS NULL
							LEFT OUTER JOIN @tempRegion TR ON TD.RegionCode = TR.RegionCode
							WHERE
							TD.IsValid=1
							AND TR.IsValid = 1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL
							
							--Failed Municipalities
							IF (@StrategyId = @InsertOnly)
							BEGIN
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'Municipality Code' + QUOTENAME(TW.WardCode) + ' is already exists in database', N'FM'
								FROM @tempWards TW
								INNER JOIN tblLocations L ON TW.WardCode = L.LocationCode
								WHERE L.ValidityTo IS NULL 
								--AND TW.IsValid=1;
							END
							--Wards insert
							SELECT @InsertWard=COUNT(1) FROM @tempWards TW 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
							LEFT  OUTER JOIN tblDistricts D ON TW.DistrictCode = D.DistrictCode AND D.ValidityTo IS NULL
							LEFT OUTER JOIN @tempDistricts TD ON TD.DistrictCode = TW.DistrictCode
							WHERE
							TW.IsValid=1
							AND TD.IsValid = 1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

							--Failed Village
							IF (@StrategyId = @InsertOnly)
							BEGIN
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'Village Code' + QUOTENAME(TV.VillageCode) + ' is already exists in database', N'FV'
								FROM @tempVillages TV
								INNER JOIN tblLocations L ON TV.VillageCode= L.LocationCode
								WHERE L.ValidityTo IS NULL 
								--AND TV.IsValid=1;
							END
							--Villages insert
							SELECT @InsertVillage=COUNT(1) FROM @tempVillages TV 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
							LEFT  OUTER JOIN tblWards W ON TV.WardCode = W.WardCode AND W.ValidityTo IS NULL
							LEFT OUTER JOIN @tempWards TW ON TV.WardCode = TW.WardCode
							WHERE
							TV.IsValid=1
							AND TW.IsValid = 1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL
						END
			


			/*========================================================================================================
			COUNTS ENDS
			========================================================================================================*/	
		
			
				IF @DryRun =0
					BEGIN
						BEGIN TRAN UPLOAD

						
			/*========================================================================================================
			UPDATE STARTS
			========================================================================================================*/	
					IF (@StrategyId & @UpdateOnly) > 0
							BEGIN
							/********************************REGIONS******************************/
								--insert historocal record(s)
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
									SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
									FROM @tempRegion TR 
									INNER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
									WHERE TR.IsValid=1 AND L.ValidityTo IS NULL

								--update
									UPDATE L SET  L.LocationName=TR.RegionName, ValidityFrom=GETDATE(),L.AuditUserId=@AuditUserId
									OUTPUT QUOTENAME(deleted.LocationCode), N'UR' INTO @tblResult
									FROM @tempRegion TR 
									INNER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
									WHERE TR.IsValid=1 AND L.ValidityTo IS NULL;

									SELECT @UpdateRegion = @@ROWCOUNT;

									/********************************DISTRICTS******************************/
								--Insert historical records
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
										SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
										FROM @tempDistricts TD 
										INNER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
										WHERE TD.IsValid=1 AND L.ValidityTo IS NULL

									--update
										UPDATE L SET L.LocationName=TD.DistrictName, ValidityFrom=GETDATE(),L.AuditUserId=@AuditUserId
										OUTPUT QUOTENAME(deleted.LocationCode), N'UD' INTO @tblResult
										FROM @tempDistricts TD 
										INNER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
										WHERE TD.IsValid=1 AND L.ValidityTo IS NULL;

										SELECT @UpdateDistrict = @@ROWCOUNT;

										/********************************WARD******************************/
								--Insert historical records
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
										SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
										FROM @tempWards TW 
										INNER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
										WHERE TW.IsValid=1 AND L.ValidityTo IS NULL

								--Update
									UPDATE L SET L.LocationName=TW.WardName, ValidityFrom=GETDATE(),L.AuditUserId=@AuditUserId
										OUTPUT QUOTENAME(deleted.LocationCode), N'UM' INTO @tblResult
										FROM @tempWards TW 
										INNER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
										WHERE TW.IsValid=1 AND L.ValidityTo IS NULL;

										SELECT @UpdateWard = @@ROWCOUNT;
									  
										/********************************VILLAGES******************************/
								--Insert historical records
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
										SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
										FROM @tempVillages TV 
										INNER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
										WHERE TV.IsValid=1 AND L.ValidityTo IS NULL

								--Update
									UPDATE L  SET L.LocationName=TV.VillageName, L.MalePopulation=TV.MalePopulation, L.FemalePopulation=TV.FemalePopulation, L.OtherPopulation=TV.OtherPopulation, L.Families=TV.Families, ValidityFrom=GETDATE(),L.AuditUserId=@AuditUserId
										OUTPUT QUOTENAME(deleted.LocationCode), N'UV' INTO @tblResult
										FROM @tempVillages TV 
										INNER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
										WHERE TV.IsValid=1 AND L.ValidityTo IS NULL;

										SELECT @UpdateVillage = @@ROWCOUNT;

							END
			/*========================================================================================================
			UPDATE ENDS
			========================================================================================================*/	

			/*========================================================================================================
			INSERT STARTS
			========================================================================================================*/	
					IF (@StrategyId & @InsertOnly) > 0
							BEGIN
								--insert Region(s)
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[LocationType],[ValidityFrom],[AuditUserId])
									OUTPUT QUOTENAME(inserted.LocationCode), N'IR' INTO @tblResult
									SELECT TR.RegionCode, TR.RegionName,'R',GETDATE(), @AuditUserId AuditUserId 
									FROM @tempRegion TR 
									LEFT OUTER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
									WHERE
									TR.IsValid=1
									AND L.ValidityTo IS NULL
									AND L.LocationCode IS NULL;

									SELECT @InsertRegion = @@ROWCOUNT;


								--Insert District(s)
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[AuditUserId])
									OUTPUT QUOTENAME(inserted.LocationCode), N'ID' INTO @tblResult
									SELECT TD.DistrictCode, TD.DistrictName, R.RegionId, 'D', GETDATE(), @AuditUserId AuditUserId 
									FROM @tempDistricts TD
									INNER JOIN tblRegions R ON TD.RegionCode = R.RegionCode
									LEFT OUTER JOIN tblDistricts D ON TD.DistrictCode = D.DistrictCode
									WHERE R.ValidityTo IS NULL
									AND D.ValidityTo IS NULL 
									AND D.DistrictId IS NULL;

									SELECT @InsertDistrict = @@ROWCOUNT;
									
								--Insert Wards
								INSERT INTO [tblLocations]
									([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[AuditUserId])
								OUTPUT QUOTENAME(inserted.LocationCode), N'IM' INTO @tblResult
								SELECT TW.WardCode, TW.WardName, D.DistrictId, 'W',GETDATE(), @AuditUserId AuditUserId 
								FROM @tempWards TW
								INNER JOIN tblDistricts D ON TW.DistrictCode = D.DistrictCode
								LEFT OUTER JOIN tblWards W ON TW.WardCode = W.WardCode
								WHERE D.ValidityTo IS NULL
								AND W.ValidityTo IS NULL 
								AND W.WardId IS NULL;

									SELECT @InsertWard = @@ROWCOUNT;
									

							--insert  villages
								INSERT INTO [tblLocations]
									([LocationCode],[LocationName],[ParentLocationId],[LocationType], [MalePopulation],[FemalePopulation],[OtherPopulation],[Families], [ValidityFrom],[AuditUserId])
								OUTPUT QUOTENAME(inserted.LocationCode), N'IV' INTO @tblResult
								SELECT TV.VillageCode,TV.VillageName,W.WardId,'V',TV.MalePopulation,TV.FemalePopulation,TV.OtherPopulation,TV.Families,GETDATE(), @AuditUserId AuditUserId
								FROM @tempVillages TV
								INNER JOIN tblWards W ON TV.WardCode = W.WardCode
								LEFT OUTER JOIN tblVillages V ON TV.VillageCode = V.VillageCode
								WHERE W.ValidityTo IS NULL
								AND V.ValidityTo IS NULL 
								AND V.VillageId IS NULL;

									SELECT @InsertVillage = @@ROWCOUNT;

							END
			/*========================================================================================================
			INSERT ENDS
			========================================================================================================*/	
							

						COMMIT TRAN UPLOAD
					END
		
			
		
		END TRY
		BEGIN CATCH
			DECLARE @InvalidXML NVARCHAR(100)
			IF ERROR_NUMBER()=245 
				BEGIN
					SET @InvalidXML='Invalid input in either MalePopulation, FemalePopulation, OtherPopulation or Number of Families '
					INSERT INTO @tblResult(Result, ResultType)
					SELECT @InvalidXML, N'FE';
				END
			ELSE  IF ERROR_NUMBER()=9436 
				BEGIN
					SET @InvalidXML='Invalid XML file, end tag does not match start tag'
					INSERT INTO @tblResult(Result, ResultType)
					SELECT @InvalidXML, N'FE';
				END
			ELSE IF  ERROR_MESSAGE()=N'-200'
				BEGIN
					INSERT INTO @tblResult(Result, ResultType)
				SELECT'Invalid Locations XML file', N'FE';
			END
			ELSE
				INSERT INTO @tblResult(Result, ResultType)
				SELECT'Invalid XML file', N'FE';

			IF @@TRANCOUNT > 0 ROLLBACK TRAN UPLOAD;
			SELECT * FROM @tblResult
			RETURN -1;
				
		END CATCH
		SELECT * FROM @tblResult
		RETURN 0;
	END






GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dw].[uspGetExpenditureRange]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @MaxAmount FLOAT,
			@Step FLOAT = 25000
		
	DECLARE @Counter FLOAT = @Step;

	DECLARE @Range NVARCHAR(30) = '',
			@Low FLOAT = 0,
			@High FLOAT

	SELECT @MaxAmount = MAX(Valuated) FROM(
	SELECT C.ClaimID, SUM(ISNULL(CI.PriceValuated,0) + ISNULL(CS.PriceValuated,0))Valuated
	FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
	LEFT OUTER JOIN tblClaimServices CS ON C.ClaimId = CS.ClaimID
	WHERE C.ValidityTo IS NULL
	AND C.ClaimStatus > 4
	GROUP BY C.ClaimID)Val

	DECLARE @Temp TABLE(ExpenditureRange NVARCHAR(50),ExpenditureLow FLOAT, ExpenditureHigh FLOAT)

	WHILE @Counter - @Step < @MaxAmount
	BEGIN
		SET @Low = CASE WHEN @Counter - @Step - 1 < 0 THEN 0 ELSE @Counter - @Step + 1 END
		SET @High = @Counter
		SET @Range = CAST(@Low AS NVARCHAR) + '-' + CAST(@High AS NVARCHAR)

		INSERT INTO @Temp(ExpenditureRange,ExpenditureLow,ExpenditureHigh)
		SELECT @Range,@Low,@High;

		SET @Counter += @Step;
	END


	SELECT * FROM @Temp;

END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dw].[uspPremumAllocated]
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @Counter INT = 1,
			@Year INT,
			@Date DATE,
			@EndDate DATE,
			@DaysInMonth INT,
			@MaxYear INT


	DECLARE @tblResult TABLE(
							Allocated DECIMAL(18,6),
							Region NVARCHAR(50), 
							DistrictName NVARCHAR(50), 
							ProductCode NVARCHAR(8), 
							ProductName NVARCHAR(100),
							MonthTime INT, 
							QuarterTime INT, 
							YearTime INT
							);

	SELECT @Year = YEAR(MIN(PayDate)) FROM tblPremium WHERE ValidityTo IS NULL;
	SELECT @MaxYear = YEAR(MAX(ExpiryDate)) FROM tblPolicy WHERE ValidityTo IS NULL;	



	WHILE @Year <= @MaxYear
	BEGIN	
		WHILE @Counter <= 12
		BEGIN

			SELECT @Date = CAST(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-' + '01' AS DATE)
			SELECT @DaysInMonth = DAY(EOMONTH(@Date)) --DATEDIFF(DAY,@Date,DATEADD(MONTH,1,@Date))
			SELECT @EndDate = EOMONTH(@Date)--CAST(CONVERT(VARCHAR(4),@Year) + '-' + CONVERT(VARCHAR(2),@Counter) + '-' + CONVERT(VARCHAR(2),@DaysInMonth) AS DATE)
	


			;WITH Allocation AS
			(
				SELECT R.RegionName Region, D.DistrictName,Prod.ProductCode, Prod.ProductName,
				@Counter MonthTime,DATEPART(QUARTER,@Date)QuarterTime,@Year YearTime
				,CASE 
				WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Counter AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
					THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
				WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Counter AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
					THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
				WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
					THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
				END Allocated
				FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
				INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
				INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
				INNER JOIN tblVillages V ON V.VillageId = F.LocationId
				INNER JOIN tblWards W ON W.WardId = V.WardId
				INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
				INNER JOIN tblRegions R ON D.Region = R.RegionID
				--LEFT OUTER JOIN tblDistricts D ON Prod.DistrictID = D.DistrictID
				--LEFT OUTER JOIN tblRegions R ON R.RegionId = D.Region
				WHERE PR.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL
				AND Prod.ValidityTo IS  NULL
				AND F.ValidityTo IS NULL
				AND D.ValidityTo IS NULL
				AND PL.PolicyStatus <> 1
				AND PR.PayDate <= PL.ExpiryDate
	
				GROUP BY PL.ExpiryDate, PR.PayDate, PL.EffectiveDate,R.RegionName, D.DistrictName,Prod.ProductCode, Prod.ProductName
			)
			INSERT INTO @tblResult(Allocated ,Region, DistrictName, ProductCode, ProductName, MonthTime, QuarterTime, YearTime)
			SELECT SUM(Allocated)Allocated, Region,DistrictName,ProductCode, ProductName,MonthTime,QuarterTime,YearTime
			FROM Allocation
			GROUP BY Region, DistrictName, ProductCode, ProductName,MonthTime,QuarterTime,YearTime;


			SET @Counter += 1;
		END	
		SET @Counter = 1;
		SET @Year += 1;
	END
	SELECT * FROM @tblResult;
END
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'N: Not Used	O: Optional	M: Mandatory' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblControls', @level2type=N'COLUMN',@level2name=N'Usage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0=Export record  1= Import record ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblExtracts', @level2type=N'COLUMN',@level2name=N'ExtractDirection'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1=Phone extract    2= Off line client FULL  4 = Offline client differential' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblExtracts', @level2type=N'COLUMN',@level2name=N'ExtractType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'H: Household
S: Students (School)
SU: Students (University)
P: Priests
T: Teachers
OP: Orphanages
C: Council
D: Data Electronics' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblFamilies', @level2type=N'COLUMN',@level2name=N'FamilyType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'E: Enrolment
R: Policy Renewal
F: Feedback
C: Claim' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblFromPhone', @level2type=N'COLUMN',@level2name=N'DocType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A: Accepted
R: Rejected
P: Pending
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblFromPhone', @level2type=N'COLUMN',@level2name=N'DocStatus'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'G: Government
C: Catholic
P: Protestant
R: Private' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblHF', @level2type=N'COLUMN',@level2name=N'LegalForm'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'I: Integrated
R: Reference
N: No Sublevel' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblHF', @level2type=N'COLUMN',@level2name=N'HFAddress'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1: Spouse of the member
2: Daughter/Son
3: Father/Mother/Father-in-law/Mother-in-law
4: Grand Father/Grand Mother
5: Brother/Sister
6: Lives in the same dwelling
7: Others' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblInsuree', @level2type=N'COLUMN',@level2name=N'Relationship'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1: Self Employed in Agriculture
2: Selft Employed in Business/Trade
3: Regular Salaried Employee
4: Casual wage Laborer
5: Does not work right now but seeking or ready to be employed
6: Not able to work due to disability/Old Age
7: Attends educational institutions
8: Pre-school child
9: Attends domestic duties for household
10: Retired, pensioner, remittance recipient, etc.
11: Housewife
12: Others' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblInsuree', @level2type=N'COLUMN',@level2name=N'Profession'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1: Nursery
2: Primary School
3: First School Certificate
4: Secondary School
5: Ordinary level certificate
6: High school
7: Advanced level certificate
8: Diploma
9: Graduate
10: Postgraduate
11: Above postgraduate
12: Never been to school and Illiterate
13: Never been to school but literate
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblInsuree', @level2type=N'COLUMN',@level2name=N'Education'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'C: Citizenship
D: Driver''s license
B: Birth Certificate
V: VDC Recommendation' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblInsuree', @level2type=N'COLUMN',@level2name=N'TypeOfId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Health facility Id' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblInsuree', @level2type=N'COLUMN',@level2name=N'HFID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1=Idle 2=active 4=suspended 8=Expired' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblPolicy', @level2type=N'COLUMN',@level2name=N'PolicyStatus'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'N = New Policy
 R = Renewed Policy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblPolicy', @level2type=N'COLUMN',@level2name=N'PolicyStage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0: Not yet sent
1: Renewal is submitted
2: Declined (Insuree didn''t want to renew)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblPolicyRenewals', @level2type=N'COLUMN',@level2name=N'ResponseStatus'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'R: Registration Fee
G: General Assembly Fee
P: Premium' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblPremium', @level2type=N'COLUMN',@level2name=N'isPhotoFee'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'S: Surgery
C: Consultation
D: Delivery
O: Other' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'tblServices', @level2type=N'COLUMN',@level2name=N'ServCategory'
GO


-- OP-154: database partitioning  

-- Adds four new filegroups to the database  

-- if the DATETIME provided in before 1970 then it goes to partition 1 else it goes to partition 2
CREATE PARTITION FUNCTION [StillValid] (DATETIME) AS RANGE LEFT
FOR
VALUES (
	N'1970-01-01T00:00:00.001'
	)
GO
-- Create partition Scheme that will define the partition to be used, both use the PRIMARY file group (not IDEAL but done to limit changes in a crisis mode)
CREATE PARTITION SCHEME [liveArchive] AS PARTITION [StillValid] TO (
	[PRIMARY]
	,[PRIMARY]
)
GO
BEGIN TRY
	BEGIN TRANSACTION; 
	ALTER TABLE tblClaimItems DROP CONSTRAINT [FK_tblClaimItems_tblClaim-ClaimID] 
	ALTER TABLE tblClaimServices DROP CONSTRAINT [FK_tblClaimServices_tblClaim-ClaimID] 
	ALTER TABLE tblFeedback DROP CONSTRAINT [FK_tblFeedback_tblClaim-ClaimID]
	
	ALTER TABLE [tblClaim] DROP CONSTRAINT [PK_tblClaim]
	CREATE UNIQUE CLUSTERED INDEX CI_tblClaimValid ON tblClaim (ClaimID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)
	
	ALTER TABLE tblClaim ADD CONSTRAINT PK_tblClaim PRIMARY KEY NONCLUSTERED (ClaimID) ON [PRIMARY];
	CREATE INDEX NCI_tblClaim_DateClaimed ON [tblClaim](DateClaimed);
	ALTER TABLE [tblClaimItems] ADD CONSTRAINT [FK_tblClaimItems_tblClaim-ClaimID] FOREIGN KEY(ClaimID) REFERENCES [tblClaim] (ClaimID) 
	ALTER TABLE [tblClaimServices] ADD CONSTRAINT [FK_tblClaimServices_tblClaim-ClaimID]  FOREIGN KEY(ClaimID) REFERENCES [tblClaim] (ClaimID)
	ALTER TABLE [tblFeedback] ADD CONSTRAINT [FK_tblFeedback_tblClaim-ClaimID] FOREIGN KEY(ClaimID) REFERENCES [tblClaim] (ClaimID)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  
GO
BEGIN TRY
	BEGIN TRANSACTION; 
	ALTER TABLE [tblClaimItems] DROP CONSTRAINT [PK_tblClaimItems]
	CREATE UNIQUE CLUSTERED INDEX CI_tblClaimItemsValid ON tblClaimItems (ClaimItemID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)
	ALTER TABLE tblClaimItems ADD CONSTRAINT PK_tblClaimItems PRIMARY KEY NONCLUSTERED (ClaimItemID) ON [PRIMARY];
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  
GO
BEGIN TRY
	BEGIN TRANSACTION; 
	ALTER TABLE [tblClaimServices] DROP CONSTRAINT [PK_tblClaimServices]
		
	CREATE UNIQUE CLUSTERED INDEX CI_tblClaimServicesValid ON  tblClaimServices (ClaimServiceID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)

	ALTER TABLE tblClaimServices ADD CONSTRAINT PK_tblClaimServices PRIMARY KEY NONCLUSTERED (ClaimServiceID) ON [PRIMARY];
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  
GO
BEGIN TRY
	BEGIN TRANSACTION; 
	ALTER TABLE tblInsuree DROP CONSTRAINT [FK_tblInsuree_tblFamilies1-FamilyID]
	ALTER TABLE tblPolicy DROP CONSTRAINT [FK_tblPolicy_tblFamilies-FamilyID]
		
	ALTER TABLE [tblFamilies] DROP CONSTRAINT [PK_tblFamilies]
	CREATE UNIQUE CLUSTERED INDEX CI_tblFamiliesValid ON tblFamilies (FamilyID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)
	ALTER TABLE tblFamilies ADD CONSTRAINT PK_tblFamilies PRIMARY KEY NONCLUSTERED (FamilyID) ON [PRIMARY];
	
	ALTER TABLE [tblInsuree] ADD CONSTRAINT [FK_tblInsuree_tblFamilies1-FamilyID] FOREIGN KEY(FamilyID) REFERENCES [tblFamilies] (FamilyID)
	ALTER TABLE [tblPolicy] ADD CONSTRAINT [FK_tblPolicy_tblFamilies-FamilyID]  FOREIGN KEY(FamilyID) REFERENCES [tblFamilies] (FamilyID)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  
GO	
BEGIN TRY
	BEGIN TRANSACTION; 
	ALTER TABLE tblClaim DROP CONSTRAINT [FK_tblClaim_tblInsuree-InsureeID]
	ALTER TABLE tblClaimDedRem DROP CONSTRAINT FK_tblClaimDedRem_tblInsuree
	ALTER TABLE tblFamilies DROP CONSTRAINT FK_tblFamilies_tblInsuree
	ALTER TABLE tblHealthStatus DROP CONSTRAINT FK_tblHealthStatus_tblInsuree
	ALTER TABLE tblInsureePolicy DROP CONSTRAINT FK_tblInsureePolicy_tblInsuree
	ALTER TABLE tblPolicyRenewalDetails DROP CONSTRAINT FK_tblPolicyRenewalDetails_tblInsuree
	ALTER TABLE tblPolicyRenewals DROP CONSTRAINT FK_tblPolicyRenewals_tblInsuree
	ALTER TABLE [tblInsuree] DROP CONSTRAINT [PK_tblInsuree]

	CREATE UNIQUE CLUSTERED INDEX CI_tblInsureeValid ON tblInsuree (InsureeID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)
	
	ALTER TABLE tblInsuree ADD CONSTRAINT PK_tblInsuree PRIMARY KEY NONCLUSTERED (InsureeID) ON [PRIMARY];
	ALTER TABLE [tblClaim] ADD CONSTRAINT [FK_tblClaim_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblClaimDedRem] ADD CONSTRAINT [FK_tblClaimDedRem_tblInsuree-InsureeID]  FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [dbo].[tblFamilies]  WITH NOCHECK ADD  CONSTRAINT [FK_tblFamilies_tblInsuree] FOREIGN KEY([InsureeID])
	  REFERENCES [dbo].[tblInsuree] ([InsureeID])
	  NOT FOR REPLICATION 
	ALTER TABLE [dbo].[tblFamilies] NOCHECK CONSTRAINT [FK_tblFamilies_tblInsuree]
	ALTER TABLE [tblHealthStatus] ADD CONSTRAINT [FK_tblHealthStatus_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblInsureePolicy] ADD CONSTRAINT [FK_tblInsureePolicy_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblPolicyRenewalDetails] ADD CONSTRAINT [FK_tblPolicyRenewalDetails_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblPolicyRenewals] ADD CONSTRAINT [FK_tblPolicyRenewals_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  
GO
BEGIN TRY
	BEGIN TRANSACTION; 
	ALTER TABLE tblHFCatchment DROP CONSTRAINT [FK_tblHFCatchment_tblLocations] 
	ALTER TABLE tblProduct DROP CONSTRAINT [FK_tblProduct_tblLocation] 
	ALTER TABLE tblUsersDistricts DROP CONSTRAINT [FK_tblUsersDistricts_tblLocations] 
	ALTER TABLE tblPayer DROP CONSTRAINT FK_tblPayer_tblLocations
	ALTER TABLE tblPLServices DROP CONSTRAINT FK_tblPLServices_tblLocations
	ALTER TABLE tblOfficerVillages DROP CONSTRAINT FK_tblOfficerVillages_tblLocations
	ALTER TABLE tblPLItems DROP CONSTRAINT FK_tblPLItems_tblLocations
	ALTER TABLE tblOfficer DROP CONSTRAINT FK_tblOfficer_tblLocations
	ALTER TABLE tblHF DROP CONSTRAINT FK_tblHF_tblLocations
	ALTER TABLE tblBatchRun DROP CONSTRAINT FK_tblBatchRun_tblLocations
	ALTER TABLE tblFamilies DROP CONSTRAINT FK_tblFamilies_tblLocations
	ALTER TABLE [tblLocations] DROP CONSTRAINT [PK_tblLocations]

	CREATE UNIQUE CLUSTERED INDEX CI_tblLocations ON tblLocations (
		[ValidityTo] ASC,
		[LocationType] ASC,
		[LocationId] ASC		
		)
	WITH
		( PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
		) ON liveArchive(ValidityTo)

	ALTER TABLE [tblLocations] ADD CONSTRAINT PK_tblLocations PRIMARY KEY NONCLUSTERED (LocationId) ON [PRIMARY];
	ALTER TABLE tblHFCatchment ADD CONSTRAINT [FK_tblHFCatchment_tblLocation] FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblProduct ADD CONSTRAINT [FK_tblProduct_tblLocations] FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblUsersDistricts ADD CONSTRAINT [FK_tblUsersDistricts_tblLocations] FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblPayer ADD CONSTRAINT FK_tblPayer_tblLocations FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblPLServices WITH NOCHECK ADD CONSTRAINT FK_tblPLServices_tblLocations FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblOfficerVillages ADD CONSTRAINT FK_tblOfficerVillages_tblLocations FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblPLItems WITH NOCHECK ADD CONSTRAINT FK_tblPLItems_tblLocations FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblOfficer ADD CONSTRAINT FK_tblOfficer_tblLocations FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblHF ADD CONSTRAINT FK_tblHF_tblLocations FOREIGN KEY(LocationId) REFERENCES [tblLocations] (LocationId)
	ALTER TABLE tblBatchRun ADD CONSTRAINT FK_tblBatchRun_tblLocations FOREIGN KEY(LocationID) REFERENCES [tblLocations] (LocationID)
	ALTER TABLE tblFamilies ADD CONSTRAINT FK_tblFamilies_tblLocations FOREIGN KEY(LocationID) REFERENCES [tblLocations] (LocationID)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  
GO
BEGIN TRY
	BEGIN TRANSACTION; 
	CREATE NONCLUSTERED INDEX NCI_tblUserDistrict_UserID ON tblUsersDistricts (ValidityTo,UserID)
	CREATE NONCLUSTERED INDEX NCI_tblUsers_UserUUID ON tblUsers (ValidityTo,UserUUID)
	CREATE NONCLUSTERED INDEX NCI_tblUserRoles_UserID ON tblUserRole (ValidityTo,UserID)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  	
Go
-- OP-154: add indexed to Location views


ALTER VIEW [dbo].[tblWards]  WITH SCHEMABINDING AS
SELECT LocationId WardId, ParentLocationId DistrictId, LocationCode WardCode, LocationName WardName, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId 
FROM [dbo].tblLocations
WHERE ValidityTo IS NULL
AND LocationType = N'W'
GO

CREATE UNIQUE CLUSTERED INDEX CI_tblWards ON tblWards(WardId) 
GO

ALTER VIEW [dbo].[tblVillages] WITH SCHEMABINDING AS
SELECT LocationId VillageId, ParentLocationId WardId, LocationCode VillageCode, LocationName VillageName,MalePopulation, FemalePopulation, OtherPopulation, Families, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId
FROM [dbo].tblLocations
WHERE ValidityTo IS NULL
AND LocationType = N'V'
GO

CREATE UNIQUE CLUSTERED INDEX CI_tblVillages ON tblVillages(VillageId) 
GO

ALTER VIEW [dbo].[tblRegions] WITH SCHEMABINDING AS
SELECT LocationId RegionId, LocationCode RegionCode, LocationName RegionName, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId
FROM [dbo].tblLocations
WHERE ValidityTo IS NULL
AND LocationType = N'R'
GO

CREATE UNIQUE CLUSTERED INDEX CI_tblRegions ON tblRegions(RegionId) 
GO

ALTER VIEW [dbo].[tblDistricts] WITH SCHEMABINDING
AS
SELECT LocationId DistrictId, LocationCode DistrictCode, LocationName DistrictName, ParentLocationId Region, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId
FROM [dbo].tblLocations
WHERE ValidityTo IS NULL
AND LocationType = N'D'
GO

CREATE UNIQUE CLUSTERED INDEX CI_tblDistricts ON tblDistricts(DistrictId)  
GO 
CREATE NONCLUSTERED INDEX NCI_HF_ValidityTo ON tblHF(ValidityTo)
GO
-- =============================================
-- Description:	Rebuilds all indexes on the openIMIS database
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[uspIndexRebuild] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TableName VARCHAR(255)
	DECLARE @sql NVARCHAR(500)
	DECLARE @fillfactor INT
	
	SET @fillfactor = 80 
	
	DECLARE TableCursor CURSOR FOR
	SELECT QUOTENAME(OBJECT_SCHEMA_NAME([object_id]))+'.' + QUOTENAME(name) AS TableName
	FROM sys.tables
	
	OPEN TableCursor
	FETCH NEXT FROM TableCursor INTO @TableName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @sql = 'ALTER INDEX ALL ON ' + @TableName + ' REBUILD WITH (FILLFACTOR = ' + CONVERT(VARCHAR(3),@fillfactor) + ')'
		EXEC (@sql)
	FETCH NEXT FROM TableCursor INTO @TableName
	END
	CLOSE TableCursor
	
	DEALLOCATE TableCursor

END
GO

CREATE OR ALTER PROCEDURE [dbo].[uspSSRSGetClaimHistory]
(
	@HFID INT,
	@LocationId INT,
	@ProdId INT, 
	@StartDate DATE, 
	@EndDate DATE,
	@ClaimStatus INT = NULL,
	@InsuranceNumber NVARCHAR(12),
	@ClaimRejReason xClaimRejReasons READONLY,
	@Scope INT= NULL
	
)
AS
BEGIN
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

	SELECT  HF.HFCode+' ' + HF.HFName HFCodeName, L.ParentLocationId AS RegionId,l.LocationId as DistrictID, R.RegionName,D.DistrictName,  C.DateClaimed,PROD.ProductCode +' ' + PROD.ProductName Product, C.ClaimID, I.ItemId, S.ServiceID, HF.HFCode, HF.HFName, C.ClaimCode, C.DateClaimed, CA.LastName + ' ' + CA.OtherNames ClaimAdminName,
			C.DateFrom, C.DateTo, Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsureeName,Ins.DOB DateOfBirth,
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
	CASE WHEN @Scope > 0 THEN CONCAT(CI.RejectionReason, ' - ', XCI.Name) ELSE NULL END ItemRejectionReason,
	CS.RejectionReason [Services] ,
	ci.RejectionReason Items,
	TFS.Adjusted ServicePriceValuated,
	TFI.Adjusted ItemPriceValuated

	FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimId = CI.ClaimID
	LEFT OUTER JOIN tblClaimServices CS ON C.ClaimId = CS.ClaimID
	LEFT OUTER JOIN tblProduct PROD ON PROD.ProdID =@ProdId
	LEFT OUTER JOIN tblItems I ON CI.ItemId = I.ItemID
	LEFT OUTER JOIN tblServices S ON CS.ServiceID = S.ServiceID
	INNER JOIN tblHF HF ON C.HFID = HF.HfID
	INNER JOIN tblLocations L ON L.LocationId = HF.LocationId
	INNER JOIN tblRegions R ON R.RegionId = L.ParentLocationId
	INNER JOIN tblDistricts D ON D.DistrictId = L.LocationId
	LEFT OUTER JOIN tblClaimAdmin CA ON C.ClaimAdminId = CA.ClaimAdminId
	INNER JOIN tblInsuree Ins ON C.InsureeId = Ins.InsureeId
	LEFT OUTER JOIN TotalForItems TFI ON C.ClaimId = TFI.ClaimID
	LEFT OUTER JOIN TotalForServices TFS ON C.ClaimId = TFS.ClaimId
	LEFT OUTER JOIN @ClaimRejReason XCI ON XCI.ID = CI.RejectionReason
	LEFT OUTER JOIN @ClaimRejReason XCS ON XCS.ID = CS.RejectionReason
	WHERE C.ValidityTo IS NULL
	AND ISNULL(C.DateTo,C.DateFrom) BETWEEN @StartDate AND @EndDate
	AND (C.ClaimStatus = @ClaimStatus OR @ClaimStatus IS NULL)
	AND (HF.LocationId = @LocationId OR @LocationId = 0)
	AND (Ins.CHFID = @InsuranceNumber)
	AND (HF.HFID = @HFID OR @HFID = 0)
	AND (CI.ProdID = @ProdId OR CS.ProdID = @ProdId  
	OR COALESCE(CS.ProdID, CI.ProdId) IS NULL OR @ProdId = 0) 
END


Go

CREATE OR ALTER PROCEDURE [dbo].[uspAPIGetClaims]
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


/****** Object:  StoredProcedure [dbo].[uspConsumeEnrollments]    Script Date: 10/29/2021 3:23:56 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[uspConsumeEnrollments](
	@XML XML,
	@FamilySent INT = 0 OUTPUT ,
	@FamilyImported INT = 0 OUTPUT,
	@FamiliesUpd INT =  0 OUTPUT,  
	@FamilyRejected INT = 0 OUTPUT,
	@InsureeSent INT = 0 OUTPUT,
	@InsureeUpd INT =0 OUTPUT,
	@InsureeImported INT = 0 OUTPUT ,
	@PolicySent INT = 0 OUTPUT,
	@PolicyImported INT = 0 OUTPUT,
	@PolicyRejected INT = 0 OUTPUT,
	@PolicyChanged INT = 0 OUTPUT,
	@PremiumSent INT = 0 OUTPUT,
	@PremiumImported INT = 0 OUTPUT,
	@PremiumRejected INT =0 OUTPUT
	)
	AS
	BEGIN

	/*=========ERROR CODES==========
	-400	:Uncaught exception
	0	:	All okay
	-1	:	Given family has no HOF
	-2	:	Insurance number of the HOF already exists
	-3	:	Duplicate Insurance number found
	-4	:	Duplicate receipt found
	-5		Double Head of Family Found
	
	*/


	DECLARE @Query NVARCHAR(500)
	--DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), ConfirmationType NVARCHAR(3), isOffline BIT, NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT,PhotoPath NVARCHAR(100), NewFamilyId INT, NewInsureeId INT, Vulnerability BIT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), isOffline BIT, NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblInureePolicy TABLE(PolicyId INT,InsureeId INT,EffectiveDate DATE, NewInsureeId INT, NewPolicyId INT)
	DECLARE @tblFamilySMS TABLE(FamilyId INT, ApprovalOfSMS BIT, LanguageOfSMS NVARCHAR(5), NewFamilyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)
	DECLARE @tblRejectedFamily TABLE(FamilyID INT)
	DECLARE @tblRejectedInsuree TABLE(InsureeID INT)
	DECLARE @tblRejectedPolicy TABLE(PolicyId INT)
	DECLARE @tblRejectedPremium TABLE(PremiumId INT)


	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)

	BEGIN TRY

		--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE FAMILY FROM THE XML
		INSERT INTO @tblFamilies(FamilyId,InsureeId,CHFID, LocationId,Poverty,FamilyType,FamilyAddress,Ethnicity, ConfirmationNo,ConfirmationType, isOffline)
		SELECT 
		T.F.value('(FamilyId)[1]','INT'),
		T.F.value('(InsureeId)[1]','INT'),
		T.F.value('(HOFCHFID)[1]','NVARCHAR(12)'),
		T.F.value('(LocationId)[1]','INT'),
		T.F.value('(Poverty)[1]','BIT'),
		NULLIF(T.F.value('(FamilyType)[1]','NVARCHAR(2)'),''),
		T.F.value('(FamilyAddress)[1]','NVARCHAR(200)'),
		T.F.value('(Ethnicity)[1]','NVARCHAR(1)'),
		T.F.value('(ConfirmationNo)[1]','NVARCHAR(12)'),
		NULLIF(T.F.value('(ConfirmationType)[1]','NVARCHAR(3)'),''),
		T.F.value('(isOffline)[1]','BIT')
		FROM @XML.nodes('Enrolment/Families/Family') AS T(F)


		--Get total number of families sent via XML
		SELECT @FamilySent = COUNT(*) FROM @tblFamilies

		--GET ALL THE INSUREES FROM XML
		INSERT INTO @tblInsuree(InsureeId,FamilyId,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Passport,Phone,CardIssued,Relationship,Profession,Education,Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurVillage, isOffline,PhotoPath, Vulnerability)
		SELECT
		T.I.value('(InsureeId)[1]','INT'),
		T.I.value('(FamilyId)[1]','INT'),
		T.I.value('(CHFID)[1]','NVARCHAR(12)'),
		T.I.value('(LastName)[1]','NVARCHAR(100)'),
		T.I.value('(OtherNames)[1]','NVARCHAR(100)'),
		T.I.value('(DOB)[1]','DATE'),
		T.I.value('(Gender)[1]','CHAR(1)'),
		NULLIF(T.I.value('(Marital)[1]','CHAR(1)'),''),
		T.I.value('(isHead)[1]','BIT'),
		T.I.value('(IdentificationNumber)[1]','NVARCHAR(25)'),
		T.I.value('(Phone)[1]','NVARCHAR(50)'),
		T.I.value('(CardIssued)[1]','BIT'),
		NULLIF(T.I.value('(Relationship)[1]','SMALLINT'),''),
		NULLIF(T.I.value('(Profession)[1]','SMALLINT'),''),
		NULLIF(T.I.value('(Education)[1]','SMALLINT'),''),
		T.I.value('(Email)[1]','NVARCHAR(100)'),
		NULLIF(T.I.value('(TypeOfId)[1]','NVARCHAR(1)'),''),
		NULLIF(T.I.value('(HFID)[1]','INT'),''),
		T.I.value('(CurrentAddress)[1]','NVARCHAR(200)'),
		T.I.value('(GeoLocation)[1]','NVARCHAR(200)'),
		NULLIF(NULLIF(T.I.value('(CurVillage)[1]','INT'),''),0),
		T.I.value('(isOffline)[1]','BIT'),
		T.I.value('(PhotoPath)[1]','NVARCHAR(100)'),
		T.I.value('(Vulnerability)[1]','BIT')
		FROM @XML.nodes('Enrolment/Insurees/Insuree') AS T(I)

		--Get total number of Insurees sent via XML
		SELECT @InsureeSent = COUNT(*) FROM @tblInsuree

		--GET ALL THE POLICIES FROM XML
		DECLARE @ActivationOption INT
		SELECT @ActivationOption = ActivationOption FROM tblIMISDefaults

		DECLARE @ActiveStatus TINYINT = 2
		DECLARE @ReadyStatus TINYINT = 16

		INSERT INTO @tblPolicy(PolicyId,FamilyId,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdId,OfficerId,PolicyStage,isOffline)
		SELECT 
		T.P.value('(PolicyId)[1]','INT'),
		T.P.value('(FamilyId)[1]','INT'),
		T.P.value('(EnrollDate)[1]','DATE'),
		T.P.value('(StartDate)[1]','DATE'),
		T.P.value('(EffectiveDate)[1]','DATE'),
		T.P.value('(ExpiryDate)[1]','DATE'),
		IIF(T.P.value('(PolicyStatus)[1]','TINYINT') = @ActiveStatus AND @ActivationOption = 3, @ReadyStatus, T.P.value('(PolicyStatus)[1]','TINYINT')),
		T.P.value('(PolicyValue)[1]','DECIMAL(18,2)'),
		T.P.value('(ProdId)[1]','INT'),
		T.P.value('(OfficerId)[1]','INT'),
		T.P.value('(PolicyStage)[1]','CHAR(1)'),
		T.P.value('(isOffline)[1]','BIT')
		FROM @XML.nodes('Enrolment/Policies/Policy') AS T(P)

		--Get total number of Policies sent via XML
		SELECT @PolicySent = COUNT(*) FROM @tblPolicy
			
		--GET INSUREEPOLICY
		INSERT INTO @tblInureePolicy(PolicyId,InsureeId,EffectiveDate)
		SELECT 
		T.P.value('(PolicyId)[1]','INT'),
		T.P.value('(InsureeId)[1]','INT'),
		NULLIF(T.P.value('(EffectiveDate)[1]','DATE'),'')
		FROM @XML.nodes('Enrolment/InsureePolicies/InsureePolicy') AS T(P)

		-- Get Family SMS
		INSERT INTO @tblFamilySMS(FamilyId, ApprovalOfSMS, LanguageOfSMS)
		SELECT 
		T.P.value('(FamilyId)[1]', 'INT'),
		IIF(
           (T.P.value('(ApprovalOfSMS)[1]','BIT') IS NOT NULL), 
            T.P.value('(ApprovalOfSMS)[1]','BIT'), 
	        0
        ),
		IIF(
		   (T.P.value('(LanguageOfSMS)[1]','NVARCHAR(5)') IS NOT NULL) AND (T.P.value('(LanguageOfSMS)[1]','NVARCHAR(5)') != ''), 
		    T.P.value('(LanguageOfSMS)[1]','NVARCHAR(5)'), 
			[dbo].udfDefaultLanguageCode()
		) FROM @XML.nodes('Enrolment/Families/Family/FamilySMS') AS T(P)
		

		--GET ALL THE PREMIUMS FROM XML
		INSERT INTO @tblPremium(PremiumId,PolicyId,PayerId,Amount,Receipt,PayDate,PayType,isPhotoFee)
		SELECT
		T.PR.value('(PremiumId)[1]','INT'),
		T.PR.value('(PolicyId)[1]','INT'),
		NULLIF(T.PR.value('(PayerId)[1]','INT'),0),
		T.PR.value('(Amount)[1]','DECIMAL(18,2)'),
		T.PR.value('(Receipt)[1]','NVARCHAR(50)'),
		T.PR.value('(PayDate)[1]','DATE'),
		T.PR.value('(PayType)[1]','CHAR(1)'),
		T.PR.value('(isPhotoFee)[1]','BIT')
		FROM @XML.nodes('Enrolment/Premiums/Premium') AS T(PR)

		--Get total number of premium sent via XML
		SELECT @PremiumSent = COUNT(*) FROM @tblPremium;

		IF ( @XML.exist('(Enrolment/FileInfo)') = 0)
			BEGIN
				INSERT INTO @tblResult VALUES
				(N'<h4 style="color:red;">Error: FileInfo doesn''t exists. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
				RAISERROR (N'<h4 style="color:red;">Error: FileInfo doesn''t exists. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
			END

			DECLARE @AuditUserId INT =-2,@AssociatedPhotoFolder NVARCHAR(255), @OfficerID INT
			IF ( @XML.exist('(Enrolment/FileInfo)')=1 )
				SET	@AuditUserId= (SELECT T.PR.value('(UserId)[1]','INT') FROM @XML.nodes('Enrolment/FileInfo') AS T(PR))
			
			IF ( @XML.exist('(Enrolment/FileInfo)')=1 )
				SET	@OfficerID= (SELECT T.PR.value('(OfficerId)[1]','INT') FROM @XML.nodes('Enrolment/FileInfo') AS T(PR))
				SET @AssociatedPhotoFolder=(SELECT AssociatedPhotoFolder FROM tblIMISDefaults)

		/********************************************************************************************************
										VALIDATING FILE				
		********************************************************************************************************/

		

		IF EXISTS(
		--Online Insuree in Offline family
		SELECT 1 FROM @tblInsuree TI
		INNER JOIN @tblFamilies TF ON TI.FamilyId = TF.FamilyId
		WHERE TF.isOffline = 1 AND TI.isOffline= 0
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: Online Insuree in Offline family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: Online Insuree in Offline family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END
		
		IF EXISTS(
		--online Policy in offline family
		SELECT 1 FROM @tblPolicy TP 
		INNER JOIN @tblFamilies TF ON TP.FamilyId = TF.FamilyId
		WHERE TF.isOffline = 1 AND TP.isOffline =0
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: online Policy in offline family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: online Policy in offline family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END
		

		IF EXISTS(
		--Insuree without family
		SELECT 1 
		FROM @tblInsuree I LEFT OUTER JOIN @tblFamilies F ON I.FamilyId = F.FamilyID
		WHERE F.FamilyID IS NULL

		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: Insuree without family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: Insuree without family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END
		
		IF EXISTS(
		
		--Policy without family
		SELECT 1 FROM
		@tblPolicy PL LEFT OUTER JOIN @tblFamilies F ON PL.FamilyId = F.FamilyId
		WHERE F.FamilyId IS NULL

		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: Policy without family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: Policy without family. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END
		
		IF EXISTS(
		
		--Premium without policy
		SELECT 1
		FROM @tblPremium PR LEFT OUTER JOIN @tblPolicy P ON PR.PolicyId = P.PolicyId
		WHERE P.PolicyId  IS NULL

		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: Premium without policy. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: Premium without policy. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END
		
		--IF EXISTS(
		
		-----Invalid Family type field
		--SELECT 1 FROM @tblFamilies F 
		--LEFT OUTER JOIN tblFamilyTypes FT ON F.FamilyType=FT.FamilyTypeCode
		--WHERE FT.FamilyType IS NULL AND F.FamilyType IS NOT NULL

		--)
		--BEGIN
		--	INSERT INTO @tblResult VALUES
		--	(N'<h4 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
		--	RAISERROR (N'<h4 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		--END
		
		IF EXISTS(
		
		---Invalid IdentificationType
		SELECT 1 FROM @tblInsuree I
		LEFT OUTER JOIN tblIdentificationTypes IT ON I.TypeOfId = IT.IdentificationCode
		WHERE IT.IdentificationCode IS NULL AND I.TypeOfId IS NOT NULL

		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: Invalid IdentificationType. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: Invalid IdentificationType. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END
		
		IF EXISTS(
		SELECT 1 FROM @tblInureePolicy TIP 
		LEFT OUTER JOIN @tblPolicy TP ON TP.PolicyId = TIP.PolicyId
		WHERE TP.PolicyId IS NULL
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Error: Invalid IdentificationType. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Error: Invalid IdentificationType. Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
		END

		--SELECT * INTO tempFamilies FROM @tblFamilies
		--SELECT * INTO tempInsuree FROM @tblInsuree
		--SELECT * INTO tempPolicy FROM @tblPolicy
		--SELECT * INTO tempInsureePolicy FROM @tblInureePolicy
		--SELECT * INTO tempPolicy FROM @tblPolicy
		--RETURN

		SELECT * FROM @tblInsuree
		SELECT * FROM @tblFamilies
		SELECT * FROM @tblPolicy
		SELECT * FROM @tblPremium
		SELECT * FROM @tblInureePolicy


		BEGIN TRAN ENROLL;

		/********************************************************************************************************
										VALIDATING FAMILY				
		********************************************************************************************************/
			--*****************************NEW FAMILY********************************
			INSERT INTO @tblResult (Result)
			SELECT  N'Insuree information is missing for Family with Insurance Number ' + QUOTENAME(F.CHFID) 
			FROM @tblFamilies F
			LEFT OUTER JOIN @tblInsuree I ON F.CHFID = I.CHFID
			WHERE I.InsureeId IS NULL AND F.isOffline =1 ;

			INSERT INTO @tblRejectedFamily (FamilyID)
			SELECT F.FamilyId
			FROM @tblFamilies F
			LEFT OUTER JOIN @tblInsuree I ON F.CHFID = I.CHFID
			WHERE I.InsureeId IS NULL AND F.isOffline =1 ;





			INSERT INTO @tblResult(Result)
			SELECT  N'Family with Insurance Number : ' + QUOTENAME(I.CHFID) + ' already exists'  
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL AND TF.isOffline = 1

			INSERT INTO @tblRejectedFamily(FamilyID)
			SELECT  TF.FamilyId
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL AND TF.isOffline = 1

			


			--*****************************EXISTING FAMILY********************************
			INSERT INTO @tblResult (Result)
			SELECT  N'Insuree information is missing for Family with Insurance Number ' + QUOTENAME(F.CHFID) 
			FROM @tblFamilies F
			LEFT OUTER JOIN tblInsuree I ON F.CHFID = I.CHFID
			WHERE i.ValidityTo IS NULL AND I.IsHead= 1 AND I.InsureeId IS NULL AND F.isOffline = 0 ;

			INSERT INTO @tblRejectedFamily (FamilyID)
			SELECT F.FamilyId
			FROM @tblFamilies F
			LEFT OUTER JOIN @tblInsuree I ON F.CHFID = I.CHFID
			WHERE I.InsureeId IS NULL AND F.isOffline =1 ;

			
			INSERT INTO @tblResult(Result)
			SELECT N'Family with Insurance Number : ' + QUOTENAME(TF.CHFID) + ' does not exists' 
			FROM @tblFamilies TF 
			LEFT OUTER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL 
			AND TF.isOffline = 0 
			AND I.CHFID IS NULL
			AND I.IsHead = 1;

			INSERT INTO @tblRejectedFamily (FamilyID)
			SELECT TF.FamilyId
			FROM @tblFamilies TF 
			LEFT OUTER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL 
			AND TF.isOffline = 0 
			AND I.CHFID IS NULL
			AND I.IsHead = 1;

			

			INSERT INTO @tblResult (Result)
			SELECT N'Changing the Location of the Family with Insurance Number : ' + QUOTENAME(I.CHFID) + ' is not allowed' 
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			INNER JOIN tblFamilies F ON F.FamilyID = ABS(I.FamilyID)
			WHERE I.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND TF.isOffline = 0 
			AND F.LocationId <> TF.LocationId

			INSERT INTO @tblRejectedFamily
			SELECT DISTINCT TF.FamilyId
			FROM @tblFamilies TF 
			INNER JOIN tblInsuree I ON TF.CHFID = I.CHFID
			INNER JOIN tblFamilies F ON F.FamilyID = ABS(I.FamilyID)
			WHERE I.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND TF.isOffline = 0 
			AND F.LocationId <> TF.LocationId

			INSERT INTO @tblResult (Result)
			SELECT N'Changing the family of the Insuree with Insurance Number : ' + QUOTENAME(I.CHFID) + ' is not allowed' 
			FROM @tblInsuree TI
			INNER JOIN tblInsuree I ON I.CHFID = TI.CHFID
			INNER JOIN @tblFamilies TF ON TF.FamilyId = TI.FamilyId
			WHERE
			I.ValidityTo IS NULL
			AND TI.isOffline = 0
			AND I.FamilyID <> ABS(TI.FamilyId)

			INSERT INTO @tblRejectedFamily
			SELECT DISTINCT TF.FamilyId
			FROM @tblInsuree TI
			INNER JOIN tblInsuree I ON I.CHFID = TI.CHFID
			INNER JOIN @tblFamilies TF ON TF.FamilyId = TI.FamilyId
			WHERE
			I.ValidityTo IS NULL
			AND TI.isOffline = 0
			AND I.FamilyID <> ABS(TI.FamilyId)

			
			/********************************************************************************************************
										VALIDATING INSUREE				
			********************************************************************************************************/
			----**************NEW INSUREE*********************-----

			INSERT INTO @tblResult(Result)
			SELECT N'Insurance Number : ' + QUOTENAME(TI.CHFID) + ' already exists' 
			FROM @tblInsuree TI
			INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL AND TI.isOffline = 1
			
			INSERT INTO @tblRejectedInsuree(InsureeID)
			SELECT TI.InsureeId
			FROM @tblInsuree TI
			INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL AND TI.isOffline = 1

			--Reject Family of the duplicate CHFID
			INSERT INTO @tblRejectedFamily(FamilyID)
			SELECT TI.FamilyId
			FROM @tblInsuree TI
			INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE I.ValidityTo IS NULL AND TI.isOffline = 1


			----**************EXISTING INSUREE*********************-----
			INSERT INTO @tblResult(Result)
			SELECT N'Insurance Number : ' + QUOTENAME(TI.CHFID) + ' does not exists' 
			FROM @tblInsuree TI
			LEFT OUTER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE 
			I.ValidityTo IS NULL 
			AND I.CHFID IS NULL
			AND TI.isOffline = 0
			
			INSERT INTO @tblRejectedInsuree(InsureeID)
			SELECT TI.InsureeId
			FROM @tblInsuree TI
			LEFT OUTER JOIN tblInsuree I ON TI.CHFID = I.CHFID
			WHERE 
			I.ValidityTo IS NULL 
			AND I.CHFID IS NULL
			AND TI.isOffline = 0


			

			/********************************************************************************************************
										VALIDATING POLICIES				
			********************************************************************************************************/


			/********************************************************************************************************
										VALIDATING PREMIUMS				
			********************************************************************************************************/
			INSERT INTO @tblResult(Result)
			SELECT N'Receipt number : ' + QUOTENAME(PR.Receipt) + ' is duplicateed in a file ' 
			FROM @tblPremium PR
			INNER JOIN @tblPolicy PL ON PL.PolicyId =PR.PolicyId
			GROUP BY PR.Receipt HAVING COUNT(PR.PolicyId) > 1

			INSERT INTO @tblRejectedPremium(PremiumId)
			SELECT TPR.PremiumId
			FROM tblPremium PR
			INNER JOIN @tblPremium TPR ON PR.Amount = TPR.Amount
			INNER JOIN @tblPolicy TP ON TP.PolicyId = TPR.PolicyId 
			AND PR.Receipt = TPR.Receipt 
			AND PR.PolicyID = TPR.NewPolicyId
			WHERE PR.ValidityTo IS NULL
			AND TP.isOffline = 0
			

            /********************************************************************************************************
                                        CHECK IF SOME INSUREE ARE ABOUT TO DELETE FROM FAMILY	
            ********************************************************************************************************/

            -- get the family id to process from online database
            DECLARE @familyIdToProcess TABLE (FamilyId INT)
            INSERT INTO @familyIdToProcess(FamilyId)
            SELECT I.FamilyId
            FROM @tblInsuree TI
            INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
            WHERE I.ValidityTo IS NULL AND TI.isOffline = 1
            GROUP BY I.FamilyID

            -- get to compare the structure of families (list of insuree) from online database
            DECLARE @insureeToProcess TABLE(CHFID NVARCHAR(12), FamilyID INT) 
            INSERT INTO @insureeToProcess(CHFID, FamilyID)
            SELECT I.CHFID, F.FamilyID FROM tblInsuree I 
            LEFT JOIN tblFamilies F ON I.FamilyID = F.FamilyID
            WHERE F.FamilyID IN (SELECT * FROM @familyIdToProcess) AND I.ValidityTo is NULL
            GROUP BY I.CHFID, F.FamilyID

            -- select the insuree to delete based on received XML payload
            -- get the insuree which are not included in "insureeToProcess"
            DECLARE @insureeToDelete TABLE(CHFID NVARCHAR(12))
            INSERT INTO @insureeToDelete(CHFID)
            SELECT IP.CHFID FROM @insureeToProcess IP
            LEFT JOIN @tblInsuree I ON I.CHFID=IP.CHFID
            WHERE I.CHFID is NULL

            -- iterate through insuree to delete - process them to remove from existing family
            -- use SP uspAPIDeleteMemberFamily and 'delete' InsureePolicy also like in webapp 
            IF EXISTS(SELECT 1 FROM @insureeToDelete)
            BEGIN 
                DECLARE @CurInsureeCHFID NVARCHAR(12)
                DECLARE CurInsuree CURSOR FOR SELECT CHFID FROM @insureeToDelete
                    OPEN CurInsuree
                        FETCH NEXT FROM CurInsuree INTO @CurInsureeCHFID;
                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                            DECLARE @currentInsureeId INT
                            SET @currentInsureeId = (SELECT InsureeID FROM tblInsuree WHERE CHFID=@CurInsureeCHFID AND ValidityTo is NULL)
                            EXEC uspAPIDeleteMemberFamily -2, @CurInsureeCHFID
                            UPDATE tblInsureePolicy SET ValidityTo = GETDATE() WHERE InsureeId = @currentInsureeId
                            FETCH NEXT FROM CurInsuree INTO @CurInsureeCHFID;
                        END
                    CLOSE CurInsuree
                DEALLOCATE CurInsuree;	 
            END

			--Validation For Phone only
			IF @AuditUserId > 0
				BEGIN

					--*****************New Family*********
					--Family already  exists
					IF EXISTS(SELECT 1 FROM @tblFamilies TF INNER JOIN tblInsuree F ON F.CHFID = TF.CHFID WHERE TF.isOffline = 1 AND F.ValidityTo IS NULL )
					RAISERROR(N'-2',16,1)
					
					
					--Family has no HOF
					IF EXISTS(SELECT 1 FROM @tblFamilies TF LEFT OUTER JOIN @tblInsuree TI ON TI.CHFID =TF.CHFID WHERE TF.isOffline = 1 AND TI.CHFID IS NULL)
					RAISERROR(N'-1',16,1)

					--Duplicate Insuree foundS
					IF EXISTS(SELECT 1 FROM @tblInsuree TI INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID WHERE I.ValidityTo IS NULL AND TI.isOffline = 1)
					RAISERROR(N'-3',16,1)

					--*****************Existing Family*********
							--Family has no HOF
					IF EXISTS(SELECT 1 FROM @tblFamilies TF 
					LEFT OUTER JOIN tblInsuree I ON TF.CHFID = I.CHFID 
					WHERE I.ValidityTo IS NULL AND I.IsHead = 1 AND I.CHFID IS NULL)
					RAISERROR(N'-1',16,1)

					--Duplicate Receipt
					IF EXISTS(SELECT 1 FROM @tblPremium TPR
					INNER JOIN tblPremium PR ON PR.PolicyID = TPR.PolicyID AND TPR.Amount = PR.Amount AND TPR.Receipt = PR.Receipt
					INNER JOIN tblPolicy PL ON PL.PolicyID = PR.PolicyID)
					RAISERROR(N'-4',16,1)


				END


			/********************************************************************************************************
										DELETE REJECTED RECORDS		
			********************************************************************************************************/

			SELECT @FamilyRejected =ISNULL(COUNT(DISTINCT FamilyID),0) FROM
			@tblRejectedFamily --GROUP BY FamilyID

			SELECT @PolicyRejected =ISNULL(COUNT(DISTINCT PolicyId),0) FROM
			@tblRejectedPolicy --GROUP BY PolicyId

			SELECT @PolicyRejected= ISNULL(COUNT(DISTINCT TP.PolicyId),0)+ ISNULL(@PolicyRejected ,0)
			FROM @tblPolicy TP 
			INNER JOIN @tblFamilies TF ON TF.FamilyId = TP.FamilyId
			INNER JOIN @tblRejectedFamily RF ON RF.FamilyID = TP.FamilyId
			GROUP BY TP.PolicyId

			SELECT @PremiumRejected =ISNULL(COUNT(DISTINCT PremiumId),0) FROM
			@tblRejectedPremium --GROUP BY PremiumId


			--Rejected Families
			DELETE TF FROM @tblFamilies TF
			INNER JOIN @tblRejectedFamily RF ON TF.FamilyId =RF.FamilyId
			
			DELETE TF FROM @tblFamilies TF
			INNER JOIN @tblInsuree TI ON TI.FamilyId = TF.FamilyId
			INNER JOIN @tblRejectedInsuree RI ON RI.InsureeID = TI.InsureeId

			DELETE TI FROM @tblInsuree TI
			INNER JOIN @tblRejectedFamily RF ON TI.FamilyId =RF.FamilyId

			DELETE TP FROM @tblPolicy TP
			INNER JOIN @tblRejectedFamily RF ON TP.FamilyId =RF.FamilyId

			DELETE TFS FROM @tblFamilySMS TFS
			INNER JOIN @tblRejectedFamily TF ON TFS.FamilyId = TF.FamilyId

			DELETE TP FROM @tblPolicy TP
			LEFT OUTER JOIN @tblFamilies TF ON TP.FamilyId =TP.FamilyId WHERE TF.FamilyId IS NULL

			--Rejected Insuree
			DELETE TI FROM @tblInsuree TI
			INNER JOIN @tblRejectedInsuree RI ON TI.InsureeId =RI.InsureeID

			DELETE TIP FROM @tblInureePolicy TIP
			INNER JOIN @tblRejectedInsuree RI ON TIP.InsureeId =RI.InsureeID
			
			--Rejected Premium
			DELETE TPR FROM @tblPremium TPR
			INNER JOIN @tblRejectedPremium RP ON RP.PremiumId = TPR.PremiumId
			

			--Making the first insuree to be head for the offline families which miss head of family ONLY for the new family
			IF NOT EXISTS(SELECT 1 FROM @tblFamilies TF INNER JOIN @tblInsuree TI ON TI.CHFID = TF.CHFID WHERE TI.IsHead = 1 AND TF.isOffline = 1)
			BEGIN
				UPDATE TI SET TI.IsHead =1 
				FROM @tblInsuree TI 
				INNER JOIN @tblFamilies TF ON TF.FamilyId = TI.FamilyId 
				WHERE TF.isOffline = 1 
				AND TI.InsureeId=(SELECT TOP 1 InsureeId FROM @tblInsuree WHERE isOffline = 1 ORDER BY InsureeId ASC)
			END
			
			--Updating FamilyId, PolicyId and InsureeId for the existing records
			UPDATE @tblFamilies SET NewFamilyId = ABS(FamilyId) WHERE isOffline = 0
			UPDATE @tblInsuree SET NewFamilyId =ABS(FamilyId)  
			UPDATE @tblPolicy SET NewPolicyId = PolicyId WHERE isOffline = 0
			UPDATE @tblFamilySMS SET NewFamilyId = ABS(FamilyId)
			
			UPDATE TP SET TP.NewFamilyId = TF.FamilyId FROM @tblPolicy TP 
			INNER JOIN @tblFamilies TF ON TF.FamilyId = TP.FamilyId 
			WHERE TF.isOffline = 0
			

			--updating existing families
			IF EXISTS(SELECT 1 FROM @tblFamilies WHERE isOffline = 0 AND FamilyId < 0)
			BEGIN
				INSERT INTO tblFamilies ([insureeid],[Poverty],[ConfirmationType],isOffline,[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],FamilyType, FamilyAddress,Ethnicity,ConfirmationNo, LocationId) 
				SELECT F.[insureeid],F.[Poverty],F.[ConfirmationType],F.isOffline,F.[ValidityFrom],getdate() ValidityTo,F.FamilyID, @AuditUserID,F.FamilyType, F.FamilyAddress,F.Ethnicity,F.ConfirmationNo,F.LocationId FROM @tblFamilies TF
				INNER JOIN tblFamilies F ON ABS(TF.FamilyId) = F.FamilyID
				WHERE 
				F.ValidityTo IS NULL
				AND TF.isOffline = 0 AND TF.FamilyId < 0

				
				UPDATE dst SET dst.[Poverty] = src.Poverty,  dst.[ConfirmationType] = src.ConfirmationType, isOffline=0, dst.[ValidityFrom]=GETDATE(), dst.[AuditUserID] = @AuditUserID, dst.FamilyType = src.FamilyType,  dst.FamilyAddress = src.FamilyAddress,
							   dst.Ethnicity = src.Ethnicity,  dst.ConfirmationNo = src.ConfirmationNo
						 FROM tblFamilies dst
						 INNER JOIN @tblFamilies src ON ABS(src.FamilyID)= dst.FamilyID WHERE src.isOffline = 0 AND src.FamilyId < 0
				SELECT @FamiliesUpd = ISNULL(@@ROWCOUNT	,0)

				UPDATE dst SET dst.[ApprovalOfSMS] = src.ApprovalOfSMS,  dst.[LanguageOfSMS] = src.LanguageOfSMS, dst.[ValidityFrom] = GETDATE()
						 FROM tblFamilySMS dst
						 INNER JOIN @tblFamilySMS src ON ABS(src.FamilyID) = dst.FamilyId WHERE src.FamilyId < 0
				

			END

			--new family
				IF EXISTS(SELECT 1 FROM @tblFamilies WHERE isOffline = 1) 
					BEGIN
						DECLARE @CurFamilyId INT
						DECLARE CurFamily CURSOR FOR SELECT FamilyId FROM @tblFamilies WHERE  isOffline = 1
							OPEN CurFamily
								FETCH NEXT FROM CurFamily INTO @CurFamilyId;
								WHILE @@FETCH_STATUS = 0
								BEGIN
								INSERT INTO tblFamilies(InsureeId, LocationId, Poverty, ValidityFrom, AuditUserId, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo, ConfirmationType, isOffline) 
								SELECT 0 , TF.LocationId, TF.Poverty, GETDATE() , @AuditUserId , TF.FamilyType, TF.FamilyAddress, TF.Ethnicity, TF.ConfirmationNo, ConfirmationType, 0 FROM @tblFamilies TF
								DECLARE @NewFamilyId  INT  =0
								SELECT @NewFamilyId= SCOPE_IDENTITY();

								
								IF @@ROWCOUNT > 0
									BEGIN
										SET @FamilyImported = ISNULL(@FamilyImported,0) + 1
										UPDATE @tblFamilies SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
										UPDATE @tblInsuree SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
										UPDATE @tblPolicy SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
										UPDATE @tblFamilySMS SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
										
									END
								
								INSERT INTO tblFamilySMS(FamilyId, ApprovalOfSMS, LanguageOfSMS, ValidityFrom) 
									SELECT @NewFamilyID, dst.ApprovalOfSMS, dst.LanguageOfSMS, GETDATE() FROM @tblFamilySMS dst
								Where dst.FamilyId = @CurFamilyId;
								

								FETCH NEXT FROM CurFamily INTO @CurFamilyId;
							END
							CLOSE CurFamily
							DEALLOCATE CurFamily;
						END


			--Delete duplicate policies
			DELETE TP
			OUTPUT 'Policy for the family : ' + QUOTENAME(I.CHFID) + ' with Product Code:' + QUOTENAME(Prod.ProductCode) + ' already exists' INTO @tblResult
			FROM tblPolicy PL 
			INNER JOIN @tblPolicy TP ON PL.FamilyID = ABS(TP.NewFamilyId )
									AND PL.EnrollDate = TP.EnrollDate 
									AND PL.StartDate = TP.StartDate 
									AND PL.ProdID = TP.ProdId 
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
			INNER JOIN tblInsuree I ON PL.FamilyId = I.FamilyId
			WHERE PL.ValidityTo IS NULL
			AND I.IsHead = 1;

			--Delete Premiums without polices
			DELETE TPR FROM @tblPremium TPR
			LEFT OUTER JOIN @tblPolicy TP ON TP.PolicyId = TPR.PolicyId
			WHERE TPR.PolicyId IS NULL


			--updating existing insuree
			IF EXISTS(SELECT 1 FROM @tblInsuree WHERE isOffline = 0)
				BEGIN
					--Insert Insuree History
					INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage], [Vulnerability]) 
					SELECT	I.[FamilyID],I.[CHFID],I.[LastName],I.[OtherNames],I.[DOB],I.[Gender],I.[Marital],I.[IsHead],I.[passport],I.[Phone],I.[PhotoID],I.[PhotoDate],I.[CardIssued],I.isOffline,I.[AuditUserID],I.[ValidityFrom] ,GETDATE() ValidityTo,I.InsureeID,I.[Relationship],I.[Profession],I.[Education],I.[Email] ,I.[TypeOfId],I.[HFID], I.[CurrentAddress], I.[GeoLocation], [CurrentVillage], I.[Vulnerability] FROM @tblInsuree TI
					INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
					WHERE I.ValidityTo IS NULL AND
					TI.isOffline = 0

					UPDATE dst SET  dst.[LastName] = src.LastName,dst.[OtherNames] = src.OtherNames,dst.[DOB] = src.DOB,dst.[Gender] = src.Gender,dst.[Marital] = src.Marital,dst.[passport] = src.passport,dst.[Phone] = src.Phone,dst.[PhotoDate] = GETDATE(),dst.[CardIssued] = src.CardIssued,dst.isOffline=0,dst.[ValidityFrom] = GetDate(),dst.[AuditUserID] = @AuditUserID ,dst.[Relationship] = src.Relationship, dst.[Profession] = src.Profession, dst.[Education] = src.Education,dst.[Email] = src.Email ,dst.TypeOfId = src.TypeOfId,dst.HFID = src.HFID, dst.CurrentAddress = src.CurrentAddress, dst.CurrentVillage = src.CurVillage, dst.GeoLocation = src.GeoLocation, dst.Vulnerability = src.Vulnerability 
					FROM tblInsuree dst
					INNER JOIN @tblInsuree src ON src.CHFID = dst.CHFID
					WHERE dst.ValidityTo IS NULL AND src.isOffline = 0;

					SELECT @InsureeUpd= ISNULL(COUNT(1),0) FROM @tblInsuree WHERE isOffline = 0


					--Insert Photo  History
					INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,PhotoDate,OfficerID,ValidityFrom,ValidityTo,AuditUserID) 
					SELECT P.InsureeID,P.CHFID,P.PhotoFolder,P.PhotoFileName,P.PhotoDate,P.OfficerID,P.ValidityFrom,GETDATE() ValidityTo,P.AuditUserID 
					FROM tblPhotos P
					INNER JOIN tblInsuree I ON I.PhotoID =P.PhotoID
					INNER JOIN @tblInsuree TI ON TI.CHFID = I.CHFID
					WHERE 
					P.ValidityTo IS NULL AND I.ValidityTo IS NULL
					AND TI.isOffline = 0

					--Update Photo
					UPDATE P SET PhotoFolder = @AssociatedPhotoFolder+'/', PhotoFileName = TI.PhotoPath, OfficerID = @OfficerID, ValidityFrom = GETDATE(), AuditUserID = @AuditUserID 
					FROM tblPhotos P
					INNER JOIN tblInsuree I ON I.PhotoID =P.PhotoID
					INNER JOIN @tblInsuree TI ON TI.CHFID = I.CHFID
					WHERE 
					P.ValidityTo IS NULL AND I.ValidityTo IS NULL
					AND TI.isOffline = 0
				END

				--new insuree
				IF EXISTS(SELECT 1 FROM @tblInsuree WHERE isOffline = 1) 
					BEGIN
						DECLARE @CurInsureeId INT
						DECLARE CurInsuree CURSOR FOR SELECT InsureeId FROM @tblInsuree WHERE  isOffline = 1
							OPEN CurInsuree
								FETCH NEXT FROM CurInsuree INTO @CurInsureeId;
								WHILE @@FETCH_STATUS = 0
								BEGIN
								INSERT INTO tblInsuree(FamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, ValidityFrom,
								AuditUserId, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage, isOffline, Vulnerability)
								SELECT NewFamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, GETDATE() ValidityFrom,
								@AuditUserId AuditUserId, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurVillage, 0, Vulnerability
								FROM @tblInsuree WHERE InsureeId = @CurInsureeId;
								DECLARE @NewInsureeId  INT  =0
								SELECT @NewInsureeId= SCOPE_IDENTITY();
								IF @@ROWCOUNT > 0
									BEGIN
										SET @InsureeImported = ISNULL(@InsureeImported,0) + 1
										--updating insureeID
										UPDATE @tblInsuree SET NewInsureeId = @NewInsureeId WHERE InsureeId = @CurInsureeId
										UPDATE @tblInureePolicy SET NewInsureeId = @NewInsureeId WHERE InsureeId = @CurInsureeId
										UPDATE F SET InsureeId = TI.NewInsureeId
										FROM @tblInsuree TI 
										INNER JOIN tblInsuree I ON TI.NewInsureeId = I.InsureeId
										INNER JOIN tblFamilies F ON TI.NewFamilyId = F.FamilyID
										WHERE TI.IsHead = 1 AND TI.InsureeId = @NewInsureeId
									END

								--Now we will insert new insuree in the table tblInsureePolicy for only existing policies
								IF EXISTS(SELECT 1 FROM tblPolicy P 
								INNER JOIN tblFamilies F ON F.FamilyID = P.FamilyID
								INNER JOIN tblInsuree I ON I.FamilyID = I.FamilyID
								WHERE I.ValidityTo IS NULL AND P.ValidityTo IS NULL AND F.ValidityTo IS NULL AND I.InsureeID = @NewInsureeId)
									EXEC uspAddInsureePolicy @NewInsureeId	

									INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
									SELECT @NewInsureeId InsureeId, CHFID, @AssociatedPhotoFolder +'/' photoFolder, PhotoPath photoFileName, @OfficerID OfficerID, getdate() photoDate, getdate() ValidityFrom,@AuditUserId AuditUserId
									FROM @tblInsuree WHERE InsureeId = @CurInsureeId 

								--Update photoId in Insuree
								UPDATE I SET PhotoId = PH.PhotoId, I.PhotoDate = PH.PhotoDate
								FROM tblInsuree I
								INNER JOIN tblPhotos PH ON PH.InsureeId = I.InsureeId
								WHERE I.CHFID IN (SELECT CHFID from @tblInsuree)
								

								FETCH NEXT FROM CurInsuree INTO @CurInsureeId;
								END
						CLOSE CurInsuree
							DEALLOCATE CurInsuree;
					END
				
				--updating family with the new insureeId of the head
				UPDATE F SET InsureeID = I.InsureeID FROM tblInsuree I
				INNER JOIN @tblInsuree TI ON I.CHFID = TI.CHFID
				INNER JOIN @tblFamilies TF ON I.FamilyID = TF.NewFamilyId
				INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
				WHERE I.ValidityTo IS NULL AND I.ValidityTo IS NULL AND I.IsHead = 1

			DELETE FROM @tblIds;

				
				---**************INSERTING POLICIES-----------
				DECLARE @FamilyId INT = 0,
				@HOFId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@ProdId INT,
				@PolicyStage CHAR(1),
				@StartDate DATE,
				@ExpiryDate DATE,
				@EnrollDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId TINYINT,
				@PolicyValueFromPhone DECIMAL(18, 4),
				@ContributionAmount DECIMAL(18, 4),
				@Active TINYINT=2,
				@Ready TINYINT=16,
				@Idle TINYINT=1,
				@NewPolicyId INT,
				@OldPolicyStatus INT,
				@NewPolicyStatus INT


			
			--New policies
		IF EXISTS(SELECT 1 FROM @tblPolicy WHERE isOffline =1)
			BEGIN
			DECLARE CurPolicies CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, StartDate, EnrollDate,ExpiryDate, PolicyStatus, PolicyValue, NewFamilyId FROM @tblPolicy WHERE isOffline = 1
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @StartDate, @EnrollDate, @ExpiryDate,  @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
			WHILE @@FETCH_STATUS = 0
			BEGIN			
							SET @EffectiveDate= NULL;
							SET @PolicyStatus = @Idle;

							EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollDate, 0, @ErrorCode OUTPUT;

							INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
							SELECT	 ABS(NewFamilyID),EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,@PolicyValue,ProdID,@OfficerID,PolicyStage,GETDATE(),@AuditUserId,  0 FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @NewPolicyId = SCOPE_IDENTITY()
							INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, @NewPolicyId)
							
							IF @@ROWCOUNT > 0
								BEGIN
									SET @PolicyImported = ISNULL(@PolicyImported,0) +1
									UPDATE @tblInureePolicy SET NewPolicyId = @NewPolicyId WHERE PolicyId=@PolicyId
									UPDATE @tblPremium SET NewPolicyId =@NewPolicyId  WHERE PolicyId = @PolicyId
									INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee,isOffline)
									SELECT NewPolicyId,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),@AuditUserId,isPhotoFee,  0
									FROM @tblPremium WHERE NewPolicyId = @NewPolicyId
									SELECT @PremiumImported = ISNULL(@PremiumImported,0) +1
								END
							
				
				SELECT @ContributionAmount = ISNULL(SUM(Amount),0) FROM tblPremium WHERE PolicyId = @NewPolicyId
					IF ((@PolicyValueFromPhone = @PolicyValue))
						BEGIN
							SELECT @PolicyStatus = PolicyStatus FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @EffectiveDate = EffectiveDate FROM @tblPolicy WHERE PolicyId=@PolicyId
							
							UPDATE tblPolicy SET PolicyStatus = @PolicyStatus, EffectiveDate = @EffectiveDate WHERE PolicyID = @NewPolicyId

							INSERT INTO tblInsureePolicy
								([InsureeId],[PolicyId],[EnrollmentDate],[StartDate],[EffectiveDate],[ExpiryDate],[ValidityFrom],[AuditUserId], isOffline) 
							SELECT
								 NewInsureeId,IP.NewPolicyId,@EnrollDate,@StartDate,IP.[EffectiveDate],@ExpiryDate,GETDATE(),@AuditUserId,  0 FROM @tblInureePolicy IP
							     WHERE IP.PolicyId=@PolicyId
						END
					ELSE
						BEGIN
							IF @ContributionAmount >= @PolicyValue
								BEGIN
									IF (@ActivationOption = 3)
									  SELECT @PolicyStatus = @Ready
									ELSE
									  SELECT @PolicyStatus = @Active
								END
								ELSE
									SELECT @PolicyStatus =@Idle
							
									--Checking the Effectice Date
										DECLARE @Amount DECIMAL(10,0), @TotalAmount DECIMAL(10,0), @PaymentDate DATE 
										DECLARE CurPremiumPayment CURSOR FOR SELECT PayDate, Amount FROM @tblPremium WHERE PolicyId = @PolicyId;
										OPEN CurPremiumPayment;
										FETCH NEXT FROM CurPremiumPayment INTO @PaymentDate,@Amount;
										WHILE @@FETCH_STATUS = 0
										BEGIN
											SELECT @TotalAmount = ISNULL(@TotalAmount,0) + @Amount;
												IF(@TotalAmount >= @PolicyValue)
													BEGIN
														SELECT @EffectiveDate = @PaymentDate
														BREAK;
													END
												ELSE
														SELECT @EffectiveDate = NULL
											FETCH NEXT FROM CurPremiumPayment INTO @PaymentDate,@Amount;
										END
										CLOSE CurPremiumPayment;
										DEALLOCATE CurPremiumPayment; 
							
								UPDATE tblPolicy SET PolicyStatus = @PolicyStatus, EffectiveDate = @EffectiveDate WHERE PolicyID = @NewPolicyId
							

							DECLARE @InsureeId INT
							DECLARE CurNewPolicy CURSOR FOR SELECT I.InsureeID FROM tblInsuree I 
													INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID 
													INNER JOIN tblPolicy P ON P.FamilyID = F.FamilyID 
													WHERE P.PolicyId = @NewPolicyId 
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

						END

				

				FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @StartDate, @EnrollDate, @ExpiryDate,  @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
			END
			CLOSE CurPolicies;
			DEALLOCATE CurPolicies; 
		END

		SELECT @PolicyImported = ISNULL(COUNT(1),0) FROM @tblPolicy WHERE isOffline = 1
			
			

		

	
	IF EXISTS(SELECT COUNT(1) 
			FROM tblInsuree 
			WHERE ValidityTo IS NULL
			AND IsHead = 1
			GROUP BY FamilyID
			HAVING COUNT(1) > 1)
			
			--Added by Amani
			BEGIN
					DELETE FROM @tblResult;
					SET @FamilyImported = 0;
					SET @FamilyRejected =0;
					SET @FamiliesUpd =0;
					SET @InsureeImported  = 0;
					SET @InsureeUpd =0;
					SET @PolicyImported  = 0;
					SET @PolicyImported  = 0;
					SET @PolicyRejected  = 0;
					SET @PremiumImported  = 0 
					INSERT INTO @tblResult VALUES
						(N'<h3 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h3>')
						--GOTO EndOfTheProcess;

						RAISERROR(N'-5',16,1)
					END


		COMMIT TRAN ENROLL;

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK TRAN ENROLL;
		
		SELECT * FROM @tblResult;
		IF  ERROR_MESSAGE()=N'-1'
			BEGIN
				RETURN -1
			END
		ELSE IF ERROR_MESSAGE()=N'-2'
			BEGIN
				RETURN -2
			END
		ELSE IF ERROR_MESSAGE()=N'-3'
			BEGIN
				RETURN -3
			END
		ELSE IF ERROR_MESSAGE()=N'-4'
			BEGIN
				RETURN -4
			END
		ELSE IF ERROR_MESSAGE()=N'-5'
			BEGIN
				RETURN -5
			END
		ELSE
			RETURN -400
	END CATCH

	
	SELECT Result FROM @tblResult;
	
	RETURN 0 --ALL OK
	END


GO


/****** Object:  StoredProcedure [dbo].[uspRestAPISubmitSingleClaim]    Script Date: 10/29/2021 3:27:21 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspRestAPISubmitSingleClaim]
	
	@AuditUser as int = 0,
	@ClaimID as int,
	@RowID as bigint = 0,
	@RtnStatus as int = 0 OUTPUT,
	@RtnItemsPassed as int = 0 OUTPUT,
	@RtnServicesPassed as int = 0 OUTPUT,
	@RtnItemsRejected as int = 0 OUTPUT,
	@RtnServicesRejected as int = 0 OUTPUT
	
	
	/*
	Rejection reasons:
	0 = NOT REJECTED
	1 = Item/Service not in Registers
	2 = Item/Service not in HF Pricelist 
	3 = Item/Service not in Covering Product/policy
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATED
	7 = CHFID Not valid / Family Not Valid 
	8 = ICD Code not in current ICD list 
	9 = Target date provision invalid
	10= Care type not consistant with Facility 
	11= Maximum Hospital admissions
	12= Maximim visits (OP)
	13= Maximum consulations
	14= Maximum Surgeries
	15= Maximum Deliveries
	16= Item/Service Maximum provision
	17= Item/Service waiting period violation
	19= Maximum Antenatal
	*/
	
AS
BEGIN
	DECLARE @oReturnValue as int 
	SET @oReturnValue = 0 
	SET @RtnStatus = 0  
	DECLARE @HFID as int  
	DECLARE @InsureeID as int 
	DECLARE @FamilyID as int  
	DECLARE @TargetDate as Date 
	DECLARE @ClaimItemID as int 
	DECLARE @ClaimServiceID as int 
	DECLARE @ItemID as int
	DECLARE @ServiceID as int
	DECLARE @ProdItemID as int
	DECLARE @ProdServiceID as int
	DECLARE @ItemPatCat as int 
	DECLARE @ServicePatCat as int 
	DECLARE @Gender as nvarchar(1)
	DECLARE @Adult as bit
	DECLARE @DOB as date 
	DECLARE @PatientMask as int 
	DECLARE @WaitingPeriod as int 
	DECLARE @LimitNo as decimal(18,2) 
	DECLARE @EffectiveDateInsuree as datetime
	DECLARE @EffectiveDatePolicy as datetime
	DECLARE @ExpiryDateInsuree as datetime
	DECLARE @PolicyStage as CHAR
	DECLARE @Count as INT
	DECLARE @ServCategory as CHAR
	DECLARE @ServLevel as CHAR
	DECLARE @ProductID as int 
	DECLARE @ClaimStartDate as datetime
	DECLARE @ClaimEndDate as datetime
	DECLARE @CareType as CHAR(1)
	DECLARE @HFCareType as CHAR(1)

	BEGIN TRY
	
	DECLARE @BaseCategory as CHAR(1)  = 'V'
	DECLARE @ClaimDateFrom date
	DECLARE @ClaimDateTo date 
	-- S = Surgery
	-- D = Delivery
	-- A = Antenatal care
	-- H = Hospitalization
	-- C = Consultation
	-- O = Other
	-- V = Visit 
	SELECT @ClaimDateFrom = DateFrom,  @ClaimDateTo = DateTo FROM tblClaim Where ClaimID = @ClaimID 
	IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
		WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'S') AND 
							 (tblServices.ValidityTo IS NULL))
	BEGIN
		SET @BaseCategory = 'S'
	END
	ELSE
	BEGIN
		IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
		WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'D') AND 
							 (tblServices.ValidityTo IS NULL))
		BEGIN
			SET @BaseCategory = 'D'
		END
		ELSE
		BEGIN
			IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
			WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'A') AND 
								 (tblServices.ValidityTo IS NULL))
			BEGIN
				SET @BaseCategory = 'A'
			END
			ELSE
			BEGIN
				IF ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom 
				BEGIN
					SET @BaseCategory = 'H'
				END
				ELSE
				BEGIN
					IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
					WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'C') AND 
										 (tblServices.ValidityTo IS NULL))
					BEGIN
						SET @BaseCategory = 'C'
					END
					ELSE
					BEGIN
						SET @BaseCategory = 'V'
					END
				END
			END
		END
	END

	--***** PREPARE PHASE *****
	SELECT @InsureeID = InsureeID, @ClaimStartDate = DateFrom , @ClaimEndDate = DateTo  FROM tblClaim WHERE ClaimID = @ClaimID 
	SELECT @FamilyID = tblFamilies.FamilyID FROM tblFamilies INNER JOIN tblInsuree ON tblFamilies.FamilyID = tblInsuree.FamilyID  WHERE tblFamilies.ValidityTo IS NULL AND tblInsuree.InsureeID = @InsureeID AND tblInsuree.ValidityTo IS NULL 

	IF ISNULL(@FamilyID,0)=0 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL
		GOTO UPDATECLAIM 
	END	
	
	SELECT @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom) FROM TblClaim WHERE ClaimID = @ClaimID 
	IF @TargetDate IS NULL 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 9 WHERE ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 9 WHERE ClaimID = @ClaimID  AND tblClaimItems.ValidityTo IS NULL
		GOTO UPDATECLAIM 
	END	
	  
	SET @PatientMask = 0 
	SELECT @Gender = Gender FROm tblInsuree WHERE InsureeID = @InsureeID 
	IF @Gender = 'M' OR @Gender = 'O'
		SET @PatientMask = @PatientMask + 1 
	ELSE
		SET @PatientMask = @PatientMask + 2 
	
	SELECT @DOB = DOB FROM tblInsuree WHERE InsureeID = @InsureeID 
	IF DATEDIFF(YY  ,@DOB,@TargetDate ) >=18 
	BEGIN
		SET @Adult = 1
		SET @PatientMask = @PatientMask + 4 
	END
	ELSE
	BEGIN
		SET @Adult = 0
		SET @PatientMask = @PatientMask + 8 
	END

	DECLARE  @DTBL_ITEMS TABLE (
							[ItemID] [int] NOT NULL,
							[ItemCode] [nvarchar](6) NOT NULL,
							[ItemType] [char](1) NOT NULL,
							[ItemPrice] [decimal](18, 2) NOT NULL,
							[ItemCareType] [char](1) NOT NULL,
							[ItemFrequency] [smallint] NULL,
							[ItemPatCat] [tinyint] NOT NULL
							)

	INSERT INTO @DTBL_ITEMS (ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat) 
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ItemId ORDER BY ValidityFrom DESC)RNo,AllItems.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom, ValidityTo, LegacyID from tblitems Where (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom,ValidityTo, LegacyID  FROM tblItems Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimItems.ItemID
	FROM            tblClaimItems 
	WHERE        (tblClaimItems.ValidityTo IS NULL) AND tblClaimItems.ClaimID = @ClaimID
	) Sub2 ON Sub1.ItemID = Sub2.ItemID 
	)  AllItems 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate 
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))  	



	DECLARE  @DTBL_SERVICES TABLE (
							[ServiceID] [int] NOT NULL,
							[ServCode] [nvarchar](6) NOT NULL,
							[ServType] [char](1) NOT NULL,
							[ServLevel] [char](1) NOT NULL,
							[ServPrice] [decimal](18, 2) NOT NULL,
							[ServCareType] [char](1) NOT NULL,
							[ServFrequency] [smallint] NULL,
							[ServPatCat] [tinyint] NOT NULL,
							[ServCategory] [char](1) NULL
							)

	INSERT INTO @DTBL_SERVICES (ServiceID , ServCode, ServType , ServLevel, ServPrice, ServCaretype ,ServFrequency, ServPatCat, ServCategory ) 
	SELECT ServiceID , ServCode, ServType , ServLevel ,ServPrice, ServCaretype ,ServFrequency, ServPatCat,ServCategory FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ServiceId ORDER BY ValidityFrom DESC)RNo,AllServices.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory ,ValidityFrom, ValidityTo, LegacyID from tblServices WHere (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory , ValidityFrom, ValidityTo, LegacyID FROM tblServices Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimServices.ServiceID 
	FROM            tblClaim INNER JOIN
							 tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID
	WHERE        (tblClaimServices.ValidityTo IS NULL) AND tblClaim.ClaimID = @ClaimID
	) Sub2 ON Sub1.ServiceID = Sub2.ServiceID 
	)  AllServices 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))  


	--***** CHECK 1 ***** --> UPDATE to REJECTED for Items/Services not in registers   REJECTION REASON = 1
	
	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL AND tblClaimItems.ItemID NOT IN 
                      (
                      SELECT     ItemID FROM @DTBL_ITEMS
                      )
                      
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL  AND tblClaimServices.ServiceID  NOT IN 
                      (
                      SELECT     ServiceID FROM @DTBL_SERVICES  
                      )
	
	--***** CHECK 2 ***** --> UPDATE to REJECTED for Items/Services not in Pricelists  REJECTION REASON = 2
	
	SELECT @HFID = HFID from tblClaim WHERE ClaimID = @ClaimID 
	SELECT @HFCareType = ISNULL(HFCareType,'B')  from tblHF where HFID = @HFID 

	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 2
	FROM dbo.tblClaimItems 
	LEFT OUTER JOIN 
	(SELECT     tblPLItemsDetail.ItemID
	FROM         tblHF INNER JOIN
						  tblPLItems ON tblHF.PLItemID = tblPLItems.PLItemID INNER JOIN
						  tblPLItemsDetail ON tblPLItems.PLItemID = tblPLItemsDetail.PLItemID
	WHERE     (tblHF.HfID = @HFID) AND (tblPLItems.ValidityTo IS NULL) AND (tblPLItemsDetail.ValidityTo IS NULL)) PLItems 
	ON tblClaimItems.ItemID = PLItems.ItemID 
	WHERE tblClaimItems.ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL AND PLItems.ItemID IS NULL
	
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 2 
	FROM dbo.tblClaimServices 
	LEFT OUTER JOIN 
	(SELECT     tblPLServicesDetail.ServiceID 
	FROM         tblHF INNER JOIN
						  tblPLServicesDetail ON tblHF.PLServiceID = tblPLServicesDetail.PLServiceID
	WHERE     (tblHF.HfID = @HFID) AND (tblPLServicesDetail.ValidityTo IS NULL) AND (tblPLServicesDetail.ValidityTo IS NULL)) PLServices 
	ON tblClaimServices.ServiceID = PLServices.ServiceID  
	WHERE tblClaimServices.ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL AND PLServices.ServiceID  IS NULL
	
	
	-- ** !!!!! ITEMS LOOPING !!!!! ** 
	
	--now loop through all (remaining) items and determine what is the matching product within valid policies using the rule least cost sharing for Insuree 
	-- at this stage we only check if any valid product itemline is found --> will not yet assign the line. 
	
	DECLARE @FAULTCODE as INT 
	DECLARE @ProdFound as BIT

	
	-- ** !!!!! SERVICES LOOPING !!!!! **

	DECLARE CLAIMSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT ClaimServiceID,ServiceID FROM TblClaimServices WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 
	OPEN CLAIMSERVICELOOP
	FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID,@ServiceID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
					SELECT @CareType =  ServCareType , @ServCategory = [ServCategory],  @ServLevel = [ServLevel] FROM @DTBL_SERVICES WHERE [ServiceID] = @ServiceID

							-- **** START CHECK 10 --> Item Care type / HF caretype Fail (10)*****
					IF  (@CareType = 'I' AND (@HFCareType = 'O' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) = @ClaimDateFrom)  )) 
					OR  (@CareType = 'O' AND (@HFCareType = 'I' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom)))	

					BEGIN
						--inconsistant patient type check 
						UPDATE tblClaimServices SET RejectionReason = 10 WHERE ClaimServiceID  = @ClaimServiceID
						GOTO NextService
					END
					-- **** END CHECK 10 *****	
		
					-- **** START CHECK 4 --> Item/Service Limitation Fail (4)*****	
					SELECT TOP 1 @ServicePatCat = ServPatCat FROM @DTBL_SERVICES WHERE ServiceID = @ServiceID 
					IF (@ServicePatCat & @PatientMask) <> @PatientMask 	
					BEGIN
						--inconsistant patient type check 
						UPDATE tblClaimServices SET RejectionReason = 4 WHERE ClaimServiceID  = @ClaimServiceID
						GOTO NextService
					END
					-- **** END CHECK 4 *****
		
					SET @FAULTCODE = 0 
					SET @ProdFound = 0

					IF @Adult = 1 
							DECLARE PRODSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR 
							SELECT  TblProduct.ProdID , tblProductServices.ProdServiceID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
							FROM         tblFamilies INNER JOIN
												  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
												  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
												  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID INNER JOIN
												  tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
							WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
												  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL) AND 
												  (tblInsureePolicy.EffectiveDate <= @TargetDate) AND (tblInsureePolicy.ExpiryDate >= @TargetDate) AND (tblInsureePolicy.InsureeId = @InsureeID) AND 
												  (tblInsureePolicy.ValidityTo IS NULL)
							ORDER BY DATEADD(m,ISNULL(tblProductServices.WaitingPeriodAdult, 0), tblInsureePolicy.EffectiveDate)
					ELSE
							DECLARE PRODSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR 
							SELECT  TblProduct.ProdID , tblProductServices.ProdServiceID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
							FROM         tblFamilies INNER JOIN
												  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
												  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
												  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID INNER JOIN
												  tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
							WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
												  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL) AND 
												  (tblInsureePolicy.EffectiveDate <= @TargetDate) AND (tblInsureePolicy.ExpiryDate >= @TargetDate) AND (tblInsureePolicy.InsureeId = @InsureeID) AND 
												  (tblInsureePolicy.ValidityTo IS NULL)
							ORDER BY DATEADD(m,ISNULL(tblProductServices.WaitingPeriodChild, 0), tblInsureePolicy.EffectiveDate)

		
					OPEN PRODSERVICELOOP
					FETCH NEXT FROM PRODSERVICELOOP INTO @ProductID ,@ProdServiceID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
					WHILE @@FETCH_STATUS = 0 
					BEGIN
						SET @ProdFound= 1 --at least there is a product that would cover --> still to check on waiting period!
			
						-- **** START CHECK 17 --> Item/Service waiting period violation (17)*****	
						IF @PolicyStage = 'N' or (@EffectiveDatePolicy < @EffectiveDateInsuree )     --new policy or Insuree was added after policy was defined.
 						BEGIN
							IF @Adult = 1 
								SELECT TOP 1 @WaitingPeriod = [WaitingPeriodAdult] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
							ELSE
								SELECT TOP 1 @WaitingPeriod = [WaitingPeriodChild] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
		

							IF @TargetDate < DATEADD(m,@WaitingPeriod,@EffectiveDateInsuree)	
							BEGIN
								--Item/Service waiting period violation
								IF @FAULTCODE = 0 
									SET @FAULTCODE = 17
								GOTO ProdServiceNext --ProdLoopFinish
							END
						END
						-- **** END CHECK 17 *****


						-- **** START CHECK 16 --> Item/Service Maximum provision (16)*****	
						SET @LimitNo = -1 
						IF @Adult = 1 
							SELECT  @LimitNo = [LimitNoAdult] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
						ELSE
							SELECT  @LimitNo = [LimitNoChild] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
		

						IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
						BEGIN
							SET @Count = 0 
							SELECT @COUNT = SUM(tblClaimServices.QtyProvided )  
							FROM         tblClaimServices INNER JOIN
												  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID
							WHERE     (tblClaim.InsureeID = @InsureeID) AND (tblClaimServices.ServiceID = @ServiceID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND 
												  @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND  tblClaimServices.RejectionReason  = 0 
			
							IF ISNULL(@Count,0) >= @LimitNo 
							BEGIN
								--Over Item/Service Maximum Number allowed  (16)
								IF @FAULTCODE = 0 
									SET @FAULTCODE = 16
								GOTO ProdServiceNext --ProdLoopFinish
							END
						END
					-- **** END CHECK 16 *****

					-- **** START CHECK 13 --> Maximum consulations (13)*****
						IF @BaseCategory  = 'C'
						BEGIN
							SET @LimitNo = -1
							SELECT TOP 1 @LimitNo = MaxNoConsultation FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID 
								--FROM         tblClaimServices INNER JOIN
								--					  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--					  tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--					  @EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--					  (tblServices.ServCategory = 'C') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID  
								--) Sub

								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'C'


								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									--Over Maximum consulations (13)
									SET @FAULTCODE = 13
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 13 *****

						-- **** START CHECK 14 --> Maximum Surgeries (14)*****	
						IF @BaseCategory = 'S'
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoSurgery FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID
								--FROM         tblClaimServices INNER JOIN
								--						tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--						tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--						(tblServices.ServCategory = 'S') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID 
								--) Sub

								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'S'

								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									----Over  Maximum Surgeries (14)
									SET @FAULTCODE = 14
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 14 *****

						-- **** START CHECK 15 --> Maximum Deliveries (15)*****	
						IF @BaseCategory = 'D'
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoDelivery FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID
								--FROM         tblClaimServices INNER JOIN
								--						tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--						tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND  (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--						(tblServices.ServCategory = 'D') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID
								--) Sub
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'D'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									----Over  Maximum deliveries (15)
									SET @FAULTCODE = 15
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 15 *****

						-- **** START CHECK 19 --> Maximum Antenatal  (19)*****	
						IF @BaseCategory = 'A'
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoAntenatal  FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID
								--FROM         tblClaimServices INNER JOIN
								--						tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--						tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--						(tblServices.ServCategory = 'A') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID
								--) Sub
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'A'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									----Over  Maximum Antenatal (19)
									SET @FAULTCODE = 19
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END


						-- **** START CHECK 11 --> Maximum Hospital admissions (11)*****

						IF (@BaseCategory  = 'H') --(@ClaimStartDate < @ClaimEndDate )
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoHospitalizaion FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check    A hospital stay is defined as a differnece between the datefrom and dateto on Claim level (not looking at items/Services !!)
							BEGIN		
								SET @Count = 0 
			
								--SELECT @COUNT = COUNT(tblClaim.ClaimID) 
								--FROM        
								--						tblClaim
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ( ISNULL(tblClaim.DateTo, tblClaim.DateFrom) > tblClaim.DateFrom)
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'H'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									--Over Maximum Hospital admissions(11)
									
									SET @FAULTCODE = 11
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 11 *****


						-- **** START CHECK 12 --> Maximum Visits (OP) (12)*****	
						--IF (@ServCategory = 'C' OR @ServCategory = 'D') AND (ISNULL(@ClaimEndDate,@ClaimStartDate) = @ClaimStartDate )
						IF (@BaseCategory  = 'V') 
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = [MaxNoVisits] FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check    A visit  is defined as the datefrom and dateto the same AND having at least one oitem of service category S or C 
							BEGIN		
								SET @Count = 0 
							
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(SELECT tblClaim.ClaimID
								-- FROM         tblClaimServices INNER JOIN
								--					  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--					  tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--					  @EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--					  (tblServices.ServCategory = 'C' OR
								--					  tblServices.ServCategory = 'S') AND (tblClaimServices.RejectionReason = 0) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) = tblClaim.DateFrom)
								--GROUP BY tblClaim.ClaimID) Sub
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'V'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									--Over Maximum Visits (12)
									
									SET @FAULTCODE = 12
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 12 *****
						
						SET @FAULTCODE = 0
						GOTO ProdLoopFinishServices


			ProdServiceNext:
						FETCH NEXT FROM PRODSERVICELOOP INTO @ProductID ,@ProdServiceID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
					END
		
				ProdLoopFinishServices:

					CLOSE PRODSERVICELOOP
					DEALLOCATE PRODSERVICELOOP
		
					IF @ProdFound = 0 
						SET @FAULTCODE = 3 
		
					IF @FAULTCODE <> 0
					BEGIN
						UPDATE tblClaimServices SET RejectionReason = @FAULTCODE WHERE ClaimServiceID = @ClaimServiceID
						GOTO NextService
					END


		NextService:	
		FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID,@ServiceID
	END
	CLOSE CLAIMSERVICELOOP
	DEALLOCATE CLAIMSERVICELOOP
	
	DECLARE CLAIMITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT ClaimItemID,ItemID FROM TblClaimItems WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 
	OPEN CLAIMITEMLOOP
	FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID,@ItemID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		SELECT @CareType =  ItemCareType  FROM @DTBL_ITEMS WHERE [ItemID] = @ItemID
		-- **** START CHECK 10 --> Item Care type / HF caretype Fail (10)*****
		
		IF  (@CareType = 'I' AND (@HFCareType = 'O' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) = @ClaimDateFrom)  )) 
					OR  (@CareType = 'O' AND (@HFCareType = 'I' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom)))	

		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimItems SET RejectionReason = 10 WHERE ClaimItemID   = @ClaimItemID 
			GOTO NextItem
		END
		-- **** END CHECK 10 *****	

		-- **** START CHECK 4 --> Item/Service Limitation Fail (4)*****
		SELECT TOP 1 @ItemPatCat = ItemPatCat FROM @DTBL_ITEMS WHERE ItemID  = @ItemID  
		IF (@ItemPatCat  & @PatientMask) <> @PatientMask 	
		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimItems SET RejectionReason = 4 WHERE ClaimItemID   = @ClaimItemID 
			GOTO NextItem
		END
		-- **** END CHECK 4 *****	
		
		SET @FAULTCODE = 0 
		SET @ProdFound = 0

		IF @Adult = 1 
				DECLARE PRODITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR 
				SELECT  TblProduct.ProdID , tblProductItems.ProdItemID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID INNER JOIN
									  tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL) AND 
									  (tblInsureePolicy.EffectiveDate <= @TargetDate) AND (tblInsureePolicy.ExpiryDate >= @TargetDate) AND (tblInsureePolicy.InsureeId = @InsureeID) AND 
									  (tblInsureePolicy.ValidityTo IS NULL)
				ORDER BY DATEADD(m,ISNULL(tblProductItems.WaitingPeriodAdult, 0), tblInsureePolicy.EffectiveDate)
		ELSE
				DECLARE PRODITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR 
				SELECT  TblProduct.ProdID , tblProductItems.ProdItemID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID INNER JOIN
									  tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL) AND 
									  (tblInsureePolicy.EffectiveDate <= @TargetDate) AND (tblInsureePolicy.ExpiryDate >= @TargetDate) AND (tblInsureePolicy.InsureeId = @InsureeID) AND 
									  (tblInsureePolicy.ValidityTo IS NULL)
				ORDER BY DATEADD(m,ISNULL(tblProductItems.WaitingPeriodChild, 0), tblInsureePolicy.EffectiveDate)

		
		OPEN PRODITEMLOOP
		FETCH NEXT FROM PRODITEMLOOP INTO @ProductID ,@ProdItemID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SET @ProdFound= 1 --at least there is a product that would cover --> still to check on waiting period!
			
			-- **** START CHECK 17 --> Item/Service waiting period violation (17)*****	
			IF @PolicyStage = 'N' or (@EffectiveDatePolicy < @EffectiveDateInsuree )     --new policy or Insuree was added after policy was defined.
 			BEGIN
				IF @Adult = 1 
					SELECT  @WaitingPeriod = [WaitingPeriodAdult] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
				ELSE
					SELECT  @WaitingPeriod = [WaitingPeriodChild] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
		

				IF @TargetDate < DATEADD(m,@WaitingPeriod,@EffectiveDateInsuree)	
				BEGIN
					--Item/Service waiting period violation (17)
					IF @FAULTCODE = 0 
						SET @FAULTCODE = 17
					GOTO ProdItemNext --ProdLoopFinish
				END
			
			END
			-- **** END CHECK 17 *****

			-- **** START CHECK 16 --> Item/Service Maximum provision (16)*****	
			SET @LimitNo = -1
			IF @Adult = 1 
				SELECT  @LimitNo = [LimitNoAdult] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
			ELSE
				SELECT  @LimitNo = [LimitNoChild] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
		

			IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
			BEGIN
				SET @Count = 0 
				SELECT @COUNT = SUM(tblClaimItems.QtyProvided)  
				FROM         tblClaimItems INNER JOIN
									  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID
				WHERE     (tblClaim.InsureeID = @InsureeID) AND (tblClaimItems.ItemID = @ItemID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND 
									  @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ValidityTo IS NULL) AND tblClaimItems.RejectionReason  = 0  
			
				IF ISNULL(@Count,0) >= @LimitNo  
				BEGIN
					--Over Item/Service Maximum Number allowed  (16)
					IF @FAULTCODE = 0 
						SET @FAULTCODE = 16
					GOTO ProdItemNext --ProdLoopFinish
				END
			END
		-- **** END CHECK 16 *****

		    SET @FAULTCODE = 0
			GOTO ProdLoopFinishItems

ProdItemNext:
			FETCH NEXT FROM PRODITEMLOOP INTO @ProductID ,@ProdItemID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
		END
		
	ProdLoopFinishItems:

		CLOSE PRODITEMLOOP
		DEALLOCATE PRODITEMLOOP
		
		IF @ProdFound = 0 
			SET @FAULTCODE = 3 
		
		IF @FAULTCODE <> 0
		BEGIN
			UPDATE tblClaimItems SET RejectionReason = @FAULTCODE WHERE ClaimItemID = @ClaimItemID
			GOTO NextItem
		END
		
		NextItem:
		FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID,@ItemID
	END
	CLOSE CLAIMITEMLOOP
	DEALLOCATE CLAIMITEMLOOP
		
	--***** START CHECK 5 ITEMS ***** --> Item/Service Limitation Fail (5)
	UPDATE tblClaimItems SET RejectionReason = 5 WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 AND ItemID IN
	(
	SELECT ClaimedItems.ItemID FROM
	(
	SELECT     Items.ItemFrequency, tblClaim.InsureeID, tblClaimItems.ItemID
	FROM         tblClaimItems INNER JOIN
				  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID
	WHERE     (Items.ItemFrequency > 0) AND (tblClaim.ClaimID = @ClaimID) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0)
	) ClaimedItems 
	INNER JOIN 
	(
	SELECT     Items.ItemFrequency, tblClaim.InsureeID, tblClaimItems.ItemID
	FROM         tblClaimItems INNER JOIN
				  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID
	WHERE     (Items.ItemFrequency > 0) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0) AND (tblClaim.InsureeID = @InsureeID) AND 
				  (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ClaimItemStatus = 1) AND (tblClaim.ClaimStatus > 2)
				  AND ABS(DATEDIFF(DD  ,ISNULL(tblClaim.DateTo,tblClaim.DateFrom) ,@TargetDate )) < ItemFrequency
	) ClaimedPrevious  --already checked,processed or valuated claims with passed items within frequency limit of days from the claim to be checked for certain Insuree
	ON ClaimedItems.InsureeID = ClaimedPrevious.InsureeID AND ClaimedItems.ItemID = ClaimedPrevious.ItemID 
	)
	-- **** END CHECK 5 ITEMS *****
	
	--***** START CHECK 5 SERVICESS ***** --> Item/Service Limitation Fail (5)
	UPDATE tblClaimServices SET RejectionReason = 5 WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 AND ServiceID IN
	(
	SELECT ClaimedServices.ServiceID FROM
	(
	SELECT     [Services].ServFrequency, tblClaim.InsureeID, tblClaimServices.ServiceID
	FROM         tblClaimServices INNER JOIN
				  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_SERVICES [Services] ON tblClaimServices.ServiceID = [Services].ServiceID
	WHERE     ([Services].ServFrequency > 0) AND (tblClaim.ClaimID = @ClaimID) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0)
	) ClaimedServices 
	INNER JOIN 
	(
	SELECT     [Services].ServFrequency, tblClaim.InsureeID, tblClaimServices.ServiceID
	FROM         tblClaimServices INNER JOIN
				  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_SERVICES [Services] ON tblClaimServices.ServiceID = [Services].ServiceID
	WHERE     ([Services].ServFrequency > 0) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0) AND (tblClaim.InsureeID = @InsureeID) AND 
				  (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ClaimServiceStatus = 1) AND (tblClaim.ClaimStatus > 2)
				  AND ABS(DATEDIFF(DD  ,ISNULL(tblClaim.DateTo,tblClaim.DateFrom) ,@TargetDate )) < ServFrequency
	) ClaimedPrevious  --already checked,processed or valuated claims with passed services within frequency limit of days from the claim to be checked for certain Insuree
	ON ClaimedServices.InsureeID = ClaimedPrevious.InsureeID AND ClaimedServices.ServiceID = ClaimedPrevious.ServiceID 
	)
	-- **** END CHECK 5 SERVICES *****




UPDATECLAIM:

	IF @FAULTCODE IN (11,12,13,14,15,19) 
	BEGIN
		--we went over themaximum of a category --> all items and services in the claim are rejected !!
		UPDATE tblClaimItems SET ClaimItemStatus = 2, QtyApproved = 0 , RejectionReason = @FAULTCODE  WHERE ClaimID = @ClaimID  
		UPDATE tblClaimServices SET ClaimServiceStatus = 2, QtyApproved = 0,  RejectionReason = @FAULTCODE  WHERE ClaimID = @ClaimID 
		
	END
	ELSE
	BEGIN
		UPDATE tblClaimItems SET ClaimItemStatus = 2, QtyApproved = 0 WHERE ClaimID = @ClaimID  AND  RejectionReason <> 0 
		UPDATE tblClaimServices SET ClaimServiceStatus = 2, QtyApproved = 0 WHERE ClaimID = @ClaimID AND RejectionReason <> 0 
	
	END

	
	SELECT @RtnItemsPassed = ISNULL(COUNT(ClaimItemID),0) FROM dbo.tblClaimItems WHERE ClaimID = @ClaimID AND ClaimItemStatus = 1 AND ValidityTo IS NULL
	SELECT @RtnServicesPassed  = ISNULL(COUNT(ClaimServiceID),0) FROM dbo.tblClaimServices  WHERE ClaimID = @ClaimID AND ClaimServiceStatus = 1 AND ValidityTo IS NULL
	SELECT @RtnItemsRejected = ISNULL(COUNT(ClaimItemID),0) FROM dbo.tblClaimItems WHERE ClaimID = @ClaimID AND ClaimItemStatus = 2 AND ValidityTo IS NULL
	SELECT @RtnServicesRejected  = ISNULL(COUNT(ClaimServiceID),0) FROM dbo.tblClaimServices  WHERE ClaimID = @ClaimID AND ClaimServiceStatus = 2 AND ValidityTo IS NULL
	
	DECLARE @AppItemValue as decimal(18,2)
	DECLARE @AppServiceValue as decimal(18,2)
	SET @AppItemValue = 0 
	SET @AppServiceValue = 0 
	
	IF @RtnItemsPassed > 0  OR @RtnServicesPassed > 0  --UPDATE CLAIM TO PASSED !! (default is not yet passed before checking procedure 
	BEGIN
		IF @RtnItemsRejected > 0 OR @RtnServicesRejected > 0
		BEGIN
			--Update Claim Approved Value 
			SELECT @AppItemValue = ISNULL(SUM((ISNULL(QtyProvided,QtyApproved) * ISNULL(PriceAsked ,PriceApproved))), 0) 
									FROM tblClaimItems WHERE 
										  (tblClaimItems.ValidityTo IS NULL )
										  AND (tblClaimItems.ClaimItemStatus = 1) 
										  AND (tblClaimItems.ClaimID  = @ClaimID)
									
			SELECT @AppServiceValue = ISNULL(SUM((ISNULL(QtyProvided,QtyApproved) * ISNULL(PriceAsked ,PriceApproved))), 0) 
									FROM tblClaimServices WHERE 
										  (tblClaimServices.ValidityTo IS NULL )
										  AND (tblClaimServices.ClaimServiceStatus = 1) 
										  AND (tblClaimServices.ClaimID  = @ClaimID)
			
			--update claim approved value due to some rejections (not all rejected!)
			UPDATE tblClaim SET ClaimStatus = 4, Approved = (@AppItemValue + @AppServiceValue) , AuditUserIDSubmit = @AuditUser , SubmitStamp = GETDATE() ,  ClaimCategory = @BaseCategory WHERE ClaimID = @ClaimID 
		END
		ELSE
		BEGIN
			--no rejections 
			UPDATE tblClaim SET ClaimStatus = 4, AuditUserIDSubmit = @AuditUser , SubmitStamp = GETDATE() ,  ClaimCategory = @BaseCategory WHERE ClaimID = @ClaimID 
		END
		SET @RtnStatus = 1 
	END
	ELSE
	BEGIN
		UPDATE tblClaim SET ClaimStatus = 1, AuditUserIDSubmit = @AuditUser , SubmitStamp = GETDATE() ,  ClaimCategory = @BaseCategory WHERE ClaimID = @ClaimID --> set rejected as all items ands services did not pass ! 
		SET @RtnStatus = 2 
	END
	
FINISH:
	
	RETURN @oReturnValue
	END TRY
	
	BEGIN CATCH
		SELECT 'Unexpected error encountered'
		SET @oReturnValue = 1 
		RETURN @oReturnValue
		
	END CATCH
END


/****** Object:  StoredProcedure [dbo].[uspRestAPIUpdateClaimFromPhone]    Script Date: 10/29/2021 3:21:24 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[uspRestAPIUpdateClaimFromPhone]
(
	@XML XML,
	@ByPassSubmit BIT = 0,
	@ClaimRejected BIT = 0 OUTPUT
)

/*
-1	-- Fatal Error
0	-- All OK
1	--Invalid HF CODe
2	--Duplicate Claim Code
3	--Invald CHFID
4	--End date is smaller than start date
5	--Invalid ICDCode
6	--Claimed amount is 0
7	--Invalid ItemCode
8	--Invalid ServiceCode
9	--Invalid Claim Admin
*/

AS
BEGIN

	SET XACT_ABORT ON

	DECLARE @Query NVARCHAR(3000)

	DECLARE @ClaimID INT
	DECLARE @ClaimDate DATE
	DECLARE @HFCode NVARCHAR(8)
	DECLARE @ClaimAdmin NVARCHAR(8)
	DECLARE @ClaimCode NVARCHAR(8)
	DECLARE @CHFID NVARCHAR(12)
	DECLARE @StartDate DATE
	DECLARE @EndDate DATE
	DECLARE @ICDCode NVARCHAR(6)
	DECLARE @Comment NVARCHAR(MAX)
	DECLARE @Total DECIMAL(18,2)
	DECLARE @ICDCode1 NVARCHAR(6)
	DECLARE @ICDCode2 NVARCHAR(6)
	DECLARE @ICDCode3 NVARCHAR(6)
	DECLARE @ICDCode4 NVARCHAR(6)
	DECLARE @VisitType CHAR(1)
	DECLARE @GuaranteeId NVARCHAR(50)


	DECLARE @HFID INT
	DECLARE @ClaimAdminId INT
	DECLARE @InsureeID INT
	DECLARE @ICDID INT
	DECLARE @ICDID1 INT
	DECLARE @ICDID2 INT
	DECLARE @ICDID3 INT
	DECLARE @ICDID4 INT
	DECLARE @TotalItems DECIMAL(18,2) = 0
	DECLARE @TotalServices DECIMAL(18,2) = 0

	DECLARE @isClaimAdminRequired BIT = (SELECT CASE Adjustibility WHEN N'M' THEN 1 ELSE 0 END FROM tblControls WHERE FieldName = N'ClaimAdministrator')
	DECLARE @isClaimAdminOptional BIT = (SELECT CASE Adjustibility WHEN N'O' THEN 1 ELSE 0 END FROM tblControls WHERE FieldName = N'ClaimAdministrator')

	SELECT @ClaimRejected = 0

	BEGIN TRY

			IF NOT OBJECT_ID('tempdb..#tblItem') IS NULL DROP TABLE #tblItem
			CREATE TABLE #tblItem(ItemCode NVARCHAR(6),ItemPrice DECIMAL(18,2), ItemQuantity INT)

			IF NOT OBJECT_ID('tempdb..#tblService') IS NULL DROP TABLE #tblService
			CREATE TABLE #tblService(ServiceCode NVARCHAR(6),ServicePrice DECIMAL(18,2), ServiceQuantity INT)

			--SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK '''+ @FileName +''',SINGLE_BLOB) AS T(X)')

			--EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

			SELECT
			@ClaimDate = Claim.value('(ClaimDate)[1]','DATE'),
			@HFCode = Claim.value('(HFCode)[1]','NVARCHAR(8)'),
			@ClaimAdmin = Claim.value('(ClaimAdmin)[1]','NVARCHAR(8)'),
			@ClaimCode = Claim.value('(ClaimCode)[1]','NVARCHAR(8)'),
			@CHFID = Claim.value('(CHFID)[1]','NVARCHAR(12)'),
			@StartDate = Claim.value('(StartDate)[1]','DATE'),
			@EndDate = Claim.value('(EndDate)[1]','DATE'),
			@ICDCode = Claim.value('(ICDCode)[1]','NVARCHAR(6)'),
			@Comment = Claim.value('(Comment)[1]','NVARCHAR(MAX)'),
			@Total = CASE Claim.value('(Total)[1]','VARCHAR(10)') WHEN '' THEN 0 ELSE CONVERT(DECIMAL(18,2),ISNULL(Claim.value('(Total)[1]','VARCHAR(10)'),0)) END,
			@ICDCode1 = Claim.value('(ICDCode1)[1]','NVARCHAR(6)'),
			@ICDCode2 = Claim.value('(ICDCode2)[1]','NVARCHAR(6)'),
			@ICDCode3 = Claim.value('(ICDCode3)[1]','NVARCHAR(6)'),
			@ICDCode4 = Claim.value('(ICDCode4)[1]','NVARCHAR(6)'),
			@VisitType = Claim.value('(VisitType)[1]','CHAR(1)'),
			@GuaranteeId = Claim.value('(GuaranteeNo)[1]','NVARCHAR(50)')
			FROM @XML.nodes('Claim/Details')AS T(Claim)


			INSERT INTO #tblItem(ItemCode,ItemPrice,ItemQuantity)
			SELECT
			T.Items.value('(ItemCode)[1]','NVARCHAR(6)'),
			CONVERT(DECIMAL(18,2),T.Items.value('(ItemPrice)[1]','DECIMAL(18,2)')),
			CONVERT(DECIMAL(18,2),T.Items.value('(ItemQuantity)[1]','NVARCHAR(15)'))
			FROM @XML.nodes('Claim/Items/Item') AS T(Items)



			INSERT INTO #tblService(ServiceCode,ServicePrice,ServiceQuantity)
			SELECT
			T.[Services].value('(ServiceCode)[1]','NVARCHAR(6)'),
			CONVERT(DECIMAL(18,2),T.[Services].value('(ServicePrice)[1]','DECIMAL(18,2)')),
			CONVERT(DECIMAL(18,2),T.[Services].value('(ServiceQuantity)[1]','NVARCHAR(15)'))
			FROM @XML.nodes('Claim/Services/Service') AS T([Services])

			--isValid HFCode

			SELECT @HFID = HFID FROM tblHF WHERE HFCode = @HFCode AND ValidityTo IS NULL
			IF @HFID IS NULL
				RETURN 1

			--isDuplicate ClaimCode
			IF EXISTS(SELECT ClaimCode FROM tblClaim WHERE ClaimCode = @ClaimCode AND HFID = @HFID AND ValidityTo IS NULL)
				RETURN 2

			--isValid CHFID
			SELECT @InsureeID = InsureeID FROM tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL
			IF @InsureeID IS NULL
				RETURN 3

			--isValid EndDate
			IF DATEDIFF(DD,@ENDDATE,@STARTDATE) > 0
				RETURN 4

			--isValid ICDCode
			SELECT @ICDID = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode AND ValidityTo IS NULL
			IF @ICDID IS NULL
				RETURN 5

			IF NOT NULLIF(@ICDCode1, '')IS NULL
			BEGIN
				SELECT @ICDID1 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode1 AND ValidityTo IS NULL
				IF @ICDID1 IS NULL
					RETURN 5
			END

			IF NOT NULLIF(@ICDCode2, '') IS NULL
			BEGIN
				SELECT @ICDID2 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode2 AND ValidityTo IS NULL
				IF @ICDID2 IS NULL
					RETURN 5
			END

			IF NOT NULLIF(@ICDCode3, '') IS NULL
			BEGIN
				SELECT @ICDID3 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode3 AND ValidityTo IS NULL
				IF @ICDID3 IS NULL
					RETURN 5
			END

			IF NOT NULLIF(@ICDCode4, '') IS NULL
			BEGIN
				SELECT @ICDID4 = ICDID FROM tblICDCodes WHERE ICDCode = @ICDCode4 AND ValidityTo IS NULL
				IF @ICDID4 IS NULL
					RETURN 5
			END
			--isValid Claimed Amount
			--THIS CONDITION CAN BE PUT BACK
			--IF @Total <= 0
			--	RETURN 6

			--isValid ItemCode
			IF EXISTS (SELECT I.ItemCode
			FROM tblItems I FULL OUTER JOIN #tblItem TI ON I.ItemCode COLLATE DATABASE_DEFAULT = TI.ItemCode COLLATE DATABASE_DEFAULT
			WHERE I.ItemCode IS NULL AND I.ValidityTo IS NULL)
				RETURN 7

			--isValid ServiceCode
			IF EXISTS(SELECT S.ServCode
			FROM tblServices S FULL OUTER JOIN #tblService TS ON S.ServCode COLLATE DATABASE_DEFAULT = TS.ServiceCode COLLATE DATABASE_DEFAULT
			WHERE S.ServCode IS NULL AND S.ValidityTo IS NULL)
				RETURN 8

			--isValid Claim Admin
			IF @isClaimAdminRequired = 1
				BEGIN
					SELECT @ClaimAdminId = ClaimAdminId FROM tblClaimAdmin WHERE ClaimAdminCode = @ClaimAdmin AND ValidityTo IS NULL
					IF @ClaimAdmin IS NULL
						RETURN 9
				END
			ELSE
				IF @isClaimAdminOptional = 1
					BEGIN
						SELECT @ClaimAdminId = ClaimAdminId FROM tblClaimAdmin WHERE ClaimAdminCode = @ClaimAdmin AND ValidityTo IS NULL
					END

		BEGIN TRAN CLAIM
			INSERT INTO tblClaim(InsureeID,ClaimCode,DateFrom,DateTo,ICDID,ClaimStatus,Claimed,DateClaimed,Explanation,AuditUserID,HFID,ClaimAdminId,ICDID1,ICDID2,ICDID3,ICDID4,VisitType,GuaranteeId)
						VALUES(@InsureeID,@ClaimCode,@StartDate,@EndDate,@ICDID,2,@Total,@ClaimDate,@Comment,-1,@HFID,@ClaimAdminId,@ICDID1,@ICDID2,@ICDID3,@ICDID4,@VisitType,@GuaranteeId);

			SELECT @ClaimID = SCOPE_IDENTITY();

			;WITH PLID AS
			(
				SELECT PLID.ItemId, PLID.PriceOverule
				FROM tblHF HF
				INNER JOIN tblPLItems PLI ON PLI.PLItemId = HF.PLItemID
				INNER JOIN tblPLItemsDetail PLID ON PLID.PLItemId = PLI.PLItemId
				WHERE HF.ValidityTo IS NULL
				AND PLI.ValidityTo IS NULL
				AND PLID.ValidityTo IS NULL
				AND HF.HFID = @HFID
			)
			INSERT INTO tblClaimItems(ClaimID,ItemID,QtyProvided,PriceAsked,AuditUserID)
			SELECT @ClaimID, I.ItemId, T.ItemQuantity, COALESCE(NULLIF(T.ItemPrice,0),PLID.PriceOverule,I.ItemPrice)ItemPrice, -1
			FROM #tblItem T
			INNER JOIN tblItems I  ON T.ItemCode COLLATE DATABASE_DEFAULT = I.ItemCode COLLATE DATABASE_DEFAULT AND I.ValidityTo IS NULL
			LEFT OUTER JOIN PLID ON PLID.ItemID = I.ItemID

			SELECT @TotalItems = SUM(PriceAsked * QtyProvided) FROM tblClaimItems
						WHERE ClaimID = @ClaimID
						GROUP BY ClaimID

			;WITH PLSD AS
			(
				SELECT PLSD.ServiceId, PLSD.PriceOverule
				FROM tblHF HF
				INNER JOIN tblPLServices PLS ON PLS.PLServiceId = HF.PLServiceID
				INNER JOIN tblPLServicesDetail PLSD ON PLSD.PLServiceId = PLS.PLServiceId
				WHERE HF.ValidityTo IS NULL
				AND PLS.ValidityTo IS NULL
				AND PLSD.ValidityTo IS NULL
				AND HF.HFID = @HFID
			)
			INSERT INTO tblClaimServices(ClaimId, ServiceID, QtyProvided, PriceAsked, AuditUserID)
			SELECT @ClaimID, S.ServiceID, T.ServiceQuantity,COALESCE(NULLIF(T.ServicePrice,0),PLSD.PriceOverule,S.ServPrice)ServicePrice , -1
			FROM #tblService T
			INNER JOIN tblServices S ON T.ServiceCode COLLATE DATABASE_DEFAULT = S.ServCode COLLATE DATABASE_DEFAULT AND S.ValidityTo IS NULL
			LEFT OUTER JOIN PLSD ON PLSD.ServiceId = S.ServiceId

						SELECT @TotalServices = SUM(PriceAsked * QtyProvided) FROM tblClaimServices
						WHERE ClaimID = @ClaimID
						GROUP BY ClaimID

						UPDATE tblClaim SET Claimed = ISNULL(@TotalItems,0) + ISNULL(@TotalServices,0)
						WHERE ClaimID = @ClaimID

		COMMIT TRAN CLAIM


		SELECT @ClaimID  = IDENT_CURRENT('tblClaim')

		IF @ByPassSubmit = 0
		BEGIN
			DECLARE @ClaimRejectionStatus INT
			EXEC uspRestAPISubmitSingleClaim -1, @ClaimID,0, @RtnStatus=@ClaimRejectionStatus OUTPUT
			IF @ClaimRejectionStatus = 2
				SELECT @ClaimRejected = 1
		END

	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN CLAIM
			SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH

	RETURN 0
END
GO
