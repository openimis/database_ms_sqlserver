--- MIGRATION Script from v1.4.2 onward

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
---------------------------- Structural changes ------------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

-- OTC-111: Changing the logic of user Roles

IF COL_LENGTH('tblUserRole', 'Assign') IS NULL
BEGIN
	ALTER TABLE tblUserRole ADD Assign int NULL 
	CONSTRAINT AssignDefaultConstraint DEFAULT 3 
	WITH VALUES
END
GO

IF TYPE_ID(N'xClaimRejReasons') IS NULL
BEGIN
CREATE TYPE [dbo].[xClaimRejReasons] AS TABLE(
	[ID] [int] NOT NULL,
	[Name] [nvarchar](100) NULL
)
END
GO
-- OP-275: Commission repport error
IF COL_LENGTH('tblPremium', 'OverviewCommissionReport') IS NULL
BEGIN
	ALTER TABLE tblPremium ADD OverviewCommissionReport datetime NULL 
END
GO
IF COL_LENGTH('tblPremium', 'AllDetailsCommissionReport') IS NULL
BEGIN
	ALTER TABLE tblPremium ADD AllDetailsCommissionReport datetime NULL 
END
GO
IF COL_LENGTH('tblPremium', 'ReportingCommisionID') IS NOT NULL
BEGIN
	ALTER TABLE tblPremium DROP COLUMN ReportingCommisionID
END
GO

IF TYPE_ID(N'xtblUserRole') IS NULL
BEGIN
	CREATE TYPE [dbo].[xtblUserRole] AS TABLE(
		[UserRoleID] [int] NOT NULL,
		[UserID] [int] NOT NULL,
		[RoleID] [int] NOT NULL,
		[ValidityFrom] [datetime] NULL,
		[ValidityTo] [datetime] NULL,
		[AudituserID] [int] NULL,
		[LegacyID] [int] NULL,
		[Assign] [int] NULL
)
END 
GO

-- OP-153: Additional items in the Reports section
IF COL_LENGTH('tblReporting', 'ReportMode') IS NULL
BEGIN
	ALTER TABLE tblReporting ADD ReportMode int 
	CONSTRAINT ReportModeDefaultConstraint DEFAULT 0 
	WITH VALUES
END 
GO

-- OP-276: New state of policies
IF COL_LENGTH('tblIMISDefaults', 'ActivationOption') IS NULL
BEGIN
	ALTER TABLE tblIMISDefaults ADD ActivationOption tinyint NOT NULL 
	CONSTRAINT ActivationOptionDefaultConstraint DEFAULT 2 
	WITH VALUES
END
GO

--OTC-149: Cannot access to report page 
IF COL_LENGTH('tblReporting', 'Scope') IS NULL
BEGIN
	ALTER TABLE tblReporting ADD [Scope] [int] NULL
END 
GO

IF COL_LENGTH('tblPayment', 'SmsRequired') IS NULL
BEGIN
	ALTER TABLE tblPayment ADD [SmsRequired] [bit] NULL
END 
GO

if not exists (
    select *
      from sys.all_columns c
      join sys.tables t on t.object_id = c.object_id
      join sys.schemas s on s.schema_id = t.schema_id
      join sys.default_constraints d on c.default_object_id = d.object_id
    where t.name = 'tblPayment'
      and c.name = 'PaymentUUID'
      and s.name = 'dbo')
ALTER TABLE [dbo].[tblPayment] ADD DEFAULT (newid()) FOR PaymentUUID
GO

ALTER VIEW [dbo].[uvwLocations]
AS
	SELECT 0 LocationId, NULL VillageId, NULL VillageName,NULL VillageCode, NULL WardId, NULL WardName,NULL WardCode, NULL DistrictId,NULL DistrictName, NULL DistrictCode, NULL RegionId, N'National' RegionName, NULL RegionCode, 0 ParentLocationId

	UNION ALL

	SELECT V.LocationId, V.LocationId VillageId, V.LocationName VillageName,V.LocationCode VillageCode, W.LocationId WardId, W.LocationName WardName,W.LocationCode WardCode, D.LocationId DistrictId, D.LocationName DistrictName, D.LocationCode DistrictCode, R.LocationId RegionId, R.LocationName RegionName , R.LocationCode RegionCode, V.ParentLocationId  FROM tblLocations R
	INNER JOIN tblLocations D  on R.LocationId = D.ParentLocationId AND D.ValidityTo IS NULL AND D.LocationType = 'D' 
	INNER JOIN tblLocations W  on D.LocationId = W.ParentLocationId AND W.ValidityTo IS NULL AND W.LocationType = 'W' 
	INNER JOIN tblLocations V  on W.LocationId = V.ParentLocationId AND V.ValidityTo IS NULL AND V.LocationType = 'V' 
	WHERE R.ValidityTo IS NULL AND R.LocationType = 'R'

	UNION ALL

	SELECT W.LocationId, NULL VillageId, NULL VillageName, NULL VillageCode, W.LocationId WardId, W.LocationName WardName,W.LocationCode WardCode,D.LocationId DistrictId, D.LocationName DistrictName, D.LocationCode DistrictCode, R.LocationId RegionId, R.LocationName RegionName , R.LocationCode RegionCode, W.ParentLocationId FROM tblLocations R
	INNER JOIN tblLocations D  on R.LocationId = D.ParentLocationId AND D.ValidityTo IS NULL AND D.LocationType = 'D' 
	INNER JOIN tblLocations W  on D.LocationId = W.ParentLocationId AND W.ValidityTo IS NULL AND W.LocationType = 'W' 
	WHERE R.ValidityTo IS NULL AND R.LocationType = 'R'

	UNION ALL

	SELECT D.LocationId, NULL VillageId, NULL VillageName,NULL VillageCode, NULL WardId, NULL WardName,NULL WardCode,D.LocationId DistrictId, D.LocationName DistrictName,D.LocationCode DistrictCode, R.LocationId RegionId, R.LocationName RegionName , R.LocationCode RegionCode, D.ParentLocationId FROM tblLocations R
	INNER JOIN tblLocations D  on R.LocationId = D.ParentLocationId AND D.ValidityTo IS NULL AND D.LocationType = 'D' 
	WHERE R.ValidityTo IS NULL AND R.LocationType = 'R'

	UNION ALL

	SELECT R.LocationId, NULL VillageId, NULL VillageName,NULL VillageCode, NULL WardId, NULL WardName,NULL WardCode, NULL DistrictId,NULL DistrictName, NULL DistrictCode, R.LocationId RegionId, R.LocationName RegionName, R.LocationCode RegionCode, 0 ParentLocationId FROM tblLocations R
	WHERE R.ValidityTo IS NULL AND R.LocationType = 'R'

Go

-- Missing column in tblProduct
IF COL_LENGTH('tblProduct', 'Recurrence') IS NULL
BEGIN
	ALTER TABLE tblProduct ADD Recurrence tinyint NULL
END
GO

IF COL_LENGTH('tblPolicy', 'RenewalOrder') IS NULL
BEGIN
	ALTER TABLE tblPolicy ADD [RenewalOrder] [int] NULL
END
GO

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------- Stored Procedures ----------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------


-- OP-277: Modify a member or family fails   

IF OBJECT_ID('uspConsumeEnrollments', 'P') IS NOT NULL
    DROP PROCEDURE uspConsumeEnrollments
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspConsumeEnrollments](
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
		T.I.value('(PhotoPath)[1]','NVARCHAR(100)')
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
            SELECT CHFID
            FROM (
            SELECT CHFID FROM @insureeToProcess
            UNION ALL
            SELECT CHFID FROM @tblInsuree TI
            ) tbl
            GROUP BY CHFID
            HAVING count(*) = 1
            ORDER BY CHFID;

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
								SELECT 0 , TF.LocationId, TF.Poverty, GETDATE() , @AuditUserId , TF.FamilyType, TF.FamilyAddress, TF.Ethnicity, TF.ConfirmationNo, ConfirmationType, 0 FROM @tblFamilies TF
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
								@AuditUserId AuditUserId, Relationship, Profession, Education, Email, TypeOfId, HFID, CurrentAddress, GeoLocation, CurVillage, 0
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
							SELECT	 ABS(NewFamilyID),EnrollDate,StartDate,@EffectiveDate,ExpiryDate,@PolicyStatus,@PolicyValue,ProdID,@OfficerID,PolicyStage,GETDATE(),@AuditUserId, 0 FROM @tblPolicy WHERE PolicyId=@PolicyId
							SELECT @NewPolicyId = SCOPE_IDENTITY()
							INSERT INTO @tblIds(OldId, [NewId]) VALUES(@PolicyId, @NewPolicyId)
							
							IF @@ROWCOUNT > 0
								BEGIN
									SET @PolicyImported = ISNULL(@PolicyImported,0) +1
									UPDATE @tblInureePolicy SET NewPolicyId = @NewPolicyId WHERE PolicyId=@PolicyId
									UPDATE @tblPremium SET NewPolicyId =@NewPolicyId  WHERE PolicyId = @PolicyId
									INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee,isOffline)
									SELECT NewPolicyId,PayerID,Amount,Receipt,PayDate,PayType,GETDATE(),@AuditUserId,isPhotoFee, 0
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
								 NewInsureeId,IP.NewPolicyId,@EnrollDate,@StartDate,IP.[EffectiveDate],@ExpiryDate,GETDATE(),@AuditUserId, 0 FROM @tblInureePolicy IP
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

--OP-222: BEPHA Claims from phones do not have an admin code assigned 
IF OBJECT_ID('uspUpdateClaimFromPhone', 'P') IS NOT NULL
    DROP PROCEDURE uspUpdateClaimFromPhone
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

--OP-190: BEPHA Policies App: Marital Status shows "-- Select Status--"
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

UPDATE tblInsuree SET Marital = null Where Marital = '';

-- OP-238: Discrepancy in reporting of IMIS Policies
DECLARE @SystemRole INT
SELECT @SystemRole = role.RoleID from tblRole role where IsSystem=1;

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 131201)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom], [ValidityTo], [AuditUserId], [LegacyID]) 
	VALUES (@SystemRole, 131201, CURRENT_TIMESTAMP, NULL, NULL, NULL)
END

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 131200)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom], [ValidityTo], [AuditUserId], [LegacyID]) 
	VALUES (@SystemRole, 131200, CURRENT_TIMESTAMP, NULL, NULL, NULL)
END
GO

-- OTC-66: User roles: Add Renewal Upload right to Scheme Administrator role

DECLARE @SystemRole INT
SELECT @SystemRole = role.RoleID from tblRole role where IsSystem=32;

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 131107)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom], [ValidityTo], [AuditUserId], [LegacyID]) 
	VALUES (@SystemRole, 131107, CURRENT_TIMESTAMP, NULL, NULL, NULL)
END
GO

-- OP-278: The system role Claim Administrator role doesn't have the required rights
DECLARE @SystemRole INT
SELECT @SystemRole = role.RoleID from tblRole role where IsSystem=256;

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 101001)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom]) 
	VALUES (@SystemRole, 101001, CURRENT_TIMESTAMP)
END 

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 101101)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom]) 
	VALUES (@SystemRole, 101101, CURRENT_TIMESTAMP)
END 

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 101201)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom]) 
	VALUES (@SystemRole, 101201, CURRENT_TIMESTAMP)
END 

IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 111012)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom]) 
	VALUES (@SystemRole, 111012, CURRENT_TIMESTAMP)
END 

-- OP-141: Fixing uspSSRSCapitationPayment stored procedure

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('uspSSRSCapitationPayment', 'P') IS NOT NULL
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

		set @DistrictId = CASE WHEN @DistrictId = 0 THEN NULL ELSE @DistrictId END

		DECLARE @Locations TABLE (
			LocationId INT,
			LocationName VARCHAR(50),
			LocationCode VARCHAR(8),
			ParentLocationId INT
			);
	    
		INSERT INTO @Locations 
		    SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId,  0 LocationCode
		    
			UNION ALL
		    
			SELECT LocationId,LocationName, LocationCode, ISNULL(ParentLocationId, 0) 
			FROM tblLocations 
			WHERE (ValidityTo IS NULL )
				AND (LocationId = ISNULL(@DistrictId, @RegionId) OR 
				(LocationType IN ('R', 'D') AND ParentLocationId = ISNULL(@DistrictId, @RegionId)))
		    
			/*UNION ALL
		    
			SELECT L.LocationId, L.LocationName, L.ParentLocationId 
		    FROM tblLocations L 
		    INNER JOIN @Locations LC ON @LC.LocationId = L.ParentLocationId
		    WHERE L.validityTo IS NULL
		    AND L.LocationType IN ('R', 'D')*/
		
		DECLARE @LocationTemp table (LocationId int, RegionId int, RegionCode [nvarchar](8) , RegionName [nvarchar](50), DistrictId int, DistrictCode [nvarchar](8), 
			DistrictName [nvarchar](50), ParentLocationId int)
		

		INSERT INTO  @LocationTemp(LocationId , RegionId , RegionCode , RegionName , DistrictId , DistrictCode , 
		DistrictName , ParentLocationId)( SELECT ISNULL(d.LocationId,r.LocationId) LocationId , r.LocationId as RegionId , r.LocationCode as RegionCode  , r.LocationName as RegionName , d.LocationId as DistrictId , d.LocationCode as DistrictCode , 
		r.LocationName as DistrictName , ISNULL(d.ParentLocationId,r.ParentLocationId) ParentLocationId FROM @Locations  d  INNER JOIN @Locations r on d.ParentLocationId = r.LocationId
		UNION ALL SELECT r.LocationId, r.LocationId as RegionId , r.LocationCode as RegionCode  , r.LocationName as RegionName , NULL DistrictId , NULL DistrictCode , 
		NULL DistrictName ,  ParentLocationId FROM @Locations  r WHERE ParentLocationId = 0)
		;
		declare @listOfHF table (id int);
		
		IF  @RegionId IS  NULL or @RegionId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.ValidityTo is NULL;
		 ELSE IF  @DistrictId is NULL or @DistrictId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF JOIN tblLocations l on tblHF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId  ;
		ELSE 
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.LocationId = @DistrictId and tblHF.ValidityTo is NULL;


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


	    DECLARE @TotalPopFam TABLE (
			HFID INT,
			TotalPopulation DECIMAL(18, 6), 
			TotalFamilies DECIMAL(18, 6)
			);

		INSERT INTO @TotalPopFam 
	    
		    SELECT C.HFID HFID ,
		    CASE WHEN ISNULL(@DistrictId, @RegionId) IN (D.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM((ISNULL(L.MalePopulation, 0) + ISNULL(L.FemalePopulation, 0) + ISNULL(L.OtherPopulation, 0)) *(0.01* Catchment)) TotalPopulation, 
		    CASE WHEN ISNULL(@DistrictId, @RegionId) IN (D.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM(ISNULL(((L.Families)*(0.01* Catchment)), 0))TotalFamilies
		    FROM tblHFCatchment C
		    LEFT JOIN tblLocations L ON L.LocationId = C.LocationId OR  L.LegacyId = C.LocationId
		    INNER JOIN tblHF HF ON C.HFID = HF.HfID
		    INNER JOIN @LocationTemp D ON HF.LocationId = D.DistrictId
		    WHERE (C.ValidityTo IS NULL OR C.ValidityTo >= @FirstDay) AND C.ValidityFrom< @FirstDay
		    AND(L.ValidityTo IS NULL OR L.ValidityTo >= @FirstDay) AND L.ValidityFrom< @FirstDay
		    AND (HF.ValidityTo IS NULL )
			AND C.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY C.HFID, D.DistrictId, D.RegionId
	    


		DECLARE @InsuredInsuree TABLE (
			HFID INT,
			ProdId INT, 
			TotalInsuredInsuree DECIMAL(18, 6)
			);

		INSERT INTO @InsuredInsuree
	    
		    SELECT HC.HFID, @ProdId ProdId, COUNT(DISTINCT IP.InsureeId)*(0.01 * Catchment) TotalInsuredInsuree
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyId
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
			AND HC.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY HC.HFID, Catchment--, L.LocationId


			

		DECLARE @InsuredFamilies TABLE (
			HFID INT,
			TotalInsuredFamilies DECIMAL(18, 6)
			);

		INSERT INTO @InsuredFamilies
		    SELECT HC.HFID, COUNT(DISTINCT F.FamilyID)*(0.01 * Catchment) TotalInsuredFamilies
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
			AND HC.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY HC.HFID, Catchment--, L.LocationId




		
	    
		DECLARE @Allocation TABLE (
			ProdId INT,
			Allocated DECIMAL(18, 6)
			);
	    
		INSERT INTO @Allocation
	        SELECT ProdId, CAST(SUM(ISNULL(Allocated, 0)) AS DECIMAL(18, 6)) Allocated
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
		    INNER JOIN  @Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
		    WHERE PR.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND PL.ProdID = @ProdId
		    AND PL.PolicyStatus <> 1
		    AND PR.PayDate <= PL.ExpiryDate
		    GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate)Alc
		    GROUP BY ProdId;
	    

		DECLARE @ReportData TABLE (
			RegionCode VARCHAR(MAX),
			RegionName VARCHAR(MAX),
			DistrictCode VARCHAR(MAX),
			DistrictName VARCHAR(MAX),
			HFCode VARCHAR(MAX),
			HFName VARCHAR(MAX),
			AccCode VARCHAR(MAX),
			HFLevel VARCHAR(MAX),
			HFSublevel VARCHAR(MAX),
			TotalPopulation DECIMAL(18, 6),
			TotalFamilies DECIMAL(18, 6),
			TotalInsuredInsuree DECIMAL(18, 6),
			TotalInsuredFamilies DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6),
			TotalAdjusted DECIMAL(18, 6),

			PaymentCathment DECIMAL(18, 6),
			AlcContriPopulation DECIMAL(18, 6),
			AlcContriNumFamilies DECIMAL(18, 6),
			AlcContriInsPopulation DECIMAL(18, 6),
			AlcContriInsFamilies DECIMAL(18, 6),
			AlcContriVisits DECIMAL(18, 6),
			AlcContriAdjustedAmount DECIMAL(18, 6),
			UPPopulation DECIMAL(18, 6),
			UPNumFamilies DECIMAL(18, 6),
			UPInsPopulation DECIMAL(18, 6),
			UPInsFamilies DECIMAL(18, 6),
			UPVisits DECIMAL(18, 6),
			UPAdjustedAmount DECIMAL(18, 6)
			

			);
	    
		DECLARE @ClaimValues TABLE (
			HFID INT,
			ProdId INT,
			TotalAdjusted DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6)
			);

		INSERT INTO @ClaimValues
		SELECT HFID, @ProdId ProdId, SUM(TotalAdjusted)TotalAdjusted, COUNT(DISTINCT ClaimId)TotalClaims FROM
		(
			SELECT HFID, SUM(PriceValuated)TotalAdjusted, ClaimId
			FROM 
			(SELECT HFID,c.ClaimId, PriceValuated FROM  tblClaim C WITH (NOLOCK)
			 LEFT JOIN tblClaimItems ci ON c.ClaimID = ci.ClaimID and  ProdId = @ProdId AND (@WeightAdjustedAmount > 0.0)
			 WHERE CI.ValidityTo IS NULL  AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month
				AND C.HFID  in  (SELECT id FROM @listOfHF)and ci.ValidityTo IS NULL 
			UNION ALL
			SELECT HFID, c.ClaimId, PriceValuated FROM tblClaim C WITH (NOLOCK) 
			LEFT JOIN tblClaimServices cs ON c.ClaimID = cs.ClaimID   and  ProdId = @ProdId AND (@WeightAdjustedAmount > 0.0)
			WHERE cs.ValidityTo IS NULL  	AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month	
				AND C.HFID  in (SELECT id FROM @listOfHF) and CS.ValidityTo IS NULL 
			) claimdetails GROUP BY HFID,ClaimId
		)claims GROUP by HFID

	    INSERT INTO @ReportData 
		    SELECT L.RegionCode, L.RegionName, L.DistrictCode, L.DistrictName, HF.HFCode, HF.HFName, Hf.AccCode, 
			HL.Name HFLevel, 
			SL.HFSublevelDesc HFSublevel,
		    PF.[TotalPopulation] TotalPopulation, PF.TotalFamilies TotalFamilies, II.TotalInsuredInsuree, IFam.TotalInsuredFamilies, CV.TotalClaims, CV.TotalAdjusted
		    ,(
			      ISNULL(ISNULL(PF.[TotalPopulation], 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightPopulation)) /  NULLIF(SUM(PF.[TotalPopulation])OVER(),0),0)  
			    + ISNULL(ISNULL(PF.TotalFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberFamilies)) /NULLIF(SUM(PF.[TotalFamilies])OVER(),0),0) 
			    + ISNULL(ISNULL(II.TotalInsuredInsuree, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightInsuredPopulation)) /NULLIF(SUM(II.TotalInsuredInsuree)OVER(),0),0) 
			    + ISNULL(ISNULL(IFam.TotalInsuredFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberInsuredFamilies)) /NULLIF(SUM(IFam.TotalInsuredFamilies)OVER(),0),0) 
			    + ISNULL(ISNULL(CV.TotalClaims, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberVisits)) /NULLIF(SUM(CV.TotalClaims)OVER() ,0),0) 
			    + ISNULL(ISNULL(CV.TotalAdjusted, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightAdjustedAmount)) /NULLIF(SUM(CV.TotalAdjusted)OVER(),0),0)

		    ) PaymentCathment

		    , A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution) AlcContriPopulation
		    , A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution) AlcContriNumFamilies
		    , A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution) AlcContriInsPopulation
		    , A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution) AlcContriInsFamilies
		    , A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution) AlcContriVisits
		    , A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution) AlcContriAdjustedAmount

		    ,  ISNULL((A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution))/ NULLIF(SUM(PF.[TotalPopulation]) OVER(),0),0) UPPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution))/NULLIF(SUM(PF.TotalFamilies) OVER(),0),0) UPNumFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution))/NULLIF(SUM(II.TotalInsuredInsuree) OVER(),0),0) UPInsPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution))/ NULLIF(SUM(IFam.TotalInsuredFamilies) OVER(),0),0) UPInsFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution)) / NULLIF(SUM(CV.TotalClaims) OVER(),0),0) UPVisits
		    ,  ISNULL((A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution))/ NULLIF(SUM(CV.TotalAdjusted) OVER(),0),0) UPAdjustedAmount
			
		    FROM tblHF HF
		    INNER JOIN @HFLevel HL ON HL.Code = HF.HFLevel
		    LEFT OUTER JOIN tblHFSublevel SL ON SL.HFSublevel = HF.HFSublevel
		    LEFT JOIN @LocationTemp L ON L.LocationId = HF.LocationId
		    LEFT OUTER JOIN @TotalPopFam PF ON PF.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredInsuree II ON II.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredFamilies IFam ON IFam.HFID = HF.HfID
		   -- LEFT OUTER JOIN @Claims C ON C.HFID = HF.HfID
		    LEFT OUTER JOIN @ClaimValues CV ON CV.HFID = HF.HfID
		    LEFT OUTER JOIN @Allocation A ON A.ProdID = @ProdId

		    WHERE HF.ValidityTo IS NULL
		    AND (((L.RegionId = @RegionId OR @RegionId IS NULL) AND (L.DistrictId = @DistrictId OR @DistrictId IS NULL)) OR CV.ProdID IS NOT NULL OR II.ProdId IS NOT NULL)
		    AND (HF.HFLevel IN (@Level1, @Level2, @Level3, @Level4) OR (@Level1 IS NULL AND @Level2 IS NULL AND @Level3 IS NULL AND @Level4 IS NULL))
		    AND(
			    ((HF.HFLevel = @Level1 OR @Level1 IS NULL) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      );





	    SELECT  MAX (RegionCode)RegionCode, 
			MAX(RegionName)RegionName,
			MAX(DistrictCode)DistrictCode,
			MAX(DistrictName)DistrictName,
			HFCode, 
			MAX(HFName)HFName,
			MAX(AccCode)AccCode, 
			MAX(HFLevel)HFLevel, 
			MAX(HFSublevel)HFSublevel,
			ISNULL(SUM([TotalPopulation]),0)[Population],
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
	
	 FROM @ReportData

	 GROUP BY HFCode
END
GO


------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------- Indexes ----------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

BEGIN TRY
	BEGIN TRANSACTION; 
	CREATE NONCLUSTERED INDEX NCI_HF_ValidityTo ON tblHF(ValidityTo)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  

-- OP-154: database partitioning  
-- moved from migration 1.4.2 

-- Adds four new filegroups to the database  

-- if the DATETIME provided in before 1970 then it goes to partition 1 else it goes to partition 2
BEGIN TRY
	BEGIN TRANSACTION; 
	CREATE PARTITION FUNCTION [StillValid] (DATETIME) AS RANGE LEFT
	FOR
	VALUES (
		N'1970-01-01T00:00:00.001'
	)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  

-- Create partition Scheme that will define the partition to be used, both use the PRIMARY file group (not IDEAL but done to limit changes in a crisis mode)
BEGIN TRY
	BEGIN TRANSACTION; 
	CREATE PARTITION SCHEME [liveArchive] AS PARTITION [StillValid] TO (
		[PRIMARY]
		,[PRIMARY]
	)
	COMMIT TRANSACTION;  
END TRY
BEGIN CATCH  
     ROLLBACK  TRANSACTION;  
END CATCH  

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

-- add partial indexes
BEGIN TRY
	CREATE NONCLUSTERED INDEX NCI_R_tblLocations ON tblLocations (
		[LocationId] ASC,
		[LocationCode] ASC)
	INCLUDE(
		[LocationName],
		[ParentLocationId]
		)
	WHERE [ValidityTo] is NULL and [LocationType] = 'R'
END TRY
BEGIN CATCH  
END CATCH  
BEGIN TRY 
	CREATE NONCLUSTERED INDEX NCI_V_tblLocations ON tblLocations (
		[LocationId] ASC,
		[LocationCode] ASC)
	INCLUDE(
		[LocationName],
		[ParentLocationId]
		)
	WHERE [ValidityTo] is NULL and [LocationType] = 'V'
END TRY
BEGIN CATCH  
END CATCH  
BEGIN TRY
	CREATE NONCLUSTERED INDEX NCI_W_tblLocations ON tblLocations (
		[LocationId] ASC,
		[LocationCode] ASC)
	INCLUDE(
		[LocationName],
		[ParentLocationId]
		)
	WHERE [ValidityTo] is NULL and [LocationType] = 'W'
END TRY
BEGIN CATCH  
END CATCH  

BEGIN TRY
	CREATE NONCLUSTERED INDEX NCI_M_tblLocations ON tblLocations (
		[LocationId] ASC,
		[LocationCode] ASC)
	INCLUDE(
		[LocationName],
		[ParentLocationId]
		)
	WHERE [ValidityTo] is NULL and [LocationType] = 'M'
END TRY
BEGIN CATCH  

END CATCH  


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

IF OBJECT_ID('uspIndexRebuild', 'P') IS NOT NULL
    DROP PROCEDURE uspIndexRebuild
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Rebuilds all indexes on the openIMIS database
-- =============================================
CREATE PROCEDURE [dbo].[uspIndexRebuild] 
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

BEGIN TRY
-- partial index for user district
	CREATE NONCLUSTERED INDEX NCI_A_tblUsersDistricts
	ON [dbo].[tblUsersDistricts] ([UserID],[LocationId])
	WHERE ValidityTo is null
END TRY
BEGIN CATCH  
END CATCH  

BEGIN TRY
-- userdistrict index as sugested by ssms 
	CREATE NONCLUSTERED INDEX NCI_tblUserDistrict_locationId
	ON [dbo].[tblUsersDistricts] ([LocationId],[ValidityTo])
	INCLUDE ([UserID])
END TRY
BEGIN CATCH  
END CATCH  
GO

-- OP-280: FIX MISSING DETAILS (ONLY REJECTED SHOWED) - otc-45 RELATED
IF OBJECT_ID('uspSSRSPremiumCollection', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSPremiumCollection
GO

CREATE PROCEDURE [dbo].[uspSSRSPremiumCollection]
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

IF OBJECT_ID('uspSSRSProductSales', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSProductSales
GO

	CREATE PROCEDURE [dbo].[uspSSRSProductSales]
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

IF OBJECT_ID('uspSSRSPremiumDistribution', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSPremiumDistribution
GO

	CREATE PROCEDURE [dbo].[uspSSRSPremiumDistribution]
	(
		@Month INT,
		@Year INT,
		@LocationId INT = 0,
		@ProductID INT = 0
	)
	AS
	BEGIN
		IF NOT OBJECT_ID('tempdb..#tmpResult') IS NULL DROP TABLE #tmpResult
	
		CREATE TABLE #tmpResult(
			MonthID INT,
			DistrictName NVARCHAR(50),
			ProductCode NVARCHAR(8),
			ProductName NVARCHAR(100),
			TotalCollected DECIMAL(18,4),
			NotAllocated DECIMAL(18,4),
			Allocated DECIMAL(18,4)
		)

		DECLARE @Date DATE,
				@DaysInMonth INT,
				@Counter INT = 1,
				@MaxCount INT = 12,
				@EndDate DATE

		IF @Month > 0
		BEGIN
			SET @Counter = @Month
			SET @MaxCount = @Month
		END

		IF @LocationId = -1
		SET @LocationId = NULL

		WHILE @Counter <> @MaxCount + 1
		BEGIN	
			SELECT @Date = CAST(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-' + '01' AS DATE)
			SELECT @DaysInMonth = DATEDIFF(DAY,@Date,DATEADD(MONTH,1,@Date))
			SELECT @EndDate = CAST(CONVERT(VARCHAR(4),@Year) + '-' + CONVERT(VARCHAR(2),@Counter) + '-' + CONVERT(VARCHAR(2),@DaysInMonth) AS DATE)
				
			
			;WITH Locations AS
			(
				SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId
				UNION
				SELECT LocationId,LocationName, ISNULL(ParentLocationId, 0) FROM tblLocations WHERE ValidityTo IS NULL AND LocationId = @LocationId
				UNION ALL
				SELECT L.LocationId, L.LocationName, L.ParentLocationId 
				FROM tblLocations L 
				INNER JOIN Locations ON Locations.LocationId = L.ParentLocationId
				WHERE L.validityTo IS NULL
				AND L.LocationType IN ('R', 'D')
			)
			INSERT INTO #tmpResult
			SELECT MonthId,DistrictName,ProductCode,ProductName,SUM(ISNULL(TotalCollected,0))TotalCollected,SUM(ISNULL(NotAllocated,0))NotAllocated,SUM(ISNULL(Allocated,0))Allocated
			FROM 
			(
			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			SUM(PR.Amount) TotalCollected,
			0 NotAllocated,
			0 Allocated
			FROM tblPremium PR 
			RIGHT OUTER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations L ON  ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL
			AND PL.ValidityTo IS NULL
			AND Prod.ValidityTo IS NULL
			AND PL.PolicyStatus <> 1
			AND (Prod.ProdId = @ProductId OR @ProductId IS NULL)
			AND MONTH(PR.PayDate) = @Counter
			AND YEAR(PR.PayDate) = @Year
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate

			UNION ALL

			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			0 TotalCollected,
			SUM(PR.Amount) NotAllocated,
			0 Allocated
			FROM tblPremium AS PR INNER JOIN tblPolicy AS PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct AS Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations AS L ON ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL
			AND (MONTH(PR.PayDate ) = @Counter) 
			AND (YEAR(PR.PayDate) = @Year) 
			AND (Prod.ProdId = @ProductId OR @ProductId IS NULL) 
			AND (PL.PolicyStatus = 1)
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate

			UNION ALL

			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			0 TotalCollected,
			SUM(PR.Amount) NotAllocated,
			0 Allocated
			FROM tblPremium AS PR INNER JOIN tblPolicy AS PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct AS Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations AS L ON ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL
			AND (MONTH(PR.PayDate ) = @Counter) 
			AND (YEAR(PR.PayDate) = @Year) 
			AND (Prod.ProdId = @ProductId OR @ProductId IS NULL) 
			AND (PR.PayDate > PL.ExpiryDate)
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate

			UNION ALL

			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			0 TotalCollected,
			0 NotAllocated,
			CASE 
			WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Counter AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
			THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
			WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Counter AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
			THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
			WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
			THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
			END Allocated
			FROM tblPremium PR 
			INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL
			AND PL.ValidityTo IS NULL
			AND Prod.ValidityTo IS  NULL
			AND Prod.ProdID = @ProductID
			AND PL.PolicyStatus <> 1
			AND PR.PayDate <= PL.ExpiryDate
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate,PL.EffectiveDate
			)PremiumDistribution
			GROUP BY MonthId,DistrictName,ProductCode,ProductName		
			SET @Counter = @Counter + 1	
		END
		SELECT MonthId, DistrictName,ProductCode,ProductName,TotalCollected,NotAllocated,Allocated FROM #tmpResult
	END
GO
	
IF OBJECT_ID('uspSSRSFeedbackPrompt', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSFeedbackPrompt
GO

CREATE PROCEDURE [dbo].[uspSSRSFeedbackPrompt]
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

IF OBJECT_ID('uspSSRSProcessBatch', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSProcessBatch
GO

CREATE PROCEDURE [dbo].[uspSSRSProcessBatch] 
	(
		@LocationId INT = 0,
		@ProdID INT = 0,
		@RunID INT = 0,
		@HFID INT = 0,
		@HFLevel as Char(1) = '',
		@DateFrom DATE = '',
		@DateTo DATE = '',
		@MinRemunerated as decimal(18,2) = 0 
	)
	AS
	BEGIN
		IF @LocationId=-1
        BEGIN
        	SET @LocationId = NULL
        END

        IF @DateFrom = '' OR @DateFrom IS NULL OR @DateTo = '' OR @DateTo IS NULL
        BEGIN
	        SET @DateFrom = N'1900-01-01'
	        SET @DateTo = N'3000-12-31'
        END


    ;WITH CDetails AS
	    (
		    SELECT CI.ClaimId, CI.ProdId,
		    SUM(ISNULL(CI.PriceApproved, CI.PriceAsked) * ISNULL(CI.QtyApproved, CI.QtyProvided)) PriceApproved,
		    SUM(CI.PriceValuated) PriceAdjusted, SUM(CI.RemuneratedAmount)RemuneratedAmount
		    FROM tblClaimItems CI
		    WHERE CI.ValidityTo IS NULL
		    AND CI.ClaimItemStatus = 1
		    GROUP BY CI.ClaimId, CI.ProdId
		    UNION ALL

		    SELECT CS.ClaimId, CS.ProdId,
		    SUM(ISNULL(CS.PriceApproved, CS.PriceAsked) * ISNULL(CS.QtyApproved, CS.QtyProvided)) PriceApproved,
		    SUM(CS.PriceValuated) PriceValuated, SUM(CS.RemuneratedAmount) RemuneratedAmount

		    FROM tblClaimServices CS
		    WHERE CS.ValidityTo IS NULL
		    AND CS.ClaimServiceStatus = 1
		    GROUP BY CS.CLaimId, CS.ProdId
	    )
	SELECT R.RegionName, D.DistrictName, HF.HFCode, HF.HFName, Prod.ProductCode, Prod.ProductName, SUM(CDetails.RemuneratedAmount)Remunerated, Prod.AccCodeRemuneration, HF.AccCode

	FROM tblClaim C
	INNER JOIN tblInsuree I ON I.InsureeId = C.InsureeID
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN CDetails ON CDetails.ClaimId = C.ClaimID
	INNER JOIN tblProduct Prod ON Prod.ProdId = CDetails.ProdID
	INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region

	WHERE C.ValidityTo IS NULL
	AND (Prod.LocationId = @LocationId OR @LocationId = 0 OR Prod.LocationId IS NULL)
	AND(Prod.ProdId = @ProdId OR @ProdId = 0)
	AND (C.RunId = @RunId OR @RunId = 0)
	AND (HF.HFId = @HFID OR @HFId = 0)
	AND (HF.HFLevel = @HFLevel OR @HFLevel = N'')
	AND (C.DateTo BETWEEN @DateFrom AND @DateTo)
	GROUP BY  R.RegionName,D.DistrictName, HF.HFCode, HF.HFName, Prod.ProductCode, Prod.ProductName, Prod.AccCodeRemuneration, HF.AccCode
	HAVING SUM(CDetails.RemuneratedAmount) > @MinRemunerated
END
GO

IF OBJECT_ID('uspSSRSPrimaryIndicators1', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSPrimaryIndicators1
GO

CREATE PROCEDURE [dbo].[uspSSRSPrimaryIndicators1] 
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

IF OBJECT_ID('uspSSRSPrimaryIndicators2', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSPrimaryIndicators2
GO

CREATE PROCEDURE [dbo].[uspSSRSPrimaryIndicators2]
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

IF OBJECT_ID('uspSSRSDerivedIndicators1', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSDerivedIndicators1
GO

CREATE PROCEDURE [dbo].[uspSSRSDerivedIndicators1]
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

IF OBJECT_ID('uspSSRSDerivedIndicators2', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSDerivedIndicators2
GO

CREATE PROCEDURE [dbo].[uspSSRSDerivedIndicators2]
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

IF OBJECT_ID('uspSSRSUserLogReport', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSUserLogReport
GO

CREATE PROCEDURE [dbo].[uspSSRSUserLogReport]
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

IF OBJECT_ID('uspSSRSStatusRegister', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSStatusRegister
GO

CREATE PROCEDURE [dbo].[uspSSRSStatusRegister]
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

IF OBJECT_ID('uspSSRSPaymentCategoryOverview', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSPaymentCategoryOverview
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

IF OBJECT_ID('uspSSRSGetMatchingFunds', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSGetMatchingFunds
GO

CREATE PROCEDURE [dbo].[uspSSRSGetMatchingFunds]
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
Go

IF OBJECT_ID('uspSSRSGetClaimOverview', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSGetClaimOverview
GO

CREATE PROCEDURE [dbo].[uspSSRSGetClaimOverview]
	(
		@HFID INT,	
		@LocationId INT,
		@ProdId INT, 
		@StartDate DATE, 
		@EndDate DATE,
		@ClaimStatus INT = NULL,
		@ClaimRejReason xClaimRejReasons READONLY,
		@Scope INT = NULL
	)
	AS
	BEGIN
		-- no scope -1
		-- claim only 0
		-- claimand rejection 1
		-- all 2
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

		SELECT C.DateClaimed, C.ClaimID, I.ItemId, S.ServiceID, HF.HFCode, HF.HFName, C.ClaimCode, C.DateClaimed, CA.LastName + ' ' + CA.OtherNames ClaimAdminName,
		C.DateFrom, C.DateTo, Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsureeName,
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
		CASE WHEN @Scope > 0 THEN CONCAT(CI.RejectionReason, ' - ', XCI.Name) ELSE NULL END ItemRejectionReason

		-- end all claims


		FROM tblClaim C LEFT OUTER JOIN tblClaimItems CI ON C.ClaimId = CI.ClaimID
		LEFT OUTER JOIN tblClaimServices CS ON C.ClaimId = CS.ClaimID
		LEFT OUTER JOIN tblItems I ON CI.ItemId = I.ItemID
		LEFT OUTER JOIN tblServices S ON CS.ServiceID = S.ServiceID
		--INNER JOIN tblProduct PROD ON PROD.ProdID = CS.ProdID AND PROD.ProdID = CI.ProdID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		LEFT OUTER JOIN tblClaimAdmin CA ON C.ClaimAdminId = CA.ClaimAdminId
		INNER JOIN tblInsuree Ins ON C.InsureeId = Ins.InsureeId
		LEFT OUTER JOIN TotalForItems TFI ON C.ClaimId = TFI.ClaimID
		LEFT OUTER JOIN TotalForServices TFS ON C.ClaimId = TFS.ClaimId
		-- all claims
		LEFT JOIN @ClaimRejReason XCI ON XCI.ID = CI.RejectionReason
		LEFT JOIN @ClaimRejReason XCS ON XCS.ID = CS.RejectionReason
		-- and all claims
		WHERE C.ValidityTo IS NULL
		AND ISNULL(C.DateTo,C.DateFrom) BETWEEN @StartDate AND @EndDate
		AND (C.ClaimStatus = @ClaimStatus OR @ClaimStatus IS NULL)
		AND (HF.LocationId = @LocationId OR @LocationId = 0)
		AND (HF.HFID = @HFID OR @HFID = 0)
		AND (CI.ProdID = @ProdId OR CS.ProdID = @ProdId  
		OR COALESCE(CS.ProdID, CI.ProdId) IS NULL OR @ProdId = 0)
	END
Go

IF OBJECT_ID('uspSSRSProcessBatchWithClaim', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSProcessBatchWithClaim
GO

CREATE PROCEDURE [dbo].[uspSSRSProcessBatchWithClaim]
	(
		@LocationId INT = 0,
		@ProdId INT = 0,
		@RunID INT = 0,
		@HFID INT = 0,
		@HFLevel CHAR(1) = N'',
		@DateFrom DATE = NULL,
		@DateTo DATE = NULL
	)
	AS
	BEGIN

		IF @DateFrom = '' OR @DateFrom IS NULL OR @DateTo = '' OR @DateTo IS NULL
	    BEGIN
		    SET @DateFrom = N'1900-01-01'
		    SET @DateTo = N'3000-12-31'
	    END

	    ;WITH CDetails AS
	(
		SELECT CI.ClaimId, CI.ProdId,
		SUM(ISNULL(CI.PriceApproved, CI.PriceAsked) * ISNULL(CI.QtyApproved, CI.QtyProvided)) PriceApproved,
		SUM(CI.PriceValuated) PriceAdjusted, SUM(CI.RemuneratedAmount)RemuneratedAmount
		FROM tblClaimItems CI
		WHERE CI.ValidityTo IS NULL
		AND CI.ClaimItemStatus = 1
		GROUP BY CI.ClaimId, CI.ProdId
		UNION ALL

		SELECT CS.ClaimId, CS.ProdId,
		SUM(ISNULL(CS.PriceApproved, CS.PriceAsked) * ISNULL(CS.QtyApproved, CS.QtyProvided)) PriceApproved,
		SUM(CS.PriceValuated) PriceValuated, SUM(CS.RemuneratedAmount) RemuneratedAmount

		FROM tblClaimServices CS
		WHERE CS.ValidityTo IS NULL
		AND CS.ClaimServiceStatus = 1
		GROUP BY CS.CLaimId, CS.ProdId
	)
	SELECT C.ClaimCode, C.DateClaimed, CA.OtherNames OtherNamesAdmin, CA.LastName LastNameAdmin, C.DateFrom, C.DateTo, I.CHFID, I.OtherNames,
	I.LastName, C.HFID, HF.HFCode, HF.HFName, HF.AccCode, Prod.ProdID, Prod.ProductCode, Prod.ProductName, 
	C.Claimed PriceAsked, SUM(CDetails.PriceApproved)PriceApproved, SUM(CDetails.PriceAdjusted)PriceAdjusted, SUM(CDetails.RemuneratedAmount)RemuneratedAmount,
	D.DistrictID, D.DistrictName, R.RegionId, R.RegionName

	FROM tblClaim C
	LEFT OUTER JOIN tblClaimAdmin CA ON CA.ClaimAdminId = C.ClaimAdminId
	INNER JOIN tblInsuree I ON I.InsureeId = C.InsureeID
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN CDetails ON CDetails.ClaimId = C.ClaimID
	INNER JOIN tblProduct Prod ON Prod.ProdId = CDetails.ProdID
	INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region

	WHERE C.ValidityTo IS NULL
	AND (Prod.LocationId = @LocationId OR @LocationId = 0 OR Prod.LocationId IS NULL)
	AND(Prod.ProdId = @ProdId OR @ProdId = 0)
	AND (C.RunId = @RunId OR @RunId = 0)
	AND (HF.HFId = @HFID OR @HFId = 0)
	AND (HF.HFLevel = @HFLevel OR @HFLevel = N'')
	AND (C.DateTo BETWEEN @DateFrom AND @DateTo)

	GROUP BY C.ClaimCode, C.DateClaimed, CA.OtherNames, CA.LastName , C.DateFrom, C.DateTo, I.CHFID, I.OtherNames,
	I.LastName, C.HFID, HF.HFCode, HF.HFName, HF.AccCode, Prod.ProdID, Prod.ProductCode, Prod.ProductName, C.Claimed,
	D.DistrictId, D.DistrictName, R.RegionId, R.RegionName
END
GO

IF OBJECT_ID('uspSSRSEnroledFamilies', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSEnroledFamilies
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

IF OBJECT_ID('uspSSRSOverviewOfCommissions', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSOverviewOfCommissions
GO

CREATE PROCEDURE [dbo].[uspSSRSOverviewOfCommissions]
(
	@Month INT,
	@Year INT, 
	@Mode INT=NULL,
	@OfficerId INT =NULL,
	@LocationId INT, 
	@ProdId INT = NULL,
	@PayerId INT = NULL,
	@ReportingId INT = NULL,
	@Scope INT = NULL,
	@CommissionRate DECIMAL(18,2) = NULL,
	@ErrorMessage NVARCHAR(200) = N'' OUTPUT
)
AS
BEGIN
	IF @ReportingId IS NULL  -- LINK THE CONTRIBUTION TO THE REPORT
    BEGIN
	-- check mandatory data
		if   @Month IS NULL OR @Month  = 0 
		BEGIN
			SELECT @ErrorMessage = 'Month Mandatory'
			RETURN
		END
		if   @Year IS NULL OR @Year  = 0 
		BEGIN
			SELECT @ErrorMessage = 'Year Mandatory'
			RETURN
		END			
		if   @LocationId IS NULL OR @LocationId  = 0 
		BEGIN
			SELECT @ErrorMessage = 'LocationId Mandatory'
			RETURN
		END	
		if   @CommissionRate IS NULL OR @CommissionRate  = 0 
		BEGIN
			SELECT @ErrorMessage = 'CommissionRate Mandatory'
			RETURN
		END	
		DECLARE @RecordFound INT = 0
		DECLARE @Rate DECIMAL(18,2) 

		SET @Rate = @CommissionRate / 100
	  	DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'; 
		DECLARE @LastDay DATE = EOMONTH(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01', 0)
		BEGIN TRY
			BEGIN TRAN
				if @Mode = 0 -- prescribed
					SELECT TOP(1) @ReportingId = ReportingId FROM tblReporting WHERE LocationId = @LocationId AND ISNULL(ProdId,0) = ISNULL(@ProdId,0) 
						AND StartDate = @FirstDay AND EndDate = @LastDay AND ISNULL(OfficerID,0) = ISNULL(@OfficerID,0) AND ReportMode = 0 AND ISNULL(PayerId,0) = ISNULL(@PayerId,0)
				IF @ReportingId is NULL
				BEGIN
					INSERT INTO tblReporting(ReportingDate,LocationId, ProdId, PayerId, StartDate, EndDate, RecordFound,OfficerID,ReportType,CommissionRate,ReportMode,Scope)
					SELECT GETDATE(),@LocationId,ISNULL(@ProdId,0), @PayerId, @FirstDay, @LastDay, 0,@OfficerId,2,@Rate,@Mode,@Scope; 
					--Get the last inserted reporting Id
					SELECT @ReportingId =  SCOPE_IDENTITY();
				END
				ELSE UPDATE  tblReporting
					SET ReportingDate = GETDATE(), CommissionRate = @Rate; 

				UPDATE tblPremium SET ReportingCommissionID = CASE  @Mode WHEN 1 THEN @ReportingId ELSE -@ReportingId END
					WHERE PremiumId IN (
					SELECT  Pr.PremiumId
					FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID AND (PL.PolicyStatus=1 OR PL.PolicyStatus=2)
					LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId
					LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID 
					INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
					INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
					INNER JOIN tblLocations V ON V.LocationId = F.LocationId
					INNER JOIN tblLocations W ON W.LocationId = V.ParentLocationId
					INNER JOIN tblLocations D ON D.LocationId = W.ParentLocationId
					INNER JOIN tblOfficer O ON O.LocationId = D.LocationId AND O.ValidityTo IS NULL AND O.Officerid = PL.OfficerID
					INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL
					LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID 
					WHERE( (@Mode = 1 and PY.MatchedDate IS NOT NULL ) OR  (PY.MatchedDate IS NULL AND @Mode = 0))
					AND Year(Pr.PayDate) = @Year AND Month(Pr.paydate) = @Month
					AND D.LocationId = @LocationId	-- or D.ParentLocationId = @LocationId
					AND (ISNULL(Prod.ProdID,0) = ISNULL(@ProdId,0) OR @ProdId is null)
					AND (ISNULL(O.OfficerID,0) = ISNULL(@OfficerId,0) OR @OfficerId IS NULL)
					AND (ISNULL(Payer.PayerID,0) = ISNULL(@PayerId,0) OR @PayerId IS NULL)
					-- AND (Pr.ReportingId IS NULL OR Pr.ReportingId < 0 ) -- not matched will be with negative ID
					AND PR.PayType <> N'F'
					AND (Pr.ReportingCommissionID IS NULL OR Pr.ReportingCommissionID < 0)
					GROUP BY Pr.PremiumId
					HAVING SUM(ISNULL(PD.Amount,0)) = MAX(ISNULL(PY.ExpectedAmount,0))
					)	
				
				SELECT @RecordFound = @@ROWCOUNT;
				IF @RecordFound = 0 
				BEGIN
					SELECT @ErrorMessage = 'No Data'
					DELETE tblReporting WHERE ReportingId = @ReportingId;
					ROLLBACK TRAN; 
					RETURN -- To avoid a second rollback
				END
				ELSE
				BEGIN
					UPDATE tblReporting SET RecordFound = @RecordFound WHERE ReportingId = @ReportingId;
					--UPDATE tblPremium SET OverviewCommissionReport = GETDATE() WHERE ReportingCommissionID = @ReportingId AND @Scope = 0 AND OverviewCommissionReport IS NULL;
					--UPDATE tblPremium SET AllDetailsCommissionReport = GETDATE() WHERE ReportingCommissionID = @ReportingId AND @Scope = 1 AND AllDetailsCommissionReport IS NULL;
				END
			COMMIT TRAN;
		END TRY
		BEGIN CATCH
			--SELECT @ErrorMessage = ERROR_MESSAGE(); ERROR MESSAGE WAS COMMENTED BY SALUMU ON 12-11-2019
			ROLLBACK TRAN;
			--RETURN -2 RETURN WAS COMMENTED BY SALUMU ON 12-11-2019
		END CATCH

	END
	      
					    
	-- FETCHT THE DATA FOR THE REPORT		 
	SELECT  Pr.PremiumId,Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName Product,PL.PolicyID,F.FamilyID,D.LocationName DistrictName,o.OfficerID , Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName,O.Code + ' ' + O.LastName Officer,
	Ins.DOB, Ins.IsHead, PL.EnrollDate,REP.ReportMode,Month(REP.StartDate)  [Month], Pr.Paydate, Pr.Receipt,CASE WHEN Ins.IsHead = 1 THEN ISNULL(Pr.Amount,0) ELSE NULL END Amount,CASE WHEN Ins.IsHead = 1 THEN Pr.Amount ELSE NULL END  PrescribedContribution, CASE WHEN Ins.IsHead = 1 THEN ISNULL(PD.Amount,0) ELSE NULL END ActualPayment, Payer.PayerName,PY.PaymentDate,CASE WHEN IsHead = 1 THEN SUM(ISNULL(Pr.Amount,0.00)) * ISNULL(rep.CommissionRate,0.00) ELSE NULL END  CommissionRate,PY.ExpectedAmount PaymentAmount,OfficerCode,V.LocationName VillageName,W.LocationName  WardName,PL.PolicyStage,TransactionNo,O.Phone PhoneNumber
	FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID AND (PL.PolicyStatus=1 OR PL.PolicyStatus=2) AND PL.ValidityTo IS NULL
	LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId AND PD.ValidityTo IS NULl AND PR.ValidityTo IS NULL
	LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID AND PY.ValidityTo IS NULL
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID AND Prod.ValidityTo IS NULL
	INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID AND F.ValidityTo IS NULL
	INNER JOIN tblLocations V ON V.LocationId = F.LocationId
	INNER JOIN tblLocations W ON W.LocationId = V.ParentLocationId
	INNER JOIN tblLocations D ON D.LocationId = W.ParentLocationId
	INNER JOIN tblOfficer O ON O.Officerid = PL.OfficerID AND  O.LocationId = D.LocationId AND O.ValidityTo IS NULL
	INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL
	INNER JOIN tblReporting REP ON REP.ReportingId = @ReportingId
	LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID
	WHERE ABS(Pr.ReportingCommissionID) = @ReportingId
    AND (Pr.OverviewCommissionReport IS NULL OR Pr.AllDetailsCommissionReport IS NULL)
	GROUP BY Pr.PremiumId,Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName , PL.PolicyID ,  F.FamilyID, D.LocationName,o.OfficerID , Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames ,O.Code + ' ' + O.LastName ,
	Ins.DOB, Ins.IsHead, PL.EnrollDate,REP.ReportMode,Month(REP.StartDate), Pr.Paydate, Pr.Receipt,Pr.Amount,Pr.Amount, PD.Amount , Payer.PayerName,PY.PaymentDate, PY.ExpectedAmount,OfficerCode,V.LocationName,W.LocationName,PL.PolicyStage,TransactionNo,CommissionRate,O.Phone
	ORDER BY PremiumId, O.OfficerID,F.FamilyID,IsHead DESC;
END
GO

IF OBJECT_ID('uspSSRSGetClaimHistory', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSGetClaimHistory
GO

CREATE PROCEDURE [dbo].[uspSSRSGetClaimHistory]
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
		ci.RejectionReason Items

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


-- OP-281: Set isOffline status to 0 for insurees in database 
IF NOT EXISTS (SELECT 1 FROM tblIMISDefaults where OfflineCHF = 1 OR OfflineHF = 1)
BEGIN
	UPDATE tblInsuree SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblFamilies SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblInsureePolicy SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblPremium SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblPolicy SET isOffline=0 where isOffline is NULL or isOffline<>0
END 

-- ready status support
IF OBJECT_ID('uspMatchPayment', 'P') IS NOT NULL
    DROP PROCEDURE uspMatchPayment
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspMatchPayment]
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
		DECLARe @PolicyStage INT
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

			FETCH NEXT FROM CurPolicies INTO @PaymentDetailsID,  @InsuranceNumber, @productCode, @PhoneNumber, @DistributedValue, @PreviousPolicyID, @AlreadyPaidDValue, @PremiumID;
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

-- OP-191: Policies App Renewal list does not reduce

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[uspGetPolicyRenewals]', 'P') IS NOT NULL
    DROP PROCEDURE uspGetPolicyRenewals
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
	 SELECT R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, CONVERT(NVARCHAR(10),R.RenewalpromptDate,103)RenewalpromptDate, O.Phone, CONVERT(NVARCHAR(10),RenewalDate,103) EnrollDate, 'R' PolicyStage, F.FamilyID, Prod.ProdID, R.ResponseDate, R.ResponseStatus FROM tblPolicyRenewals R  
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

IF OBJECT_ID('[uspInsertIndexMonthly]', 'P') IS NOT NULL
    DROP PROCEDURE [uspInsertIndexMonthly]
GO
 CREATE PROCEDURE [dbo].[uspInsertIndexMonthly]
(
@Type varchar(1),
@RelType INT, -- M 12, Q 4, Y 1 
@MStart INT,    --M 1--12  Q 1--4  Y --1 
@MEnd INT,
@Year INT,
@Period INT,
@LocationId INT = 0,
@ProductID INT = 0,
@PrdValue decimal(18,2) =0,
@AuditUser int = -1
)

AS
BEGIN
	DECLARE @DistrPerc as decimal(18,2)
	DECLARE @ClaimValueItems as decimal(18,2)
	DECLARE @ClaimValueservices as decimal(18,2)
	DECLARE @RelIndex as decimal(18,4)



	SELECT @DistrPerc = ISNULL(DistrPerc,1) FROM dbo.tblRelDistr WHERE ProdID = @ProductID AND Period = @Period AND DistrType = @RelType AND DistrCareType = @Type AND ValidityTo IS NULL
			
			SELECT @ClaimValueItems = ISNULL(SUM(tblClaimItems.PriceValuated),0) 
										FROM tblClaim INNER JOIN
										tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID INNER JOIN
										tblHF ON tblClaim.HFID = tblHF.HfID
										INNER JOIN tblProductItems pi on tblClaimItems.ProdID = pi.ProdID and pi.PriceOrigin = 'R' AND pi.ValidityTo is null and tblClaimItems.ItemID = pi.ItemID
										WHERE     (tblClaimItems.ClaimItemStatus = 1) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 16 OR
										tblClaim.ClaimStatus = 8) AND (ISNULL(MONTH(tblClaim.ProcessStamp) ,-1) BETWEEN @MStart AND @MEnd ) AND
										(ISNULL(YEAR(tblClaim.ProcessStamp) ,-1) = @Year) AND
										(tblClaimItems.ProdID = @ProductID) 
										AND ((@TYPE =  'O' AND (tblHF.HFLevel = 'H')) OR (@TYPE =  'I' AND (tblHF.HFLevel <> 'H'))  OR @TYPE =  'B')

			
			SELECT @ClaimValueservices = ISNULL(SUM(tblClaimServices.PriceValuated) ,0)
										FROM tblClaim INNER JOIN
										tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN
										tblHF ON tblClaim.HFID = tblHF.HfID
										INNER JOIN tblProductServices ps on tblClaimServices.ProdID = ps.ProdID and ps.PriceOrigin = 'R'  AND ps.ValidityTo is null and tblClaimServices.ServiceID = ps.ServiceID
										WHERE     (tblClaimServices.ClaimServiceStatus = 1) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 16 OR
										tblClaim.ClaimStatus = 8) AND (ISNULL(MONTH(tblClaim.ProcessStamp) ,-1) BETWEEN @MStart AND @MEnd ) AND 
										(ISNULL(YEAR(tblClaim.ProcessStamp) ,-1) = @Year) AND
										(tblClaimServices.ProdID = @ProductID) 
										AND ((@TYPE =  'O' AND (tblHF.HFLevel = 'H')) OR (@TYPE =  'I' AND (tblHF.HFLevel <> 'H'))  OR @TYPE =  'B')
			
			
			IF @ClaimValueItems + @ClaimValueservices = 0 
			BEGIN
				--basically all 100% is available
				SET @RelIndex = 1 
				INSERT INTO [tblRelIndex] ([ProdID],[RelType],[RelCareType],[RelYear],[RelPeriod],[CalcDate],[RelIndex],[AuditUserID],[LocationId] )
				VALUES (@ProductID,@RelType,@Type,@Year,@Period,GETDATE(),@RelIndex,@AuditUser,@LocationId )
			END
			ELSE
			BEGIN
				SET @RelIndex = CAST((@PrdValue * @DistrPerc) as Decimal(18,4)) / (@ClaimValueItems + @ClaimValueservices)
				INSERT INTO [tblRelIndex] ([ProdID],[RelType],[RelCareType],[RelYear],[RelPeriod],[CalcDate],[RelIndex],[AuditUserID],[LocationId])
				VALUES (@ProductID,@RelType,@Type,@Year,@Period,GETDATE(),@RelIndex,@AuditUser,@LocationId )
			END
END
GO


IF OBJECT_ID('[uspRelativeIndexCalculationMonthly]', 'P') IS NOT NULL
    DROP PROCEDURE [uspRelativeIndexCalculationMonthly]
GO
CREATE PROCEDURE [dbo].[uspRelativeIndexCalculationMonthly]
(
@RelType INT,   --Month = 12 Quarter = 4 Year = 1    
@Period INT,    --M 1--12  Q 1--4  Y --1 
@Year INT,
@LocationId INT = 0,
@ProductID INT = 0,
@AuditUser int = -1,
@RtnStatus as int = 0 OUTPUT
)

AS
BEGIN
	DECLARE @oReturnValue as int 
	SET @oReturnValue = 0 
	BEGIN TRY
	
	DECLARE @MStart as int
	DECLARE @MEnd as int 
	DECLARE @Month as int
	DECLARE @PrdID as int 
	DECLARE @CurLocationId as int
	DECLARE @PrdValue as decimal(18,2)
	
	--!!!! Check first if not existing in the meantime !!!!!!!
	
	CREATE TABLE #Numerator (
						LocationId int,
						ProdID int,
						Value decimal(18,2),
						WorkValue bit 
						)
	
	
	--first include the right period for processing
	IF @RelType = 12
	BEGIN
		SET @MStart = @Period 
		SET @MEnd = @Period 
		
	END
	
	IF @RelType = 4
	BEGIN
		IF @Period = 1 
		BEGIN
			SET @MStart = 1 
			SET @MEnd = 3 
		END
		IF @Period = 2 
		BEGIN
			SET @MStart = 4
			SET @MEnd = 6
		END
		IF @Period = 3
		BEGIN
			SET @MStart = 7
			SET @MEnd = 9
		END
		IF @Period = 4
		BEGIN
			SET @MStart = 10
			SET @MEnd = 12
		END
	END
	
	IF @RelType = 1
	BEGIN
		SET @MStart = 1
		SET @MEnd = 12
		
	END
	
	DECLARE @Date date
	DECLARE @DaysInMonth int 
	DECLARE @EndDate date
	
	SET @Month = @MStart 
	WHILE @Month <= @MEnd
	BEGIN
		
		SELECT @Date = CAST(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-' + '01' AS DATE)
		SELECT @DaysInMonth = DATEDIFF(DAY,@Date,DATEADD(MONTH,1,@Date))
		SELECT @EndDate = CAST(CONVERT(VARCHAR(4),@Year) + '-' + CONVERT(VARCHAR(2),@Month ) + '-' + CONVERT(VARCHAR(2),@DaysInMonth) AS DATE)

		INSERT INTO #Numerator (LocationId,ProdID,Value,WorkValue ) 
		
		
		--Get all the payment falls under the current month and assign it to Allocated
		
		SELECT NumValue.LocationId, NumValue.ProdID, ISNULL(SUM(NumValue.Allocated),0) Allocated , 1  
		FROM 
		(	
		SELECT L.LocationId  ,Prod.ProdID ,
		CASE 
		WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
			THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
		WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
			THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
		WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
			THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
		END Allocated
		FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
		INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
		LEFT JOIN tblLocations L ON ISNULL(Prod.LocationId,-1) = ISNULL(L.LocationId,-1)
		WHERE PR.ValidityTo IS NULL
		AND PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS  NULL
		AND ISNULL(Prod.LocationId,-1) = ISNULL(@LocationId,-1) 
		AND (Prod.ProdID = @ProductID OR @ProductId = 0)
		AND PL.PolicyStatus <> 1
		AND PR.PayDate <= PL.ExpiryDate
		
		--AND ((MONTH(PR.PayDate) = @Counter OR MONTH(PL.EffectiveDate) = @Counter)
		--	OR (YEAR(PR.PayDate) = @Year OR YEAR(PL.EffectiveDate) = @Year))
		GROUP BY L.LocationId ,Prod.ProdID ,PR.Amount,PR.PayDate,PL.ExpiryDate,PL.EffectiveDate
		) NumValue
		
		GROUP BY LocationId,ProdID
																								
		SET @Month = @Month + 1 
	END
	
	--Now sum up the collected values 
	INSERT INTO #Numerator (LocationId,ProdID,Value,WorkValue) 
			SELECT LocationId, ProdID, ISNULL(SUM(Value),0) Allocated , 0 
			FROM #Numerator GROUP BY LocationId,ProdID
			
	DELETE FROM #Numerator WHERE WorkValue = 1
	
	-- DECLARE @Test as decimal(18,2)
	--SELECT @Test = SUM(Value) FROM #Numerator WHERE ProdID = 108
	
	
	-- Now fetch the product percentage for relative prices --If not found then assume 1 = 100%
	DECLARE @DistrType as char(1) ,@DistrTypeIP  as char(1),@DistrTypeOP  as char(1)
	
	--DECLARE @ClaimValueItems as decimal(18,2)
	--DECLARE @ClaimValueservices as decimal(18,2)
	--DECLARE @RelIndex as decimal(18,4)
	DECLARE @DistrPeriod as int, @DistrPeriodIP as int, @DistrPeriodOP as int
	--DECLARE @ClaimValueG as decimal(18,2)
	--DECLARE @ClaimValueIP as decimal(18,2)
	--DECLARE @ClaimValueOP as decimal(18,2)
	
	DECLARE PRDLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT ProdID,Value, LocationId FROM #Numerator 
	OPEN PRDLOOP
	FETCH NEXT FROM PRDLOOP INTO @PrdID , @PrdValue , @CurLocationId
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		--IF @PrdID = 108
		--BEGIN
		--	SET @Test = @PrdValue
		--END
		-- SELECT  @DistrType = ISNULL(PeriodRelPrices,''), @DistrTypeIP = ISNULL(PeriodRelPricesIP,''), @DistrTypeOP = ISNULL(PeriodRelPricesOP,'') FROM dbo.tblProduct Where ProdID = @PrdID 
		SET  @DistrType =  (SELECT ISNULL(PeriodRelPrices,'') FROM  dbo.tblProduct Where ProdID = @PrdID)
		SET @DistrTypeIP = (SELECT ISNULL(PeriodRelPricesIP,'') FROM  dbo.tblProduct Where ProdID = @PrdID)
		SET @DistrTypeOP = (SELECT ISNULL(PeriodRelPricesOP,'') FROM  dbo.tblProduct Where ProdID = @PrdID)
		
		-- don't run the index if not required
		SET @DistrPeriod = CASE WHEN @RelType = 12 AND @DistrType = 'M' THEN 12
							WHEN (@RelType = 4  ) AND @DistrType = 'Q'  THEN 4
							WHEN  (@RelType = 1  ) AND @DistrType = 'Y' THEN 1
							ELSE 0
							END
		SET @DistrPeriodIP = CASE 
							WHEN @RelType = 12 AND @DistrTypeIP = 'M' THEN 12
							WHEN (@RelType = 4 ) AND @DistrTypeIP = 'Q'  THEN 4
							WHEN  (@RelType = 1 ) AND @DistrTypeIP = 'Y' THEN 1
							ELSE 0
							END
		SET @DistrPeriodOP = CASE WHEN @RelType = 12 AND @DistrTypeOP = 'M' THEN 12
						WHEN (@RelType = 4 ) AND @DistrTypeOP = 'Q'  THEN 4
						WHEN  (@RelType = 1 ) AND @DistrTypeOP = 'Y' THEN 1
						ELSE 0
						END
		
		IF @DistrPeriod > 0  BEGIN EXEC [dbo].[uspInsertIndexMonthly]  'B',  @RelType,@MStart, @MEnd,  @Year,@Period,@CurLocationId ,@PrdID ,@PrdValue ,@AuditUser END
		ELSE -- cannot have IP/OP with General 
		BEGIN
			IF @DistrPeriodIP > 0 BEGIN EXEC [dbo].[uspInsertIndexMonthly]  'I',   @RelType, @MStart, @MEnd, @Year,@Period ,@CurLocationId ,@PrdID ,@PrdValue ,@AuditUser END 
			IF @DistrPeriodOP > 0 BEGIN EXEC [dbo].[uspInsertIndexMonthly]  'O',  @RelType, @MStart, @MEnd, @Year ,@Period,@CurLocationId ,@PrdID ,@PrdValue , @AuditUser END 
		END
		

		-- GET the total Claim Value 
		
		--Now insert into the relative index table 
		
		FETCH NEXT FROM PRDLOOP INTO @PrdID , @PrdValue,@CurLocationId
	END
	CLOSE PRDLOOP
	DEALLOCATE PRDLOOP
	
	SET @RtnStatus = 0
FINISH:
	
	RETURN @oReturnValue
END TRY
	
	BEGIN CATCH
		SELECT 'Unexpected error encountered'
		SET @oReturnValue = 1 
		SET @RtnStatus = 1
		RETURN @oReturnValue
		
	END CATCH
	
END
GO

SET ANSI_NULLS ON


IF OBJECT_ID('[uspInsertPaymentIntent]', 'P') IS NOT NULL
    DROP PROCEDURE [uspInsertPaymentIntent]
GO
CREATE PROCEDURE [dbo].[uspInsertPaymentIntent]
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

		INSERT INTO @tblDetail(InsuranceNumber, productCode, isRenewal)
		SELECT 
		LEFT(NULLIF(T.D.value('(InsuranceNumber)[1]','NVARCHAR(12)'),''),12),
		LEFT(NULLIF(T.D.value('(ProductCode)[1]','NVARCHAR(8)'),''),8),
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
	4 �Enrolment officer code and insurance product code are not compatible
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
			UPDATE @tblDetail SET PolicyValue = ISNULL(@PolicyValue,0), PolicyStage = @PolicyStage  WHERE InsuranceNumber = @InsuranceNumber AND productCode = @productCode AND isRenewal = @isRenewal
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

IF OBJECT_ID('[uspSSRSCapitationPayment]', 'P') IS NOT NULL
    DROP PROCEDURE [uspSSRSCapitationPayment]
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

		set @DistrictId = CASE @DistrictId WHEN 0 THEN NULL ELSE @DistrictId END

		DECLARE @Locations TABLE (
			LocationId INT,
			LocationName VARCHAR(50),
			LocationCode VARCHAR(8),
			ParentLocationId INT
			);
	    
		INSERT INTO @Locations 
		    SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId,  0 LocationCode
		    
			UNION ALL
		    
			SELECT LocationId,LocationName, LocationCode, ISNULL(ParentLocationId, 0) 
			FROM tblLocations 
			WHERE (ValidityTo IS NULL )
				AND (LocationId = ISNULL(@DistrictId, @RegionId) OR 
				(LocationType IN ('R', 'D') AND ParentLocationId = ISNULL(@DistrictId, @RegionId)))
		    
		
		DECLARE @LocationTemp table (LocationId int, RegionId int, RegionCode [nvarchar](8) , RegionName [nvarchar](50), DistrictId int, DistrictCode [nvarchar](8), 
			DistrictName [nvarchar](50), ParentLocationId int)
		

		INSERT INTO  @LocationTemp(LocationId , RegionId , RegionCode , RegionName , DistrictId , DistrictCode , 
		DistrictName , ParentLocationId)( SELECT ISNULL(d.LocationId,r.LocationId) LocationId , r.LocationId as RegionId , r.LocationCode as RegionCode  , r.LocationName as RegionName , d.LocationId as DistrictId , d.LocationCode as DistrictCode , 
		d.LocationName as DistrictName , ISNULL(d.ParentLocationId,r.ParentLocationId) ParentLocationId FROM @Locations  d  INNER JOIN @Locations r on d.ParentLocationId = r.LocationId
		UNION ALL SELECT r.LocationId, r.LocationId as RegionId , r.LocationCode as RegionCode  , r.LocationName as RegionName , NULL DistrictId , NULL DistrictCode , 
		NULL DistrictName ,  ParentLocationId FROM @Locations  r WHERE ParentLocationId = 0)
		;
		declare @listOfHF table (id int);
		
		IF  @RegionId IS  NULL or @RegionId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.ValidityTo is NULL;
		 ELSE IF  @DistrictId is NULL or @DistrictId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF JOIN tblLocations l on tblHF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId  ;
		ELSE 
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.LocationId = @DistrictId and tblHF.ValidityTo is NULL;


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


	    DECLARE @TotalPopFam TABLE (
			HFID INT,
			TotalPopulation DECIMAL(18, 6), 
			TotalFamilies DECIMAL(18, 6)
			);

		INSERT INTO @TotalPopFam 
	    
		    SELECT C.HFID HFID ,
		    CASE WHEN ISNULL(@DistrictId, @RegionId) IN (D.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM((ISNULL(L.MalePopulation, 0) + ISNULL(L.FemalePopulation, 0) + ISNULL(L.OtherPopulation, 0)) *(0.01* Catchment)) TotalPopulation, 
		    CASE WHEN ISNULL(@DistrictId, @RegionId) IN (D.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM(ISNULL(((L.Families)*(0.01* Catchment)), 0))TotalFamilies
		    FROM tblHFCatchment C
		    LEFT JOIN tblLocations L ON L.LocationId = C.LocationId OR  L.LegacyId = C.LocationId
		    INNER JOIN tblHF HF ON C.HFID = HF.HfID
		    INNER JOIN @LocationTemp D ON HF.LocationId = D.DistrictId
		    WHERE (C.ValidityTo IS NULL OR C.ValidityTo >= @FirstDay) AND C.ValidityFrom< @FirstDay
		    AND(L.ValidityTo IS NULL OR L.ValidityTo >= @FirstDay) AND L.ValidityFrom< @FirstDay
		    AND (HF.ValidityTo IS NULL )
			AND C.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY C.HFID, D.DistrictId, D.RegionId
	    


		DECLARE @InsuredInsuree TABLE (
			HFID INT,
			ProdId INT, 
			TotalInsuredInsuree DECIMAL(18, 6)
			);

		INSERT INTO @InsuredInsuree
	    
		    SELECT HC.HFID, @ProdId ProdId, COUNT(DISTINCT IP.InsureeId)*(0.01 * Catchment) TotalInsuredInsuree
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyId
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
			AND HC.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY HC.HFID, Catchment--, L.LocationId


			

		DECLARE @InsuredFamilies TABLE (
			HFID INT,
			TotalInsuredFamilies DECIMAL(18, 6)
			);

		INSERT INTO @InsuredFamilies
		    SELECT HC.HFID, COUNT(DISTINCT F.FamilyID)*(0.01 * Catchment) TotalInsuredFamilies
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
			AND HC.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY HC.HFID, Catchment--, L.LocationId




		
	    
		DECLARE @Allocation TABLE (
			ProdId INT,
			Allocated DECIMAL(18, 6)
			);
	    
		INSERT INTO @Allocation
	        SELECT ProdId, CAST(SUM(ISNULL(Allocated, 0)) AS DECIMAL(18, 6)) Allocated
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
		    INNER JOIN  @Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
		    WHERE PR.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND PL.ProdID = @ProdId
		    AND PL.PolicyStatus <> 1
		    AND PR.PayDate <= PL.ExpiryDate
		    GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate)Alc
		    GROUP BY ProdId;
	    

		DECLARE @ReportData TABLE (
			RegionCode VARCHAR(MAX),
			RegionName VARCHAR(MAX),
			DistrictCode VARCHAR(MAX),
			DistrictName VARCHAR(MAX),
			HFCode VARCHAR(MAX),
			HFName VARCHAR(MAX),
			AccCode VARCHAR(MAX),
			HFLevel VARCHAR(MAX),
			HFSublevel VARCHAR(MAX),
			TotalPopulation DECIMAL(18, 6),
			TotalFamilies DECIMAL(18, 6),
			TotalInsuredInsuree DECIMAL(18, 6),
			TotalInsuredFamilies DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6),
			TotalAdjusted DECIMAL(18, 6),

			PaymentCathment DECIMAL(18, 6),
			AlcContriPopulation DECIMAL(18, 6),
			AlcContriNumFamilies DECIMAL(18, 6),
			AlcContriInsPopulation DECIMAL(18, 6),
			AlcContriInsFamilies DECIMAL(18, 6),
			AlcContriVisits DECIMAL(18, 6),
			AlcContriAdjustedAmount DECIMAL(18, 6),
			UPPopulation DECIMAL(18, 6),
			UPNumFamilies DECIMAL(18, 6),
			UPInsPopulation DECIMAL(18, 6),
			UPInsFamilies DECIMAL(18, 6),
			UPVisits DECIMAL(18, 6),
			UPAdjustedAmount DECIMAL(18, 6)
			

			);
	    
		DECLARE @ClaimValues TABLE (
			HFID INT,
			ProdId INT,
			TotalAdjusted DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6)
			);

		INSERT INTO @ClaimValues
		SELECT HFID, @ProdId ProdId, SUM(TotalAdjusted)TotalAdjusted, COUNT(DISTINCT ClaimId)TotalClaims FROM
		(
			SELECT HFID, SUM(PriceValuated)TotalAdjusted, ClaimId
			FROM 
			(SELECT HFID,c.ClaimId, PriceValuated FROM  tblClaim C WITH (NOLOCK)
			 LEFT JOIN tblClaimItems ci ON c.ClaimID = ci.ClaimID and  ProdId = @ProdId AND (@WeightAdjustedAmount > 0.0)
			 WHERE CI.ValidityTo IS NULL  AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month
				AND C.HFID  in  (SELECT id FROM @listOfHF)and ci.ValidityTo IS NULL 
			UNION ALL
			SELECT HFID, c.ClaimId, PriceValuated FROM tblClaim C WITH (NOLOCK) 
			LEFT JOIN tblClaimServices cs ON c.ClaimID = cs.ClaimID   and  ProdId = @ProdId AND (@WeightAdjustedAmount > 0.0)
			WHERE cs.ValidityTo IS NULL  	AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month	
				AND C.HFID  in (SELECT id FROM @listOfHF) and CS.ValidityTo IS NULL 
			) claimdetails GROUP BY HFID,ClaimId
		)claims GROUP by HFID

	    INSERT INTO @ReportData 
		    SELECT L.RegionCode, L.RegionName, L.DistrictCode, L.DistrictName, HF.HFCode, HF.HFName, Hf.AccCode, 
			HL.Name HFLevel, 
			SL.HFSublevelDesc HFSublevel,
		    PF.[TotalPopulation] TotalPopulation, PF.TotalFamilies TotalFamilies, II.TotalInsuredInsuree, IFam.TotalInsuredFamilies, CV.TotalClaims, CV.TotalAdjusted
		    ,(
			      ISNULL(ISNULL(PF.[TotalPopulation], 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightPopulation)) /  NULLIF(SUM(PF.[TotalPopulation])OVER(),0),0)  
			    + ISNULL(ISNULL(PF.TotalFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberFamilies)) /NULLIF(SUM(PF.[TotalFamilies])OVER(),0),0) 
			    + ISNULL(ISNULL(II.TotalInsuredInsuree, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightInsuredPopulation)) /NULLIF(SUM(II.TotalInsuredInsuree)OVER(),0),0) 
			    + ISNULL(ISNULL(IFam.TotalInsuredFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberInsuredFamilies)) /NULLIF(SUM(IFam.TotalInsuredFamilies)OVER(),0),0) 
			    + ISNULL(ISNULL(CV.TotalClaims, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberVisits)) /NULLIF(SUM(CV.TotalClaims)OVER() ,0),0) 
			    + ISNULL(ISNULL(CV.TotalAdjusted, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightAdjustedAmount)) /NULLIF(SUM(CV.TotalAdjusted)OVER(),0),0)

		    ) PaymentCathment

		    , A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution) AlcContriPopulation
		    , A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution) AlcContriNumFamilies
		    , A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution) AlcContriInsPopulation
		    , A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution) AlcContriInsFamilies
		    , A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution) AlcContriVisits
		    , A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution) AlcContriAdjustedAmount

		    ,  ISNULL((A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution))/ NULLIF(SUM(PF.[TotalPopulation]) OVER(),0),0) UPPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution))/NULLIF(SUM(PF.TotalFamilies) OVER(),0),0) UPNumFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution))/NULLIF(SUM(II.TotalInsuredInsuree) OVER(),0),0) UPInsPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution))/ NULLIF(SUM(IFam.TotalInsuredFamilies) OVER(),0),0) UPInsFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution)) / NULLIF(SUM(CV.TotalClaims) OVER(),0),0) UPVisits
		    ,  ISNULL((A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution))/ NULLIF(SUM(CV.TotalAdjusted) OVER(),0),0) UPAdjustedAmount
			
		    FROM tblHF HF
		    INNER JOIN @HFLevel HL ON HL.Code = HF.HFLevel
		    LEFT OUTER JOIN tblHFSublevel SL ON SL.HFSublevel = HF.HFSublevel
		    LEFT JOIN @LocationTemp L ON L.LocationId = HF.LocationId
		    LEFT OUTER JOIN @TotalPopFam PF ON PF.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredInsuree II ON II.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredFamilies IFam ON IFam.HFID = HF.HfID
		   -- LEFT OUTER JOIN @Claims C ON C.HFID = HF.HfID
		    LEFT OUTER JOIN @ClaimValues CV ON CV.HFID = HF.HfID
		    LEFT OUTER JOIN @Allocation A ON A.ProdID = @ProdId

		    WHERE HF.ValidityTo IS NULL
		    AND (((L.RegionId = @RegionId OR @RegionId IS NULL) AND (L.DistrictId = @DistrictId OR @DistrictId IS NULL)) OR CV.ProdID IS NOT NULL OR II.ProdId IS NOT NULL)
		    AND (HF.HFLevel IN (@Level1, @Level2, @Level3, @Level4) OR (@Level1 IS NULL AND @Level2 IS NULL AND @Level3 IS NULL AND @Level4 IS NULL))
		    AND(
			    ((HF.HFLevel = @Level1 OR @Level1 IS NULL) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      );

	    SELECT  MAX (RegionCode)RegionCode, 
			MAX(RegionName)RegionName,
			MAX(DistrictCode)DistrictCode,
			MAX(DistrictName)DistrictName,
			HFCode, 
			MAX(HFName)HFName,
			MAX(AccCode)AccCode, 
			MAX(HFLevel)HFLevel, 
			MAX(HFSublevel)HFSublevel,
			ISNULL(SUM([TotalPopulation]),0)[Population],
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
	
	 FROM @ReportData

	 GROUP BY HFCode
END
GO

IF OBJECT_ID('[uspLastDateForPayment]', 'P') IS NOT NULL
    DROP PROCEDURE [uspLastDateForPayment]
GO
CREATE PROCEDURE [dbo].[uspLastDateForPayment]
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

IF OBJECT_ID('uspAddInsureePolicy', 'P') IS NOT NULL
    DROP PROCEDURE [uspAddInsureePolicy]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[uspAddInsureePolicy]
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

-- OTC-10: Changing the logic of user Roles
IF OBJECT_ID('uspCreateCapitationPaymentReportData', 'P') IS NOT NULL
    DROP PROCEDURE uspCreateCapitationPaymentReportData
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspCreateCapitationPaymentReportData]
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

		set @DistrictId = CASE @DistrictId WHEN 0 THEN NULL ELSE @DistrictId END

		DECLARE @Locations TABLE (
			LocationId INT,
			LocationName VARCHAR(50),
			LocationCode VARCHAR(8),
			ParentLocationId INT
			);

		INSERT INTO @Locations 
		    SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId,  0 LocationCode

			UNION ALL

			SELECT LocationId,LocationName, LocationCode, ISNULL(ParentLocationId, 0) 
			FROM tblLocations 
			WHERE (ValidityTo IS NULL )
				AND (LocationId = ISNULL(@DistrictId, @RegionId) OR 
				(LocationType IN ('R', 'D') AND ParentLocationId = ISNULL(@DistrictId, @RegionId)))


		DECLARE @LocationTemp table (LocationId int, RegionId int, RegionCode [nvarchar](8) , RegionName [nvarchar](50), DistrictId int, DistrictCode [nvarchar](8), 
			DistrictName [nvarchar](50), ParentLocationId int)


		INSERT INTO  @LocationTemp(LocationId , RegionId , RegionCode , RegionName , DistrictId , DistrictCode , 
		DistrictName , ParentLocationId)( SELECT ISNULL(d.LocationId,r.LocationId) LocationId , r.LocationId as RegionId , r.LocationCode as RegionCode  , r.LocationName as RegionName , d.LocationId as DistrictId , d.LocationCode as DistrictCode , 
		d.LocationName as DistrictName , ISNULL(d.ParentLocationId,r.ParentLocationId) ParentLocationId FROM @Locations  d  INNER JOIN @Locations r on d.ParentLocationId = r.LocationId
		UNION ALL SELECT r.LocationId, r.LocationId as RegionId , r.LocationCode as RegionCode  , r.LocationName as RegionName , NULL DistrictId , NULL DistrictCode , 
		NULL DistrictName ,  ParentLocationId FROM @Locations  r WHERE ParentLocationId = 0)
		;
		declare @listOfHF table (id int);

		IF  @RegionId IS  NULL or @RegionId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.ValidityTo is NULL;
		 ELSE IF  @DistrictId is NULL or @DistrictId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF JOIN tblLocations l on tblHF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId  ;
		ELSE 
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.LocationId = @DistrictId and tblHF.ValidityTo is NULL;


	    SELECT @Level1 = Level1, @Sublevel1 = Sublevel1, @Level2 = Level2, @Sublevel2 = Sublevel2, @Level3 = Level3, @Sublevel3 = Sublevel3, 
	    @Level4 = Level4, @Sublevel4 = Sublevel4, @ShareContribution = ISNULL(ShareContribution, 0), @WeightPopulation = ISNULL(WeightPopulation, 0), 
	    @WeightNumberFamilies = ISNULL(WeightNumberFamilies, 0), @WeightInsuredPopulation = ISNULL(WeightInsuredPopulation, 0), @WeightNumberInsuredFamilies = ISNULL(WeightNumberInsuredFamilies, 0), 
	    @WeightNumberVisits = ISNULL(WeightNumberVisits, 0), @WeightAdjustedAmount = ISNULL(WeightAdjustedAmount, 0)
	    FROM tblProduct Prod 
	    WHERE ProdId = @ProdId;


	    DECLARE @TotalPopFam TABLE (
			HFID INT,
			TotalPopulation DECIMAL(18, 6), 
			TotalFamilies DECIMAL(18, 6)
			);

		INSERT INTO @TotalPopFam 

		    SELECT C.HFID HFID ,
		    CASE WHEN ISNULL(@DistrictId, @RegionId) IN (D.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM((ISNULL(L.MalePopulation, 0) + ISNULL(L.FemalePopulation, 0) + ISNULL(L.OtherPopulation, 0)) *(0.01* Catchment)) TotalPopulation, 
		    CASE WHEN ISNULL(@DistrictId, @RegionId) IN (D.RegionId, D.DistrictId) THEN 1 ELSE 0 END * SUM(ISNULL(((L.Families)*(0.01* Catchment)), 0))TotalFamilies
		    FROM tblHFCatchment C
		    LEFT JOIN tblLocations L ON L.LocationId = C.LocationId OR  L.LegacyId = C.LocationId
		    INNER JOIN tblHF HF ON C.HFID = HF.HfID
		    INNER JOIN @LocationTemp D ON HF.LocationId = D.DistrictId
		    WHERE (C.ValidityTo IS NULL OR C.ValidityTo >= @FirstDay) AND C.ValidityFrom< @FirstDay
		    AND(L.ValidityTo IS NULL OR L.ValidityTo >= @FirstDay) AND L.ValidityFrom< @FirstDay
		    AND (HF.ValidityTo IS NULL )
			AND C.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY C.HFID, D.DistrictId, D.RegionId



		DECLARE @InsuredInsuree TABLE (
			HFID INT,
			ProdId INT, 
			TotalInsuredInsuree DECIMAL(18, 6)
			);

		INSERT INTO @InsuredInsuree

		    SELECT HC.HFID, @ProdId ProdId, COUNT(DISTINCT IP.InsureeId)*(0.01 * Catchment) TotalInsuredInsuree
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyId
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
			AND HC.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY HC.HFID, Catchment--, L.LocationId




		DECLARE @InsuredFamilies TABLE (
			HFID INT,
			TotalInsuredFamilies DECIMAL(18, 6)
			);

		INSERT INTO @InsuredFamilies
		    SELECT HC.HFID, COUNT(DISTINCT F.FamilyID)*(0.01 * Catchment) TotalInsuredFamilies
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
			AND HC.HFID in  (SELECT id FROM @listOfHF)
		    GROUP BY HC.HFID, Catchment--, L.LocationId






		DECLARE @Allocation TABLE (
			ProdId INT,
			Allocated DECIMAL(18, 6)
			);

		INSERT INTO @Allocation
	        SELECT ProdId, CAST(SUM(ISNULL(Allocated, 0)) AS DECIMAL(18, 6)) Allocated
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
		    INNER JOIN  @Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
		    WHERE PR.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND PL.ProdID = @ProdId
		    AND PL.PolicyStatus <> 1
		    AND PR.PayDate <= PL.ExpiryDate
		    GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate)Alc
		    GROUP BY ProdId;


		DECLARE @ReportData TABLE (
			RegionCode VARCHAR(MAX),
			RegionName VARCHAR(MAX),
			DistrictCode VARCHAR(MAX),
			DistrictName VARCHAR(MAX),
			HFCode VARCHAR(MAX),
			HFID INT,
			HFName VARCHAR(MAX),
			AccCode VARCHAR(MAX),
			HFLevel VARCHAR(MAX),
			HFSublevel VARCHAR(MAX),
			TotalPopulation DECIMAL(18, 6),
			TotalFamilies DECIMAL(18, 6),
			TotalInsuredInsuree DECIMAL(18, 6),
			TotalInsuredFamilies DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6),
			TotalAdjusted DECIMAL(18, 6),

			PaymentCathment DECIMAL(18, 6),
			AlcContriPopulation DECIMAL(18, 6),
			AlcContriNumFamilies DECIMAL(18, 6),
			AlcContriInsPopulation DECIMAL(18, 6),
			AlcContriInsFamilies DECIMAL(18, 6),
			AlcContriVisits DECIMAL(18, 6),
			AlcContriAdjustedAmount DECIMAL(18, 6),
			UPPopulation DECIMAL(18, 6),
			UPNumFamilies DECIMAL(18, 6),
			UPInsPopulation DECIMAL(18, 6),
			UPInsFamilies DECIMAL(18, 6),
			UPVisits DECIMAL(18, 6),
			UPAdjustedAmount DECIMAL(18, 6)


			);

		DECLARE @ClaimValues TABLE (
			HFID INT,
			ProdId INT,
			TotalAdjusted DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6)
			);

		INSERT INTO @ClaimValues
		SELECT HFID, @ProdId ProdId, SUM(TotalAdjusted)TotalAdjusted, COUNT(DISTINCT ClaimId)TotalClaims FROM
		(
			SELECT HFID, SUM(PriceValuated)TotalAdjusted, ClaimId
			FROM 
			(SELECT HFID,c.ClaimId, PriceValuated FROM  tblClaim C WITH (NOLOCK)
			 LEFT JOIN tblClaimItems ci ON c.ClaimID = ci.ClaimID and  ProdId = @ProdId AND (@WeightAdjustedAmount > 0.0)
			 WHERE CI.ValidityTo IS NULL  AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month
				AND C.HFID  in  (SELECT id FROM @listOfHF)and ci.ValidityTo IS NULL 
			UNION ALL
			SELECT HFID, c.ClaimId, PriceValuated FROM tblClaim C WITH (NOLOCK) 
			LEFT JOIN tblClaimServices cs ON c.ClaimID = cs.ClaimID   and  ProdId = @ProdId AND (@WeightAdjustedAmount > 0.0)
			WHERE cs.ValidityTo IS NULL  	AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month	
				AND C.HFID  in (SELECT id FROM @listOfHF) and CS.ValidityTo IS NULL 
			) claimdetails GROUP BY HFID,ClaimId
		)claims GROUP by HFID

	    INSERT INTO @ReportData 
		    SELECT L.RegionCode, L.RegionName, L.DistrictCode, L.DistrictName, HF.HFCode, HF.HfID, HF.HFName, Hf.AccCode, 
			HL.Name HFLevel, 
			SL.HFSublevelDesc HFSublevel,
		    PF.[TotalPopulation] TotalPopulation, PF.TotalFamilies TotalFamilies, II.TotalInsuredInsuree, IFam.TotalInsuredFamilies, CV.TotalClaims, CV.TotalAdjusted
		    ,(
			      ISNULL(ISNULL(PF.[TotalPopulation], 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightPopulation)) /  NULLIF(SUM(PF.[TotalPopulation])OVER(),0),0)  
			    + ISNULL(ISNULL(PF.TotalFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberFamilies)) /NULLIF(SUM(PF.[TotalFamilies])OVER(),0),0) 
			    + ISNULL(ISNULL(II.TotalInsuredInsuree, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightInsuredPopulation)) /NULLIF(SUM(II.TotalInsuredInsuree)OVER(),0),0) 
			    + ISNULL(ISNULL(IFam.TotalInsuredFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberInsuredFamilies)) /NULLIF(SUM(IFam.TotalInsuredFamilies)OVER(),0),0) 
			    + ISNULL(ISNULL(CV.TotalClaims, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberVisits)) /NULLIF(SUM(CV.TotalClaims)OVER() ,0),0) 
			    + ISNULL(ISNULL(CV.TotalAdjusted, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightAdjustedAmount)) /NULLIF(SUM(CV.TotalAdjusted)OVER(),0),0)

		    ) PaymentCathment

		    , A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution) AlcContriPopulation
		    , A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution) AlcContriNumFamilies
		    , A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution) AlcContriInsPopulation
		    , A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution) AlcContriInsFamilies
		    , A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution) AlcContriVisits
		    , A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution) AlcContriAdjustedAmount

		    ,  ISNULL((A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution))/ NULLIF(SUM(PF.[TotalPopulation]) OVER(),0),0) UPPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution))/NULLIF(SUM(PF.TotalFamilies) OVER(),0),0) UPNumFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution))/NULLIF(SUM(II.TotalInsuredInsuree) OVER(),0),0) UPInsPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution))/ NULLIF(SUM(IFam.TotalInsuredFamilies) OVER(),0),0) UPInsFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution)) / NULLIF(SUM(CV.TotalClaims) OVER(),0),0) UPVisits
		    ,  ISNULL((A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution))/ NULLIF(SUM(CV.TotalAdjusted) OVER(),0),0) UPAdjustedAmount

		    FROM tblHF HF
		    INNER JOIN @HFLevel HL ON HL.Code = HF.HFLevel
		    LEFT OUTER JOIN tblHFSublevel SL ON SL.HFSublevel = HF.HFSublevel
		    LEFT JOIN @LocationTemp L ON L.LocationId = HF.LocationId
		    LEFT OUTER JOIN @TotalPopFam PF ON PF.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredInsuree II ON II.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredFamilies IFam ON IFam.HFID = HF.HfID
		   -- LEFT OUTER JOIN @Claims C ON C.HFID = HF.HfID
		    LEFT OUTER JOIN @ClaimValues CV ON CV.HFID = HF.HfID
		    LEFT OUTER JOIN @Allocation A ON A.ProdID = @ProdId

		    WHERE HF.ValidityTo IS NULL
		    AND (((L.RegionId = @RegionId OR @RegionId IS NULL) AND (L.DistrictId = @DistrictId OR @DistrictId IS NULL)) OR CV.ProdID IS NOT NULL OR II.ProdId IS NOT NULL)
		    AND (HF.HFLevel IN (@Level1, @Level2, @Level3, @Level4) OR (@Level1 IS NULL AND @Level2 IS NULL AND @Level3 IS NULL AND @Level4 IS NULL))
		    AND(
			    ((HF.HFLevel = @Level1 OR @Level1 IS NULL) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      );


		INSERT INTO tblCapitationPayment(
		    CapitationPaymentUUID, ValidityFrom, ProductID,
		    [year], [month],

		    HfID, 
		    RegionCode, RegionName, 
		    DistrictCode, DistrictName, 
		    HFCode, HFName, AccCode, HFLevel, HFSublevel, 
		    TotalPopulation, TotalFamilies, TotalInsuredInsuree, 
		    TotalInsuredFamilies, TotalClaims, 
		    AlcContriPopulation, AlcContriNumFamilies, 
		    AlcContriInsPopulation, AlcContriInsFamilies, 
		    AlcContriVisits, AlcContriAdjustedAmount, 
		    UPPopulation, UPNumFamilies, UPInsPopulation, 
		    UPInsFamilies, UPVisits, UPAdjustedAmount, PaymentCathment, TotalAdjusted
		)
		    SELECT  
		    	NEWID(), GETDATE(), @ProdId, 
		        @Year, @Month, * FROM 
		        (SELECT 
					    MAX(HfID)HfID, 
					    MAX (RegionCode)RegionCode, MAX(RegionName)RegionName,
					    MAX(DistrictCode)DistrictCode, MAX(DistrictName)DistrictName,
					    HFCode, MAX(HFName)HFName, MAX(AccCode)AccCode, MAX(HFLevel)HFLevel, MAX(HFSublevel)HFSublevel,
					    ISNULL(SUM([TotalPopulation]),0)[Population], ISNULL(SUM(TotalFamilies),0)TotalFamilies, ISNULL(SUM(TotalInsuredInsuree),0)TotalInsuredInsuree,
						ISNULL(SUM(TotalInsuredFamilies),0)TotalInsuredFamilies, ISNULL(MAX(TotalClaims), 0)TotalClaims,
						ISNULL(SUM(AlcContriPopulation),0)AlcContriPopulation, ISNULL(SUM(AlcContriNumFamilies),0)AlcContriNumFamilies,
						ISNULL(SUM(AlcContriInsPopulation),0)AlcContriInsPopulation, ISNULL(SUM(AlcContriInsFamilies),0)AlcContriInsFamilies,
						ISNULL(SUM(AlcContriVisits),0)AlcContriVisits, ISNULL(SUM(AlcContriAdjustedAmount),0)AlcContriAdjustedAmount,
						ISNULL(SUM(UPPopulation),0)UPPopulation, ISNULL(SUM(UPNumFamilies),0)UPNumFamilies, ISNULL(SUM(UPInsPopulation),0)UPInsPopulation,
						ISNULL(SUM(UPInsFamilies),0)UPInsFamilies, ISNULL(SUM(UPVisits),0)UPVisits,
						ISNULL(SUM(UPAdjustedAmount),0)UPAdjustedAmount, ISNULL(SUM(PaymentCathment),0)PaymentCathment, ISNULL(SUM(TotalAdjusted),0)TotalAdjusted	
					FROM @ReportData GROUP BY HFCode) r;
END
GO

IF OBJECT_ID('uspSSRSRetrieveCapitationPaymentReportData', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSRetrieveCapitationPaymentReportData
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspSSRSRetrieveCapitationPaymentReportData]
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
		declare @listOfHF table (id int);

		IF  @RegionId IS  NULL or @RegionId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.ValidityTo is NULL;
		 ELSE IF  @DistrictId is NULL or @DistrictId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF JOIN tblLocations l on tblHF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId  ;
		ELSE 
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.LocationId = @DistrictId and tblHF.ValidityTo is NULL;


	    SELECT  RegionCode, 
				RegionName,
				DistrictCode,
				DistrictName,
				HFCode, 
				HFName,
				AccCode, 
				HFLevel, 
				HFSublevel,
				TotalPopulation[Population],
				TotalFamilies,
				TotalInsuredInsuree,
				TotalInsuredFamilies,
				TotalClaims,
				AlcContriPopulation,
				AlcContriNumFamilies,
				AlcContriInsPopulation,
				AlcContriInsFamilies,
				AlcContriVisits,
				AlcContriAdjustedAmount,
				UPPopulation,
				UPNumFamilies,
				UPInsPopulation,
				UPInsFamilies,
				UPVisits,
				UPAdjustedAmount,
				PaymentCathment,
				TotalAdjusted
	   FROM tblCapitationPayment WHERE [year] = @Year AND [month] = @Month AND HfID in (SELECT id from  @listOfHF) AND @ProdId = ProductID;
END

GO 