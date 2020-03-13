--- MIGRATION Script from v1.4.0 to v1.4.1

-- OP-140 : Fixing uspConsumeEnrollments stored procedure

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[uspConsumeEnrollments](
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

-- OP-154: database partitioning  

-- Adds four new filegroups to the database  
BEGIN TRY
	BEGIN TRANSACTION; 
	
	-- if the DATETIME provided in before 1970 then it goes to partition 1 else it goes to partition 2
	CREATE PARTITION FUNCTION [StillValid] (DATETIME) AS RANGE LEFT
	FOR
	VALUES (
		N'1970-01-01T00:00:00.001'
		)

	-- Create partition Scheme that will define the partition to be used, both use the PRIMARY file group (not IDEAL but done to limit changes in a crisis mode)
	CREATE PARTITION SCHEME [liveArchive] AS PARTITION [StillValid] TO (
		[PRIMARY]
		,[PRIMARY]
	)

	ALTER TABLE tblClaimItems DROP CONSTRAINT [FK_tblClaimItems_tblClaim-ClaimID] 
	ALTER TABLE tblClaimServices DROP CONSTRAINT [FK_tblClaimServices_tblClaim-ClaimID] 
	ALTER TABLE tblFeedback DROP CONSTRAINT [FK_tblFeedback_tblClaim-ClaimID]
	
	-- Modular
	IF OBJECT_ID('claim_ClaimAttachment') IS NOT NULL
	BEGIN
		ALTER TABLE claim_ClaimAttachment DROP CONSTRAINT claim_ClaimAttachment_claim_id_6d421217_fk_tblClaim_ClaimID	
	END

	IF OBJECT_ID('claim_ClaimMutation') IS NOT NULL
	BEGIN
		ALTER TABLE claim_ClaimMutation DROP CONSTRAINT claim_ClaimMutation_claim_id_22e307c0_fk_tblClaim_ClaimID
	END

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

	IF OBJECT_ID('claim_ClaimAttachment') IS NOT NULL
	BEGIN
		ALTER TABLE [claim_ClaimAttachment] ADD CONSTRAINT claim_ClaimAttachment_claim_id_6d421217_fk_tblClaim_ClaimID FOREIGN KEY(claim_id) REFERENCES [tblClaim] (ClaimID)
	END

	IF OBJECT_ID('claim_ClaimMutation') IS NOT NULL
	BEGIN
		ALTER TABLE claim_ClaimMutation ADD CONSTRAINT claim_ClaimMutation_claim_id_22e307c0_fk_tblClaim_ClaimID FOREIGN KEY(claim_id) REFERENCES [tblClaim] (ClaimID)
	END
	
	ALTER TABLE [tblClaimItems] DROP CONSTRAINT [PK_tblClaimItems]
	CREATE UNIQUE CLUSTERED INDEX CI_tblClaimItemsValid ON tblClaimItems (ClaimItemID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)
	ALTER TABLE tblClaimItems ADD CONSTRAINT PK_tblClaimItems PRIMARY KEY NONCLUSTERED (ClaimItemID) ON [PRIMARY];
		
	ALTER TABLE [tblClaimServices] DROP CONSTRAINT [PK_tblClaimServices]
		
	CREATE UNIQUE CLUSTERED INDEX CI_tblClaimServicesValid ON  tblClaimServices (ClaimServiceID,ValidityTo)
	WITH
	(	PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
	) ON liveArchive(ValidityTo)
	ALTER TABLE tblClaimServices ADD CONSTRAINT PK_tblClaimServices PRIMARY KEY NONCLUSTERED (ClaimServiceID) ON [PRIMARY];
	
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
	ALTER TABLE [tblFamilies] ADD CONSTRAINT [FK_tblFamilies_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblHealthStatus] ADD CONSTRAINT [FK_tblHealthStatus_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblInsureePolicy] ADD CONSTRAINT [FK_tblInsureePolicy_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblPolicyRenewalDetails] ADD CONSTRAINT [FK_tblPolicyRenewalDetails_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)
	ALTER TABLE [tblPolicyRenewals] ADD CONSTRAINT [FK_tblPolicyRenewals_tblInsuree-InsureeID] FOREIGN KEY(InsureeID) REFERENCES [tblInsuree] (InsureeID)

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
	CREATE UNIQUE CLUSTERED INDEX CI_tblLocations ON tblLocations (LocationId,ValidityTo)
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

-- OP-154: add indexed to Location views

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

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
