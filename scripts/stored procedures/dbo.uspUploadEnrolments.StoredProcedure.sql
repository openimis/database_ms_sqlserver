USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspUploadEnrolments]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspUploadEnrolments]
(
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
	DECLARE @tblFamilies TABLE(FamilyId INT,InsureeId INT, CHFID nvarchar(12),  LocationId INT,Poverty NVARCHAR(1),FamilyType NVARCHAR(2),FamilyAddress NVARCHAR(200), Ethnicity NVARCHAR(1), ConfirmationNo NVARCHAR(12))
	DECLARE @tblInsuree TABLE(InsureeId INT,FamilyId INT,CHFID NVARCHAR(12),LastName NVARCHAR(100),OtherNames NVARCHAR(100),DOB DATE,Gender CHAR(1),Marital CHAR(1),IsHead BIT,Passport NVARCHAR(25),Phone NVARCHAR(50),CardIssued BIT,Relationship SMALLINT,Profession SMALLINT,Education SMALLINT,Email NVARCHAR(100), TypeOfId NVARCHAR(1), HFID INT,EffectiveDate DATE, Updated BIT DEFAULT 0)
	DECLARE @tblPolicy TABLE(PolicyId INT,FamilyId INT,EnrollDate DATE,StartDate DATE,EffectiveDate DATE,ExpiryDate DATE,PolicyStatus TINYINT,PolicyValue DECIMAL(18,2),ProdId INT,OfficerId INT,PolicyStage CHAR(1), Updated BIT DEFAULT 0)
	DECLARE @tblPremium TABLE(PremiumId INT,PolicyId INT,PayerId INT,Amount DECIMAL(18,2),Receipt NVARCHAR(50),PayDate DATE,PayType CHAR(1),isPhotoFee BIT, Updated BIT DEFAULT 0)
	DECLARE @tblResult TABLE(Result NVARCHAR(Max))
	
	DECLARE @Counter INT = 0

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
		T.F.value('(Poverty)[1]','NVARCHAR(1)'),
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
		SELECT @PremiumSent = COUNT(*) FROM @tblPremium


		--Check if the file is in old format
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
				GOTO EndOfTheProcess;
			END


		BEGIN TRAN Enrol
			PRINT 'INSERTING ALL THE FAMILIES'
			--INSERT ALL THE FAMILIES
			DECLARE @FamilyId INT,
					@NewFamilyId INT,
					@HeadCHFID NVARCHAR(12)
					
			DECLARE CurFamily CURSOR FOR SELECT FamilyId FROM @tblFamilies
			OPEN CurFamily
				FETCH NEXT FROM CurFamily INTO @FamilyId
				WHILE @@FETCH_STATUS =0
				BEGIN
					--Grarb b the chfid from the XML table if that does not exist them fetch it from the live data
					SET @HeadCHFID = (SELECT TOP 1 CHFID FROM @tblInsuree WHERE FamilyID = @FamilyId AND IsHead = 1 AND Updated = 0)

					IF @HeadCHFID IS NULL
						SELECT TOP 1 @HeadCHFID = I.CHFID
						FROM @tblFamilies TF INNER JOIN @tblInsuree TI ON TF.FamilyId = TI.FamilyId
						INNER JOIN tblInsuree I ON TI.CHFID COLLATE DATABASE_DEFAULT = I.CHFID COLLATE DATABASE_DEFAULT
						WHERE I.IsHead = 1
						AND I.ValidityTo IS NULL
						AND TI.Updated = 0;

						IF @HeadCHFID IS NULL
						BEGIN
							SET @HeadCHFID = (SELECT TOP 1 CHFID FROM @tblFamilies WHERE FamilyID = @FamilyId)

						END

						
						IF @HeadCHFID IS NULL
						BEGIN
							DECLARE @Error NVARCHAR(300) = N'Error in family: ' + CAST(@FamilyId AS NVARCHAR(10));
							RAISERROR(@Error, 16, 1);
						END

					
					IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @HeadCHFID AND ValidityTo IS NULL) AND @HeadCHFID IS NOT NULL
					BEGIN	
						INSERT INTO tblFamilies(InsureeID,LocationId,Poverty,ValidityFrom,AuditUserID,FamilyType,FamilyAddress, Ethnicity, ConfirmationNo)
						SELECT 0, LocationId,Poverty,GETDATE(),-1,FamilyType,FamilyAddress, Ethnicity, ConfirmationNo FROM @tblFamilies WHERE FamilyId = @FamilyId;
						
						SET @Counter = @Counter + 1
						
						--GET THE NEWLY ADDED FAMILYID
						SET @NewFamilyId = (SELECT SCOPE_IDENTITY());
						
						--UPDATE Insuree table's FamilyId with newly added ID
						UPDATE @tblInsuree SET FamilyId = @NewFamilyId, Updated = 1 WHERE FamilyId = @FamilyId AND Updated = 0;
						
						--UPDATE Policy table's FamilyId with newly added ID
						UPDATE @tblPolicy SET FamilyId = @NewFamilyId, Updated = 1 WHERE FamilyId = @FamilyId AND Updated = 0
					END
					ELSE
					BEGIN
						INSERT INTO @tblResult(Result)
						VALUES('Family Of the Insurance Code: ' + @HeadCHFID + ' already exists.')
						SET @NewFamilyId = (SELECT FamilyId FROM tblInsuree WHERE CHFID = @HeadCHFID AND ValidityTo IS NULL)
						
						UPDATE @tblInsuree SET FamilyId = @NewFamilyId, Updated = 1 WHERE FamilyId = @FamilyId AND Updated = 0;
						UPDATE @tblPolicy SET FamilyId = @NewFamilyId, Updated = 1 WHERE FamilyId = @FamilyId AND Updated = 0;
																
						
					END
					
					FETCH NEXT FROM CurFamily INTO @FamilyId
				END
			CLOSE CurFamily
			DEALLOCATE CurFamily
			
			
			
			SET @FamilyImported = @Counter;
			
			SET @Counter = 0;
			
			PRINT 'INSERTING ALL THE INSUREES'

			--INSERT ALL THE INSUREES
			DECLARE @InsureeId INT,
					@NewInsureeId INT,
					@CHFID NVARCHAR(12),
					@IsHead BIT,
					@PolId INT,
					@PolVal DECIMAL(18,2),
					@NewPolVal DECIMAL(18,2),
					@PolicyStage NVARCHAR(1)
					

			DECLARE CurInsuree CURSOR FOR SELECT InsureeId FROM @tblInsuree
			OPEN CurInsuree
				FETCH NEXT FROM CurInsuree INTO @InsureeId
				WHILE @@FETCH_STATUS = 0
				BEGIN
					
					SET @CHFID = (SELECT CHFID FROM @tblInsuree WHERE InsureeID = @InsureeId)
					SET @IsHead =(SELECT IsHead FROM @tblInsuree WHERE InsureeID = @InsureeId)
					SET @FamilyId = (SELECT FamilyID FROM @tblInsuree WHERE InsureeId = @InsureeId)
					
					--CHECK if this CHFID already exists?
					IF EXISTS(SELECT * FROM tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL)
					BEGIN
						INSERT INTO @tblResult(Result)
						VALUES('Insurance Code: '+ @CHFID + ' already exists.')
						GOTO FETCH_NEXT
					END
					ELSE
					BEGIN
						INSERT INTO tblInsuree(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,passport,Phone,CardIssued,ValidityFrom,AuditUserID,Relationship,Profession,Education,Email,TypeOfId, HFID)
						SELECT FamilyId,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Passport,Phone,CardIssued,GETDATE(),-1,Relationship,Profession,Education,Email,TypeOfId, HFID FROM @tblInsuree WHERE InsureeId = @InsureeId;
						
						SET @Counter = @Counter + 1;
						
						--GET the newly added InsureeId
						SET @NewInsureeId = (SELECT SCOPE_IDENTITY());
						
						--Now we will insert new insuree in the table tblInsureePolicy
						EXEC uspAddInsureePolicy @NewInsureeId
						
						
						--Insert a record in tblPhotos
						INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
						SELECT InsureeID,CHFID,'','',0,GETDATE(),ValidityFrom,AuditUserID FROM tblInsuree WHERE InsureeID = @NewInsureeId;
						
						--UPDATE newly inserted PhotoId Back to the tblInsuree
						UPDATE tblInsuree SET PhotoID = (SELECT IDENT_CURRENT('tblPhotos')) WHERE InsureeID = @NewInsureeId;
						
						--IF the insuree is the head of the family then update the newly added InsureeId in tblFamily
						IF @IsHead = 1
						BEGIN
							
							
							UPDATE tblFamilies SET InsureeID = @NewInsureeId WHERE FamilyID = @FamilyId AND ValidityTo IS NULL;
						END
						
						DECLARE Cur CURSOR FOR SELECT PolicyID,PolicyValue,PolicyStage FROM tblPolicy WHERE FamilyID = @FamilyId AND ValidityTo IS NULL
						OPEN Cur
							FETCH NEXT FROM Cur INTO @PolId,@PolVal,@PolicyStage
							WHILE @@FETCH_STATUS = 0
							BEGIN
								EXEC @NewPolVal = uspPolicyValue @PolicyId = @PolId,@PolicyStage = @PolicyStage, @ErrorCode= 0;
								IF @PolVal <> @NewPolVal	--Value is changed after adding this insuree
								BEGIN
									INSERT INTO tblPolicy (FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStatus,PolicyValue,isOffline, ValidityTo, LegacyID, AuditUserID)
									SELECT	FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStatus,PolicyValue,isOffline, GetDate(), @PolId, AuditUserID FROM tblPolicy WHERE PolicyID = @PolId;
							
									--Update ExpiryDate ,EffiectiveDate and status of the policy
									UPDATE tblPolicy SET PolicyValue = @NewPolVal WHERE PolicyID = @PolId;
							
									INSERT INTO @tblResult(Result)
											VALUES('Policy Value is changed after adding Insurance Code: ' + @CHFID)
									
								END
							FETCH NEXT FROM Cur INTO @PolId,@PolVal,@PolicyStage
							END
						CLOSE Cur
						DEALLOCATE Cur
						
					END
			FETCH_NEXT:
					FETCH NEXT FROM CurInsuree INTO @InsureeId
				END
			CLOSE CurInsuree
			DEALLOCATE CurInsuree
			
			SET @InsureeImported = @Counter;
			SET @Counter = 0;
			
			PRINT 'INSERTING ALL THE POLICIES'

			--INSERT ALL THE POLICIES
			DECLARE @PolicyID INT,
					@NewPolicyID INT,
					@PolicyCHFID NVARCHAR(12),
					@Product NVARCHAR(20)
					
			DECLARE CurPolicy CURSOR FOR SELECT PolicyId FROM @tblPolicy
			OPEN CurPolicy
				FETCH NEXT FROM CurPolicy INTO @PolicyID
				WHILE @@FETCH_STATUS = 0
				BEGIN
					--Check if the policy already exists
					IF NOT EXISTS(SELECT 1 FROM tblPolicy PL INNER JOIN @tblPolicy PL1 ON PL.FamilyID = PL1.FamilyId AND PL.EnrollDate = PL1.EnrollDate AND PL.StartDate = PL1.StartDate AND PL.ProdID = PL1.ProdId WHERE PL1.PolicyId = @PolicyID AND PL.ValidityTo IS NULL)
					BEGIN
						INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID)
						SELECT F.FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,GETDATE(),-1 
						FROM @tblPolicy PL INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID 
						WHERE PolicyId = @PolicyID;
						



						IF @@ROWCOUNT > 0
							SET @Counter = @Counter + 1;	
						
						--GET the newly added PolicyId 
						SET @NewPolicyID = (SELECT SCOPE_IDENTITY());
						




					
						--Also insert all the family memebers to the table tblInsureePolicy
						INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,AuditUserId)
						SELECT I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,TI.EffectiveDate,PL.ExpiryDate,PL.AuditUserID 
						FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID 
						INNER JOIN @tblInsuree TI ON TI.CHFID=I.CHFID
						WHERE(I.ValidityTo Is NULL) AND PL.ValidityTo IS NULL 
						AND PL.PolicyID = @NewPolicyID
						








						--UPDATE @tblPremium's PolicyId with new policyId
						UPDATE @tblPremium SET PolicyId = @NewPolicyID, Updated = 1 WHERE PolicyId = @PolicyID AND Updated = 0;
					END
					ELSE
					BEGIN
						--It is a duplicate Policy
						SET @PolicyCHFID = (SELECT CHFID FROM tblInsuree WHERE IsHead = 1 AND FamilyID = (SELECT FamilyID FROM @tblPolicy WHERE PolicyId = @PolicyID))
						SET @Product = (SELECT ProductCode FROM tblProduct WHERE ProdID = (SELECT ProdID FROM @tblPolicy WHERE PolicyId = @PolicyID))
						INSERT INTO @tblResult(Result) VALUES('Policy for the family : ' + @PolicyCHFID + ' with Product Code:' + @Product + ' already exists')

						SET @NewPolicyId = (SELECT TOP 1 PL.PolicyID FROM tblPolicy PL INNER JOIN @tblPolicy PL1 ON PL.FamilyID = PL1.FamilyId AND PL.EnrollDate = PL1.EnrollDate AND PL.StartDate = PL1.StartDate AND PL.ProdID = PL1.ProdId WHERE PL1.PolicyId = @PolicyID AND PL.ValidityTo IS NULL)
						UPDATE @tblPremium SET PolicyId = @NewPolicyID, Updated = 1 WHERE PolicyId = @PolicyID AND Updated = 0;		


					END
					FETCH NEXT FROM CurPolicy INTO @PolicyID
				END
			CLOSE CurPolicy
			DEALLOCATE CurPolicy
			
			SET @PolicyImported = @Counter;
			SET @Counter = 0;
			
			PRINT 'INSERTING ALL THE PREMIUM'

			--INSERT ALL THE PREMIUMS 
			DECLARE @PremiumId INT,
					@NewPremiumID INT,
					@TotalPremiumCollection DECIMAL(18,2),
					@PolicyValue DECIMAL(18,2),
					@InsurancePeriod INT,
					@Recipt NVARCHAR(50),
					@EffectiveDate DATE,
					@PayDate DATE
					
			DECLARE CurPremium CURSOR FOR SELECT PremiumId FROM @tblPremium
			OPEN CurPremium
				FETCH NEXT FROM CurPremium INTO @PremiumID
				WHILE @@FETCH_STATUS = 0
				BEGIN
					--Check if premium already exists
					IF NOT EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN @tblPremium PR1 ON PR.PolicyID = PR1.PolicyId AND PR.Amount = PR1.Amount AND PR.Receipt = PR1.Receipt WHERE PR1.PremiumId = @PremiumId AND PR.ValidityTo IS NULL)
					BEGIN
						--GET THE PolicyId 
						SET @PolicyID = (SELECT PolicyID FROM @tblPremium WHERE PremiumId = @PremiumId)
						SET @PolicyValue = (SELECT PolicyValue FROM tblPolicy WHERE PolicyID = @PolicyID)
						SET @EffectiveDate = (SELECT EffectiveDate FROM tblPolicy where PolicyID = @PolicyID)
						--SET @InsurancePeriod =(SELECT InsurancePeriod FROM tblProduct WHERE ProdID = (SELECT ProdID FROM tblPolicy WHERE PolicyID = @PolicyID))
						
						INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee)
						SELECT PolicyID,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),-1,isPhotoFee FROM @tblPremium WHERE PremiumId = @PremiumId
					
						IF @@ROWCOUNT > 0
							SET @Counter = @Counter + 1;
					END
					ELSE
					BEGIN
						--Duplicate Primium found
						SET @Recipt = (SELECT Receipt FROM @tblPremium WHERE PremiumId = @PremiumId)
						INSERT INTO @tblResult(Result) VALUES('Premium on receipt number ' + @Recipt + ' already exists.')
					END
					
					
					
					
					--Perform update of the policy only if the policy was not created offline
					IF NOT EXISTS(SELECT 1 FROM @tblPolicy WHERE PolicyId = @PolicyID)
					BEGIN
					--Get all the premium collection against this policy
						SELECT @TotalPremiumCollection = ISNULL(SUM(Amount),0) FROM tblPremium WHERE ValidityTo IS NULL AND PolicyID = @PolicyID AND isPhotoFee = 0
						
						--If total collection convers the policy value then make the policy active
						IF @TotalPremiumCollection >= @PolicyValue
						BEGIN
							INSERT INTO tblPolicy (FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStage,PolicyStatus,PolicyValue,isOffline, ValidityTo, LegacyID, AuditUserID)
							SELECT	FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, ProdID, OfficerID,PolicyStage,PolicyStatus,PolicyValue,isOffline, GetDate(), @PolicyID, AuditUserID FROM tblPolicy WHERE PolicyID = @PolicyID;
							
							SET @PayDate = (SELECT TOP 1 PayDate FROM tblPremium WHERE PolicyID = @PolicyID AND ValidityTo IS NULL AND isPhotoFee = 0 ORDER BY PremiumId DESC)
							
							--IF policy is in idle state then Make it active and also active all the insurees belong to that policy
							IF @EffectiveDate IS NULL
								UPDATE tblPolicy SET EffectiveDate = @PayDate,PolicyStatus = 2 WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
							ELSE
							--IF policy is already in active state and insurees are not yet convered then activate those insurees
								UPDATE tblInsureePolicy SET EffectiveDate = @PayDate WHERE ValidityTo IS NULL AND EffectiveDate IS NULL AND PolicyId = @PolicyId
						END
					END
					FETCH NEXT FROM CurPremium INTO @PremiumID
				END
			CLOSE CurPremium
			DEALLOCATE CurPremium
			
			SET @PremiumImported = @Counter;
			SET @Counter = 0;
	
--Check if any family has double Head Of Family....If found any then throw an exception and rollback everything
			
			IF EXISTS(SELECT COUNT(1) 
			FROM tblInsuree 
			WHERE ValidityTo IS NULL
			AND IsHead = 1
			GROUP BY FamilyID
			HAVING COUNT(1) > 1)
			
			--Added 06/12 by Amani
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
		COMMIT TRAN Enrol
		
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRAN Enrol
		END
		SELECT ERROR_MESSAGE()
		--RETURN -1
		GOTO EndOfTheProcess
	END CATCH

EndOfTheProcess:	
	SELECT Result FROM @tblResult
	RETURN 0
END

GO
