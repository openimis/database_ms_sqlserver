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
