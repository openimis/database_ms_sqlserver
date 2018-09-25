

--- MIGRATION Script from V17.5.14 to V17.5.15

IF NOT OBJECT_ID('uspAddInsureePolicyOffline') IS NULL
DROP PROCEDURE [dbo].[uspAddInsureePolicyOffline]
GO

CREATE Procedure [dbo].[uspAddInsureePolicyOffline]
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


IF NOT OBJECT_ID('uspUploadEnrolmentFromPhone') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
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
		DECLARE @Family TABLE(FamilyId INT,InsureeId INT,LocationId INT, HOFCHFID nvarchar(12),Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), ConfirmationType NVARCHAR(3),isOffline INT)
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
		NULLIF(T.F.value('(Poverty)[1]', 'BIT'), ''),
		NULLIF(T.F.value('(FamilyType)[1]', 'NVARCHAR(2)'), ''),
		NULLIF(T.F.value('(FamilyAddress)[1]', 'NVARCHAR(200)'), ''),
		NULLIF(T.F.value('(Ethnicity)[1]', 'NVARCHAR(1)'), ''),
		NULLIF(T.F.value('(ConfirmationNo)[1]', 'NVARCHAR(12)'), ''),
		NULLIF(T.F.value('(ConfirmationType)[1]', 'NVARCHAR(3)'), ''),
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
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID AND dt.InsureeId <> I.InsureeID
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
							SELECT I.InsureeId, I.CHFID, @AssociatedPhotoFolder + '\'PhotoFolder, dt.PhotoPath, @OfficerId OfficerId, GETDATE() PhotoDate, GETDATE() ValidityFrom, @AuditUserId AuditUserId
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
								SELECT  I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,I.EffectiveDate, PL.ExpiryDate,PL.AuditUserID,I.isOffline
								FROM @Insuree I
								INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
								WHERE PL.ValidityTo IS NULL
								AND PL.PolicyID = @NewPolicyId
								)

								INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate, EffectiveDate,ExpiryDate,AuditUserId,isOffline)
								SELECT InsureeId, PolicyId, EnrollDate, StartDate,EffectiveDate, ExpiryDate, AuditUserId, isOffline
								FROM IP
								

								IF   EXISTS(SELECT 1 FROM @Premium WHERE isOffline = 1)
								BEGIN
									INSERT INTO tblPremium(PolicyId, PayerId, Amount, Receipt, PayDate, PayType, ValidityFrom, AuditUserId, isOffline, isPhotoFee)
									SELECT  PolicyId, PayerId, Amount, Receipt, PayDate, PayType, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, isPhotoFee 
									FROM @Premium
									WHERE PolicyId = @NewPolicyId;
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
		IF NOT EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.FamilyId = I.FamilyId
				  WHERE I.ValidityTo IS NULL AND I.IsHead = 1)
			RETURN -1;
		--end added by Amani
		IF EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID AND dt.InsureeId <> I.InsureeID
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
								DECLARE @InsureeId INT,
										@PhotoFileName NVARCHAR(200)
								SELECT @InsureeId = InsureeId, @PhotoFileName = PhotoPath FROM @Insuree WHERE CHFID = @CHFID
								update @Insuree set InsureeId = (select TOP 1 InsureeId from tblInsuree where CHFID = @CHFID and ValidityTo is null)
								where CHFID = @CHFID
								--Insert Insuree History
								INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],						[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
								SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,GETDATE(),InsureeID,[Relationship],[Profession],[Education],[Email] ,[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage] 
								FROM tblInsuree WHERE InsureeID = @InsureeId; 

								--Update Insuree Record
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
								
								UPDATE tblPhotos SET PhotoFolder = @AssociatedPhotoFolder+'\',PhotoFileName = @PhotoFileName, OfficerID = @OfficerID, ValidityFrom = GETDATE(), AuditUserID = @AuditUserID 
								WHERE PhotoID = @PhotoID
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










IF NOT OBJECT_ID('uspSSRSPaymentCategoryOverview') IS NULL
DROP PROCEDURE [dbo].[uspSSRSPaymentCategoryOverview]
GO

CREATE PROCEDURE [dbo].[uspSSRSPaymentCategoryOverview]
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

IF NOT OBJECT_ID('uspSSRSEnroledFamilies') IS NULL
DROP PROCEDURE [dbo].[uspSSRSEnroledFamilies]
GO



CREATE PROCEDURE [dbo].[uspSSRSEnroledFamilies]
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



/*====================================================================================================================
MIGRATION SCRIPT TO CHANGE FROM 17.5.15 TO 18.0.0
====================================================================================================================*/

--ON 06/03/2018
IF NOT OBJECT_ID('uspPolicyInquiry') IS NULL
DROP PROCEDURE uspPolicyInquiry
GO


CREATE PROCEDURE [dbo].[uspPolicyInquiry] 
(
	@CHFID NVARCHAR(12) = '',
	@LocationId int =  0
)
AS
BEGIN
	IF NOT OBJECT_ID('tempdb..#tempBase') IS NULL DROP TABLE #tempBase

		SELECT PR.ProdID,PL.PolicyID,I.CHFID,P.PhotoFolder + case when RIGHT(P.PhotoFolder,1) = '\' then '' else '\' end + P.PhotoFileName PhotoPath,I.LastName + ' ' + I.OtherNames InsureeName,
		CONVERT(VARCHAR,DOB,103) DOB, CASE WHEN I.Gender = 'M' THEN 'Male' ELSE 'Female' END Gender,PR.ProductCode,PR.ProductName,
		CONVERT(VARCHAR(12),IP.ExpiryDate,103) ExpiryDate, 
		CASE WHEN IP.EffectiveDate IS NULL OR CAST(GETDATE() AS DATE) < IP.EffectiveDate  THEN 'I' WHEN CAST(GETDATE() AS DATE) NOT BETWEEN IP.EffectiveDate AND IP.ExpiryDate THEN 'E' ELSE 
		CASE PL.PolicyStatus WHEN 1 THEN 'I' WHEN 2 THEN 'A' WHEN 4 THEN 'S' ELSE 'E' END
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

--ON 14/03/2017
IF  NOT OBJECT_ID('uspUploadEnrolments') IS NULL
DROP PROCEDURE uspUploadEnrolments
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolments](
	@File NVARCHAR(300),
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
	DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,EffectiveDate DATE, NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)

	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)


	BEGIN TRY

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


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

			--Delete existing families from temp table, we don't need them anymore
			DELETE FROM @tblFamilies WHERE NewFamilyId IS NOT NULL;


			--Insert new Families
			MERGE INTO tblFamilies 
			USING @tblFamilies AS TF ON 1 = 0 
			WHEN NOT MATCHED THEN 
				INSERT (InsureeId, LocationId, Poverty, ValidityFrom, AuditUserId, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo) 
				VALUES(0 , TF.LocationId, TF.Poverty, GETDATE() , -1 , TF.FamilyType, TF.FamilyAddress, TF.Ethnicity, TF.ConfirmationNo)
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

			--Insert new insurees 
			MERGE tblInsuree
			USING @tblInsuree TI ON 1 = 0
			WHEN NOT MATCHED THEN
				INSERT(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,passport,Phone,CardIssued,ValidityFrom,AuditUserID,Relationship,Profession,Education,Email,TypeOfId, HFID)
				VALUES(TI.NewFamilyId, TI.CHFID, TI.LastName, TI.OtherNames, TI.DOB, TI.Gender, TI.Marital, TI.IsHead, TI.Passport, TI.Phone, TI.CardIssued, GETDATE(), -1, TI.Relationship, TI.Profession, TI.Education, TI.Email, TI.TypeOfId, TI.HFID)
				OUTPUT TI.InsureeId, inserted.InsureeId INTO @tblIds;


			SELECT @InsureeImported = @@ROWCOUNT;

			--Update Ids of newly inserted insurees 
			UPDATE TI SET NewInsureeId = Id.[NewId]
			FROM @tblInsuree TI 
			INNER JOIN @tblIds Id ON TI.InsureeId = Id.OldId;

			--Insert Photos
			INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
			SELECT NewInsureeId,CHFID,'','',0,GETDATE(),GETDATE() ValidityFrom, -1 AuditUserID 
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
				VALUES(TP.NewFamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),-1)
			OUTPUT TP.PolicyId, inserted.PolicyId INTO @tblIds;
		
			SELECT @PolicyImported = @@ROWCOUNT;


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
			SELECT NewPolicyId,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),-1,isPhotoFee 
			FROM @tblPremium
		
			SELECT @PremiumImported = @@ROWCOUNT;


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
						(N'<h1 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h1>')
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


IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE Name = 'IX_tblInsuree-IsHead_VT-Fid-CHF')
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblInsuree-IsHead_VT-Fid-CHF] 
	ON [dbo].[tblInsuree]([IsHead], [ValidityTo])
	INCLUDE ([FamilyID], [CHFID]) 
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE Name = 'IX_tblInsuree_VT-CHFID')
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblInsuree_VT-CHFID]
	ON [dbo].[tblInsuree] ([ValidityTo])
	INCLUDE ([CHFID])
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE Name = 'IX_tblInsuree_CHFID_VT')
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblInsuree_CHFID_VT]
	ON [dbo].[tblInsuree] ([CHFID],[ValidityTo])
END
GO

--ON 20/03/2018

IF NOT OBJECT_ID('uspSSRSCapitationPayment') IS NULL
DROP PROCEDURE uspSSRSCapitationPayment
GO
CREATE PROCEDURE [dbo].[uspSSRSCapitationPayment]

(
	@RegionId INT = NULL,
	@DistrictId INT = NULL,
	@ProdId INT,
	@Year INT,
	@Month INT,
	@HFLevel xAttributeV READONLY
)
AS
BEGIN
	
	DECLARE @Level1 CHAR(1) = NULL,
			@Sublevel1 CHAR(1) = NULL,
			@Level2 CHAR(1) = NULL,
			@Sublevel2 CHAR(1) = NULL,
			@Level3 CHAR(1) = NULL,
			@Sublevel3 CHAR(1) = NULL,
			@Level4 CHAR(1) = NULL,
			@Sublevel4 CHAR(1) = NULL,
			@ShareContribution DECIMAL(5, 2),
			@WeightPopulation DECIMAL(5, 2),
			@WeightNumberFamilies DECIMAL(5, 2),
			@WeightInsuredPopulation DECIMAL(5, 2),
			@WeightNumberInsuredFamilies DECIMAL(5, 2),
			@WeightNumberVisits DECIMAL(5, 2),
			@WeightAdjustedAmount DECIMAL(5, 2)

	DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'; 
	DECLARE @LastDay DATE = EOMONTH(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01', 0)
	DECLARE @DaysInMonth INT = DATEDIFF(DAY,@FirstDay,DATEADD(MONTH,1,@FirstDay));

	SELECT @Level1 = Level1, @Sublevel1 = Sublevel1, @Level2 = Level2, @Sublevel2 = Sublevel2, @Level3 = Level3, @Sublevel3 = Sublevel3, 
	@Level4 = Level4, @Sublevel4 = Sublevel4, @ShareContribution = ISNULL(ShareContribution, 0), @WeightPopulation = ISNULL(WeightPopulation, 0), 
	@WeightNumberFamilies = ISNULL(WeightNumberFamilies, 0), @WeightInsuredPopulation = ISNULL(WeightInsuredPopulation, 0), @WeightNumberInsuredFamilies = ISNULL(WeightNumberInsuredFamilies, 0), 
	@WeightNumberVisits = ISNULL(WeightNumberVisits, 0), @WeightAdjustedAmount = ISNULL(WeightAdjustedAmount, 0)
	FROM tblProduct Prod 
	WHERE ProdId = @ProdId;


	PRINT @ShareContribution
	PRINT @WeightPopulation
	PRINT @WeightNumberFamilies 
	PRINT @WeightInsuredPopulation 
	PRINT @WeightNumberInsuredFamilies 
	PRINT @WeightNumberVisits 
	PRINT @WeightAdjustedAmount


	;WITH TotalPopFam AS
	(
	SELECT C.HFID , SUM((ISNULL(L.MalePopulation, 0) + ISNULL(L.FemalePopulation, 0) + ISNULL(L.OtherPopulation, 0)) *(0.01* Catchment))[Population], SUM(ISNULL(((L.Families)*(0.01* Catchment)), 0))TotalFamilies
		FROM tblHFCatchment C
		INNER JOIN tblLocations L ON L.LocationId = C.LocationId
		WHERE C.ValidityTo IS NULL
		AND L.ValidityTo IS NULL
		GROUP BY C.HFID--, L.LocationId, Catchment
	), InsuredInsuree AS
	(
		SELECT HC.HFID, COUNT(DISTINCT IP.InsureeId)*(0.01 * Catchment) TotalInsuredInsuree
		FROM tblInsureePolicy IP
		INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyId
		INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		INNER JOIN uvwLocations L ON L.LocationId = HC.LocationId
		INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		WHERE HC.ValidityTo IS NULL 
		AND I.ValidityTo IS NULL
		AND IP.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND IP.EffectiveDate <= @LastDay 
		AND IP.ExpiryDate > @LastDay
		AND PL.ProdID = @ProdId
		GROUP BY HC.HFID, L.LocationId, Catchment
	), InsuredFamilies AS
	(
		SELECT HC.HFID, COUNT(DISTINCT F.FamilyID)*(0.01 * Catchment) TotalInsuredFamilies
		FROM tblInsureePolicy IP
		INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		INNER JOIN uvwLocations L ON L.LocationId = HC.LocationId
		INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		WHERE HC.ValidityTo IS NULL 
		AND I.ValidityTo IS NULL
		AND IP.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND IP.EffectiveDate <= @LastDay 
		AND IP.ExpiryDate > @LastDay
		AND PL.ProdID = @ProdId
		GROUP BY HC.HFID, L.LocationId, Catchment
	), Claims AS
	(
		SELECT C.HFID,  COUNT(C.ClaimId)TotalClaims
		FROM tblClaim C
		INNER JOIN (
			SELECT ClaimId FROM tblClaimItems WHERE ProdId = @ProdId AND ValidityTo IS NULL
			UNION
			SELECT ClaimId FROM tblClaimServices WHERE ProdId = @ProdId AND ValidityTo IS NULL
			) CProd ON CProd.ClaimID = C.ClaimID
		WHERE C.ValidityTo IS NULL
		AND C.ClaimStatus >= 8
		AND YEAR(C.DateProcessed) = @Year
		AND MONTH(C.DateProcessed) = @Month
		GROUP BY C.HFID
	), ClaimValues AS
	(
		SELECT HFID, SUM(PriceValuated)TotalAdjusted
		FROM(
		SELECT C.HFID, CValue.PriceValuated
		FROM tblClaim C
		INNER JOIN (
			SELECT ClaimId, PriceValuated FROM tblClaimItems WHERE ValidityTo IS NULL AND ProdId = @ProdId
			UNION ALL
			SELECT ClaimId, PriceValuated FROM tblClaimServices WHERE ValidityTo IS NULL AND ProdId = @ProdId
			) CValue ON CValue.ClaimID = C.ClaimID
		WHERE C.ValidityTo IS NULL
		AND C.ClaimStatus >= 8
		AND YEAR(C.DateProcessed) = @Year
		AND MONTH(C.DateProcessed) = @Month
		)CValue
		GROUP BY HFID
	),Locations AS
	(
		SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId
		UNION
		SELECT LocationId,LocationName, ISNULL(ParentLocationId, 0) FROM tblLocations WHERE ValidityTo IS NULL AND LocationId = ISNULL(@DistrictId, @RegionId)
		UNION ALL
		SELECT L.LocationId, L.LocationName, L.ParentLocationId 
		FROM tblLocations L 
		INNER JOIN Locations ON Locations.LocationId = L.ParentLocationId
		WHERE L.validityTo IS NULL
		AND L.LocationType IN ('R', 'D')
	), Allocation AS
	(
		SELECT ProdId, CAST(SUM(ISNULL(Allocated, 0)) AS DECIMAL(18, 6))Allocated
		FROM
		(SELECT PL.ProdID,
		CASE 
		WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
			THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @FirstDay THEN @FirstDay ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @FirstDay THEN @FirstDay ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
		WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
			THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
		WHEN PL.EffectiveDate < @FirstDay AND PL.ExpiryDate > @LastDay AND PR.PayDate < @FirstDay
			THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
		END Allocated
		FROM tblPremium PR 
		INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
		WHERE PR.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND PL.ProdID = @ProdId
		AND PL.PolicyStatus <> 1
		AND PR.PayDate <= PL.ExpiryDate
		GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate)Alc
		GROUP BY ProdId
	) ,ReportData AS
	(
		SELECT L.RegionCode, L.RegionName, L.DistrictCode, L.DistrictName, HF.HFCode, HF.HFName, Hf.AccCode, HL.Name HFLevel, SL.HFSublevelDesc HFSublevel,
		PF.[Population] [Population], PF.TotalFamilies TotalFamilies, II.TotalInsuredInsuree, IFam.TotalInsuredFamilies, C.TotalClaims, CV.TotalAdjusted
		,(
			  ISNULL(ISNULL(PF.[Population], 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightPopulation)) /  NULLIF(SUM(PF.[Population])OVER(),0),0)  
			+ ISNULL(ISNULL(PF.TotalFamilies, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberFamilies)) /NULLIF(SUM(PF.[TotalFamilies])OVER(),0),0) 
			+ ISNULL(ISNULL(II.TotalInsuredInsuree, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightInsuredPopulation)) /NULLIF(SUM(II.TotalInsuredInsuree)OVER(),0),0) 
			+ ISNULL(ISNULL(IFam.TotalInsuredFamilies, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberInsuredFamilies)) /NULLIF(SUM(IFam.TotalInsuredFamilies)OVER(),0),0) 
			+ ISNULL(ISNULL(C.TotalClaims, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberVisits)) /NULLIF(SUM(C.TotalClaims)OVER() ,0),0) 
			+ ISNULL(ISNULL(CV.TotalAdjusted, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightAdjustedAmount)) /NULLIF(SUM(CV.TotalAdjusted)OVER(),0),0)

		) PaymentCathment

		, Allocation.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution) AlcContriPopulation
		, Allocation.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution) AlcContriNumFamilies
		, Allocation.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution) AlcContriInsPopulation
		, Allocation.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution) AlcContriInsFamilies
		, Allocation.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution) AlcContriVisits
		, Allocation.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution) AlcContriAdjustedAmount

		,  ISNULL((Allocation.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution))/ NULLIF(SUM(PF.[Population]) OVER(),0),0) UPPopulation
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution))/NULLIF(SUM(PF.TotalFamilies) OVER(),0),0) UPNumFamilies
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution))/NULLIF(SUM(II.TotalInsuredInsuree) OVER(),0),0) UPInsPopulation
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution))/ NULLIF(SUM(IFam.TotalInsuredFamilies) OVER(),0),0) UPInsFamilies
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution)) / NULLIF(SUM(C.TotalClaims) OVER(),0),0) UPVisits
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution))/ NULLIF(SUM(CV.TotalAdjusted) OVER(),0),0) UPAdjustedAmount




		FROM tblHF HF
		INNER JOIN @HFLevel HL ON HL.Code = HF.HFLevel
		LEFT OUTER JOIN tblHFSublevel SL ON SL.HFSublevel = HF.HFSublevel
		INNER JOIN uvwLocations L ON L.LocationId = HF.LocationId
		LEFT OUTER JOIN TotalPopFam PF ON PF.HFID = HF.HfID
		LEFT OUTER JOIN InsuredInsuree II ON II.HFID = HF.HfID
		LEFT OUTER JOIN InsuredFamilies IFam ON IFam.HFID = HF.HfID
		LEFT OUTER JOIN Claims C ON C.HFID = HF.HfID
		LEFT OUTER JOIN ClaimValues CV ON CV.HFID = HF.HfID
		INNER JOIN Allocation ON Allocation.ProdID = @ProdId

		WHERE HF.ValidityTo IS NULL
		AND (L.RegionId = @RegionId OR @RegionId IS NULL)
		AND (L.DistrictId = @DistrictId OR @DistrictId IS NULL)
		AND (HF.HFLevel IN (@Level1, @Level2, @Level3, @Level4) OR (@Level1 IS NULL AND @Level2 IS NULL AND @Level3 IS NULL AND @Level4 IS NULL))
		AND(
			((HF.HFLevel = @Level1 OR @Level1 IS NULL) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		  )

	)



	SELECT  MAX (RegionCode)RegionCode, 
		MAX(RegionName)RegionName,
		MAX(DistrictCode)DistrictCode,
		MAX(DistrictName)DistrictName,
		HFCode, 
		MAX(HFName)HFName,
		MAX(AccCode)AccCode, 
		MAX(HFLevel)HFLevel, 
		MAX(HFSublevel)HFSublevel,
		ISNULL(SUM([Population]),0)[Population],
		ISNULL(SUM(TotalFamilies),0)TotalFamilies,
		ISNULL(SUM(TotalInsuredInsuree),0)TotalInsuredInsuree,
		ISNULL(SUM(TotalInsuredFamilies),0)TotalInsuredFamilies,
		ISNULL(SUM(TotalClaims),0)TotalClaims,
		ISNULL(SUM(AlcContriPopulation),0)AlcContriPopulation,
		ISNULL(SUM(AlcContriNumFamilies),0)AlcContriNumFamilies,
		ISNULL(SUM(AlcContriInsPopulation),0)AlcContriInsPopulation,
		ISNULL(SUM(AlcContriInsFamilies),0)AlcContriInsFamilies,
		ISNULL(SUM(AlcContriVisits),0)AlcContriVisits,
		ISNULL(SUM(AlcContriAdjustedAmount),0)AlcContriAdjustedAmount,
		ISNULL(SUM(UPPopulation),0)UPPopulation,
		ISNULL(SUM(UPNumFamilies),0)UPNumFamilies,
		ISNULL(SUM(UPInsPopulation),0)UPInsPopulation,
		ISNULL(SUM(UPInsFamilies),0)UPInsFamilies,
		ISNULL(SUM(UPVisits),0)UPVisits,
		ISNULL(SUM(UPAdjustedAmount),0)UPAdjustedAmount,
		ISNULL(SUM(PaymentCathment),0)PaymentCathment,
		ISNULL(SUM(TotalAdjusted),0)TotalAdjusted
	
	 FROM ReportData

	 GROUP BY HFCode

	  

END
GO

--ON 21/03/2018

IF NOT OBJECT_ID('uspImportLocations') IS NULL
DROP PROC uspImportLocations
GO
CREATE PROCEDURE [dbo].[uspImportLocations]
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

	;WITH AllLocations AS
	(
		SELECT RegionCode LocationCode FROM tblRegions
		UNION ALL
		SELECT DistrictCode FROM tblDistricts
		UNION ALL
		SELECT WardCode FROM tblWards
		UNION ALL
		SELECT VillageCode FROM tblVillages
	)
	SELECT AC.LocationCode
	FROM @AllCodes AC
	INNER JOIN AllLocations AL ON AC.LocationCode COLLATE DATABASE_DEFAULT = AL.LocationCode COLLATE DATABASE_DEFAULT

	IF @@ROWCOUNT > 0
		RAISERROR ('One or more location codes are already existing in database', 16, 1)
	
	BEGIN TRAN
	
 
	--INSERT REGION IN DATABASE
	IF EXISTS(SELECT * FROM tblRegions
			 INNER JOIN #tempRegion ON tblRegions.RegionCode COLLATE DATABASE_DEFAULT = #tempRegion.RegionCode COLLATE DATABASE_DEFAULT)
		BEGIN
			ROLLBACK TRAN

			--RETURN -4
		END
	ELSE
		--INSERT INTO tblRegions(RegionName,RegionCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocatioNname, LocationType, AuditUserId)
		SELECT RegionCode, REPLACE(RegionName,CHAR(12),''),'R',-1 
		FROM #tempRegion
		WHERE RegionName IS NOT NULL

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
		WHERE #tempDistricts.DistrictName is NOT NULL
		 
		
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
		SELECT WardCode, REPLACE(#tempWards.WardName,CHAR(9),''),tblDistricts.DistrictID,'W',-1
		FROM #tempWards 
		INNER JOIN tblDistricts ON #tempWards.DistrictCode COLLATE DATABASE_DEFAULT = tblDistricts.DistrictCode COLLATE DATABASE_DEFAULT
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


IF NOT OBJECT_ID('uspCreateEnrolmentXML') IS NULL
DROP PROC uspCreateEnrolmentXML
GO
CREATE PROCEDURE [dbo].[uspCreateEnrolmentXML]
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
	SELECT I.InsureeID,I.FamilyID,I.CHFID,I.LastName,I.OtherNames,I.DOB,I.Gender,I.Marital,I.IsHead,I.passport,I.Phone,I.CardIssued,NULL EffectiveDate
	FROM tblInsuree I
	LEFT OUTER JOIN tblInsureePolicy IP ON IP.InsureeId=I.InsureeID
	WHERE I.ValidityTo IS NULL AND I.isOffline = 1
	AND IP.ValidityTo IS NULL 
	GROUP BY I.InsureeID,I.FamilyID,I.CHFID,I.LastName,I.OtherNames,I.DOB,I.Gender,I.Marital,I.IsHead,I.passport,I.Phone,I.CardIssued
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

IF NOT OBJECT_ID('dw.udfNumberOfCurrentInsuree') IS NULL
DROP FUNCTION [dw].[udfNumberOfCurrentInsuree]
GO


CREATE FUNCTION [dw].[udfNumberOfCurrentInsuree]()
RETURNS @Result TABLE(NumberOfCurrentInsuree INT, MonthTime INT, QuarterTime INT, YearTime INT, Age INT, Gender CHAR(1),Region NVARCHAR(20), InsureeDistrictName NVARCHAR(50), WardName NVARCHAR(50), VillageName NVARCHAR(50), ProdDistrictName NVARCHAR(50), ProductCode NVARCHAR(15), ProductName NVARCHAR(100), OfficeDistrict NVARCHAR(20), OfficerCode NVARCHAR(15), LastName NVARCHAR(100), OtherNames NVARCHAR(100), ProdRegion NVARCHAR(50))
AS
BEGIN

	DECLARE @StartDate DATE --= (SELECT MIN(EffectiveDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @EndDate DATE --= (SELECT Max(ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @LastDate DATE

	SET @StartDate = '2011-01-01'
	SET @EndDate = DATEADD(YEAR,3,GETDATE())

	DECLARE @tblLastDays TABLE(LastDate DATE)

	WHILE @StartDate <= @EndDate
	BEGIN
	SET @LastDate = DATEADD(DAY,-1,DATEADD(MONTH,DATEDIFF(MONTH,0,@StartDate) + 1,0));
	SET @StartDate = DATEADD(MONTH,1,@StartDate);
	INSERT INTO @tblLastDays(LastDate) VALUES(@LastDate)
	END

	INSERT INTO @Result(NumberOfCurrentInsuree,MonthTime,QuarterTime,YearTime,Age,Gender,Region,InsureeDistrictName,WardName,VillageName,
	ProdDistrictName,ProductCode,ProductName, OfficeDistrict, OfficerCode,LastName,OtherNames, ProdRegion)

	SELECT COUNT(I.InsureeID)NumberOfCurrentInsuree,MONTH(LD.LastDate)MonthTime,DATENAME(Q,LastDate)QuarterTime,YEAR(LD.LastDate)YearTime,
	DATEDIFF(YEAR,I.DOB,GETDATE()) Age,CAST(I.Gender AS VARCHAR(1)) Gender,R.RegionName Region,D.DistrictName, W.WardName,V.VillageName,
	ISNULL(PD.DistrictName, D.DistrictName) ProdDistrictName,Prod.ProductCode, Prod.ProductName, 
	ODist.DistrictName OfficerDistrict,O.Code, O.LastName,O.OtherNames, 
	--COALESCE(ISNULL(PD.DistrictName, R.RegionName) ,PR.RegionName, R.RegionName)ProdRegion
	COALESCE(R.RegionName, PR.RegionName)ProdRegion

	FROM tblPolicy PL INNER JOIN tblInsuree I ON PL.FamilyID = I.FamilyID
	INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardID = V.WardID
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	INNER JOIN tblDistricts ODist ON O.LocationId = ODist.DistrictID
	INNER JOIN tblInsureePolicy PIns ON I.InsureeID = PIns.InsureeId AND PL.PolicyID = PIns.PolicyId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	LEFT OUTER JOIN tblDistricts PD ON PD.DistrictID = Prod.LocationId
	LEFT OUTER JOIN tblRegions PR ON PR.RegionId = Prod.LocationId
	CROSS APPLY @tblLastDays LD 

	WHERE PL.ValidityTo IS NULL 
	AND I.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND Prod.ValidityTo IS NULL 
	AND O.ValidityTo IS NULL
	AND ODist.ValidityTo IS NULL
	AND PIns.ValidityTo IS NULL
	AND PIns.EffectiveDate <= LD.LastDate
	AND PIns.ExpiryDate  > LD.LastDate--= DATEADD(DAY, 1, DATEADD(MONTH,-1,EOMONTH(LD.LastDate,0))) 
	
	GROUP BY MONTH(LD.LastDate),DATENAME(Q,LastDate),YEAR(LD.LastDate),I.DOB,I.Gender, R.RegionName,D.DistrictName, W.WardName,V.VillageName,
	Prod.ProductCode, Prod.ProductName, ODist.DistrictName,O.Code, O.LastName,O.OtherNames, PD.DistrictName, PR.RegionName

	RETURN;

END

GO

IF NOT OBJECT_ID('dw.udfNumberOfCurrentPolicies') IS NULL
DROP FUNCTION [dw].[udfNumberOfCurrentPolicies]
GO


CREATE FUNCTION [dw].[udfNumberOfCurrentPolicies]()
RETURNS @Result TABLE(NumberOfCurrentPolicies INT, MonthTime INT, QuarterTime INT, YearTime INT, Age INT, Gender CHAR(1),Region NVARCHAR(20), InsureeDistrictName NVARCHAR(50), WardName NVARCHAR(50), VillageName NVARCHAR(50), ProdDistrictName NVARCHAR(50), ProductCode NVARCHAR(15), ProductName NVARCHAR(100), OfficeDistrict NVARCHAR(20), OfficerCode NVARCHAR(15), LastName NVARCHAR(100), OtherNames NVARCHAR(100), ProdRegion NVARCHAR(50))
AS
BEGIN
	DECLARE @StartDate DATE --= (SELECT MIN(EffectiveDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @EndDate DATE--= (SELECT Max(ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @LastDate DATE
	DECLARE @tblLastDays TABLE(LastDate DATE)

	DECLARE @Year INT,
		@MonthCounter INT = 1
	
	DECLARE Cur CURSOR FOR 
						SELECT Years FROM
						(SELECT YEAR(EffectiveDate) Years FROM tblPolicy WHERE ValidityTo IS NULL AND EffectiveDate IS NOT NULL GROUP BY YEAR(EffectiveDate) 
						UNION 
						SELECT YEAR(ExpiryDate) Years FROM tblPolicy WHERE ValidityTo IS NULL AND ExpiryDate IS NOT NULL GROUP BY YEAR(ExpiryDate)
						)Yrs ORDER BY Years
	OPEN Cur
		FETCH NEXT FROM Cur into @Year
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @StartDate = CAST(CAST(@Year AS VARCHAR(4))+ '-01-01' AS DATE)
			SET @MonthCounter = 1
			WHILE YEAR(@StartDate) = @Year
			BEGIN
				SET @LastDate = DATEADD(DAY,-1,DATEADD(MONTH,DATEDIFF(MONTH,0,@StartDate) + 1,0));
				SET @StartDate = DATEADD(MONTH,1,@StartDate);
				INSERT INTO @tblLastDays(LastDate) VALUES(@LastDate);
			END
			FETCH NEXT FROM Cur into @Year
		END
	CLOSE Cur
	DEALLOCATE Cur

	INSERT INTO @Result(NumberOfCurrentPolicies,MonthTime,QuarterTime,YearTime,Age,Gender,Region,InsureeDistrictName,WardName,VillageName,
	ProdDistrictName,ProductCode,ProductName, OfficeDistrict, OfficerCode,LastName,OtherNames, ProdRegion)
	SELECT COUNT(PolicyId) NumberOfCurrentPolicies, MONTH(LD.LastDate)MonthTime, DATENAME(Q,LD.LastDate)QuarterTime, YEAR(LD.LastDate)YearTime,
	DATEDIFF(YEAR, I.DOB,LD.LastDate)Age, I.Gender, R.RegionName Region, FD.DistrictName InsureeDistrictName, W.WardName, V.VillageName,
	ISNULL(PD.DistrictName, FD.DistrictName) ProdDistrictName, PR.ProductCode, PR.ProductName, OD.DistrictName OfficeDistrict, O.Code OfficerCode, O.LastName, O.OtherNames,
	--COALESCE(ISNULL(PD.DistrictName, R.RegionName) ,PRDR.RegionName, R.RegionName)ProdRegion
	COALESCE(R.RegionName, PRDR.RegionName)ProdRegion

	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
	INNER JOIN tblInsuree I ON F.InsureeID = I.InsureeID
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardID
	INNER JOIN tblDistricts FD ON FD.DistrictID = W.DistrictID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
	INNER JOIN tblOfficer O ON PL.OfficerId  = O.OfficerID
	INNER JOIN tblDistricts OD ON OD.DistrictId = O.LocationId
	INNER JOIN tblRegions R ON R.RegionId = FD.Region
	LEFT OUTER JOIN tblDistricts PD ON PD.DistrictId = PR.LocationId
	LEFT OUTER JOIN tblRegions PRDR ON PRDR.Regionid = PR.LocationId
	CROSS APPLY @tblLastDays LD
	WHERE PL.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND FD.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND PR.ValidityTo IS NULL
	AND O.ValidityTo IS NULL
	AND OD.ValidityTo IS NULL
	AND PL.EffectiveDate <= LD.LastDate
	AND PL.ExpiryDate > LD.LastDate--DATEADD(DAY, 1, DATEADD(MONTH,-1,EOMONTH(LD.LastDate,0))) 
	AND PL.PolicyStatus > 1

	GROUP BY DATEDIFF(YEAR, I.DOB,LD.LastDate),MONTH(LD.LastDate), DATENAME(Q,LD.LastDate), YEAR(LD.LastDate),
	I.Gender, R.RegionName, FD.DistrictName, W.WardName, V.VillageName,PR.ProductCode, 
	PR.ProductName,OD.DistrictName, O.COde ,O.LastName, O.OtherNames, PD.DistrictName, PRDR.RegionName
	
	RETURN;
END

GO

--ON 22/03/2017
IF NOT OBJECT_ID('uspImportLocations') IS NULL
DROP PROC uspImportLocations
GO
CREATE PROCEDURE [dbo].[uspImportLocations]
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
--ON 28/03/2018

IF NOT EXISTS(SELECT 1 FROM tblControls WHERE FieldName = N'ClaimAdministrator')
	INSERT INTO tblControls(FieldName, Adjustibility, Usage)
	SELECT N'ClaimAdministrator', N'M', N'FindClaim, Claim, ClaimReview, ClaimFeedback';
GO

IF NOT OBJECT_ID('uspUploadDiagnosisXML') IS NULL
DROP PROCEDURE uspUploadDiagnosisXML
GO


CREATE PROCEDURE uspUploadDiagnosisXML
(
	@File NVARCHAR(300),
	@StratergyId INT,	--1	: Insert Only,	2: Insert & Update	3: Insert, Update & Delete
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
	

	SET @Inserts = 0;
	SET @Updates = 0;
	SET @Deletes = 0;

	DECLARE @Query NVARCHAR(500)
	DECLARE @XML XML
	DECLARE @tblDiagnosis TABLE(ICDCode nvarchar(50),  ICDName NVARCHAR(255), IsValid BIT)
	DECLARE @tblDeleted TABLE(Id INT, Code NVARCHAR(8));
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))

	BEGIN TRY

		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE DIAGNOSES	 FROM THE XML
		INSERT INTO @tblDiagnosis(ICDCode,ICDName, IsValid)
		SELECT 
		T.F.value('(ICDCode)[1]','NVARCHAR(12)'),
		T.F.value('(ICDName)[1]','NVARCHAR(255)'),
		1 IsValid
		FROM @XML.nodes('Diagnosis/ICD') AS T(F)

		SELECT @DiagnosisSent=@@ROWCOUNT
	
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
			SELECT CONVERT(NVARCHAR(3), COUNT(D.ICDCode)) + N' ICD(s) have empty code', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'ICD Code ' + QUOTENAME(D.ICDCode) + N' has empty name field', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDName, '')) = 0


			UPDATE D SET IsValid = 0
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0 OR LEN(ISNULL(D.ICDName, '')) = 0

			--Check if any ICD Code is greater than 6 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the ICD Code ' + QUOTENAME(D.ICDCode) + ' is greater than 6 characters', N'E'
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
		IF @StratergyId = 3
			SELECT @Deletes = COUNT(1)
			FROM tblICDCodes D
			LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode AND temp.IsValid = 1
			LEFT OUTER JOIN tblClaim C ON C.ICDID = D.ICDID OR C.ICDID1 = D.ICDID OR C.ICDID2 = D.ICDID OR C.ICDID3 = D.ICDID OR C.ICDID4 = D.ICDID
			WHERE D.ValidityTo IS NULL
			AND temp.ICDCode IS NULL
			AND C.ClaimId IS NULL;
			
		
		--To be udpated
		IF @StratergyId = 2 OR @StratergyId = 3
		BEGIN
			SELECT @Updates = COUNT(1)
			FROM tblICDCodes ICD
			INNER JOIN @tblDiagnosis D ON ICD.ICDCode = D.ICDCode
			WHERE ICD.ValidityTo IS NULL
			AND D.IsValid = 1
		END
		
		SELECT @Inserts = COUNT(1)
		FROM @tblDiagnosis D
		LEFT OUTER JOIN tblICDCodes ICD ON D.ICDCode = ICD.ICDCode AND ICD.ValidityTo IS NULL
		WHERE D.IsValid = 1
		AND ICD.ICDCode IS NULL

		/*========================================================================================================
		VALIDATION ENDS
		========================================================================================================*/	

		IF @DryRun = 0
		BEGIN
			BEGIN TRAN UPLOAD

			/*========================================================================================================
			DELETE STARTS
			========================================================================================================*/	
				IF @StratergyId = 3
				BEGIN
					INSERT INTO @tblDeleted(Id, Code)
					SELECT D.ICDID, D.ICDCode
					FROM tblICDCodes D
					LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode
					WHERE D.ValidityTo IS NULL
					AND temp.ICDCode IS NULL
					AND temp.IsValid = 1

					--Check if any of the ICDCodes are used in Claims and remove them from the temporory table
					DELETE D
					FROM tblClaim C
					INNER JOIN @tblDeleted D ON C.ICDID = D.Id OR C.ICDID1 = D.Id OR C.ICDID2 = D.Id OR C.ICDID3 = D.Id OR C.ICDID4 = D.Id
	
					--Insert a copy of the to be deleted records
					INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, ValidityTo, LegacyId, AuditUserId)
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

	
				IF @StratergyId = 2 OR @StratergyId = 3
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

				INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, AuditUserId)
				SELECT D.ICDCode, D.ICDName, GETDATE() ValidityFrom, @AuditUserId AuditUserId
				FROM @tblDiagnosis D
				LEFT OUTER JOIN tblICDCodes ICD ON D.ICDCode = ICD.ICDCode AND ICD.ValidityTo IS NULL
				WHERE D.IsValid = 1
				AND ICD.ICDCode IS NULL;
	
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

		RETURN -1;
	END CATCH

	SELECT * FROM @tblResult;
	RETURN 0;
END
GO


IF NOT OBJECT_ID('uspImportHFXML') IS NULL
DROP PROCEDURE uspImportHFXML
GO

CREATE PROCEDURE uspImportHFXML
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

--ON 29/03/2017
IF NOT OBJECT_ID('uspUpdateClaimFromPhone') IS NULL
DROP PROCEDURE uspUpdateClaimFromPhone
GO

CREATE PROCEDURE [dbo].[uspUpdateClaimFromPhone]
(
	@FileName NVARCHAR(255),
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

	DECLARE @XML XML
	
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
	
	BEGIN TRY
		
			IF NOT OBJECT_ID('tempdb..#tblItem') IS NULL DROP TABLE #tblItem
			CREATE TABLE #tblItem(ItemCode NVARCHAR(6),ItemPrice DECIMAL(18,2), ItemQuantity INT)

			IF NOT OBJECT_ID('tempdb..#tblService') IS NULL DROP TABLE #tblService
			CREATE TABLE #tblService(ServiceCode NVARCHAR(6),ServicePrice DECIMAL(18,2), ServiceQuantity INT)

			SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK '''+ @FileName +''',SINGLE_BLOB) AS T(X)')
			
			EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

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
			@VisitType = Claim.value('(VisitType)[1]','CHAR(1)')
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

		BEGIN TRAN CLAIM
			INSERT INTO tblClaim(InsureeID,ClaimCode,DateFrom,DateTo,ICDID,ClaimStatus,Claimed,DateClaimed,Explanation,AuditUserID,HFID,ClaimAdminId,ICDID1,ICDID2,ICDID3,ICDID4,VisitType)
						VALUES(@InsureeID,@ClaimCode,@StartDate,@EndDate,@ICDID,2,@Total,@ClaimDate,@Comment,-1,@HFID,@ClaimAdminId,@ICDID1,@ICDID2,@ICDID3,@ICDID4,@VisitType);

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


--ON 03/04/2018
IF OBJECT_ID('tblIMISDetaulsPhone') IS NULL
BEGIN 
	CREATE TABLE [dbo].[tblIMISDetaulsPhone](
		[RuleName] [nvarchar](100) NULL,
		[RuleValue] [bit] NULL
	);

	INSERT INTO tblIMISDetaulsPhone(RuleName, RuleValue)VALUES
	(N'AllowInsureeWithoutPhoto', 0), (N'AllowFamilyWithoutPolicy', 0), (N'AllowPolicyWithoutPremium', 0)

END

GO

--ON 06/04/2018
IF NOT OBJECT_ID('uspUploadDiagnosisXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadDiagnosisXML]
GO

CREATE PROCEDURE [dbo].[uspUploadDiagnosisXML]
(
	@File NVARCHAR(300),
	@StratergyId INT,	--1	: Insert Only,	2: Insert & Update	3: Insert, Update & Delete
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
	

	SET @Inserts = 0;
	SET @Updates = 0;
	SET @Deletes = 0;

	DECLARE @Query NVARCHAR(500)
	DECLARE @XML XML
	DECLARE @tblDiagnosis TABLE(ICDCode nvarchar(50),  ICDName NVARCHAR(255), IsValid BIT)
	DECLARE @tblDeleted TABLE(Id INT, Code NVARCHAR(8));
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))

	BEGIN TRY

		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE DIAGNOSES	 FROM THE XML
		INSERT INTO @tblDiagnosis(ICDCode,ICDName, IsValid)
		SELECT 
		T.F.value('(ICDCode)[1]','NVARCHAR(12)'),
		T.F.value('(ICDName)[1]','NVARCHAR(255)'),
		1 IsValid
		FROM @XML.nodes('Diagnosis/ICD') AS T(F)

		SELECT @DiagnosisSent=@@ROWCOUNT
	
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
			SELECT CONVERT(NVARCHAR(3), COUNT(D.ICDCode)) + N' ICD(s) have empty code', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'ICD Code ' + QUOTENAME(D.ICDCode) + N' has empty name field', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDName, '')) = 0


			UPDATE D SET IsValid = 0
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0 OR LEN(ISNULL(D.ICDName, '')) = 0

			--Check if any ICD Code is greater than 6 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the ICD Code ' + QUOTENAME(D.ICDCode) + ' is greater than 6 characters', N'E'
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
		IF @StratergyId = 3
			SELECT @Deletes = COUNT(1)
			FROM tblICDCodes D
			LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode AND temp.IsValid = 1
			LEFT OUTER JOIN tblClaim C ON C.ICDID = D.ICDID OR C.ICDID1 = D.ICDID OR C.ICDID2 = D.ICDID OR C.ICDID3 = D.ICDID OR C.ICDID4 = D.ICDID
			WHERE D.ValidityTo IS NULL
			AND temp.ICDCode IS NULL
			AND C.ClaimId IS NULL;
			
		
		--To be udpated
		IF @StratergyId = 2 OR @StratergyId = 3
		BEGIN
			SELECT @Updates = COUNT(1)
			FROM tblICDCodes ICD
			INNER JOIN @tblDiagnosis D ON ICD.ICDCode = D.ICDCode
			WHERE ICD.ValidityTo IS NULL
			AND D.IsValid = 1
		END
		
		SELECT @Inserts = COUNT(1)
		FROM @tblDiagnosis D
		LEFT OUTER JOIN tblICDCodes ICD ON D.ICDCode = ICD.ICDCode AND ICD.ValidityTo IS NULL
		WHERE D.IsValid = 1
		AND ICD.ICDCode IS NULL

		/*========================================================================================================
		VALIDATION ENDS
		========================================================================================================*/	

		IF @DryRun = 0
		BEGIN
			BEGIN TRAN UPLOAD

			/*========================================================================================================
			DELETE STARTS
			========================================================================================================*/	
				IF @StratergyId = 3
				BEGIN
					INSERT INTO @tblDeleted(Id, Code)
					SELECT D.ICDID, D.ICDCode
					FROM tblICDCodes D
					LEFT OUTER JOIN @tblDiagnosis temp ON D.ICDCode = temp.ICDCode
					WHERE D.ValidityTo IS NULL
					AND temp.ICDCode IS NULL
					AND temp.IsValid = 1

					--Check if any of the ICDCodes are used in Claims and remove them from the temporory table
					DELETE D
					FROM tblClaim C
					INNER JOIN @tblDeleted D ON C.ICDID = D.Id OR C.ICDID1 = D.Id OR C.ICDID2 = D.Id OR C.ICDID3 = D.Id OR C.ICDID4 = D.Id
	
					--Insert a copy of the to be deleted records
					INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, ValidityTo, LegacyId, AuditUserId)
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

	
				IF @StratergyId = 2 OR @StratergyId = 3
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

				INSERT INTO tblICDCodes(ICDCode, ICDName, ValidityFrom, AuditUserId)
				SELECT D.ICDCode, D.ICDName, GETDATE() ValidityFrom, @AuditUserId AuditUserId
				FROM @tblDiagnosis D
				LEFT OUTER JOIN tblICDCodes ICD ON D.ICDCode = ICD.ICDCode AND ICD.ValidityTo IS NULL
				WHERE D.IsValid = 1
				AND ICD.ICDCode IS NULL;
	
				SELECT @Inserts = @@ROWCOUNT;


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

IF NOT OBJECT_ID('uspUploadLocationsXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadLocationsXML]
GO

CREATE PROCEDURE [dbo].[uspUploadLocationsXML]
(
		@File NVARCHAR(500),
		@StratergyId INT,
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

		DECLARE @Query NVARCHAR(500)
		DECLARE @XML XML
		DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
		DECLARE @tempRegion TABLE(RegionCode NVARCHAR(100), RegionName NVARCHAR(100), IsValid BIT )
		DECLARE @tempLocation TABLE(LocationCode NVARCHAR(100))
		DECLARE @tempDistricts TABLE(RegionCode NVARCHAR(100),DistrictCode NVARCHAR(100),DistrictName NVARCHAR(100), IsValid BIT )
		DECLARE @tempWards TABLE(DistrictCode NVARCHAR(100),WardCode NVARCHAR(100),WardName NVARCHAR(100), IsValid BIT )
		DECLARE @tempVillages TABLE(WardCode NVARCHAR(100),VillageCode NVARCHAR(100), VillageName NVARCHAR(100),MalePopulation INT,FemalePopulation INT, OtherPopulation INT, Families INT, IsValid BIT )

		BEGIN TRY
	
			SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

			EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


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
			NULLIF(T.R.value('(WardCode)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(WardName)[1]','NVARCHAR(100)'),''),
			1
			FROM @XML.nodes('Locations/Wards/Ward') AS T(R)
		
			SELECT @SentWard = @@ROWCOUNT

			--GET ALL THE VILLAGES FROM THE XML
			INSERT INTO @tempVillages(WardCode, VillageCode, VillageName, MalePopulation, FemalePopulation, OtherPopulation, Families, IsValid)
			SELECT 
			NULLIF(T.R.value('(WardCode)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(VillageCode)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(VillageName)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(MalePopulation)[1]','INT'),0),
			NULLIF(T.R.value('(FemalePopulation)[1]','INT'),0),
			NULLIF(T.R.value('(MalePopulation)[1]','INT'),0),
			NULLIF(T.R.value('(Families)[1]','INT'),0),
			1
			FROM @XML.nodes('Locations/Villages/Village') AS T(R)
		
			SELECT @SentVillage=@@ROWCOUNT

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
		
			/********************************DISTRICT ENDS******************************/

			/********************************WARDS STARTS******************************/
			--check if the ward has districtcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + N' has empty District Code', N'E' FROM @tempWards WHERE  LEN(ISNULL(DistrictCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(DistrictCode,''))=0 

			--check if the ward has valid districtCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + N' has invalid District Code', N'E' FROM @tempWards TW
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
			SELECT  CONVERT(NVARCHAR(3), COUNT(1)) + N' Ward(s) have empty Ward code', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 
		
			--check if the wardname is null 
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + N' has empty name', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardName,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(WardName,''))=0 
		
			--Check for Duplicates in file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(WardCode)) + ' times in the file', N'C'  FROM @tempWards GROUP BY WardCode HAVING COUNT(WardCode) >1 
		
			UPDATE W SET IsValid = 0 FROM @tempWards W
			WHERE WardCode in (SELECT WardCode from @tempWards GROUP BY WardCode HAVING COUNT(WardCode) >1)

			--check the length of the wardcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Ward Code ' + QUOTENAME(WardCode) + N' is greater than 50', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))>50
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardCode,''))>50

			--check the length of the wardname
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Ward Name ' + QUOTENAME(WardName) + N' is greater than 50', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardName,''))>50
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardName,''))>50
		
			/********************************WARDS ENDS******************************/

			/********************************VILLAGE STARTS******************************/
			--check if the village has Wardcoce
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has empty Ward Code', N'E' FROM @tempVillages WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempVillages SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 

			--check if the village has valid wardcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has invalid Ward Code', N'E' FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON  TW.WardCode=TV.WardCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TW.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0

			UPDATE TV SET TV.IsValid=0 FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON  TW.WardCode=TV.WardCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TW.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0

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
		
			UPDATE @tempVillages SET IsValid=0  WHERE Families<0

		
			/********************************VILLAGE ENDS******************************/
			/*========================================================================================================
			VALIDATION ENDS
			========================================================================================================*/	
	
			/*========================================================================================================
			COUNTS START
			========================================================================================================*/	
					IF @StratergyId =1 OR @StratergyId =2
						BEGIN
							--Regions insert
							SELECT @InsertRegion=COUNT(1) FROM @tempRegion TR 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
							WHERE
							TR.IsValid=1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

						--Districts insert
							SELECT @InsertDistrict=COUNT(1) FROM @tempDistricts TD 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
							WHERE
							TD.IsValid=1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

						--Wards insert
							SELECT @InsertWard=COUNT(1) FROM @tempWards TW 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
							WHERE
							TW.IsValid=1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

						--Villages insert
							SELECT @InsertVillage=COUNT(1) FROM @tempVillages TV 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
							WHERE
							TV.IsValid=1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL
						END
			

					IF @StratergyId=2
						BEGIN
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

			/*========================================================================================================
			COUNTS ENDS
			========================================================================================================*/	
		
			
				IF @DryRun =0
					BEGIN
						BEGIN TRAN UPLOAD

						
			/*========================================================================================================
			UPDATE STARTS
			========================================================================================================*/	
					IF @StratergyId=2
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
									UPDATE L SET  L.LocationName=TR.RegionName
									FROM @tempRegion TR 
									INNER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
									WHERE TR.IsValid=1 AND L.ValidityTo IS NULL

									/********************************REGIONS******************************/
								--Insert historical records
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
										SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
										FROM @tempDistricts TD 
										INNER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
										WHERE TD.IsValid=1 AND L.ValidityTo IS NULL

									--update
										UPDATE L SET L.LocationName=TD.DistrictCode
										FROM @tempDistricts TD 
										INNER JOIN tblLocations L ON L.LocationCode=TD.DistrictCode AND L.LocationType='D'
										WHERE TD.IsValid=1 AND L.ValidityTo IS NULL

										/********************************WARD******************************/
								--Insert historical records
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
										SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
										FROM @tempWards TW 
										INNER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
										WHERE TW.IsValid=1 AND L.ValidityTo IS NULL

								--Update
									UPDATE L SET L.LocationName=TW.WardName
										FROM @tempWards TW 
										INNER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W'
										WHERE TW.IsValid=1 AND L.ValidityTo IS NULL

									  
										/********************************WARD******************************/
								--Insert historical records
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[ValidityTo] ,[LegacyId],[AuditUserId],[MalePopulation] ,[FemalePopulation],[OtherPopulation],[Families])
										SELECT L.LocationCode, L.LocationName,L.ParentLocationId,L.LocationType, L.ValidityFrom,GETDATE(),L.LocationId,@AuditUserId AuditUserId, L.MalePopulation, L.FemalePopulation, L.OtherPopulation,L.Families 
										FROM @tempVillages TV 
										INNER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
										WHERE TV.IsValid=1 AND L.ValidityTo IS NULL

								--Update
									UPDATE L  SET L.LocationName=TV.VillageName, L.MalePopulation=TV.MalePopulation, L.FemalePopulation=TV.FemalePopulation, L.OtherPopulation=TV.OtherPopulation, L.Families=TV.Families
										FROM @tempVillages TV 
										INNER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='V'
										WHERE TV.IsValid=1 AND L.ValidityTo IS NULL

							END
			/*========================================================================================================
			UPDATE ENDS
			========================================================================================================*/	

			/*========================================================================================================
			INSERT STARTS
			========================================================================================================*/	
						IF @StratergyId=1 OR @StratergyId=2
							BEGIN
							
								--insert Region(s)
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[LocationType],[ValidityFrom],[AuditUserId])
									SELECT TR.RegionCode, TR.RegionName,'R',GETDATE(), @AuditUserId AuditUserId FROM @tempRegion TR 
									LEFT OUTER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
									WHERE
									TR.IsValid=1
									AND L.ValidityTo IS NULL
									AND L.LocationCode IS NULL

								--Insert District(s)
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[AuditUserId])
									SELECT TD.DistrictCode, TD.DistrictName, L.LocationId, 'D', GETDATE(), @AuditUserId AuditUserId FROM @tempDistricts TD 
									LEFT OUTER JOIN tblLocations L ON L.LocationCode=TD.RegionCode AND L.LocationType='R'
									WHERE
									TD.IsValid=1
									AND L.ValidityTo IS NULL
									AND L.LocationCode IS NULL

							--Insert Wards
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType],[ValidityFrom],[AuditUserId])
									SELECT TW.WardCode, TW.WardName, L.LocationId, 'W',GETDATE(), @AuditUserId AuditUserId FROM @tempWards TW 
									LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='D'
									WHERE
									TW.IsValid=1
									AND L.ValidityTo IS NULL
									AND L.LocationCode IS NULL


							--insert  villages
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[ParentLocationId],[LocationType], [MalePopulation],[FemalePopulation],[OtherPopulation],[Families], [ValidityFrom],[AuditUserId])
									SELECT TV.VillageCode,TV.VillageName,L.LocationId,'V',TV.MalePopulation,TV.FemalePopulation,TV.OtherPopulation,TV.Families,GETDATE(), @AuditUserId AuditUserId
									FROM @tempVillages TV 
									LEFT OUTER JOIN tblLocations L ON L.LocationCode=TV.VillageCode AND L.LocationType='W'
									WHERE
									TV.IsValid=1
									AND L.ValidityTo IS NULL
									AND L.LocationCode IS NULL

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

IF NOT OBJECT_ID('uspUploadHFXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadHFXML]
GO

CREATE PROCEDURE [dbo].[uspUploadHFXML]
(
	@File NVARCHAR(300),
	@StratergyId INT,	--1	: Insert Only,	2: Insert & Update	3: Insert, Update & Delete
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
	

	DECLARE @Query NVARCHAR(500)
	DECLARE @XML XML
	DECLARE @tblHF TABLE(LegalForms NVARCHAR(15), [Level] NVARCHAR(15)  NULL, SubLevel NVARCHAR(15), Code NVARCHAR (50) NULL, Name NVARCHAR (101) NULL, [Address] NVARCHAR (101), DistrictCode NVARCHAR (50) NULL,Phone NVARCHAR (51), Fax NVARCHAR (51), Email NVARCHAR (51), CareType CHAR (15) NULL, AccountCode NVARCHAR (26), IsValid BIT )
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
	DECLARE @tblCatchment TABLE(HFCode NVARCHAR(50), VillageCode NVARCHAR(50),Percentage INT, IsValid BIT )

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
		FROM @XML.nodes('HealthFacilities/HealthFacilityDetails/HealthFacility') AS T(F)

		SELECT @SentHF=@@ROWCOUNT


		INSERT INTO @tblCatchment(HFCode,VillageCode,Percentage,IsValid)
		SELECT 
		C.CT.value('(HFCode)[1]','NVARCHAR(50)'),
		C.CT.value('(VillageCode)[1]','NVARCHAR(50)'),
		C.CT.value('(Percentage)[1]','INT'),
		1
		FROM @XML.nodes('HealthFacilities/CatchmentDetails/Catchment') AS C(CT)

		SELECT @sentCatchment=@@ROWCOUNT

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

			--Invalidate Catchment with empy HFCode
		IF EXISTS(SELECT  1 FROM @tblCatchment WHERE LEN(ISNULL(HFCode,''))=0)
		INSERT INTO @tblResult(Result,ResultType)
		SELECT  CONVERT(NVARCHAR(3), COUNT(HFCode)) + N' Catchment(s) have empty HFcode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(HFCode,''))=0
		UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(HFCode,''))=0

		--Invalidate Catchment with invalid HFCode
		INSERT INTO @tblResult(Result,ResultType)
		SELECT N'Invalid HF Code ' + QUOTENAME(C.HFCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN @tblHF HF ON C.HFCode=HF.Code WHERE HF.Code IS NULL
		UPDATE C SET C.IsValid =0 FROM @tblCatchment C LEFT OUTER JOIN @tblHF HF ON C.HFCode=HF.Code WHERE HF.Code IS NULL
		
		--Invalidate Catchment with empy VillageCode
		INSERT INTO @tblResult(Result,ResultType)
		SELECT N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section have empty VillageCode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(VillageCode,''))=0
		UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(VillageCode,''))=0

		--Invalidate Catchment with invalid VillageCode
		INSERT INTO @tblResult(Result,ResultType)
		SELECT N'Invalid Village Code ' + QUOTENAME(C.VillageCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL AND LEN(ISNULL(VillageCode,''))>0
		UPDATE C SET IsValid=0 FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL
		
		--Invalidate Catchment with empy percentage
		INSERT INTO @tblResult(Result,ResultType)
		SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has empty percentage', N'E' FROM @tblCatchment WHERE Percentage=0
		UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage=0

		--Invalidate Catchment with invalid percentage
		INSERT INTO @tblResult(Result,ResultType)
		SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has invalid percentage', N'E' FROM @tblCatchment WHERE Percentage<0 OR Percentage >100
		UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage<0 OR Percentage >100


			--Get the counts
			--To be udpated
			IF @StratergyId=2
				BEGIN
					SELECT @Updates=COUNT(1) FROM @tblHF TempHF
					INNER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
					WHERE TempHF.IsValid=1

					SELECT @UpdateCatchment =COUNT(1) FROM @tblCatchment C 
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
			SELECT @Inserts=COUNT(1) FROM @tblHF TempHF
			LEFT OUTER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
			WHERE TempHF.IsValid=1
			AND HF.HFCode IS NULL

			SELECT @InsertCatchment=COUNT(1) FROM @tblCatchment C 
			INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
			INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
			LEFT OUTER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
			WHERE 
			C.IsValid =1
			AND L.ValidityTo IS NULL
			AND HF.ValidityTo IS NULL
			AND HFC.ValidityTo IS NULL
			AND HFC.LocationId IS NULL
			AND HFC.HFID IS NULL
			
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
					UPDATE HF SET HF.HFName = TempHF.Name, HF.LegalForm=TempHF.LegalForms,HF.HFLevel=TempHF.Level, HF.HFSublevel=TempHF.SubLevel,HF.HFAddress=TempHF.Address,HF.LocationId=L.LocationId, HF.Phone=TempHF.Phone, HF.Fax=TempHF.Fax, HF.eMail=TempHF.Email,HF.HFCareType=TempHF.CareType, HF.AccCode=TempHF.AccountCode, HF.OffLine=0, HF.ValidityFrom=GETDATE(), AuditUserID = @AuditUserID
					FROM tblHF HF
					INNER JOIN @tblHF TempHF  ON HF.HFCode=TempHF.Code
					INNER JOIN tblLocations L ON L.LocationCode=TempHF.DistrictCode
					WHERE HF.ValidityTo IS NULL
					AND L.ValidityTo IS NULL
					AND TempHF.IsValid = 1;

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
			UPDATE ENDS
			========================================================================================================*/	


			/*========================================================================================================
			INSERT STARTS
			========================================================================================================*/	

			--INSERT HF
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

--ON 07/04/2018

IF NOT OBJECT_ID('uspUploadHFXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadHFXML]
GO

CREATE PROCEDURE [dbo].[uspUploadHFXML]
(
	@File NVARCHAR(300),
	@StratergyId INT,	--1	: Insert Only,	2: Insert & Update	3: Insert, Update & Delete
	@AuditUserID INT = -1,
	@DryRun BIT=0,
	@SentHF INT = 0 OUTPUT,
	@Inserts INT  = 0 OUTPUT,
	@Updates INT  = 0 OUTPUT
	--@sentCatchment INT =0 OUTPUT,
	--@InsertCatchment INT =0 OUTPUT,
	--@UpdateCatchment INT =0 OUTPUT
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
	DECLARE @tblCatchment TABLE(HFCode NVARCHAR(50), VillageCode NVARCHAR(50),Percentage INT, IsValid BIT )

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
		FROM @XML.nodes('HealthFacilities/HealthFacilityDetails/HealthFacility') AS T(F)

		SELECT @SentHF=@@ROWCOUNT


		INSERT INTO @tblCatchment(HFCode,VillageCode,Percentage,IsValid)
		SELECT 
		C.CT.value('(HFCode)[1]','NVARCHAR(50)'),
		C.CT.value('(VillageCode)[1]','NVARCHAR(50)'),
		C.CT.value('(Percentage)[1]','INT'),
		1
		FROM @XML.nodes('HealthFacilities/CatchmentDetails/Catchment') AS C(CT)

		--SELECT @sentCatchment=@@ROWCOUNT


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

			--Invalidate Catchment with empy HFCode
		IF EXISTS(SELECT  1 FROM @tblCatchment WHERE LEN(ISNULL(HFCode,''))=0)
		INSERT INTO @tblResult(Result,ResultType)
		SELECT  CONVERT(NVARCHAR(3), COUNT(HFCode)) + N' Catchment(s) have empty HFcode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(HFCode,''))=0
		UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(HFCode,''))=0

		--Invalidate Catchment with invalid HFCode
		INSERT INTO @tblResult(Result,ResultType)
		SELECT N'Invalid HF Code ' + QUOTENAME(C.HFCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN @tblHF HF ON C.HFCode=HF.Code WHERE HF.Code IS NULL
		UPDATE C SET C.IsValid =0 FROM @tblCatchment C LEFT OUTER JOIN @tblHF HF ON C.HFCode=HF.Code WHERE HF.Code IS NULL
		
		--Invalidate Catchment with empy VillageCode
		INSERT INTO @tblResult(Result,ResultType)
		SELECT N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section have empty VillageCode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(VillageCode,''))=0
		UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(VillageCode,''))=0

		--Invalidate Catchment with invalid VillageCode
		INSERT INTO @tblResult(Result,ResultType)
		SELECT N'Invalid Village Code ' + QUOTENAME(C.VillageCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL AND LEN(ISNULL(VillageCode,''))>0
		UPDATE C SET IsValid=0 FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL
		
		--Invalidate Catchment with empy percentage
		INSERT INTO @tblResult(Result,ResultType)
		SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has empty percentage', N'E' FROM @tblCatchment WHERE Percentage=0
		UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage=0

		--Invalidate Catchment with invalid percentage
		INSERT INTO @tblResult(Result,ResultType)
		SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has invalid percentage', N'E' FROM @tblCatchment WHERE Percentage<0 OR Percentage >100
		UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage<0 OR Percentage >100


			--Get the counts
			--To be udpated
			IF @StratergyId=2
				BEGIN
					SELECT @Updates=COUNT(1) FROM @tblHF TempHF
					INNER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
					WHERE TempHF.IsValid=1

					--SELECT @UpdateCatchment =COUNT(1) FROM @tblCatchment C 
					--INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					--INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					--INNER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					--WHERE 
					--C.IsValid =1
					--AND L.ValidityTo IS NULL
					--AND HF.ValidityTo IS NULL
					--AND HFC.ValidityTo IS NULL
				END
			
			--To be Inserted
			SELECT @Inserts=COUNT(1) FROM @tblHF TempHF
			LEFT OUTER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
			WHERE TempHF.IsValid=1
			AND HF.HFCode IS NULL

			--SELECT @InsertCatchment=COUNT(1) FROM @tblCatchment C 
			--INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
			--INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
			--LEFT OUTER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
			--WHERE 
			--C.IsValid =1
			--AND L.ValidityTo IS NULL
			--AND HF.ValidityTo IS NULL
			--AND HFC.ValidityTo IS NULL
			--AND HFC.LocationId IS NULL
			--AND HFC.HFID IS NULL
			
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
					UPDATE HF SET HF.HFName = TempHF.Name, HF.LegalForm=TempHF.LegalForms,HF.HFLevel=TempHF.Level, HF.HFSublevel=TempHF.SubLevel,HF.HFAddress=TempHF.Address,HF.LocationId=L.LocationId, HF.Phone=TempHF.Phone, HF.Fax=TempHF.Fax, HF.eMail=TempHF.Email,HF.HFCareType=TempHF.CareType, HF.AccCode=TempHF.AccountCode, HF.OffLine=0, HF.ValidityFrom=GETDATE(), AuditUserID = @AuditUserID
					FROM tblHF HF
					INNER JOIN @tblHF TempHF  ON HF.HFCode=TempHF.Code
					INNER JOIN tblLocations L ON L.LocationCode=TempHF.DistrictCode
					WHERE HF.ValidityTo IS NULL
					AND L.ValidityTo IS NULL
					AND TempHF.IsValid = 1;

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

					--SELECT @UpdateCatchment =@@ROWCOUNT

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
			UPDATE ENDS
			========================================================================================================*/	


			/*========================================================================================================
			INSERT STARTS
			========================================================================================================*/	

			--INSERT HF
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
				
				--SELECT @InsertCatchment=@@ROWCOUNT
				

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

IF NOT OBJECT_ID('uspUploadLocationsXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadLocationsXML]
GO

CREATE PROCEDURE [dbo].[uspUploadLocationsXML]
(
		@File NVARCHAR(500),
		@StratergyId INT,
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

		DECLARE @Query NVARCHAR(500)
		DECLARE @XML XML
		DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
		DECLARE @tempRegion TABLE(RegionCode NVARCHAR(100), RegionName NVARCHAR(100), IsValid BIT )
		DECLARE @tempLocation TABLE(LocationCode NVARCHAR(100))
		DECLARE @tempDistricts TABLE(RegionCode NVARCHAR(100),DistrictCode NVARCHAR(100),DistrictName NVARCHAR(100), IsValid BIT )
		DECLARE @tempWards TABLE(DistrictCode NVARCHAR(100),WardCode NVARCHAR(100),WardName NVARCHAR(100), IsValid BIT )
		DECLARE @tempVillages TABLE(WardCode NVARCHAR(100),VillageCode NVARCHAR(100), VillageName NVARCHAR(100),MalePopulation INT,FemalePopulation INT, OtherPopulation INT, Families INT, IsValid BIT )

		BEGIN TRY
	
			SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

			EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


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
			NULLIF(T.R.value('(WardCode)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(WardName)[1]','NVARCHAR(100)'),''),
			1
			FROM @XML.nodes('Locations/Wards/Ward') AS T(R)
		
			SELECT @SentWard = @@ROWCOUNT

			--GET ALL THE VILLAGES FROM THE XML
			INSERT INTO @tempVillages(WardCode, VillageCode, VillageName, MalePopulation, FemalePopulation, OtherPopulation, Families, IsValid)
			SELECT 
			NULLIF(T.R.value('(WardCode)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(VillageCode)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(VillageName)[1]','NVARCHAR(100)'),''),
			NULLIF(T.R.value('(MalePopulation)[1]','INT'),0),
			NULLIF(T.R.value('(FemalePopulation)[1]','INT'),0),
			NULLIF(T.R.value('(OtherPopulation)[1]','INT'),0),
			NULLIF(T.R.value('(Families)[1]','INT'),0),
			1
			FROM @XML.nodes('Locations/Villages/Village') AS T(R)
		
			SELECT @SentVillage=@@ROWCOUNT


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
		
			/********************************DISTRICT ENDS******************************/

			/********************************WARDS STARTS******************************/
			--check if the ward has districtcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + N' has empty District Code', N'E' FROM @tempWards WHERE  LEN(ISNULL(DistrictCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(DistrictCode,''))=0 

			--check if the ward has valid districtCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + N' has invalid District Code', N'E' FROM @tempWards TW
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
			SELECT  CONVERT(NVARCHAR(3), COUNT(1)) + N' Ward(s) have empty Ward code', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 
		
			--check if the wardname is null 
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + N' has empty name', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardName,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(WardName,''))=0 
		
			--Check for Duplicates in file
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Ward Code ' + QUOTENAME(WardCode) + ' found  ' + CONVERT(NVARCHAR(3), COUNT(WardCode)) + ' times in the file', N'C'  FROM @tempWards GROUP BY WardCode HAVING COUNT(WardCode) >1 
		
			UPDATE W SET IsValid = 0 FROM @tempWards W
			WHERE WardCode in (SELECT WardCode from @tempWards GROUP BY WardCode HAVING COUNT(WardCode) >1)

			--check the length of the wardcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Ward Code ' + QUOTENAME(WardCode) + N' is greater than 50', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardCode,''))>50
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardCode,''))>50

			--check the length of the wardname
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'length of the Ward Name ' + QUOTENAME(WardName) + N' is greater than 50', N'E' FROM @tempWards WHERE  LEN(ISNULL(WardName,''))>50
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardName,''))>50
		
			/********************************WARDS ENDS******************************/

			/********************************VILLAGE STARTS******************************/
			--check if the village has Wardcoce
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has empty Ward Code', N'E' FROM @tempVillages WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempVillages SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 

			--check if the village has valid wardcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has invalid Ward Code', N'E' FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON  TW.WardCode=TV.WardCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TW.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0

			UPDATE TV SET TV.IsValid=0 FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON  TW.WardCode=TV.WardCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TW.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0

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
		
			UPDATE @tempVillages SET IsValid=0  WHERE Families<0

		
			/********************************VILLAGE ENDS******************************/
			/*========================================================================================================
			VALIDATION ENDS
			========================================================================================================*/	
	
			/*========================================================================================================
			COUNTS START
			========================================================================================================*/	
					IF @StratergyId =1 OR @StratergyId =2
						BEGIN
							--Regions insert
							SELECT @InsertRegion=COUNT(1) FROM @tempRegion TR 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
							WHERE
							TR.IsValid=1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

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
			

					IF @StratergyId=2
						BEGIN
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

			/*========================================================================================================
			COUNTS ENDS
			========================================================================================================*/	
		
			
				IF @DryRun =0
					BEGIN
						BEGIN TRAN UPLOAD

						
			/*========================================================================================================
			UPDATE STARTS
			========================================================================================================*/	
					IF @StratergyId=2
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
										UPDATE L SET L.LocationName=TD.DistrictCode, ValidityFrom=GETDATE(),L.AuditUserId=@AuditUserId
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
						IF @StratergyId=1 OR @StratergyId=2
							BEGIN
							
								--insert Region(s)
									INSERT INTO [tblLocations]
										([LocationCode],[LocationName],[LocationType],[ValidityFrom],[AuditUserId])
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

IF NOT OBJECT_ID('uspCleanTables') IS NULL
DROP PROCEDURE [dbo].[uspCleanTables]
GO


CREATE PROCEDURE [dbo].[uspCleanTables]
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
	
	
	--Create Encryption Set
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = '!ExactImis';
	
	CREATE CERTIFICATE EncryptData 
	WITH Subject = 'Encrypt Data';
	
	CREATE SYMMETRIC KEY EncryptionKey
	WITH ALGORITHM = TRIPLE_DES, 
	KEY_SOURCE = 'Exact Key Source',
	IDENTITY_VALUE = 'Exact Identity Value'
	ENCRYPTION BY CERTIFICATE EncryptData
	
	
	--insert new user Admin-Admin
	IF @OffLine = 2  --CHF offline
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 1048576,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0, FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0, DatabaseBackupFolder = ''
        
	END
	
	
	IF @OffLine = 1 --HF offline
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 524288,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0,FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0, DatabaseBackupFolder = ''
        
	END
	IF @OffLine = 0 --ONLINE CREATION NEW COUNTRY NO DEFAULTS KEPT
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 1023,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
		UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0,FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0,				DatabaseBackupFolder = ''
    END
	
	IF @OffLine = -1 --ONLINE CREATION WITH DEFAULTS KEPT AS PREVIOUS CONTENTS
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 1023,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
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

IF NOT OBJECT_ID('uspUploadEnrolmentFromPhone') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
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
		NULLIF(T.F.value('(ConfirmationType)[1]', 'NVARCHAR(3)'), ''),
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
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID AND dt.InsureeId <> I.InsureeID
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
							SELECT I.InsureeId, I.CHFID, @AssociatedPhotoFolder + '\'PhotoFolder, dt.PhotoPath, @OfficerId OfficerId, GETDATE() PhotoDate, GETDATE() ValidityFrom, @AuditUserId AuditUserId
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
								SELECT  I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,I.EffectiveDate, PL.ExpiryDate,PL.AuditUserID,I.isOffline
								FROM @Insuree I
								INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
								WHERE PL.ValidityTo IS NULL
								AND PL.PolicyID = @NewPolicyId
								)

								INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate, EffectiveDate,ExpiryDate,AuditUserId,isOffline)
								SELECT InsureeId, PolicyId, EnrollDate, StartDate,EffectiveDate, ExpiryDate, AuditUserId, isOffline
								FROM IP
								

								IF   EXISTS(SELECT 1 FROM @Premium WHERE isOffline = 1)
								BEGIN
									INSERT INTO tblPremium(PolicyId, PayerId, Amount, Receipt, PayDate, PayType, ValidityFrom, AuditUserId, isOffline, isPhotoFee)
									SELECT  PolicyId, PayerId, Amount, Receipt, PayDate, PayType, GETDATE() ValidityFrom, @AuditUserId AuditUserId, 0 isOffline, isPhotoFee 
									FROM @Premium
									WHERE PolicyId = @NewPolicyId;
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
		IF NOT EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.FamilyId = I.FamilyId
				  WHERE I.ValidityTo IS NULL AND I.IsHead = 1)
			RETURN -1;
		--end added by Amani
		IF EXISTS(SELECT 1 FROM tblInsuree I 
				  INNER JOIN @Insuree dt ON dt.CHFID = I.CHFID AND dt.InsureeId <> I.InsureeID
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
									SELECT @InsureeId = InsureeId, @PhotoFileName = PhotoPath FROM @Insuree WHERE CHFID = @CHFID
									update @Insuree set InsureeId = (select TOP 1 InsureeId from tblInsuree where CHFID = @CHFID and ValidityTo is null)
									where CHFID = @CHFID
									--Insert Insuree History
									INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],						[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
									SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,GETDATE(),InsureeID,[Relationship],[Profession],[Education],[Email] ,[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage] 
									FROM tblInsuree WHERE InsureeID = @InsureeId; 

									--Update Insuree Record
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
								
									UPDATE tblPhotos SET PhotoFolder = @AssociatedPhotoFolder+'\',PhotoFileName = @PhotoFileName, OfficerID = @OfficerID, ValidityFrom = GETDATE(), AuditUserID = @AuditUserID 
									WHERE PhotoID = @PhotoID
								FETCH NEXT FROM CurUpdateInsuree INTO  @CurHFID;
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

--ON 10/04/2018

IF NOT OBJECT_ID('uspSSRSCapitationPayment') IS NULL
DROP PROCEDURE uspSSRSCapitationPayment
GO

CREATE PROCEDURE [dbo].[uspSSRSCapitationPayment]

(
	@RegionId INT = NULL,
	@DistrictId INT = NULL,
	@ProdId INT,
	@Year INT,
	@Month INT,
	@HFLevel xAttributeV READONLY
)
AS
BEGIN
	
	DECLARE @Level1 CHAR(1) = NULL,
			@Sublevel1 CHAR(1) = NULL,
			@Level2 CHAR(1) = NULL,
			@Sublevel2 CHAR(1) = NULL,
			@Level3 CHAR(1) = NULL,
			@Sublevel3 CHAR(1) = NULL,
			@Level4 CHAR(1) = NULL,
			@Sublevel4 CHAR(1) = NULL,
			@ShareContribution DECIMAL(5, 2),
			@WeightPopulation DECIMAL(5, 2),
			@WeightNumberFamilies DECIMAL(5, 2),
			@WeightInsuredPopulation DECIMAL(5, 2),
			@WeightNumberInsuredFamilies DECIMAL(5, 2),
			@WeightNumberVisits DECIMAL(5, 2),
			@WeightAdjustedAmount DECIMAL(5, 2)

	DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'; 
	DECLARE @LastDay DATE = EOMONTH(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01', 0)
	DECLARE @DaysInMonth INT = DATEDIFF(DAY,@FirstDay,DATEADD(MONTH,1,@FirstDay));

	SELECT @Level1 = Level1, @Sublevel1 = Sublevel1, @Level2 = Level2, @Sublevel2 = Sublevel2, @Level3 = Level3, @Sublevel3 = Sublevel3, 
	@Level4 = Level4, @Sublevel4 = Sublevel4, @ShareContribution = ISNULL(ShareContribution, 0), @WeightPopulation = ISNULL(WeightPopulation, 0), 
	@WeightNumberFamilies = ISNULL(WeightNumberFamilies, 0), @WeightInsuredPopulation = ISNULL(WeightInsuredPopulation, 0), @WeightNumberInsuredFamilies = ISNULL(WeightNumberInsuredFamilies, 0), 
	@WeightNumberVisits = ISNULL(WeightNumberVisits, 0), @WeightAdjustedAmount = ISNULL(WeightAdjustedAmount, 0)
	FROM tblProduct Prod 
	WHERE ProdId = @ProdId;


	PRINT @ShareContribution
	PRINT @WeightPopulation
	PRINT @WeightNumberFamilies 
	PRINT @WeightInsuredPopulation 
	PRINT @WeightNumberInsuredFamilies 
	PRINT @WeightNumberVisits 
	PRINT @WeightAdjustedAmount


	;WITH TotalPopFam AS
	(
		SELECT C.HFID  ,
		CASE WHEN ISNULL(@DistrictId, @RegionId) IN (R.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM((ISNULL(L.MalePopulation, 0) + ISNULL(L.FemalePopulation, 0) + ISNULL(L.OtherPopulation, 0)) *(0.01* Catchment))[Population], 
		CASE WHEN ISNULL(@DistrictId, @RegionId) IN (R.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM(ISNULL(((L.Families)*(0.01* Catchment)), 0))TotalFamilies
		FROM tblHFCatchment C
		INNER JOIN tblLocations L ON L.LocationId = C.LocationId
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN tblDistricts D ON HF.LocationId = D.DistrictId
		INNER JOIN tblRegions R ON D.Region = R.RegionId
		WHERE C.ValidityTo IS NULL
		AND L.ValidityTo IS NULL
		AND HF.ValidityTo IS NULL
		GROUP BY C.HFID, D.DistrictId, R.RegionId
	), InsuredInsuree AS
	(
		SELECT HC.HFID, @ProdId ProdId, COUNT(DISTINCT IP.InsureeId)*(0.01 * Catchment) TotalInsuredInsuree
		FROM tblInsureePolicy IP
		INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyId
		INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		INNER JOIN uvwLocations L ON L.LocationId = HC.LocationId
		INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		WHERE HC.ValidityTo IS NULL 
		AND I.ValidityTo IS NULL
		AND IP.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND IP.EffectiveDate <= @LastDay 
		AND IP.ExpiryDate > @LastDay
		AND PL.ProdID = @ProdId
		GROUP BY HC.HFID, Catchment--, L.LocationId
	), InsuredFamilies AS
	(
		SELECT HC.HFID, COUNT(DISTINCT F.FamilyID)*(0.01 * Catchment) TotalInsuredFamilies
		FROM tblInsureePolicy IP
		INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		INNER JOIN uvwLocations L ON L.LocationId = HC.LocationId
		INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		WHERE HC.ValidityTo IS NULL 
		AND I.ValidityTo IS NULL
		AND IP.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND IP.EffectiveDate <= @LastDay 
		AND IP.ExpiryDate > @LastDay
		AND PL.ProdID = @ProdId
		GROUP BY HC.HFID, Catchment--, L.LocationId
	), Claims AS
	(
		SELECT C.HFID,  COUNT(C.ClaimId)TotalClaims
		FROM tblClaim C
		INNER JOIN (
			SELECT ClaimId FROM tblClaimItems WHERE ProdId = @ProdId AND ValidityTo IS NULL
			UNION
			SELECT ClaimId FROM tblClaimServices WHERE ProdId = @ProdId AND ValidityTo IS NULL
			) CProd ON CProd.ClaimID = C.ClaimID
		WHERE C.ValidityTo IS NULL
		AND C.ClaimStatus >= 8
		AND YEAR(C.DateProcessed) = @Year
		AND MONTH(C.DateProcessed) = @Month
		GROUP BY C.HFID
	), ClaimValues AS
	(
		SELECT HFID, @ProdId ProdId, SUM(PriceValuated)TotalAdjusted
		FROM(
		SELECT C.HFID, CValue.PriceValuated
		FROM tblClaim C
		INNER JOIN (
			SELECT ClaimId, PriceValuated FROM tblClaimItems WHERE ValidityTo IS NULL AND ProdId = @ProdId
			UNION ALL
			SELECT ClaimId, PriceValuated FROM tblClaimServices WHERE ValidityTo IS NULL AND ProdId = @ProdId
			) CValue ON CValue.ClaimID = C.ClaimID
		WHERE C.ValidityTo IS NULL
		AND C.ClaimStatus >= 8
		AND YEAR(C.DateProcessed) = @Year
		AND MONTH(C.DateProcessed) = @Month
		)CValue
		GROUP BY HFID
	),Locations AS
	(
		SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId
		UNION
		SELECT LocationId,LocationName, ISNULL(ParentLocationId, 0) FROM tblLocations WHERE ValidityTo IS NULL AND LocationId = ISNULL(@DistrictId, @RegionId)
		UNION ALL
		SELECT L.LocationId, L.LocationName, L.ParentLocationId 
		FROM tblLocations L 
		INNER JOIN Locations ON Locations.LocationId = L.ParentLocationId
		WHERE L.validityTo IS NULL
		AND L.LocationType IN ('R', 'D')
	), Allocation AS
	(
		SELECT ProdId, CAST(SUM(ISNULL(Allocated, 0)) AS DECIMAL(18, 6))Allocated
		FROM
		(SELECT PL.ProdID,
		CASE 
		WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
			THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @FirstDay THEN @FirstDay ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @FirstDay THEN @FirstDay ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
		WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
			THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
		WHEN PL.EffectiveDate < @FirstDay AND PL.ExpiryDate > @LastDay AND PR.PayDate < @FirstDay
			THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
		END Allocated
		FROM tblPremium PR 
		INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
		WHERE PR.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND PL.ProdID = @ProdId
		AND PL.PolicyStatus <> 1
		AND PR.PayDate <= PL.ExpiryDate
		GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate)Alc
		GROUP BY ProdId
	)



	,ReportData AS
	(
		SELECT L.RegionCode, L.RegionName, L.DistrictCode, L.DistrictName, HF.HFCode, HF.HFName, Hf.AccCode, HL.Name HFLevel, SL.HFSublevelDesc HFSublevel,
		PF.[Population] [Population], PF.TotalFamilies TotalFamilies, II.TotalInsuredInsuree, IFam.TotalInsuredFamilies, C.TotalClaims, CV.TotalAdjusted
		,(
			  ISNULL(ISNULL(PF.[Population], 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightPopulation)) /  NULLIF(SUM(PF.[Population])OVER(),0),0)  
			+ ISNULL(ISNULL(PF.TotalFamilies, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberFamilies)) /NULLIF(SUM(PF.[TotalFamilies])OVER(),0),0) 
			+ ISNULL(ISNULL(II.TotalInsuredInsuree, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightInsuredPopulation)) /NULLIF(SUM(II.TotalInsuredInsuree)OVER(),0),0) 
			+ ISNULL(ISNULL(IFam.TotalInsuredFamilies, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberInsuredFamilies)) /NULLIF(SUM(IFam.TotalInsuredFamilies)OVER(),0),0) 
			+ ISNULL(ISNULL(C.TotalClaims, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberVisits)) /NULLIF(SUM(C.TotalClaims)OVER() ,0),0) 
			+ ISNULL(ISNULL(CV.TotalAdjusted, 0) * (Allocation.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightAdjustedAmount)) /NULLIF(SUM(CV.TotalAdjusted)OVER(),0),0)

		) PaymentCathment

		, Allocation.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution) AlcContriPopulation
		, Allocation.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution) AlcContriNumFamilies
		, Allocation.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution) AlcContriInsPopulation
		, Allocation.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution) AlcContriInsFamilies
		, Allocation.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution) AlcContriVisits
		, Allocation.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution) AlcContriAdjustedAmount

		,  ISNULL((Allocation.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution))/ NULLIF(SUM(PF.[Population]) OVER(),0),0) UPPopulation
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution))/NULLIF(SUM(PF.TotalFamilies) OVER(),0),0) UPNumFamilies
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution))/NULLIF(SUM(II.TotalInsuredInsuree) OVER(),0),0) UPInsPopulation
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution))/ NULLIF(SUM(IFam.TotalInsuredFamilies) OVER(),0),0) UPInsFamilies
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution)) / NULLIF(SUM(C.TotalClaims) OVER(),0),0) UPVisits
		,  ISNULL((Allocation.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution))/ NULLIF(SUM(CV.TotalAdjusted) OVER(),0),0) UPAdjustedAmount




		FROM tblHF HF
		INNER JOIN @HFLevel HL ON HL.Code = HF.HFLevel
		LEFT OUTER JOIN tblHFSublevel SL ON SL.HFSublevel = HF.HFSublevel
		INNER JOIN uvwLocations L ON L.LocationId = HF.LocationId
		LEFT OUTER JOIN TotalPopFam PF ON PF.HFID = HF.HfID
		LEFT OUTER JOIN InsuredInsuree II ON II.HFID = HF.HfID
		LEFT OUTER JOIN InsuredFamilies IFam ON IFam.HFID = HF.HfID
		LEFT OUTER JOIN Claims C ON C.HFID = HF.HfID
		LEFT OUTER JOIN ClaimValues CV ON CV.HFID = HF.HfID
		LEFT OUTER JOIN Allocation ON Allocation.ProdID = @ProdId

		WHERE HF.ValidityTo IS NULL
		AND (((L.RegionId = @RegionId OR @RegionId IS NULL) AND (L.DistrictId = @DistrictId OR @DistrictId IS NULL)) OR CV.ProdID IS NOT NULL OR II.ProdId IS NOT NULL)
		AND (HF.HFLevel IN (@Level1, @Level2, @Level3, @Level4) OR (@Level1 IS NULL AND @Level2 IS NULL AND @Level3 IS NULL AND @Level4 IS NULL))
		AND(
			((HF.HFLevel = @Level1 OR @Level1 IS NULL) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		  )

	)



	SELECT  MAX (RegionCode)RegionCode, 
			MAX(RegionName)RegionName,
			MAX(DistrictCode)DistrictCode,
			MAX(DistrictName)DistrictName,
			HFCode, 
			MAX(HFName)HFName,
			MAX(AccCode)AccCode, 
			MAX(HFLevel)HFLevel, 
			MAX(HFSublevel)HFSublevel,
			ISNULL(SUM([Population]),0)[Population],
			ISNULL(SUM(TotalFamilies),0)TotalFamilies,
			ISNULL(SUM(TotalInsuredInsuree),0)TotalInsuredInsuree,
			ISNULL(SUM(TotalInsuredFamilies),0)TotalInsuredFamilies,
			ISNULL(MAX(TotalClaims), 0)TotalClaims,
			ISNULL(SUM(AlcContriPopulation),0)AlcContriPopulation,
			ISNULL(SUM(AlcContriNumFamilies),0)AlcContriNumFamilies,
			ISNULL(SUM(AlcContriInsPopulation),0)AlcContriInsPopulation,
			ISNULL(SUM(AlcContriInsFamilies),0)AlcContriInsFamilies,
			ISNULL(SUM(AlcContriVisits),0)AlcContriVisits,
			ISNULL(SUM(AlcContriAdjustedAmount),0)AlcContriAdjustedAmount,
			ISNULL(SUM(UPPopulation),0)UPPopulation,
			ISNULL(SUM(UPNumFamilies),0)UPNumFamilies,
			ISNULL(SUM(UPInsPopulation),0)UPInsPopulation,
			ISNULL(SUM(UPInsFamilies),0)UPInsFamilies,
			ISNULL(SUM(UPVisits),0)UPVisits,
			ISNULL(SUM(UPAdjustedAmount),0)UPAdjustedAmount,
			ISNULL(SUM(PaymentCathment),0)PaymentCathment,
			ISNULL(SUM(TotalAdjusted),0)TotalAdjusted
	
	 FROM ReportData

	 GROUP BY HFCode



END
GO

--ON 11/04/2018
IF NOT OBJECT_ID('uspUploadHFXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadHFXML]
GO

CREATE PROCEDURE [dbo].[uspUploadHFXML]
(
	@File NVARCHAR(300),
	@StrategyId INT,	--1	: Insert Only,	2: Update Only	3: Insert & Update	7: Insert, Update & Delete
	@AuditUserID INT = -1,
	@DryRun BIT=0,
	@SentHF INT = 0 OUTPUT,
	@Inserts INT  = 0 OUTPUT,
	@Updates INT  = 0 OUTPUT
	--@sentCatchment INT =0 OUTPUT,
	--@InsertCatchment INT =0 OUTPUT,
	--@UpdateCatchment INT =0 OUTPUT
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
	
	DECLARE @Query NVARCHAR(500)
	DECLARE @XML XML
	DECLARE @tblHF TABLE(LegalForms NVARCHAR(15), [Level] NVARCHAR(15)  NULL, SubLevel NVARCHAR(15), Code NVARCHAR (50) NULL, Name NVARCHAR (101) NULL, [Address] NVARCHAR (101), DistrictCode NVARCHAR (50) NULL,Phone NVARCHAR (51), Fax NVARCHAR (51), Email NVARCHAR (51), CareType CHAR (15) NULL, AccountCode NVARCHAR (26),ItemPriceListName NVARCHAR(120),ServicePriceListName NVARCHAR(120), IsValid BIT )
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
	DECLARE @tblCatchment TABLE(HFCode NVARCHAR(50), VillageCode NVARCHAR(50),Percentage INT, IsValid BIT )

	BEGIN TRY
		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

		IF ( @XML.exist('(HealthFacilities/HealthFacilityDetails)')=1)
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
				C.CT.value('(Percentage)[1]','INT'),
				1
				FROM @XML.nodes('HealthFacilities/CatchmentDetails/Catchment') AS C(CT)

				--SELECT @sentCatchment=@@ROWCOUNT
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
			SELECT N'Invalid HF Code ' + QUOTENAME(C.HFCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN @tblHF HF ON C.HFCode=HF.Code WHERE HF.Code IS NULL
			UPDATE C SET C.IsValid =0 FROM @tblCatchment C LEFT OUTER JOIN @tblHF HF ON C.HFCode=HF.Code WHERE HF.Code IS NULL
		
			--Invalidate Catchment with empy VillageCode
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section have empty VillageCode', N'E' FROM @tblCatchment WHERE LEN(ISNULL(VillageCode,''))=0
			UPDATE @tblCatchment SET IsValid = 0 WHERE LEN(ISNULL(VillageCode,''))=0

			--Invalidate Catchment with invalid VillageCode
			INSERT INTO @tblResult(Result,ResultType)
			SELECT N'Invalid Village Code ' + QUOTENAME(C.VillageCode) + N' in catchment section', N'E' FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL AND LEN(ISNULL(VillageCode,''))>0
			UPDATE C SET IsValid=0 FROM @tblCatchment C LEFT OUTER JOIN tblLocations L ON L.LocationCode=C.VillageCode WHERE L.ValidityTo IS NULL AND L.LocationCode IS NULL
		
			--Invalidate Catchment with empy percentage
			INSERT INTO @tblResult(Result,ResultType)
			SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has empty percentage', N'E' FROM @tblCatchment WHERE Percentage=0
			UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage=0

			--Invalidate Catchment with invalid percentage
			INSERT INTO @tblResult(Result,ResultType)
			SELECT  N'HF Code ' + QUOTENAME(HFCode) + N' in catchment section has invalid percentage', N'E' FROM @tblCatchment WHERE Percentage<0 OR Percentage >100
			UPDATE @tblCatchment SET IsValid = 0 WHERE Percentage<0 OR Percentage >100

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(C.VillageCode) + ' fount ' + CAST(COUNT(C.VillageCode) AS NVARCHAR(4)) + ' time(s) in the Catchemnt for the HF Code ' + QUOTENAME(C.HFCode), 'C'
			FROM @tblCatchment C
			GROUP BY C.HFCode, C.VillageCode
			HAVING COUNT(C.VillageCode) > 1;


			UPDATE HF SET IsValid = 0
			FROM @tblHF HF
			INNER JOIN @tblCatchment C ON HF.Code = C.HFCode
			 WHERE C.HFCode IN (
				SELECT C.HFCode
				FROM @tblCatchment C
				GROUP BY C.HFCode
				HAVING COUNT(C.VillageCode) > 1
			 )

			UPDATE C SET IsValid = 0
			FROM @tblCatchment C
			 WHERE C.HFCode IN (
				SELECT C.HFCode
				FROM @tblCatchment C
				GROUP BY C.HFCode
				HAVING COUNT(C.VillageCode) > 1
			 )


			--Get the counts
			--To be udpated
			IF (@StrategyId & @UpdateOnly) > 0
				BEGIN
					SELECT @Updates=COUNT(1) FROM @tblHF TempHF
					INNER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
					WHERE TempHF.IsValid=1

					--SELECT @UpdateCatchment =COUNT(1) FROM @tblCatchment C 
					--INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					--INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					--INNER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					--WHERE 
					--C.IsValid =1
					--AND L.ValidityTo IS NULL
					--AND HF.ValidityTo IS NULL
					--AND HFC.ValidityTo IS NULL
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
							AND  tempHF.IsValid=1
						END

					SELECT @Inserts=COUNT(1) FROM @tblHF TempHF
					LEFT OUTER JOIN tblHF HF ON HF.HFCode=TempHF.Code AND HF.ValidityTo IS NULL
					WHERE TempHF.IsValid=1
					AND HF.HFCode IS NULL

					--SELECT @InsertCatchment=COUNT(1) FROM @tblCatchment C 
					--INNER JOIN tblHF HF ON C.HFCode=HF.HFCode
					--INNER JOIN tblLocations L ON L.LocationCode=C.VillageCode
					--LEFT OUTER JOIN tblHFCatchment HFC ON HFC.LocationId=L.LocationId AND HFC.HFID=HF.HfID
					--WHERE 
					--C.IsValid =1
					--AND L.ValidityTo IS NULL
					--AND HF.ValidityTo IS NULL
					--AND HFC.ValidityTo IS NULL
					--AND HFC.LocationId IS NULL
					--AND HFC.HFID IS NULL
				END
			
		/*========================================================================================================
		VALIDATION ENDS
		========================================================================================================*/	
		IF @DryRun=0
		BEGIN
			BEGIN TRAN UPLOAD
				
			/*========================================================================================================
			UDPATE STARTS
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

					--SELECT @UpdateCatchment =@@ROWCOUNT

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
			UPDATE ENDS
			========================================================================================================*/	


			/*========================================================================================================
			INSERT STARTS
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
				
					--SELECT @InsertCatchment=@@ROWCOUNT
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

IF NOT OBJECT_ID('uspUploadLocationsXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadLocationsXML]
GO

CREATE PROCEDURE [dbo].[uspUploadLocationsXML]
(
		@File NVARCHAR(500),
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
		DECLARE @XML XML
		DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))
		DECLARE @tempRegion TABLE(RegionCode NVARCHAR(100), RegionName NVARCHAR(100), IsValid BIT )
		DECLARE @tempLocation TABLE(LocationCode NVARCHAR(100))
		DECLARE @tempDistricts TABLE(RegionCode NVARCHAR(100),DistrictCode NVARCHAR(100),DistrictName NVARCHAR(100), IsValid BIT )
		DECLARE @tempWards TABLE(DistrictCode NVARCHAR(100),WardCode NVARCHAR(100),WardName NVARCHAR(100), IsValid BIT )
		DECLARE @tempVillages TABLE(WardCode NVARCHAR(100),VillageCode NVARCHAR(100), VillageName NVARCHAR(100),MalePopulation INT,FemalePopulation INT, OtherPopulation INT, Families INT, IsValid BIT )

		BEGIN TRY
	
			SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

			EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT
			
			
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
		
			/********************************DISTRICT ENDS******************************/

			/********************************WARDS STARTS******************************/
			--check if the ward has districtcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Municipality Code ' + QUOTENAME(WardCode) + N' has empty District Code', N'E' FROM @tempWards WHERE  LEN(ISNULL(DistrictCode,''))=0 
		
			UPDATE @tempWards SET IsValid=0  WHERE  LEN(ISNULL(DistrictCode,''))=0 

			--check if the ward has valid districtCode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Municipality Code ' + QUOTENAME(WardCode) + N' has invalid District Code', N'E' FROM @tempWards TW
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
		
			UPDATE @tempWards SET IsValid=0  WHERE LEN(ISNULL(WardName,''))>50
		
			/********************************WARDS ENDS******************************/

			/********************************VILLAGE STARTS******************************/
			--check if the village has Wardcoce
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has empty Municipality Code', N'E' FROM @tempVillages WHERE  LEN(ISNULL(WardCode,''))=0 
		
			UPDATE @tempVillages SET IsValid=0  WHERE  LEN(ISNULL(WardCode,''))=0 

			--check if the village has valid wardcode
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Village Code ' + QUOTENAME(VillageCode) + N' has invalid Municipality Code', N'E' FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON  TW.WardCode=TV.WardCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TW.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0

			UPDATE TV SET TV.IsValid=0 FROM @tempVillages TV
			LEFT OUTER JOIN @tempWards TW ON  TW.WardCode=TV.WardCode
			LEFT OUTER JOIN tblLocations L ON L.LocationCode=TW.WardCode AND L.LocationType='W' 
			WHERE L.ValidityTo IS NULL
			AND L.LocationCode IS NULL
			AND TW.WardCode IS NULL
			AND LEN(TV.WardCode)>0
			AND LEN(TV.VillageCode) >0

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
		
			UPDATE @tempVillages SET IsValid=0  WHERE Families<0

		
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
								WHERE L.ValidityTo IS NULL AND TR.IsValid=1;
							END
							--Regions insert
							SELECT @InsertRegion=COUNT(1) FROM @tempRegion TR 
							LEFT OUTER JOIN tblLocations L ON L.LocationCode=TR.RegionCode AND L.LocationType='R'
							WHERE
							TR.IsValid=1
							AND L.ValidityTo IS NULL
							AND L.LocationCode IS NULL

							--Failed Districts
							IF (@StrategyId = @InsertOnly)
							BEGIN
								INSERT INTO @tblResult(Result, ResultType)
								SELECT 'District Code' + QUOTENAME(TD.DistrictCode) + ' is already exists in database', N'FD'
								FROM @tempDistricts TD
								INNER JOIN tblLocations L ON TD.DistrictCode = L.LocationCode
								WHERE L.ValidityTo IS NULL AND TD.IsValid=1;
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
								WHERE L.ValidityTo IS NULL AND TW.IsValid=1;
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
								WHERE L.ValidityTo IS NULL AND TV.IsValid=1;
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

IF NOT OBJECT_ID('uspUploadDiagnosisXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadDiagnosisXML]
GO

CREATE PROCEDURE [dbo].[uspUploadDiagnosisXML]
(
	@File NVARCHAR(300),
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
	DECLARE @XML XML
	DECLARE @tblDiagnosis TABLE(ICDCode nvarchar(50),  ICDName NVARCHAR(255), IsValid BIT)
	DECLARE @tblDeleted TABLE(Id INT, Code NVARCHAR(8));
	DECLARE @tblResult TABLE(Result NVARCHAR(Max), ResultType NVARCHAR(2))

	BEGIN TRY

		IF @AuditUserID IS NULL
			SET @AuditUserID=-1

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

		IF ( @XML.exist('(Diagnoses/Diagnosis/ICDCode)')=1)
			BEGIN
				--GET ALL THE DIAGNOSES	 FROM THE XML
				INSERT INTO @tblDiagnosis(ICDCode,ICDName, IsValid)
				SELECT 
				T.F.value('(ICDCode)[1]','NVARCHAR(12)'),
				T.F.value('(ICDName)[1]','NVARCHAR(255)'),
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
			SELECT CONVERT(NVARCHAR(3), COUNT(D.ICDCode)) + N' Diagnosis have empty ICD code', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0

			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'ICD Code ' + QUOTENAME(D.ICDCode) + N' has empty name field', N'E'
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDName, '')) = 0


			UPDATE D SET IsValid = 0
			FROM @tblDiagnosis D 
			WHERE LEN(ISNULL(D.ICDCode, '')) = 0 OR LEN(ISNULL(D.ICDName, '')) = 0

			--Check if any ICD Code is greater than 6 characters
			INSERT INTO @tblResult(Result, ResultType)
			SELECT N'Length of the ICD Code ' + QUOTENAME(D.ICDCode) + ' is greater than 6 characters', N'E'
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
					SELECT 'ICD Code '+  QUOTENAME(D.ICDCode) +' already exists in Database',N'FI' FROM @tblDiagnosis D
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



-- MIGRATION FROM 18.1.0 to 1.2.0

UPDATE tblInsuree SET Gender = NULL where Gender = ''
GO

--ON 24/04/2018
IF NOT OBJECT_id('uspUploadEnrolmentFromPhone') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
GO



CREATE PROCEDURE [dbo].[uspUploadEnrolmentFromPhone]
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
							SELECT I.InsureeId, I.CHFID, @AssociatedPhotoFolder + '\'PhotoFolder, dt.PhotoPath, @OfficerId OfficerId, GETDATE() PhotoDate, GETDATE() ValidityFrom, @AuditUserId AuditUserId
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
								
									UPDATE tblPhotos SET PhotoFolder = @AssociatedPhotoFolder+'\',PhotoFileName = @PhotoFileName, OfficerID = @OfficerID, ValidityFrom = GETDATE(), AuditUserID = @AuditUserID 
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


/*====================================================================================================================
SCRIPT TO CHANGE FROM 18.0.0 TO 18.1.0
====================================================================================================================*/

--ON 10/05/2018

IF OBJECT_ID(N'tblGender') IS NULL
BEGIN
	CREATE TABLE tblGender
	(
		Code CHAR(1) NOT NULL CONSTRAINT PK_tblGender PRIMARY KEY,
		Gender NVARCHAR(50),
		AltLanguage NVARCHAR(50),
		SortOrder INT
	)

	INSERT INTO tblGender(Code, Gender,SortOrder) VALUES
	(N'M', N'Male',1),
	(N'F', N'Female',2),
	(N'O', N'Other',3)

END
GO


IF OBJECT_ID(N'FK_tblInsuree_tblGender') IS NULL
ALTER TABLE tblInsuree
ADD CONSTRAINT FK_tblInsuree_tblGender FOREIGN KEY(Gender) REFERENCES tblGender(Code)
GO

IF NOT OBJECT_ID('uspCleanTables') IS NULL
DROP PROCEDURE [dbo].[uspCleanTables]
GO

CREATE PROCEDURE [dbo].[uspCleanTables]
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
	
	
	--Create Encryption Set
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = '!ExactImis';
	
	CREATE CERTIFICATE EncryptData 
	WITH Subject = 'Encrypt Data';
	
	CREATE SYMMETRIC KEY EncryptionKey
	WITH ALGORITHM = TRIPLE_DES, 
	KEY_SOURCE = 'Exact Key Source',
	IDENTITY_VALUE = 'Exact Identity Value'
	ENCRYPTION BY CERTIFICATE EncryptData
	
	
	--insert new user Admin-Admin
	IF @OffLine = 2  --CHF offline
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 1048576,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0, FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0, DatabaseBackupFolder = ''
        
	END
	
	
	IF @OffLine = 1 --HF offline
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 524288,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
        UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0,FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0, DatabaseBackupFolder = ''
        
	END
	IF @OffLine = 0 --ONLINE CREATION NEW COUNTRY NO DEFAULTS KEPT
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 1023,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
		UPDATE tblIMISDefaults SET OffLineHF = 0,OfflineCHF = 0,FTPHost = '',FTPUser = '', FTPPassword = '',FTPPort = 0,FTPClaimFolder = '',FtpFeedbackFolder = '',FTPPolicyRenewalFolder = '',FTPPhoneExtractFolder = '',FTPOfflineExtractFolder = '',AppVersionEnquire = 0,AppVersionEnroll = 0,AppVersionRenewal = 0,AppVersionFeedback = 0,AppVersionClaim = 0, AppVersionImis = 0,				DatabaseBackupFolder = ''
    END
	
	IF @OffLine = -1 --ONLINE CREATION WITH DEFAULTS KEPT AS PREVIOUS CONTENTS
	BEGIN
		OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData
        INSERT INTO tblUsers ([LastName],[OtherNames],[Phone],[LoginName],[Password],[RoleID],[LanguageID],[HFID],[AuditUserID])
        VALUES('Admin', 'Admin', '', 'Admin', ENCRYPTBYKEY(KEY_GUID('EncryptionKey'),N'Admin'), 1023,'en',0,0)
        CLOSE SYMMETRIC KEY EncryptionKey
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

IF NOT EXISTS(SELECT 1 FROM tblControls WHERE FieldName = N'GuaranteeNo')
INSERT INTO tblControls(FieldName, Adjustibility, Usage) VALUES(N'GuaranteeNo', N'O', N'Claim, ClaimReview')
GO

--ON 11/05/2018



IF NOT OBJECT_ID('uspImportOffLineExtract3') IS NULL
DROP PROCEDURE [dbo].[uspImportOffLineExtract3]
GO


IF NOT TYPE_ID('xGender') IS NULL
DROP TYPE [dbo].[xGender]
GO


CREATE TYPE [dbo].[xGender] AS TABLE(
	[Code] [char](1)  NULL,
	[Gender] [nvarchar](50) NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL
)
GO



CREATE PROCEDURE [dbo].[uspImportOffLineExtract3]
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


IF NOT OBJECT_ID('uspExportOffLineExtract3') IS NULL
DROP PROCEDURE [dbo].[uspExportOffLineExtract3]
GO

CREATE PROCEDURE [dbo].[uspExportOffLineExtract3]
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

IF NOT OBJECT_ID('uspUpdateClaimFromPhone') IS NULL
DROP PROCEDURE uspUpdateClaimFromPhone
GO

CREATE PROCEDURE [dbo].[uspUpdateClaimFromPhone]
(
	@FileName NVARCHAR(255),
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

	DECLARE @XML XML
	
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
	
	BEGIN TRY
		
			IF NOT OBJECT_ID('tempdb..#tblItem') IS NULL DROP TABLE #tblItem
			CREATE TABLE #tblItem(ItemCode NVARCHAR(6),ItemPrice DECIMAL(18,2), ItemQuantity INT)

			IF NOT OBJECT_ID('tempdb..#tblService') IS NULL DROP TABLE #tblService
			CREATE TABLE #tblService(ServiceCode NVARCHAR(6),ServicePrice DECIMAL(18,2), ServiceQuantity INT)

			SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK '''+ @FileName +''',SINGLE_BLOB) AS T(X)')
			
			EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT

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



--ON 2018-05-16 17:22:00.417
IF NOT OBJECT_ID('udfGetSnapshotIndicators') IS NULL
DROP FUNCTION [dbo].[udfGetSnapshotIndicators]
GO

CREATE FUNCTION [dbo].[udfGetSnapshotIndicators](
	@Date DATE, 
	@OfficerId INT
) RETURNS @tblSnapshotIndicators TABLE(ACtive INT,Expired INT,Iddle INT,Suspended INT)
	AS
	BEGIN
		DECLARE @ACtive INT=0
		DECLARE @Expired INT=0
		DECLARE @Iddle INT=0
		DECLARE @Suspended INT=0

		SET @ACtive = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=2 AND  EffectiveDate = @Date )
		SET @Expired = (SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			AND  PL.PolicyStatus = 2
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate =@Date)
			AND PL.OfficerID = @OfficerId
			)
		SET @Iddle = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=1 AND  EnrollDate = @Date )
		SET @Suspended = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=4 AND  EnrollDate = @Date )
		INSERT INTO @tblSnapshotIndicators(ACtive, Expired, Iddle, Suspended) VALUES (@ACtive, @Expired, @Iddle, @Suspended)
		  RETURN
	END

GO

IF NOT OBJECT_ID('udfCollectedContribution') IS NULL
DROP FUNCTION [dbo].[udfCollectedContribution]
GO


CREATE FUNCTION [dbo].[udfCollectedContribution](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS DECIMAL(18,2)
AS
BEGIN
      RETURN(
	  SELECT SUM(Amount)  FROM tblPremium PR
INNER JOIN tblPolicy PL ON PL.PolicyID=PR.PolicyID
WHERE 
PL.ValidityTo IS NULL
AND PR.ValidityTo IS NULL
AND PayDate >= @DateTo
AND PayDate <=@DateTo
AND PL.OfficerID=@OfficerId
	  )
END

GO


IF NOT OBJECT_ID('udfExpiredPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfExpiredPoliciesPhoneStatistics]
GO

CREATE FUNCTION [dbo].[udfExpiredPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
      RETURN(
			SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate >= @DateFrom AND PL.ExpiryDate < = @DateTo)
			AND PL.OfficerID = @OfficerId
	  )
END


GO


IF NOT OBJECT_ID('udfNewPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfNewPoliciesPhoneStatistics]
GO
CREATE FUNCTION [dbo].[udfNewPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
      RETURN(
	  SELECT COUNT(1)  
	  FROM 
	  tblPolicy 
	  WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStage ='N' AND EnrollDate >= @DateFrom AND EnrollDate <=@DateTo
	  )
END


GO

IF NOT OBJECT_ID('udfRenewedPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfRenewedPoliciesPhoneStatistics]
GO


CREATE FUNCTION [dbo].[udfRenewedPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
      RETURN(
	  SELECT COUNT(1)  FROM 
	  tblPolicy 
	  WHERE 
	  ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStage ='R' AND EnrollDate >= @DateFrom AND EnrollDate <=@DateTo
	  )
END


GO


IF NOT OBJECT_ID('udfSuspendedPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfSuspendedPoliciesPhoneStatistics]
GO

CREATE FUNCTION [dbo].[udfSuspendedPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
      RETURN(
		SELECT  COUNT(1) SuspendedPolicies
		FROM tblPolicy PL 
		WHERE PL.ValidityTo IS NULL
		AND PL.PolicyStatus = 4
		AND (ExpiryDate >= @DateFrom AND ExpiryDate < = @DateTo)
		AND PL.OfficerID = @OfficerId
	  )
END


GO

--ON 2018-05-17 18:01:03.460
	IF NOT OBJECT_ID('uspUploadEnrolmentsFromOfflinePhone') IS NULL
	DROP PROCEDURE uspUploadEnrolmentsFromOfflinePhone
	GO

	CREATE PROCEDURE uspUploadEnrolmentsFromOfflinePhone(
	@File NVARCHAR(300),
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
	DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT, NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)

	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)

	BEGIN TRY

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


		--GET ALL THE FAMILY FROM THE XML
		INSERT INTO @tblFamilies(FamilyId,InsureeId,CHFID, LocationId,Poverty,FamilyType,FamilyAddress,Ethnicity, ConfirmationNo)
		SELECT 
		T.F.value('(FamilyId)[1]','INT'),
		T.F.value('(InsureeId)[1]','INT'),
		T.F.value('(HOFCHFID)[1]','NVARCHAR(12)'),
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
		INSERT INTO @tblInsuree(InsureeId,FamilyId,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Passport,Phone,CardIssued,Relationship,Profession,Education,Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurVillage, isOffline)
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
		NULLIF(T.I.value('(Relationship)[1]','SMALLINT'),0),
		NULLIF(T.I.value('(Profession)[1]','SMALLINT'),0),
		NULLIF(T.I.value('(Education)[1]','SMALLINT'),0),
		T.I.value('(Email)[1]','NVARCHAR(100)'),
		T.I.value('(TypeOfId)[1]','NVARCHAR(1)'),
		NULLIF(T.I.value('(HFID)[1]','INT'),0),
		T.I.value('(CurrentAddress)[1]','NVARCHAR(200)'),
		T.I.value('(GeoLocation)[1]','NVARCHAR(200)'),
		NULLIF(T.I.value('(CurVillage)[1]','INT'),0),
		T.I.value('(isOffline)[1]','BIT')
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

		DECLARE @AuditUserId INT =-2

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
		WHERE FT.FamilyType IS NULL

		UNION ALL

		---Invalid IdentificationType
		SELECT 1 FROM @tblInsuree I
		LEFT OUTER JOIN tblIdentificationTypes IT ON I.TypeOfId = IT.IdentificationCode
		WHERE IT.IdentificationCode IS NULL
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h1 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h1>')
		
			RAISERROR (N'<h1 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h1>', 16, 1);
		END


		--SELECT * FROM @tblFamilies
		SELECT * FROM @tblInsuree
		--SELECT * FROM @tblPolicy
		--SELECT * FROM @tblPremium

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
				DECLARE @FamilyId INT = 0,
				@HOFId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@ProdId INT,
				@PolicyStage CHAR(1),
				@EnrollDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId TINYINT,
				@GivenPolicyValue DECIMAL(18, 4),
				@ContributionAmount DECIMAL(18, 4),
				@Active TINYINT=2,
				@Idle TINYINT=1


			DECLARE CurPolicies CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, EnrollDate, PolicyStatus, PolicyValue, FamilyId FROM @tblPolicy 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @GivenPolicyValue, @FamilyId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollDate, 0, @ErrorCode OUTPUT;
				SELECT @EffectiveDate=EffectiveDate FROM @tblPolicy WHERE PolicyId=@PolicyId
					IF (@GivenPolicyValue >= @PolicyValue)
						BEGIN
							SELECT @PolicyStatus = PolicyStatus FROM @tblPolicy WHERE PolicyId=@PolicyId
						END
					ELSE
						BEGIN
							SELECT @ContributionAmount = SUM(Amount)  FROM @tblPremium WHERE PolicyId=@PolicyId
							IF @ContributionAmount >= @PolicyValue
								SELECT @PolicyStatus = @Active
							ELSE
								SELECT @PolicyStatus = @Idle
								SELECT @EffectiveDate = NULL
						END

						--INSERTING POLICY

						INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID)
						SELECT	 NewFamilyID,EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),@AuditUserId FROM @tblPolicy WHERE PolicyId=@PolicyId
						INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, SCOPE_IDENTITY())

				IF @@ROWCOUNT > 0
				SET @PolicyImported = @PolicyImported +1

				FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @GivenPolicyValue, @FamilyId;
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
						(N'<h1 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h1>')
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


IF NOT OBJECT_ID('udfGetSnapshotIndicators') IS NULL
DROP FUNCTION [dbo].[udfGetSnapshotIndicators]
GO

CREATE FUNCTION [dbo].[udfGetSnapshotIndicators](
	@Date DATE, 
	@OfficerId INT
) RETURNS @tblSnapshotIndicators TABLE(ACtive INT,Expired INT,Idle INT,Suspended INT)
	AS
	BEGIN
		DECLARE @ACtive INT=0
		DECLARE @Expired INT=0
		DECLARE @Idle INT=0
		DECLARE @Suspended INT=0

		SET @ACtive = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=2 AND  EffectiveDate = @Date )
		SET @Expired = (SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			AND  PL.PolicyStatus = 2
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate =@Date)
			AND PL.OfficerID = @OfficerId
			)
		SET @Idle = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=1 AND  EnrollDate = @Date )
		SET @Suspended = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=4 AND  EnrollDate = @Date )
		INSERT INTO @tblSnapshotIndicators(ACtive, Expired, Idle, Suspended) VALUES (@ACtive, @Expired, @Idle, @Suspended)
		  RETURN
	END


GO


--ON 2018-05-18 11:10:33.263
IF NOT OBJECT_ID('udfCollectedContribution') IS NULL
DROP FUNCTION [dbo].[udfCollectedContribution]
GO

	
CREATE FUNCTION [dbo].[udfCollectedContribution](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS DECIMAL(18,2)
AS
BEGIN
      RETURN(
	  SELECT SUM(Amount)  FROM tblPremium PR
INNER JOIN tblPolicy PL ON PL.PolicyID=PR.PolicyID
WHERE 
PL.ValidityTo IS NULL
AND PR.ValidityTo IS NULL
AND PayDate >= @DateFrom
AND PayDate <=@DateTo
AND PL.OfficerID=@OfficerId
	  )
END


GO




--ON 2018-05-21 16:57:38.887

IF NOT OBJECT_ID('uspUploadEnrolmentsFromOfflinePhone') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone]
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone](
	@File NVARCHAR(300),
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
	DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT,PhotoPath NVARCHAR(100), NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)

	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)

	BEGIN TRY

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


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
		--SELECT * INTO tempPremium FROM @tblPremium
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

			--Insert Photos
			INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
			SELECT NewInsureeId,CHFID,@AssociatedPhotoFolder + '\'PhotoFolder, PhotoPath,0,GETDATE(),GETDATE() ValidityFrom, @AuditUserId AuditUserID 
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
				@EnrollDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId TINYINT,
				@GivenPolicyValue DECIMAL(18, 4),
				@ContributionAmount DECIMAL(18, 4),
				@Active TINYINT=2,
				@Idle TINYINT=1


			DECLARE CurPolicies CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, EnrollDate, PolicyStatus, PolicyValue, NewFamilyId FROM @tblPolicy 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @GivenPolicyValue, @FamilyId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollDate, 0, @ErrorCode OUTPUT;
				SELECT @EffectiveDate=EffectiveDate FROM @tblPolicy WHERE PolicyId=@PolicyId
					IF (@GivenPolicyValue >= @PolicyValue)
						BEGIN
							SELECT @PolicyStatus = PolicyStatus FROM @tblPolicy WHERE PolicyId=@PolicyId
						END
					ELSE
						BEGIN
							SELECT @ContributionAmount = SUM(Amount)  FROM @tblPremium WHERE PolicyId=@PolicyId
							IF @ContributionAmount >= @PolicyValue
								SELECT @PolicyStatus = @Active
							ELSE
								SELECT @PolicyStatus = @Idle
								SELECT @EffectiveDate = NULL
						END

						--INSERTING POLICY

						INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID)
						SELECT	 NewFamilyID,EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,@PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),@AuditUserId FROM @tblPolicy WHERE PolicyId=@PolicyId
						INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, SCOPE_IDENTITY())

				IF @@ROWCOUNT > 0
				SET @PolicyImported = ISNULL(@PolicyImported,0) +1

				FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @GivenPolicyValue, @FamilyId;
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
						(N'<h1 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h1>')
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

IF NOT OBJECT_ID('udfGetSnapshotIndicators') IS NULL
DROP FUNCTION [dbo].[udfGetSnapshotIndicators]
GO


CREATE FUNCTION [dbo].[udfGetSnapshotIndicators](
	@Date DATE, 
	@OfficerId INT
) RETURNS @tblSnapshotIndicators TABLE(ACtive INT,Expired INT,Idle INT,Suspended INT)
	AS
	BEGIN
		DECLARE @ACtive INT=0
		DECLARE @Expired INT=0
		DECLARE @Idle INT=0
		DECLARE @Suspended INT=0

		SET @ACtive = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=2 AND  EffectiveDate = @Date )
		SET @Expired = (SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			AND  PL.PolicyStatus = 2
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate =@Date)
			AND PL.OfficerID = @OfficerId
			)
		SET @Idle = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=1 AND  EnrollDate = @Date )
		SET @Suspended = (SELECT COUNT(1) FROM  tblPolicy WHERE ValidityTo IS NULL AND OfficerID=@OfficerId AND PolicyStatus=4 AND  EnrollDate = @Date )
		INSERT INTO @tblSnapshotIndicators(ACtive, Expired, Idle, Suspended) VALUES (@ACtive, @Expired, @Idle, @Suspended)
		  RETURN
	END



GO



--ON 2018-05-22 17:48:11.473

IF NOT OBJECT_ID ('uspUploadEnrolmentsFromOfflinePhone') IS NULL
DROP PROCEDURE uspUploadEnrolmentsFromOfflinePhone
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone](
	@File NVARCHAR(300),
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
	DECLARE @XML XML
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT,PhotoPath NVARCHAR(100), NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblInureePolicy TABLE(PolicyId INT,InsureeId INT,EffectiveDate DATE, NewInsureeId INT, NewPolicyId INT)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, NewPolicyId INT)

	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	DECLARE @tblIds TABLE(OldId INT, [NewId] INT)

	BEGIN TRY

		SET @Query = (N'SELECT @XML = CAST(X as XML) FROM OPENROWSET(BULK  '''+ @File +''' ,SINGLE_BLOB) AS T(X)')

		EXECUTE SP_EXECUTESQL @Query,N'@XML XML OUTPUT',@XML OUTPUT


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
			SELECT NewInsureeId,CHFID,@AssociatedPhotoFolder + '\'PhotoFolder, PhotoPath,0,GETDATE(),GETDATE() ValidityFrom, @AuditUserId AuditUserID 
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


			DECLARE CurPolicies CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, EnrollDate, PolicyStatus, PolicyValue, NewFamilyId FROM @tblPolicy 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
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
							([InsureeId],[PolicyId],[EnrollmentDate],[StartDate],[EffectiveDate],[ExpiryDate],[ValidityFrom],[AuditUserId]) SELECT
							 NewInsureeId,IP.NewPolicyId,P.[EnrollDate],P.[StartDate],IP.[EffectiveDate],P.[ExpiryDate],GETDATE(),@AuditUserId FROM @tblInureePolicy IP
							 INNER JOIN @tblPolicy P ON IP.PolicyId=P.PolicyId WHERE P.PolicyId=@PolicyId
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

				

				FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
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


			--TODO: Insert the InsureePolicy Table 
			--Create a cursor and loop through each new insuree 
	
			
	
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
						(N'<h1 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h1>')
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





--------************************FIXING PROCEDURES FOR VER 18.0.0 ON 29/05 TO 31/05/2018******************-------------





IF NOT OBJECT_ID('uspIsValidRenewal') IS NULL
DROP PROCEDURE [dbo].[uspIsValidRenewal]
GO
CREATE PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(200),
	@XML XML
)
AS
BEGIN

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
	
	--SELECT @FilePath = 'C:/inetpub/wwwroot/IMIS' + FTPPolicyRenewalFolder + '/' + @FileName FROM tblIMISDefaults
	
	--SET @Query =  (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')

	--EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
	
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


	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;


	DECLARE @Tbl TABLE(Id INT)

	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
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

	SELECT TOP 1 @ProdId = tblPolicy.ProdID, @ExpiryDate = tblPolicy.ExpiryDate from tblPolicy INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID WHERE FamilyID = @FamilyID AND tblProduct.ProductCode = @ProductCode AND tblProduct.ValidityTo IS NULL ORDER BY ExpiryDate DESC
	
	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	IF @LastRenewalDate < @Date
		RETURN -2
	
	SELECT @RecordCount = COUNT(1) FROM @Tbl;
	
	IF @RecordCount = 2
	BEGIN
		IF @Discontinue = 'false' OR @Discontinue = N''
			BEGIN

				--Get policy period
				DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)

				INSERT INTO @tblPeriod
				EXEC uspGetPolicyPeriod @ProdId, @ExpiryDate, @HasCycle OUTPUT;

				DECLARE @ExpiryDatePreviousPolicy DATE
				SELECT @ExpiryDatePreviousPolicy = ExpiryDate FROM tblPolicy WHERE PolicyID=@PreviousPolicyId AND ValidityTo IS NULL
				SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				IF @StartDate < @ExpiryDatePreviousPolicy
					UPDATE @tblPeriod SET StartDate=DATEADD(DAY, 1, @ExpiryDatePreviousPolicy)
				

				IF @HasCycle = 1
					SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				ELSE
					SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;


				DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
				DECLARE @PolicyValue DECIMAL(18,2) 
				--EXEC @PolicyValue = uspPolicyValue 0, 0,@FamilyID, @ProdId,@Date, 
				EXEC @PolicyValue = uspPolicyValue
										@FamilyId = @FamilyID,
										@ProdId = @ProdId,
										@EnrollDate = @Date,
										@PreviousPolicyId = @PreviousPolicyId,
										@PolicyStage = 'R';
		
				DECLARE @PolicyStatus TINYINT = 2
		
				IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
				INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
								VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
				DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
		
				INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
								Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
				

				INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,AuditUserId,isOffline)
				SELECT I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,PL.EffectiveDate,PL.ExpiryDate,PL.AuditUserID,I.isOffline 
				FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID 
				WHERE(I.ValidityTo Is NULL) 
				AND PL.ValidityTo IS NULL 
				AND PL.PolicyID = @PolicyId;

				UPDATE tblPolicyRenewals SET ResponseStatus = 1, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId;
			END
		ELSE
			BEGIN
				UPDATE tblPolicyRenewals SET ResponseStatus = 2, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId
			END

		UPDATE tblFromPhone SET DocStatus = N'A' WHERE FromPhoneId = @FromPhoneId;
		
		SELECT * FROM @Tbl;
	END
END

GO

IF NOT OBJECT_ID('uspInsertFeedback') IS NULL
DROP PROCEDURE [dbo].[uspInsertFeedback]
GO
CREATE PROCEDURE [dbo].[uspInsertFeedback]
(
	@XML XML
	--@FileName VARCHAR(100)
)
/*
	-1: Fatal Error
	0: All OK
	1: Invalid Officer code
	2: Claim does not exist
	3: Invalid CHFID
	
*/
AS
BEGIN
	
	BEGIN TRY
		--DECLARE @FilePath NVARCHAR(250)
		--DECLARE @XML XML
		DECLARE @Query NVARCHAR(3000)
		
		DECLARE @OfficerCode NVARCHAR(8)
		DECLARE @OfficerID INT
		DECLARE @ClaimID INT
		DECLARE @CHFID VARCHAR(12)
		DECLARE @Answers VARCHAR(5)
		DECLARE @FeedbackDate DATE
		
		--SELECT @FilePath = 'C:/inetpub/wwwroot' + FTPFeedbackFolder + '/' + @FileName FROM tblIMISDefaults
				
		--SET @Query = (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')
		
		--EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
		
		SELECT
		@OfficerCode = feedback.value('(Officer)[1]','NVARCHAR(8)'),
		@ClaimID = feedback.value('(ClaimID)[1]','NVARCHAR(8)'),
		@CHFID  = feedback.value('(CHFID)[1]','VARCHAR(12)'),
		@Answers = feedback.value('(Answers)[1]','VARCHAR(5)'),
		@FeedbackDate = CONVERT(DATE,feedback.value('(Date)[1]','VARCHAR(10)'),103)
		FROM @XML.nodes('feedback') AS T(feedback)


		IF NOT EXISTS(SELECT * FROM tblOfficer WHERE Code = @OfficerCode AND ValidityTo IS NULL)
			RETURN 1
		ELSE
			SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @OfficerCode AND ValidityTo IS NULL

		IF NOT EXISTS(SELECT * FROM tblClaim WHERE ClaimID = @ClaimID)
			RETURN 2
		
		IF NOT EXISTS(SELECT C.ClaimID FROM tblClaim C INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID WHERE C.ClaimID = @ClaimID AND I.CHFID = @CHFID)
			RETURN 3
		
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

IF NOT OBJECT_ID('uspUpdateClaimFromPhone') IS NULL
DROP PROCEDURE [dbo].[uspUpdateClaimFromPhone]
GO
CREATE PROCEDURE [dbo].[uspUpdateClaimFromPhone]
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


IF NOT OBJECT_ID('uspUploadEnrolments') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolments]
GO



CREATE PROCEDURE [dbo].[uspUploadEnrolments](
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

		--SELECT * INTO tempFamilies FROM @tblFamilies
		--SELECT * INTO tempInsuree FROM @tblInsuree
		--SELECT * INTO tempPolicy FROM @tblPolicy
		--SELECT * INTO tempPremium FROM @tblPremium
		--RETURN
		--DECLARE @AuditUserId INT 
		--	IF ( @XML.exist('(Enrolment/UserId)')=1 )
		--		SET	@AuditUserId= (SELECT T.PR.value('(UserId)[1]','INT') FROM @XML.nodes('Enrolment/UserId') AS T(PR))
		--	ELSE
		--		SET @AuditUserId=-1
		
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

			--Delete existing families from temp table, we don't need them anymore
			DELETE FROM @tblFamilies WHERE NewFamilyId IS NOT NULL;


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
			USING @tblInsuree TI ON 1 = 0
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
						(N'<h1 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h1>')
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



IF NOT OBJECT_ID ('uspUploadEnrolmentsFromOfflinePhone') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone]
GO



CREATE PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone](
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
			SELECT NewInsureeId,CHFID,@AssociatedPhotoFolder + '\'PhotoFolder, PhotoPath,0,GETDATE(),GETDATE() ValidityFrom, @AuditUserId AuditUserID 
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


			DECLARE CurPolicies CURSOR FOR SELECT PolicyId, ProdId, ISNULL(PolicyStage, N'N') PolicyStage, EnrollDate, PolicyStatus, PolicyValue, NewFamilyId FROM @tblPolicy 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
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
							([InsureeId],[PolicyId],[EnrollmentDate],[StartDate],[EffectiveDate],[ExpiryDate],[ValidityFrom],[AuditUserId]) SELECT
							 NewInsureeId,IP.NewPolicyId,P.[EnrollDate],P.[StartDate],IP.[EffectiveDate],P.[ExpiryDate],GETDATE(),@AuditUserId FROM @tblInureePolicy IP
							 INNER JOIN @tblPolicy P ON IP.PolicyId=P.PolicyId WHERE P.PolicyId=@PolicyId
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

				

				FETCH NEXT FROM CurPolicies INTO @PolicyId, @ProdId, @PolicyStage, @EnrollDate, @PolicyStatus, @PolicyValueFromPhone, @FamilyId;
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


			--TODO: Insert the InsureePolicy Table 
			--Create a cursor and loop through each new insuree 
	
			
	
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
						(N'<h1 style="color:red;">Double HOF Found. <br />Please contact your IT manager for further assistant.</h1>')
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



IF NOT OBJECT_ID ('uspUploadDiagnosisXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadDiagnosisXML]
GO


CREATE PROCEDURE [dbo].[uspUploadDiagnosisXML]
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


IF NOT OBJECT_ID ('uspUploadHFXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadHFXML]
GO

CREATE PROCEDURE [dbo].[uspUploadHFXML]
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


IF NOT OBJECT_ID ('uspUploadLocationsXML') IS NULL
DROP PROCEDURE [dbo].[uspUploadLocationsXML]
GO

CREATE PROCEDURE [dbo].[uspUploadLocationsXML]
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





IF NOT OBJECT_ID('uspUploadEnrolments') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolments]
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolments](
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


--ON 2018-06-01 12:21:33.553

IF NOT OBJECT_ID('uspUploadEnrolmentsFromOfflinePhone') IS NULL
DROP PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone]
GO

CREATE PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone](
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
			SELECT NewInsureeId,CHFID,@AssociatedPhotoFolder + '\'PhotoFolder, PhotoPath,0,GETDATE(),GETDATE() ValidityFrom, @AuditUserId AuditUserID 
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


--ON 2018-06-06 17:44:39.043

IF NOT OBJECT_ID('uspIsValidRenewal') IS NULL
DROP PROCEDURE [dbo].[uspIsValidRenewal]
GO

CREATE PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(200),
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
	
	--SELECT @FilePath = 'C:/inetpub/wwwroot/IMIS' + FTPPolicyRenewalFolder + '/' + @FileName FROM tblIMISDefaults
	
	--SET @Query =  (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')

	--EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
	
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
	SELECT @DocStatus = FP.DocStatus FROM tblFromPhone FP
	INNER JOIN tblPolicyRenewals R ON R.PolicyID = (SELECT PolicyId FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId)
	WHERE OfficerCode = @Officer AND CHFID = @CHFID
	
	IF @DocStatus ='R'
		RETURN -3
	ELSE IF @DocStatus ='A'
		RETURN -4

	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;


	DECLARE @Tbl TABLE(Id INT)

	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
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

	SELECT TOP 1 @ProdId = tblPolicy.ProdID, @ExpiryDate = tblPolicy.ExpiryDate from tblPolicy INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID WHERE FamilyID = @FamilyID AND tblProduct.ProductCode = @ProductCode AND tblProduct.ValidityTo IS NULL ORDER BY ExpiryDate DESC
	
	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	IF @LastRenewalDate < @Date
		RETURN -2
	
	SELECT @RecordCount = COUNT(1) FROM @Tbl;
	
	IF @RecordCount = 2
	BEGIN
		IF @Discontinue = 'false' OR @Discontinue = N''
			BEGIN

				--Get policy period
				DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)

				INSERT INTO @tblPeriod
				EXEC uspGetPolicyPeriod @ProdId, @ExpiryDate, @HasCycle OUTPUT;

				DECLARE @ExpiryDatePreviousPolicy DATE
				SELECT @ExpiryDatePreviousPolicy = ExpiryDate FROM tblPolicy WHERE PolicyID=@PreviousPolicyId AND ValidityTo IS NULL
				SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				IF @StartDate < @ExpiryDatePreviousPolicy
					UPDATE @tblPeriod SET StartDate=DATEADD(DAY, 1, @ExpiryDatePreviousPolicy)
				

				IF @HasCycle = 1
					SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				ELSE
					SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;


				DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
				DECLARE @PolicyValue DECIMAL(18,2) 
				--EXEC @PolicyValue = uspPolicyValue 0, 0,@FamilyID, @ProdId,@Date, 
				EXEC @PolicyValue = uspPolicyValue
										@FamilyId = @FamilyID,
										@ProdId = @ProdId,
										@EnrollDate = @Date,
										@PreviousPolicyId = @PreviousPolicyId,
										@PolicyStage = 'R';
		
				DECLARE @PolicyStatus TINYINT = 2
		
				IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
				INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
								VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
				DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
		
				INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
								Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
				

				INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,AuditUserId,isOffline)
				SELECT I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,PL.EffectiveDate,PL.ExpiryDate,PL.AuditUserID,I.isOffline 
				FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID 
				WHERE(I.ValidityTo Is NULL) 
				AND PL.ValidityTo IS NULL 
				AND PL.PolicyID = @PolicyId;

				UPDATE tblPolicyRenewals SET ResponseStatus = 1, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId;
			END
		ELSE
			BEGIN
				UPDATE tblPolicyRenewals SET ResponseStatus = 2, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId
			END

		UPDATE tblFromPhone SET DocStatus = N'A' WHERE FromPhoneId = @FromPhoneId;
		
		SELECT * FROM @Tbl;
	END
END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END


GO



IF NOT OBJECT_ID('udfExpiredPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfExpiredPoliciesPhoneStatistics]
GO


CREATE FUNCTION [dbo].[udfExpiredPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
			SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID OR(PL.ProdID = PR.ConversionProdID )
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate >= @DateFrom AND PL.ExpiryDate < = @DateTo)
			
	  )
END



GO


IF NOT OBJECT_ID('udfNewPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfNewPoliciesPhoneStatistics]
GO

CREATE FUNCTION [dbo].[udfNewPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
	
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
	  SELECT COUNT(1)  
	  FROM 
	  tblPolicy PL
	  INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
	  WHERE PL.ValidityTo IS NULL  AND PolicyStage ='N' AND EnrollDate >= @DateFrom AND EnrollDate <=@DateTo
	  )
END



GO


IF NOT OBJECT_ID('udfRenewedPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfRenewedPoliciesPhoneStatistics]
GO


CREATE FUNCTION [dbo].[udfRenewedPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
	  SELECT COUNT(1)  FROM 
	  tblPolicy PL
	  INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
	  WHERE 
	  ValidityTo IS NULL AND PolicyStage ='R' AND EnrollDate >= @DateFrom AND EnrollDate <=@DateTo
	  )
END



GO


IF NOT OBJECT_ID('udfSuspendedPoliciesPhoneStatistics') IS NULL
DROP FUNCTION [dbo].[udfSuspendedPoliciesPhoneStatistics]
GO

CREATE FUNCTION [dbo].[udfSuspendedPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
		SELECT  COUNT(1) SuspendedPolicies
		FROM tblPolicy PL 
		INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
		WHERE PL.ValidityTo IS NULL
		AND PL.PolicyStatus = 4
		AND (ExpiryDate >= @DateFrom AND ExpiryDate < = @DateTo)
		
	  )
END



GO


IF NOT OBJECT_ID('udfCollectedContribution') IS NULL
DROP FUNCTION [dbo].[udfCollectedContribution]
GO


	
CREATE FUNCTION [dbo].[udfCollectedContribution](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS DECIMAL(18,2)
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
	  SELECT SUM(Amount)  FROM tblPremium PR
INNER JOIN tblPolicy PL ON PL.PolicyID=PR.PolicyID
INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
WHERE 
PL.ValidityTo IS NULL
AND PR.ValidityTo IS NULL
AND PayDate >= @DateFrom
AND PayDate <=@DateTo

	  )
END



GO


IF NOT OBJECT_ID('udfGetSnapshotIndicators') IS NULL
DROP FUNCTION [dbo].[udfGetSnapshotIndicators]
GO



CREATE FUNCTION [dbo].[udfGetSnapshotIndicators](
	@Date DATE, 
	@OfficerId INT
) RETURNS @tblSnapshotIndicators TABLE(ACtive INT,Expired INT,Idle INT,Suspended INT)
	AS
	BEGIN
		DECLARE @ACtive INT=0
		DECLARE @Expired INT=0
		DECLARE @Idle INT=0
		DECLARE @Suspended INT=0
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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


		SET @ACtive = (
						SELECT COUNT(DISTINCT P.FamilyID) ActivePolicies FROM tblPolicy P 
						INNER JOIN @tblOfficerSub O ON P.OfficerID = O.NewOfficer
						WHERE P.ValidityTo IS NULL AND PolicyStatus = 2 
						AND ExpiryDate >=@Date
					  )

		SET @Expired = (SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID OR (PL.ProdID = PR.ConversionProdID)
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			AND  PL.PolicyStatus = 2
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate =@Date)
			)
		SET @Idle =		(
						SELECT COUNT(DISTINCT PL.FamilyID) IddlePolicies FROM tblPolicy PL 
						INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
						INNER JOIN tblProduct PR ON PR.ProdID = PL.ProdID
						LEFT OUTER JOIN (SELECT FamilyID, ProdID FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyStatus =2 AND  ExpiryDate >=@Date) ActivePolicies ON ActivePolicies.FamilyID = PL.FamilyID AND (ActivePolicies.ProdID = PL.ProdID OR ActivePolicies.ProdID = PR.ConversionProdID)
						WHERE PL.ValidityTo IS NULL AND PL.PolicyStatus = 1 
						AND ExpiryDate >=@Date
						AND ActivePolicies.ProdID IS NULL
						)
		SET @Suspended = (
						SELECT COUNT(DISTINCT PL.FamilyID) SuspendedPolicies FROM tblPolicy PL 
						INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
						INNER JOIN tblProduct PR ON PR.ProdID = PL.ProdID
						LEFT OUTER JOIN (SELECT FamilyID, ProdID FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyStatus =2 AND  ExpiryDate >=@Date) ActivePolicies ON ActivePolicies.FamilyID = PL.FamilyID AND (ActivePolicies.ProdID = PL.ProdID OR ActivePolicies.ProdID = PR.ConversionProdID)
						WHERE PL.ValidityTo IS NULL AND PL.PolicyStatus = 4
						AND ExpiryDate >=@Date
						AND ActivePolicies.ProdID IS NULL
						)
		INSERT INTO @tblSnapshotIndicators(ACtive, Expired, Idle, Suspended) VALUES (@ACtive, @Expired, @Idle, @Suspended)
		  RETURN
	END

GO



IF NOT OBJECT_ID ('uspCreateEnrolmentXML') IS NULL
DROP PROCEDURE [dbo].[uspCreateEnrolmentXML]
GO


CREATE PROCEDURE [dbo].[uspCreateEnrolmentXML]
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
	SELECT I.InsureeID,I.FamilyID,I.CHFID,I.LastName,I.OtherNames,I.DOB,I.Gender,I.Marital,I.IsHead,I.passport,I.Phone,I.CardIssued,NULL EffectiveDate
	FROM tblInsuree I
	LEFT OUTER JOIN tblInsureePolicy IP ON IP.InsureeId=I.InsureeID
	WHERE I.ValidityTo IS NULL AND I.isOffline = 1
	AND IP.ValidityTo IS NULL 
	GROUP BY I.InsureeID,I.FamilyID,I.CHFID,I.LastName,I.OtherNames,I.DOB,I.Gender,I.Marital,I.IsHead,I.passport,I.Phone,I.CardIssued
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



IF NOT OBJECT_ID ('uspGetPolicyRenewals') IS NULL
DROP PROCEDURE uspGetPolicyRenewals
GO

CREATE PROCEDURE uspGetPolicyRenewals
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


	 ;WITH FollowingPolicies AS ( SELECT P.PolicyId, P.FamilyId, ISNULL(Prod.ConversionProdId, Prod.ProdId)ProdID, P.StartDate FROM tblPolicy P INNER JOIN tblProduct Prod ON P.ProdId = ISNULL(Prod.ConversionProdId, Prod.ProdId) WHERE P.ValidityTo IS NULL AND Prod.ValidityTo IS NULL ) SELECT R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, CONVERT(NVARCHAR(10),R.RenewalpromptDate,103)RenewalpromptDate, O.Phone, CONVERT(NVARCHAR(10),Po.EnrollDate,103) EnrollDate,Po.PolicyStage, F.FamilyID, Prod.ProdID FROM tblPolicyRenewals R  
	 INNER JOIN tblOfficer O ON R.NewOfficerId = O.OfficerId 
	 INNER JOIN tblInsuree I ON R.InsureeId = I.InsureeId 
	 LEFT OUTER JOIN tblProduct Prod ON R.NewProdId = Prod.ProdId 
	 INNER JOIN tblFamilies F ON I.FamilyId = F.Familyid 
	 INNER JOIN tblVillages V ON F.LocationId = V.VillageId 
	 INNER JOIN tblPolicy Po ON Po.PolicyID = R.PolicyID
	 INNER JOIN @tblOfficerSub OS ON OS.NewOfficer = R.NewOfficerID
	 LEFT OUTER JOIN FollowingPolicies FP ON FP.FamilyID = F.FamilyId AND FP.ProdId = Po.ProdID AND FP.PolicyId <> R.PolicyID 
	 WHERE R.ValidityTo Is NULL AND ISNULL(R.ResponseStatus, 0) = 0 AND FP.PolicyId IS NULL
 END
 GO


IF NOT OBJECT_ID('uspGetPolicyRenewals') IS NULL
DROP PROCEDURE [dbo].[uspGetPolicyRenewals]
GO


CREATE PROCEDURE [dbo].[uspGetPolicyRenewals]
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


	 ;WITH FollowingPolicies AS ( SELECT P.PolicyId, P.FamilyId, ISNULL(Prod.ConversionProdId, Prod.ProdId)ProdID, P.StartDate FROM tblPolicy P INNER JOIN tblProduct Prod ON P.ProdId = ISNULL(Prod.ConversionProdId, Prod.ProdId) WHERE P.ValidityTo IS NULL AND Prod.ValidityTo IS NULL ) 
	 SELECT R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, CONVERT(NVARCHAR(10),R.RenewalpromptDate,103)RenewalpromptDate, O.Phone, CONVERT(NVARCHAR(10),GETDATE(),103) EnrollDate, 'R' PolicyStage, F.FamilyID, Prod.ProdID FROM tblPolicyRenewals R  
	 INNER JOIN tblOfficer O ON R.NewOfficerId = O.OfficerId 
	 INNER JOIN tblInsuree I ON R.InsureeId = I.InsureeId 
	 LEFT OUTER JOIN tblProduct Prod ON R.NewProdId = Prod.ProdId 
	 INNER JOIN tblFamilies F ON I.FamilyId = F.Familyid 
	 INNER JOIN tblVillages V ON F.LocationId = V.VillageId 
	 INNER JOIN tblPolicy Po ON Po.PolicyID = R.PolicyID
	 INNER JOIN @tblOfficerSub OS ON OS.NewOfficer = R.NewOfficerID
	 LEFT OUTER JOIN FollowingPolicies FP ON FP.FamilyID = F.FamilyId AND FP.ProdId = Po.ProdID AND FP.PolicyId <> R.PolicyID 
	 WHERE R.ValidityTo Is NULL AND ISNULL(R.ResponseStatus, 0) = 0 AND FP.PolicyId IS NULL
 END

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[uspGetPolicyPeriod]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[uspGetPolicyPeriod]
GO
/****** Object:  StoredProcedure [dbo].[uspGetPolicyPeriod]    Script Date: 19/06/2018 19:03:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[uspGetPolicyPeriod]
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

--FROM Hans
/****** Object:  StoredProcedure [dbo].[uspProcessClaims]    Script Date: 21/06/2018 17:28:25 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[uspProcessClaims]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[uspProcessClaims]
GO

/****** Object:  StoredProcedure [dbo].[uspSubmitClaims]    Script Date: 21/06/2018 17:28:34 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[uspSubmitClaims]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[uspSubmitClaims]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspSubmitClaims]
	
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

CREATE PROCEDURE [dbo].[uspProcessClaims]
	
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

-- *********** Indexes tblCLAIM

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaim]') AND name = N'NCI_InsureeID')
DROP INDEX [NCI_tblClaims_InsureeID] ON [dbo].[tblClaim]
GO

/****** Object:  Index [NCI_HFID]    Script Date: 11/06/2018 12:10:18 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaim]') AND name = N'NCI_HFID')
DROP INDEX [NCI_tblClaim_HFID] ON [dbo].[tblClaim]
GO

/****** Object:  Index [NCI_DateFromTo]    Script Date: 11/06/2018 12:10:18 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaim]') AND name = N'NCI_DateFromTo')
DROP INDEX [NCI_tblClaim_DateFromTo] ON [dbo].[tblClaim]
GO

/****** Object:  Index [NonClusteredIndex-20180529-011603]    Script Date: 11/06/2018 12:08:04 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaim_HFID] ON [dbo].[tblClaim]
(
	[HFID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-011622]    Script Date: 11/06/2018 12:08:04 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaim_InsureeID] ON [dbo].[tblClaim]
(
	[InsureeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-011650]    Script Date: 11/06/2018 12:08:04 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaim_DateFromTo] ON [dbo].[tblClaim]
(
	[DateFrom] ASC,
	[DateTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

--Indexes ********** tblCLAIMDEDREM

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimDedRem]') AND name = N'NCI_tblClaimDedRem_PolicyID')
DROP INDEX [NCI_tblClaimDedRem_PolicyID] ON [dbo].[tblClaimDedRem]
GO

/****** Object:  Index [NCI_tblClaimDedRem_InsureeID]    Script Date: 11/06/2018 12:34:18 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimDedRem]') AND name = N'NCI_tblClaimDedRem_InsureeID')
DROP INDEX [NCI_tblClaimDedRem_InsureeID] ON [dbo].[tblClaimDedRem]
GO

/****** Object:  Index [NCI_tblClaimDedRem_ClaimID]    Script Date: 11/06/2018 12:34:18 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimDedRem]') AND name = N'NCI_tblClaimDedRem_ClaimID')
DROP INDEX [NCI_tblClaimDedRem_ClaimID] ON [dbo].[tblClaimDedRem]
GO

CREATE NONCLUSTERED INDEX [NCI_tblClaimDedRem_InsureeID] ON [dbo].[tblClaimDedRem]
(
	[InsureeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-010807]    Script Date: 11/06/2018 12:30:03 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimDedRem_PolicyID] ON [dbo].[tblClaimDedRem]
(
	[PolicyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-010824]    Script Date: 11/06/2018 12:30:03 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimDedRem_ClaimID] ON [dbo].[tblClaimDedRem]
(
	[ClaimID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

--Indexes ************ tblCLAIMITEMS

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimItems]') AND name = N'tblClaimItems_tblClaimItems_ItemID')
DROP INDEX [tblClaimItems_tblClaimItems_ItemID] ON [dbo].[tblClaimItems]
GO

/****** Object:  Index [NCI_tblClaimItems_ProdID]    Script Date: 11/06/2018 12:39:54 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimItems]') AND name = N'NCI_tblClaimItems_ProdID')
DROP INDEX [NCI_tblClaimItems_ProdID] ON [dbo].[tblClaimItems]
GO

/****** Object:  Index [NCI_tblClaimItems_ClaimID]    Script Date: 11/06/2018 12:39:54 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimItems]') AND name = N'NCI_tblClaimItems_ClaimID')
DROP INDEX [NCI_tblClaimItems_ClaimID] ON [dbo].[tblClaimItems]
GO

/****** Object:  Index [NonClusteredIndex-20180529-010253]    Script Date: 11/06/2018 12:38:22 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimItems_ClaimID] ON [dbo].[tblClaimItems]
(
	[ClaimID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-010325]    Script Date: 11/06/2018 12:38:22 ******/
CREATE NONCLUSTERED INDEX [tblClaimItems_tblClaimItems_ItemID] ON [dbo].[tblClaimItems]
(
	[ItemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-010459]    Script Date: 11/06/2018 12:38:22 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimItems_ProdID] ON [dbo].[tblClaimItems]
(
	[ProdID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

--Indexes ************ tblCLAIMSERVICES

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimServices]') AND name = N'NCI_tblClaimServices_ServiceID')
DROP INDEX [NCI_tblClaimServices_ServiceID] ON [dbo].[tblClaimServices]
GO

/****** Object:  Index [NCI_tblClaimServices_ProdID]    Script Date: 11/06/2018 12:43:50 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimServices]') AND name = N'NCI_tblClaimServices_ProdID')
DROP INDEX [NCI_tblClaimServices_ProdID] ON [dbo].[tblClaimServices]
GO

/****** Object:  Index [NCI_tblClaimServices_ClaimID]    Script Date: 11/06/2018 12:43:50 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblClaimServices]') AND name = N'NCI_tblClaimServices_ClaimID')
DROP INDEX [NCI_tblClaimServices_ClaimID] ON [dbo].[tblClaimServices]
GO

/****** Object:  Index [NonClusteredIndex-20180529-010416]    Script Date: 11/06/2018 12:42:17 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimServices_ClaimID] ON [dbo].[tblClaimServices]
(
	[ClaimID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-010428]    Script Date: 11/06/2018 12:42:17 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimServices_ServiceID] ON [dbo].[tblClaimServices]
(
	[ServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-010443]    Script Date: 11/06/2018 12:42:17 ******/
CREATE NONCLUSTERED INDEX [NCI_tblClaimServices_ProdID] ON [dbo].[tblClaimServices]
(
	[ProdID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

--Indexes ************ tblFamilies

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblFamilies]') AND name = N'NCI_tblFamilies_ValidityTo')
DROP INDEX [NCI_tblFamilies_ValidityTo] ON [dbo].[tblFamilies]
GO

/****** Object:  Index [NCI_tblFamilies_LocationID]    Script Date: 11/06/2018 12:53:05 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblFamilies]') AND name = N'NCI_tblFamilies_LocationID')
DROP INDEX [NCI_tblFamilies_LocationID] ON [dbo].[tblFamilies]
GO

/****** Object:  Index [NCI_tblFamilies_InsureeID]    Script Date: 11/06/2018 12:53:05 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblFamilies]') AND name = N'NCI_tblFamilies_InsureeID')
DROP INDEX [NCI_tblFamilies_InsureeID] ON [dbo].[tblFamilies]
GO

/****** Object:  Index [IX_tblFamilies_ValidityTo]    Script Date: 11/06/2018 12:51:04 ******/
CREATE NONCLUSTERED INDEX [NCI_tblFamilies_ValidityTo] ON [dbo].[tblFamilies]
(
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NCI_tblFamilies_InsureeID]    Script Date: 11/06/2018 12:51:04 ******/
CREATE NONCLUSTERED INDEX [NCI_tblFamilies_InsureeID] ON [dbo].[tblFamilies]
(
	[InsureeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NCI_tblFamilies_LocationID]    Script Date: 11/06/2018 12:51:04 ******/
CREATE NONCLUSTERED INDEX [NCI_tblFamilies_LocationID] ON [dbo].[tblFamilies]
(
	[LocationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

--Indexes ************ tblInsuree


--NONE


--Indexes ************ tblInsureePolicy

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblInsureePolicy]') AND name = N'NCI_tblInsureePolicy_PolicyID')
DROP INDEX [NCI_tblInsureePolicy_PolicyID] ON [dbo].[tblInsureePolicy]
GO

/****** Object:  Index [NCI_tblInsureePolicy_InsureeID]    Script Date: 11/06/2018 13:12:38 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblInsureePolicy]') AND name = N'NCI_tblInsureePolicy_InsureeID')
DROP INDEX [NCI_tblInsureePolicy_InsureeID] ON [dbo].[tblInsureePolicy]
GO

/****** Object:  Index [NCI_tblInsureePolicy_EffDate_Expiry]    Script Date: 11/06/2018 13:12:38 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblInsureePolicy]') AND name = N'NCI_tblInsureePolicy_EffDate_Expiry')
DROP INDEX [NCI_tblInsureePolicy_EffDate_Expiry] ON [dbo].[tblInsureePolicy]
GO

/****** Object:  Index [NonClusteredIndex-20180529-011212]    Script Date: 11/06/2018 13:10:59 ******/
CREATE NONCLUSTERED INDEX [NCI_tblInsureePolicy_InsureeID] ON [dbo].[tblInsureePolicy]
(
	[InsureeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-011232]    Script Date: 11/06/2018 13:10:59 ******/
CREATE NONCLUSTERED INDEX [NCI_tblInsureePolicy_PolicyID] ON [dbo].[tblInsureePolicy]
(
	[PolicyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-012226]    Script Date: 11/06/2018 13:10:59 ******/
CREATE NONCLUSTERED INDEX [NCI_tblInsureePolicy_EffDate_Expiry] ON [dbo].[tblInsureePolicy]
(
	[EffectiveDate] ASC,
	[ExpiryDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


-- Indexes ************ TblItems

/****** Object:  Index [NCI_tblItems_ValidityFrom_To]    Script Date: 11/06/2018 13:14:54 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblItems]') AND name = N'NCI_tblItems_ValidityFrom_To')
DROP INDEX [NCI_tblItems_ValidityFrom_To] ON [dbo].[tblItems]
GO

CREATE NONCLUSTERED INDEX [NCI_tblItems_ValidityFrom_To] ON [dbo].[tblItems]
(
	[ValidityFrom] ASC,
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


-- Indexes ************ TblLocations

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblLocations]') AND name = N'NCI_tblLocations_ValidityFromTo')
DROP INDEX [NCI_tblLocations_ValidityFromTo] ON [dbo].[tblLocations]
GO

/****** Object:  Index [NCI_tblLocations_ParentLocID]    Script Date: 11/06/2018 13:49:47 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblLocations]') AND name = N'NCI_tblLocations_ParentLocID')
DROP INDEX [NCI_tblLocations_ParentLocID] ON [dbo].[tblLocations]
GO


/****** Object:  Index [NCI_tblLocations_ParentLocID]    Script Date: 11/06/2018 13:49:25 ******/
CREATE NONCLUSTERED INDEX [NCI_tblLocations_ParentLocID] ON [dbo].[tblLocations]
(
	[ParentLocationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NCI_tblLocations_ValidityFromTo]    Script Date: 11/06/2018 13:49:25 ******/
CREATE NONCLUSTERED INDEX [NCI_tblLocations_ValidityFromTo] ON [dbo].[tblLocations]
(
	[ValidityFrom] ASC,
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

-- Indexes ************ TblOfficer

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblOfficer]') AND name = N'NCI_tblOfficer_ValidityTo_LocationID')
DROP INDEX [NCI_tblOfficer_ValidityTo_LocationID] ON [dbo].[tblOfficer]
GO

CREATE NONCLUSTERED INDEX [NCI_tblOfficer_ValidityTo_LocationID] ON [dbo].[tblOfficer]
(
	[ValidityTo] ASC,
	[LocationId] ASC
)
INCLUDE ( 	[Code],
	[LastName],
	[OtherNames]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

-- Indexes ************ TblPhotos


IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPhotos]') AND name = N'IX_tblPhotos_ValidityTo')
DROP INDEX [IX_tblPhotos_ValidityTo] ON [dbo].[tblPhotos]
GO

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPhotos]') AND name = N'NCI_tblPhotos_InsureeIDValidityTo')
DROP INDEX [NCI_tblPhotos_InsureeIDValidityTo] ON [dbo].[tblPhotos]
GO

CREATE NONCLUSTERED INDEX [NCI_tblPhotos_InsureeIDValidityTo] ON [dbo].[tblPhotos]
(
	[InsureeID] ASC,
	[ValidityTo] ASC
)
INCLUDE ( 	[PhotoFileName]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO


-- Indexes  **************** TblPolicy 

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPolicy]') AND name = N'IX_tblPolicy_Dates')
CREATE NONCLUSTERED INDEX [IX_tblPolicy_Dates] ON [dbo].[tblPolicy]
(
	[ValidityTo] ASC,
	[EffectiveDate] ASC,
	[ExpiryDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [IX_tblPolicy_FamilyId_ProdId]    Script Date: 11/06/2018 16:29:16 ******/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPolicy]') AND name = N'IX_tblPolicy_FamilyId_ProdId')
CREATE NONCLUSTERED INDEX [IX_tblPolicy_FamilyId_ProdId] ON [dbo].[tblPolicy]
(
	[FamilyID] ASC,
	[ProdID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [IX_tblpolicy_PId_VT_ED_EX]    Script Date: 11/06/2018 16:29:16 ******/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPolicy]') AND name = N'IX_tblpolicy_PId_VT_ED_EX')
CREATE NONCLUSTERED INDEX [IX_tblpolicy_PId_VT_ED_EX] ON [dbo].[tblPolicy]
(
	[ProdID] ASC,
	[ValidityTo] ASC,
	[EffectiveDate] ASC,
	[ExpiryDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [IX_tblPolicy_ValidityTo]    Script Date: 11/06/2018 16:29:16 ******/
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPolicy]') AND name = N'IX_tblPolicy_ValidityTo')
CREATE NONCLUSTERED INDEX [IX_tblPolicy_ValidityTo] ON [dbo].[tblPolicy]
(
	[ValidityTo] ASC,
	[PolicyStatus] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

-- indexes *************** tblPremium 

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblPremium]') AND name = N'IX_tblPremium_ProdId')
CREATE NONCLUSTERED INDEX [IX_tblPremium_ProdId] ON [dbo].[tblPremium]
(
	[PolicyID] ASC,
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

--Indexes ********** tblProductItems 

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblProductItems]') AND name = N'NCI_tblProductItems_ValidityFromTo')
DROP INDEX [NCI_tblProductItems_ValidityFromTo] ON [dbo].[tblProductItems]
GO

/****** Object:  Index [NCI_tblProductItems_ItemID]    Script Date: 11/06/2018 16:38:01 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblProductItems]') AND name = N'NCI_tblProductItems_ItemID')
DROP INDEX [NCI_tblProductItems_ItemID] ON [dbo].[tblProductItems]
GO


/****** Object:  Index [NonClusteredIndex-20180529-011754]    Script Date: 11/06/2018 16:35:30 ******/
CREATE NONCLUSTERED INDEX [NCI_tblProductItems_ItemID] ON [dbo].[tblProductItems]
(
	[ItemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-011912]    Script Date: 11/06/2018 16:35:30 ******/
CREATE NONCLUSTERED INDEX [NCI_tblProductItems_ValidityFromTo] ON [dbo].[tblProductItems]
(
	[ValidityFrom] ASC,
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

-- Indexes ******************* tblProductServices

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblProductServices]') AND name = N'NCI_tblProductServices_ValidityFromTo')
DROP INDEX [NCI_tblProductServices_ValidityFromTo] ON [dbo].[tblProductServices]
GO

/****** Object:  Index [NCI_tblProductServices_ServiceID]    Script Date: 11/06/2018 16:41:58 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblProductServices]') AND name = N'NCI_tblProductServices_ServiceID')
DROP INDEX [NCI_tblProductServices_ServiceID] ON [dbo].[tblProductServices]
GO

CREATE NONCLUSTERED INDEX [NCI_tblProductServices_ServiceID] ON [dbo].[tblProductServices]
(
	[ServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NonClusteredIndex-20180529-011932]    Script Date: 11/06/2018 16:38:41 ******/
CREATE NONCLUSTERED INDEX [NCI_tblProductServices_ValidityFromTo] ON [dbo].[tblProductServices]
(
	[ValidityFrom] ASC,
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

-- Indexes ********** tblServices

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblServices]') AND name = N'NCI_tblServices_ValidityFromTo')
DROP INDEX [NCI_tblServices_ValidityFromTo] ON [dbo].[tblServices]
GO

CREATE NONCLUSTERED INDEX [NCI_tblServices_ValidityFromTo] ON [dbo].[tblServices]
(
	[ValidityFrom] ASC,
	[ValidityTo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

-- Indexes *********** tblSubmittedPhotos

IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblSubmittedPhotos]') AND name = N'NCI_tblSubmittedPhotos_CHFID')
DROP INDEX [NCI_tblSubmittedPhotos_CHFID] ON [dbo].[tblSubmittedPhotos]
GO

/****** Object:  Index [NCI_tblSubmittedPhotos_OfficerID]    Script Date: 11/06/2018 16:47:44 ******/
IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblSubmittedPhotos]') AND name = N'NCI_tblSubmittedPhotos_OfficerID')
DROP INDEX [NCI_tblSubmittedPhotos_OfficerID] ON [dbo].[tblSubmittedPhotos]
GO

CREATE NONCLUSTERED INDEX [NCI_tblSubmittedPhotos_OfficerID] ON [dbo].[tblSubmittedPhotos]
(
	[OfficerCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO

/****** Object:  Index [NCI_tblSubmittedPhotos_CHFID]    Script Date: 11/06/2018 16:48:15 ******/
CREATE NONCLUSTERED INDEX [NCI_tblSubmittedPhotos_CHFID] ON [dbo].[tblSubmittedPhotos]
(
	[CHFID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO




IF NOT OBJECT_ID('uspIsValidRenewal') IS NULL
DROP PROCEDURE [dbo].[uspIsValidRenewal]
GO


CREATE PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(200),
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
	
	--SELECT @FilePath = 'C:/inetpub/wwwroot/IMIS' + FTPPolicyRenewalFolder + '/' + @FileName FROM tblIMISDefaults
	
	--SET @Query =  (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')

	--EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
	
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
	
	
	IF @DocStatus ='R'
		RETURN -3
	ELSE IF @DocStatus ='A'
		RETURN -4

	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;


	DECLARE @Tbl TABLE(Id INT)

	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
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

	SELECT TOP 1 @ProdId = tblPolicy.ProdID, @ExpiryDate = tblPolicy.ExpiryDate from tblPolicy INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID WHERE FamilyID = @FamilyID AND tblProduct.ProductCode = @ProductCode AND tblProduct.ValidityTo IS NULL ORDER BY ExpiryDate DESC
	
	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	IF @LastRenewalDate < @Date
		RETURN -2
	
	SELECT @RecordCount = COUNT(1) FROM @Tbl;
	
	IF @RecordCount = 2
	BEGIN
		IF @Discontinue = 'false' OR @Discontinue = N''
			BEGIN

				--Get policy period
				DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)

				INSERT INTO @tblPeriod
				EXEC uspGetPolicyPeriod @ProdId, @ExpiryDate, @HasCycle OUTPUT;

				DECLARE @ExpiryDatePreviousPolicy DATE
				SELECT @ExpiryDatePreviousPolicy = ExpiryDate FROM tblPolicy WHERE PolicyID=@PreviousPolicyId AND ValidityTo IS NULL
				SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				IF @StartDate < @ExpiryDatePreviousPolicy
					UPDATE @tblPeriod SET StartDate=DATEADD(DAY, 1, @ExpiryDatePreviousPolicy)
				

				IF @HasCycle = 1
					SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				ELSE
					SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;


				DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
				DECLARE @PolicyValue DECIMAL(18,2) 
				--EXEC @PolicyValue = uspPolicyValue 0, 0,@FamilyID, @ProdId,@Date, 
				EXEC @PolicyValue = uspPolicyValue
										@FamilyId = @FamilyID,
										@ProdId = @ProdId,
										@EnrollDate = @Date,
										@PreviousPolicyId = @PreviousPolicyId,
										@PolicyStage = 'R';
		
				DECLARE @PolicyStatus TINYINT = 2
		
				IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
				INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
								VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
				DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
		
				INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
								Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
				

				INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,AuditUserId,isOffline)
				SELECT I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,PL.EffectiveDate,PL.ExpiryDate,PL.AuditUserID,I.isOffline 
				FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID 
				WHERE(I.ValidityTo Is NULL) 
				AND PL.ValidityTo IS NULL 
				AND PL.PolicyID = @PolicyId;

				UPDATE tblPolicyRenewals SET ResponseStatus = 1, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId;
			END
		ELSE
			BEGIN
				UPDATE tblPolicyRenewals SET ResponseStatus = 2, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId
			END

		UPDATE tblFromPhone SET DocStatus = N'A' WHERE FromPhoneId = @FromPhoneId;
		
		SELECT * FROM @Tbl;
	END
END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END

GO



IF NOT OBJECT_ID('uspInsertFeedback') IS NULL
DROP PROCEDURE [dbo].[uspInsertFeedback]
GO


CREATE PROCEDURE [dbo].[uspInsertFeedback]
(
	@XML XML
	--@FileName VARCHAR(100)
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
		--DECLARE @FilePath NVARCHAR(250)
		--DECLARE @XML XML
		DECLARE @Query NVARCHAR(3000)
		
		DECLARE @OfficerCode NVARCHAR(8)
		DECLARE @OfficerID INT
		DECLARE @ClaimID INT
		DECLARE @CHFID VARCHAR(12)
		DECLARE @Answers VARCHAR(5)
		DECLARE @FeedbackDate DATE
		
		--SELECT @FilePath = 'C:/inetpub/wwwroot' + FTPFeedbackFolder + '/' + @FileName FROM tblIMISDefaults
				
		--SET @Query = (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')
		
		--EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
		
		SELECT
		@OfficerCode = feedback.value('(Officer)[1]','NVARCHAR(8)'),
		@ClaimID = feedback.value('(ClaimID)[1]','NVARCHAR(8)'),
		@CHFID  = feedback.value('(CHFID)[1]','VARCHAR(12)'),
		@Answers = feedback.value('(Answers)[1]','VARCHAR(5)'),
		@FeedbackDate = CONVERT(DATE,feedback.value('(Date)[1]','VARCHAR(10)'),103)
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


IF NOT OBJECT_ID('uspGetPolicyRenewals') IS NULL
DROP PROCEDURE [dbo].[uspGetPolicyRenewals]
GO



CREATE PROCEDURE [dbo].[uspGetPolicyRenewals]
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


	 ;WITH FollowingPolicies AS ( SELECT P.PolicyId, P.FamilyId, ISNULL(Prod.ConversionProdId, Prod.ProdId)ProdID, P.StartDate FROM tblPolicy P INNER JOIN tblProduct Prod ON P.ProdId = ISNULL(Prod.ConversionProdId, Prod.ProdId) WHERE P.ValidityTo IS NULL AND Prod.ValidityTo IS NULL ) 
	 SELECT R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, CONVERT(NVARCHAR(10),R.RenewalpromptDate,103)RenewalpromptDate, O.Phone, CONVERT(NVARCHAR(10),RenewalDate,103) EnrollDate, 'R' PolicyStage, F.FamilyID, Prod.ProdID FROM tblPolicyRenewals R  
	 INNER JOIN tblOfficer O ON R.NewOfficerId = O.OfficerId 
	 INNER JOIN tblInsuree I ON R.InsureeId = I.InsureeId 
	 LEFT OUTER JOIN tblProduct Prod ON R.NewProdId = Prod.ProdId 
	 INNER JOIN tblFamilies F ON I.FamilyId = F.Familyid 
	 INNER JOIN tblVillages V ON F.LocationId = V.VillageId 
	 INNER JOIN tblPolicy Po ON Po.PolicyID = R.PolicyID
	 INNER JOIN @tblOfficerSub OS ON OS.NewOfficer = R.NewOfficerID
	 LEFT OUTER JOIN FollowingPolicies FP ON FP.FamilyID = F.FamilyId AND FP.ProdId = Po.ProdID AND FP.PolicyId <> R.PolicyID 
	 WHERE R.ValidityTo Is NULL AND ISNULL(R.ResponseStatus, 0) = 0 AND FP.PolicyId IS NULL
 END


GO



IF NOT OBJECT_ID('uspIsValidRenewal') IS NULL
DROP PROCEDURE [dbo].[uspIsValidRenewal]
GO


CREATE PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(200),
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
	
	--SELECT @FilePath = 'C:/inetpub/wwwroot/IMIS' + FTPPolicyRenewalFolder + '/' + @FileName FROM tblIMISDefaults
	
	--SET @Query =  (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')

	--EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
	
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
	
	
	IF @DocStatus ='R'
		RETURN -3
	ELSE IF @DocStatus ='A'
		RETURN -4

	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;


	DECLARE @Tbl TABLE(Id INT)

	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
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

	SELECT TOP 1 @ProdId = tblPolicy.ProdID, @ExpiryDate = tblPolicy.ExpiryDate from tblPolicy INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID WHERE FamilyID = @FamilyID AND tblProduct.ProductCode = @ProductCode AND tblProduct.ValidityTo IS NULL ORDER BY ExpiryDate DESC
	
	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	IF @LastRenewalDate < @Date
		RETURN -2
	
	SELECT @RecordCount = COUNT(1) FROM @Tbl;
	
	IF @RecordCount = 2
	BEGIN
		IF @Discontinue = 'false' OR @Discontinue = N''
			BEGIN

				--Get policy period
				DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)

				INSERT INTO @tblPeriod
				EXEC uspGetPolicyPeriod @ProdId, @ExpiryDate, @HasCycle OUTPUT;

				DECLARE @ExpiryDatePreviousPolicy DATE
				SELECT @ExpiryDatePreviousPolicy = ExpiryDate FROM tblPolicy WHERE PolicyID=@PreviousPolicyId AND ValidityTo IS NULL
				SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				IF @StartDate < @ExpiryDatePreviousPolicy
					UPDATE @tblPeriod SET StartDate=DATEADD(DAY, 1, @ExpiryDatePreviousPolicy)
				

				IF @HasCycle = 1
					SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				ELSE
					SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;


				DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
				DECLARE @PolicyValue DECIMAL(18,2) 
				--EXEC @PolicyValue = uspPolicyValue 0, 0,@FamilyID, @ProdId,@Date, 
				EXEC @PolicyValue = uspPolicyValue
										@FamilyId = @FamilyID,
										@ProdId = @ProdId,
										@EnrollDate = @Date,
										@PreviousPolicyId = @PreviousPolicyId,
										@PolicyStage = 'R';
		
				DECLARE @PolicyStatus TINYINT = 2
		
				IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
				INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
								VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
				DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
		
				INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
								Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
				

				
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
END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END


GO



IF NOT OBJECT_ID('uspConsumeEnrollments') IS NULL
DROP PROCEDURE [dbo].[uspConsumeEnrollments]
GO



CREATE PROCEDURE [dbo].[uspConsumeEnrollments](
--@File NVARCHAR(300),
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
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT,PhotoPath NVARCHAR(100), NewFamilyId INT, NewInsureeId INT)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), isOffline BIT, NewFamilyId INT, NewPolicyId INT)
	DECLARE @tblInureePolicy TABLE(PolicyId INT,InsureeId INT,EffectiveDate DATE, NewInsureeId INT, NewPolicyId INT)
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
		INSERT INTO @tblPolicy(PolicyId,FamilyId,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdId,OfficerId,PolicyStage,isOffline)
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
				(N'<h4 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
				RAISERROR (N'<h4 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
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
		
		--online Policy in offline family
		UNION ALL
		SELECT 1 FROM @tblPolicy TP 
		INNER JOIN @tblFamilies TF ON TP.FamilyId = TF.FamilyId
		WHERE TF.isOffline = 1 AND TP.isOffline =0

		UNION ALL
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

		UNION ALL
		SELECT 1 FROM @tblInureePolicy TIP 
		LEFT OUTER JOIN @tblPolicy TP ON TP.PolicyId = TIP.PolicyId
		WHERE TP.PolicyId IS NULL
		)
		BEGIN
			INSERT INTO @tblResult VALUES
			(N'<h4 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>')
		
			RAISERROR (N'<h4 style="color:red;">Wrong format of the extract found. <br />Please contact your IT manager for further assistant.</h4>', 16, 1);
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


			--Validatiion For Phone only
			IF @AuditUserId > 0
				BEGIN

					--*****************New Family*********
					--Family already  exists
					IF EXISTS(SELECT 1 FROM @tblFamilies TF INNER JOIN tblInsuree F ON F.CHFID = TF.CHFID WHERE TF.isOffline = 1 AND F.ValidityTo IS NULL )
					RAISERROR(N'-2',16,1)
					
					--Family has no HOF
					IF EXISTS(SELECT 1 FROM @tblFamilies TF LEFT OUTER JOIN @tblInsuree TI ON TI.CHFID =TF.CHFID WHERE TF.isOffline = 1 AND TI.CHFID IS NULL)
					RAISERROR(N'-1',16,1)

					--Duplicate Insuree found
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
								SELECT 0 , TF.LocationId, TF.Poverty, GETDATE() , @AuditUserId , TF.FamilyType, TF.FamilyAddress, TF.Ethnicity, TF.ConfirmationNo, ConfirmationType,1 isOffline FROM @tblFamilies TF
								DECLARE @NewFamilyId  INT  =0
								SELECT @NewFamilyId= SCOPE_IDENTITY();
								IF @@ROWCOUNT > 0
									BEGIN
										SET @FamilyImported = ISNULL(@FamilyImported,0) + 1
										UPDATE @tblFamilies SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
										UPDATE @tblInsuree SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
										UPDATE @tblPolicy SET NewFamilyId = @NewFamilyId WHERE FamilyId = @CurFamilyId
									END
								
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
					INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
					SELECT	I.[FamilyID],I.[CHFID],I.[LastName],I.[OtherNames],I.[DOB],I.[Gender],I.[Marital],I.[IsHead],I.[passport],I.[Phone],I.[PhotoID],I.[PhotoDate],I.[CardIssued],I.isOffline,I.[AuditUserID],I.[ValidityFrom] ,GETDATE() ValidityTo,I.InsureeID,I.[Relationship],I.[Profession],I.[Education],I.[Email] ,I.[TypeOfId],I.[HFID], I.[CurrentAddress], I.[GeoLocation], [CurrentVillage] FROM @tblInsuree TI
					INNER JOIN tblInsuree I ON TI.CHFID = I.CHFID
					WHERE I.ValidityTo IS NULL AND
					TI.isOffline = 0

					UPDATE dst SET  dst.[LastName] = src.LastName,dst.[OtherNames] = src.OtherNames,dst.[DOB] = src.DOB,dst.[Gender] = src.Gender,dst.[Marital] = src.Marital,dst.[passport] = src.passport,dst.[Phone] = src.Phone,dst.[PhotoDate] = GETDATE(),dst.[CardIssued] = src.CardIssued,dst.isOffline=0,dst.[ValidityFrom] = GetDate(),dst.[AuditUserID] = @AuditUserID ,dst.[Relationship] = src.Relationship, dst.[Profession] = src.Profession, dst.[Education] = src.Education,dst.[Email] = src.Email ,dst.TypeOfId = src.TypeOfId,dst.HFID = src.HFID, dst.CurrentAddress = src.CurrentAddress, dst.CurrentVillage = src.CurVillage, dst.GeoLocation = src.GeoLocation 
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
								AuditUserId, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurrentVillage, isOffline)
								SELECT NewFamilyId, CHFID, LastName, OtherNames, DOB, Gender, Marital, IsHead, passport, Phone, CardIssued, GETDATE() ValidityFrom,
								@AuditUserId AuditUserId, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurVillage, 1 isOffLine
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
							SELECT	 ABS(NewFamilyID),EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,@PolicyValue,ProdID,@OfficerID,PolicyStage,GETDATE(),@AuditUserId, 1 isOffline FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @NewPolicyId = SCOPE_IDENTITY()
							INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, @NewPolicyId)
							
							IF @@ROWCOUNT > 0
								BEGIN
									SET @PolicyImported = ISNULL(@PolicyImported,0) +1
									UPDATE @tblInureePolicy SET NewPolicyId = @NewPolicyId WHERE PolicyId=@PolicyId
									UPDATE @tblPremium SET NewPolicyId =@NewPolicyId  WHERE PolicyId = @PolicyId
									INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee,isOffline)
									SELECT NewPolicyId,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),@AuditUserId,isPhotoFee, 1 isOffline
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
								 NewInsureeId,IP.NewPolicyId,@EnrollDate,@StartDate,IP.[EffectiveDate],@ExpiryDate,GETDATE(),@AuditUserId, 1 isOffline FROM @tblInureePolicy IP
							     WHERE IP.PolicyId=@PolicyId
						END
					ELSE
						BEGIN
							IF @ContributionAmount >= @PolicyValue
									SELECT @PolicyStatus = @Active
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





Exec sp_msforeachtable 'SET QUOTED_IDENTIFIER ON; ALTER INDEX ALL ON ? REBUILD'
GO



