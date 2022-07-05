IF OBJECT_ID('[dbo].[uspUploadEnrolmentsFromOfflinePhone]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspUploadEnrolmentsFromOfflinePhone]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(50),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12), NewFamilyId INT)
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(50),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,CurrentAddress NVARCHAR(200),GeoLocation NVARCHAR(200),CurVillage INT,isOffline BIT,PhotoPath NVARCHAR(100), NewFamilyId INT, NewInsureeId INT)
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
		T.F.value('(HOFCHFID)[1]','NVARCHAR(50)'),
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
		T.I.value('(CHFID)[1]','NVARCHAR(50)'),
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
