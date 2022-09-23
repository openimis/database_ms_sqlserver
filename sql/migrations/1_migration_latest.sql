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

IF COL_LENGTH('tblPayment', 'PayerPhoneNumber') IS NULL
BEGIN
	ALTER TABLE tblPayment ADD PayerPhoneNumber [nvarchar](15) NULL
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

ALTER TABLE tblFamilySMS DROP CONSTRAINT IF EXISTS DF_tblFamilies_LanguageOfSMS;
GO
DROP FUNCTION IF EXISTS [dbo].[udfDefaultLanguageCode] 
GO

CREATE FUNCTION [dbo].[udfDefaultLanguageCode]()
RETURNS NVARCHAR(5)
AS
BEGIN
	DECLARE @DefaultLanguageCode NVARCHAR(5)
	IF EXISTS (SELECT DISTINCT SortOrder from tblLanguages where SortOrder is not null)
	    SELECT TOP(1) @DefaultLanguageCode=LanguageCode FROM tblLanguages sort ORDER BY SortOrder ASC
	ELSE
	    SELECT TOP(1) @DefaultLanguageCode=LanguageCode FROM tblLanguages sort
	RETURN(@DefaultLanguageCode)
END
GO


IF NOT EXISTS (SELECT * from sysobjects where name='tblFamilySMS' and xtype='U')
BEGIN
	CREATE TABLE [dbo].[tblFamilySMS](
		[FamilyID] [int] NOT NULL, 
		[ApprovalOfSMS] [bit] NULL,
		[LanguageOfSMS] [nvarchar](5) NULL,
		[ValidityFrom] [datetime] NOT NULL,
		[ValidityTo] [datetime] NULL, 
		CONSTRAINT UC_FamilySMS UNIQUE (FamilyID,ValidityTo)
	);
	ALTER TABLE [dbo].[tblFamilySMS] ADD  CONSTRAINT [DF_tblFamilies_ApprovalOfSMS]  DEFAULT ((0)) FOR [ApprovalOfSMS];
    ALTER TABLE [dbo].[tblFamilySMS] ADD  CONSTRAINT [DF_tblFamilies_LanguageOfSMS]  DEFAULT([dbo].[udfDefaultLanguageCode]()) FOR [LanguageOfSMS];
END
GO


ALTER TABLE tblFamilySMS DROP CONSTRAINT IF EXISTS DF_tblFamilies_LanguageOfSMS;
GO


IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS 
			   WHERE CONSTRAINT_NAME ='FK_tblFamilySMS_tblFamily-FamilyID')
	ALTER TABLE [dbo].[tblFamilySMS] WITH CHECK ADD CONSTRAINT [FK_tblFamilySMS_tblFamily-FamilyID] FOREIGN KEY([FamilyID]) REFERENCES [dbo].[tblFamilies]
GO

IF NOT EXISTS (SELECT * FROM tblControls where FieldName = 'ApprovalOfSMS')
    INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ApprovalOfSMS', N'N', N'Family')
GO

IF COL_LENGTH(N'tblInsuree', N'Vulnerability') IS NULL
ALTER TABLE tblInsuree
ADD Vulnerability BIT NOT NULL DEFAULT(0)
GO

IF NOT EXISTS(SELECT 1 FROM tblControls WHERE FieldName = N'Vulnerability')
INSERT INTO tblControls(FieldName, Adjustibility, Usage)
VALUES(N'Vulnerability', N'O', N'Insuree, Family')
GO

DROP PROCEDURE uspImportOffLineExtract4
GO

DROP TYPE [dbo].[xInsuree]
GO

CREATE TYPE [dbo].[xInsuree] AS TABLE(
	[InsureeID] [int] NULL,
	[FamilyID] [int] NULL,
	[CHFID] [nvarchar](12) NULL,
	[LastName] [nvarchar](100) NULL,
	[OtherNames] [nvarchar](100) NULL,
	[DOB] [date] NULL,
	[Gender] [char](1) NULL,
	[Marital] [char](1) NULL,
	[IsHead] [bit] NULL,
	[passport] [nvarchar](25) NULL,
	[Phone] [nvarchar](50) NULL,
	[PhotoID] [int] NULL,
	[PhotoDate] [date] NULL,
	[CardIssued] [bit] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[Relationship] [smallint] NULL,
	[Profession] [smallint] NULL,
	[Education] [smallint] NULL,
	[Email] [nvarchar](100) NULL,
	[isOffline] [bit] NULL,
	[TypeOfId] [nvarchar](1) NULL,
	[HFID] [int] NULL,
	[CurrentAddress] [nvarchar](200) NULL,
	[CurrentVillage] [int] NULL,
	[GeoLocation] [nvarchar](250) NULL,
	[Vulnerability] [bit]  NULL
)
GO

IF OBJECT_ID('uspImportOffLineExtract4', 'P') IS NOT NULL
    DROP PROCEDURE uspImportOffLineExtract4
GO

CREATE PROCEDURE [dbo].[uspImportOffLineExtract4]
	
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

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = 'ApprovalOfSMS')
    INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ApprovalOfSMS', N'N', N'Family')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Age')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Age', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'AntenatalAmountLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'AntenatalAmountLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ApprovalOfSMS')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ApprovalOfSMS', N'N', N'Family')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'BeneficiaryCard')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'BeneficiaryCard', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Ceiling1')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Ceiling1', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Ceiling2')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Ceiling2', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'CHFID')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'CHFID', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ClaimAdministrator')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ClaimAdministrator', N'M', N'FindClaim, Claim, ClaimReview, ClaimFeedback')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Confirmation')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Confirmation', N'O', N'Family, Insuree, OverviewFamily, ChangeFamily')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ConfirmationNo')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ConfirmationNo', N'O', N'Family, Insuree, FindFamily, OverviewFamily, ChangeFamily')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ConsultationAmountLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ConsultationAmountLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ContributionCategory')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ContributionCategory', N'O', N'Premium, FindPremium')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'CurrentAddress')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'CurrentAddress', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'CurrentDistrict')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'CurrentDistrict', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'CurrentMunicipality')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'CurrentMunicipality', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'CurrentVillage')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'CurrentVillage', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Ded1')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Ded1', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Ded2')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Ded2', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'DeliveryAmountLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'DeliveryAmountLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'DistrictOfFSP')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'DistrictOfFSP', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'DOB')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'DOB', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Education')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Education', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ExpiryDate')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ExpiryDate', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'FamilyType')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'FamilyType', N'O', N'Family, ChangeFamily')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'FirstServicePoint')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'FirstServicePoint', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'FSP')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'FSP', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'FSPCategory')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'FSPCategory', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'FSPDistrict')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'FSPDistrict', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Gender')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Gender', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'GuaranteeNo')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'GuaranteeNo', N'O', N'Claim, ClaimReview')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'HFLevel')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'HFLevel', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'HospitalizationAmountLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'HospitalizationAmountLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'IdentificationNumber')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'IdentificationNumber', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'IdentificationType')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'IdentificationType', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'InsureeEmail')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'InsureeEmail', N'O', N'Family, Insuree, FindFamily')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'LastName')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'LastName', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'lblItemCode')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'lblItemCode', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'lblItemCodeL')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'lblItemCodeL', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'lblItemLeftL')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'lblItemLeftL', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'lblItemMinDate')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'lblItemMinDate', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'lblServiceLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'lblServiceLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'lblServiceMinDate')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'lblServiceMinDate', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'MaritalStatus')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'MaritalStatus', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'OtherNames')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'OtherNames', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'PermanentAddress')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'PermanentAddress', N'O', N'Family, Insuree, ChangeFamily')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'PolicyStatus')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'PolicyStatus', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Poverty')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Poverty', N'O', N'Family, Insuree, Policy, Premium, FindFamily, ChangeFamily')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'ProductCode')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'ProductCode', N'M', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Profession')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Profession', N'O', N'Family, Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'RegionOfFSP')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'RegionOfFSP', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'Relationship')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'Relationship', N'O', N'Insuree')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'SurgeryAmountLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'SurgeryAmountLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalAdmissionsLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalAdmissionsLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalAmount')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalAmount', N'N', N'AppPolicies')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalAntenatalLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalAntenatalLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalConsultationsLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalConsultationsLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalDelivieriesLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalDelivieriesLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalSurgeriesLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalSurgeriesLeft', N'O', N'Search Insurance Number/Enquiry')
GO

IF NOT EXISTS (SELECT 1 FROM tblControls where FieldName = N'TotalVisitsLeft')
		INSERT [dbo].[tblControls] ([FieldName], [Adjustibility], [Usage]) VALUES (N'TotalVisitsLeft', N'O', N'Search Insurance Number/Enquiry')
GO


--New fields in tblPayment
IF COL_LENGTH(N'tblPayment', N'SpReconcReqId') IS NULL
	ALTER TABLE tblPayment ADD SpReconcReqId NVARCHAR(30) NULL
GO

IF COL_LENGTH(N'tblPayment', N'ReconciliationDate') IS NULL
	ALTER TABLE tblPayment ADD ReconciliationDate DATETIME NULL
GO

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------- Stored Procedures ----------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------



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

-- OTC-243 Enquiry in IMIS Claims doesn't function.
IF NOT EXISTS (SELECT * FROM [tblRoleRight] WHERE [RoleID] = @SystemRole AND [RightID] = 101105)
BEGIN
	INSERT [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom]) 
	VALUES (@SystemRole, 101105, CURRENT_TIMESTAMP)
END



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

ALTER TABLE tblInsuree ALTER COLUMN [FamilyID] [int] NULL
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

-- OP-281: Set isOffline status to 0 for insurees in database 
IF NOT EXISTS (SELECT 1 FROM tblIMISDefaults where OfflineCHF = 1 OR OfflineHF = 1)
BEGIN
	UPDATE tblInsuree SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblFamilies SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblInsureePolicy SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblPremium SET isOffline=0 where isOffline is NULL or isOffline<>0
	UPDATE tblPolicy SET isOffline=0 where isOffline is NULL or isOffline<>0
END 


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


	;WITH FollowingPolicies AS 
	( 
		SELECT P.PolicyId, P.FamilyId, ISNULL(Prod.ConversionProdId, Prod.ProdId)ProdID, P.StartDate 
		FROM tblPolicy P 
		INNER JOIN tblProduct Prod ON P.ProdId = ISNULL(Prod.ConversionProdId, Prod.ProdId) 
		WHERE P.ValidityTo IS NULL 
		AND Prod.ValidityTo IS NULL 
	) 

	SELECT R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, R.RenewalpromptDate RenewalpromptDate, O.Phone, RenewalDate EnrollDate, 'R' PolicyStage, F.FamilyID, Prod.ProdID, R.ResponseDate, R.ResponseStatus 
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

-- OTC-8: Authorisation doesn't work properly
-- Adds user profile rights to IMIS Administrator

DECLARE @SystemRole INT
SELECT @SystemRole = role.RoleID from tblRole role where IsSystem=64; --IMIS Administrator

INSERT INTO [dbo].[tblRoleRight] ([RoleID], [RightID], [ValidityFrom], [ValidityTo], [AuditUserId], [LegacyID])
	SELECT @SystemRole, RightIDToAdd, CURRENT_TIMESTAMP, NULL, NULL, NULL
	FROM ( values (122000), (122001), (122002), (122003), (122004), (122005)) as RightsToAdd (RightIDToAdd) -- User Profile Rights
	WHERE NOT EXISTS (SELECT TOP (1) * FROM [dbo].[tblRoleRight] WHERE [RoleID]=@SystemRole AND [RightID]=RightIDToAdd)
GO

-- end of OTC-8

IF OBJECT_ID('uspAddInsureePolicy', 'P') IS NOT NULL
    DROP PROCEDURE [uspAddInsureePolicy]
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


IF OBJECT_ID('uspAcknowledgeControlNumberRequest', 'P') IS NOT NULL
    DROP PROCEDURE uspAcknowledgeControlNumberRequest
GO

CREATE PROCEDURE [dbo].[uspAcknowledgeControlNumberRequest]
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

IF OBJECT_ID('uspPhoneExtract', 'P') IS NOT NULL
    DROP PROCEDURE uspPhoneExtract
GO
CREATE PROCEDURE [dbo].[uspPhoneExtract]
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


IF OBJECT_ID('uspExportOffLineExtract5', 'P') IS NOT NULL
    DROP PROCEDURE uspExportOffLineExtract5
GO
CREATE PROCEDURE [dbo].[uspExportOffLineExtract5]
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
IF OBJECT_ID('uspCreateEnrolmentXML', 'P') IS NOT NULL
    DROP PROCEDURE uspCreateEnrolmentXML
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

IF OBJECT_ID('uspReceiveControlNumber', 'P') IS NOT NULL
    DROP PROCEDURE uspReceiveControlNumber
GO

CREATE PROCEDURE [dbo].[uspReceiveControlNumber]
(
	@PaymentID INT,
	@ControlNumber NVARCHAR(50),
	@ResponseOrigin NVARCHAR(50) = NULL,
	@Failed BIT = 0,
	@Message NVARCHAR (100)=NULL
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
				UPDATE tblPayment SET PaymentStatus = -3, RejectedReason = @Message WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
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

IF OBJECT_ID('uspPrepareBulkControlNumberRequests', 'P') IS NOT NULL
    DROP PROCEDURE uspPrepareBulkControlNumberRequests
GO


CREATE PROCEDURE uspPrepareBulkControlNumberRequests
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

IF COL_LENGTH(N'tblItems', N'Quantity')  IS NULL
ALTER TABLE tblItems ADD Quantity DECIMAL(18, 2) NULL
GO

IF NOT EXISTS(SELECT RuleName from tblIMISDefaultsPhone WHERE RuleName='ShowPaymentOption')
	INSERT INTO tblIMISDefaultsPhone(RuleName, RuleValue) VALUES('ShowPaymentOption', 1)
GO

IF COL_LENGTH(N'dbo.tblIMISDefaultsPhone', N'Usage') IS NULL
	ALTER TABLE [dbo].[tblIMISDefaultsPhone] ADD [Usage] [nvarchar](200) NULL
GO

IF EXISTS (SELECT [RuleName] FROM [dbo].[tblIMISDefaultsPhone]
	WHERE [RuleName] in ('AllowInsureeWithoutPhoto', 'AllowFamilyWithoutPolicy', 'AllowPolicyWithoutPremium', 'ShowPaymentOption')
	and [Usage] IS NULL)
BEGIN
	UPDATE	[dbo].[tblIMISDefaultsPhone]
	SET [Usage] = CASE
		WHEN [RuleName] = 'AllowInsureeWithoutPhoto' THEN 'Allow synchronization of Insurees without a Photo.'
		WHEN [RuleName] = 'AllowFamilyWithoutPolicy' THEN 'Allow synchronization of Families without a Policy.'
		WHEN [RuleName] = 'AllowPolicyWithoutPremium' THEN 'Allow synchronization of Policies without a Contribution. If ShowPaymentOption is false, this rule value is read as true.'
		WHEN [RuleName] = 'ShowPaymentOption' THEN 'Show or hide the Payment option to allow or not to add a Contribution for a Policy.'
		END
	WHERE [RuleName] in ('AllowInsureeWithoutPhoto', 'AllowFamilyWithoutPolicy', 'AllowPolicyWithoutPremium', 'ShowPaymentOption')
END
GO

-- OTC-484
IF COL_LENGTH(N'tblPolicy', N'SelfRenewed') IS NULL
	ALTER TABLE tblPolicy
	ADD SelfRenewed BIT NOT NULL DEFAULT 0
GO

--OTC-73
IF COL_LENGTH(N'tblLanguages', N'CountryCode') IS NULL
	ALTER TABLE tblLanguages
	ADD [CountryCode] NVARCHAR(10) NULL
GO

--feature/fix_missing_fk
IF OBJECT_ID('FK_tblControlNumber_tblPayment') IS NULL
	ALTER TABLE tblControlNumber
	ADD CONSTRAINT FK_tblControlNumber_tblPayment
	FOREIGN KEY (PaymentId) REFERENCES tblPayment(PaymentId)
GO

IF OBJECT_ID('FK_tblPaymentDetails_tblPayment') IS NULL
	ALTER TABLE tblPaymentDetails
	ADD CONSTRAINT FK_tblPaymentDetails_tblPayment
	FOREIGN KEY (PaymentId) REFERENCES tblPayment(PaymentId)

--OTC-511
IF COL_LENGTH(N'tblPremium', N'CreatedDate') IS NULL
	ALTER TABLE tblPremium 
	ADD [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
	UPDATE tblPremium SET CreatedDate = ValidityFrom
GO

--OTC-520
IF COL_LENGTH(N'tblPayment', N'PhoneNumber') IS NOT NULL
	ALTER TABLE tblPayment
	ALTER COLUMN PhoneNumber NVARCHAR(50) NULL
GO

--OTC-528
UPDATE tblPLItems SET LocationId=NULL WHERE LocationId=0
UPDATE tblPLServices SET LocationId=NULL WHERE LocationId=0
GO

--OTC-565
IF (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'tblProduct' AND COLUMN_NAME='MemberCount' AND DATA_TYPE='smallint')=1
ALTER TABLE tblProduct
ALTER COLUMN MemberCount Int NOT NULL
GO

--OTC-578
IF COL_LENGTH(N'tblPayment', N'PayerPhoneNumber') IS NOT NULL
	ALTER TABLE tblPayment ALTER COLUMN PayerPhoneNumber NVARCHAR(50)
GO

IF COL_LENGTH(N'tblOfficer', N'VEOPhone') IS NOT NULL
	ALTER TABLE tblOfficer ALTER COLUMN VEOPhone NVARCHAR(50)
GO

IF COL_LENGTH(N'tblFeedbackPrompt', N'PhoneNumber') IS NOT NULL
	ALTER TABLE tblFeedbackPrompt ALTER COLUMN PhoneNumber NVARCHAR(50)
GO

IF COL_LENGTH(N'tblPolicyRenewals', N'PhoneNumber') IS NOT NULL
	ALTER TABLE tblPolicyRenewals ALTER COLUMN PhoneNumber NVARCHAR(50)
GO

IF COL_LENGTH(N'tblIMISDefaults', N'BypassReviewClaim') IS NULL
	ALTER TABLE tblIMISDefaults ADD  [BypassReviewClaim] BIT NOT NULL DEFAULT (0)
GO

--OP-248
IF COL_LENGTH(N'tblEmailSettings', N'SenderDisplayName') IS NULL
	ALTER TABLE tblEmailSettings ADD SenderDisplayName NVARCHAR(255) NULL
GO


DROP FUNCTION IF EXISTS [dbo].[udfGetSnapshotIndicators];
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
						INNER JOIN tblFamilies F on F.FamilyID = P.FamilyID
						WHERE P.ValidityTo IS NULL AND PolicyStatus = 2
						AND F.ValidityTo IS NULL 
						AND ExpiryDate >=@Date
					  )

		SET @Expired = (SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
				LEFT OUTER JOIN (
					SELECT PL.PolicyID, F.FamilyID, PR.ProdID
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
						INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
						LEFT OUTER JOIN (SELECT FamilyID, ProdID FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyStatus =2 AND  ExpiryDate >=@Date) ActivePolicies ON ActivePolicies.FamilyID = PL.FamilyID AND (ActivePolicies.ProdID = PL.ProdID OR ActivePolicies.ProdID = PR.ConversionProdID)
						WHERE PL.ValidityTo IS NULL AND PL.PolicyStatus = 1 
						AND ExpiryDate >=@Date
						AND ActivePolicies.ProdID IS NULL
						AND F.ValidityTo IS NULL
						)
		SET @Suspended = (
						SELECT COUNT(DISTINCT PL.FamilyID) SuspendedPolicies FROM tblPolicy PL 
						INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
						INNER JOIN tblProduct PR ON PR.ProdID = PL.ProdID
						INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
						LEFT OUTER JOIN (SELECT FamilyID, ProdID FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyStatus =2 AND  ExpiryDate >=@Date) ActivePolicies ON ActivePolicies.FamilyID = PL.FamilyID AND (ActivePolicies.ProdID = PL.ProdID OR ActivePolicies.ProdID = PR.ConversionProdID)
						WHERE PL.ValidityTo IS NULL AND PL.PolicyStatus = 4
						AND ExpiryDate >=@Date
						AND ActivePolicies.ProdID IS NULL
						AND F.ValidityTo IS NULL
						)
		INSERT INTO @tblSnapshotIndicators(ACtive, Expired, Idle, Suspended) VALUES (@ACtive, @Expired, @Idle, @Suspended)
		  RETURN
	END
GO

--OTC-616
IF COL_LENGTH(N'tblFamilies', N'Source') IS NULL
	ALTER TABLE tblFamilies ADD Source NVARCHAR(50) NULL
GO

IF COL_LENGTH(N'tblFamilies', N'SourceVersion') IS NULL
	ALTER TABLE tblFamilies ADD SourceVersion NVARCHAR(15) NULL
GO

IF COL_LENGTH(N'tblInsuree', N'Source') IS NULL
	ALTER TABLE tblInsuree ADD Source NVARCHAR(50) NULL
GO

IF COL_LENGTH(N'tblInsuree', N'SourceVersion') IS NULL
	ALTER TABLE tblInsuree ADD SourceVersion NVARCHAR(15) NULL
GO

IF COL_LENGTH(N'tblPolicy', N'Source') IS NULL
	ALTER TABLE tblPolicy ADD Source NVARCHAR(50) NULL
GO

IF COL_LENGTH(N'tblPolicy', N'SourceVersion') IS NULL
	ALTER TABLE tblPolicy ADD SourceVersion NVARCHAR(15) NULL
GO

IF COL_LENGTH(N'tblPremium', N'Source') IS NULL
	ALTER TABLE tblPremium ADD Source NVARCHAR(50) NULL
GO

IF COL_LENGTH(N'tblPremium', N'SourceVersion') IS NULL
	ALTER TABLE tblPremium ADD SourceVersion NVARCHAR(15) NULL
GO

--OTC-619
IF TYPE_ID('xBulkControlNumbers') IS NULL
BEGIN
	CREATE TYPE [dbo].[xBulkControlNumbers] AS TABLE(
	BillId INT, 
	ProdId INT,
	OfficerId INT, 
	Amount DECIMAL(18,2)
)
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE [TABLE_NAME] = 'tblClaim' AND [COLUMN_NAME] = 'ClaimCode' AND LOWER([DATA_TYPE]) = 'nvarchar' AND [CHARACTER_MAXIMUM_LENGTH] < 50)
BEGIN
	ALTER TABLE [tblClaim] ALTER COLUMN [ClaimCode] NVARCHAR(50)
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE [TABLE_NAME] = 'tblInsuree' AND [COLUMN_NAME] = 'CHFID' AND LOWER([DATA_TYPE]) = 'nvarchar' AND [CHARACTER_MAXIMUM_LENGTH] < 50)
BEGIN
	ALTER TABLE [tblInsuree] ALTER COLUMN [CHFID] NVARCHAR(50)
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE [TABLE_NAME] = 'tblFromPhone' AND [COLUMN_NAME] = 'CHFID' AND LOWER([DATA_TYPE]) = 'nvarchar' AND [CHARACTER_MAXIMUM_LENGTH] < 50)
BEGIN
	ALTER TABLE [tblFromPhone] ALTER COLUMN [CHFID] NVARCHAR(50)
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE [TABLE_NAME] = 'tblPhotos' AND [COLUMN_NAME] = 'CHFID' AND LOWER([DATA_TYPE]) = 'nvarchar' AND [CHARACTER_MAXIMUM_LENGTH] < 50)
BEGIN
	ALTER TABLE [tblPhotos] ALTER COLUMN [CHFID] NVARCHAR(50)
END
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE [TABLE_NAME] = 'tblSubmittedPhotos' AND [COLUMN_NAME] = 'CHFID' AND LOWER([DATA_TYPE]) = 'nvarchar' AND [CHARACTER_MAXIMUM_LENGTH] < 50)
BEGIN
	ALTER TABLE [tblSubmittedPhotos] ALTER COLUMN [CHFID] NVARCHAR(50)
END
GO

--OTC-568
DROP INDEX [missing_index_181] ON [dbo].[tblInsureePolicy]
GO

DROP INDEX [missing_index_250] ON [dbo].[tblInsureePolicy]
GO

DROP INDEX [NCI_tblInsureePolicy_InsureeID] ON [dbo].[tblInsureePolicy]
GO

DROP INDEX [tblInsureePolicy_ValidityTo_EffectiveDate_ExpiryDate] ON [dbo].[tblInsureePolicy]
GO

DROP INDEX [missing_index_203] ON [dbo].[tblInsureePolicy]
GO

DROP INDEX [missing_index_356] ON [dbo].[tblInsureePolicy]
GO

DROP INDEX [NCI_tblInsureePolicy_PolicyID] ON [dbo].[tblInsureePolicy]
GO

--Delete all dirty data where InsureeId is null
DELETE FROM tblInsureePolicy WHERE InsureeId IS NULL
GO

IF COL_LENGTH(N'tblInsureePolicy', N'InsureeId') IS NOT NULL
ALTER TABLE tblInsureePolicy 
ALTER COLUMN InsureeId INT NOT NULL
GO

IF COL_LENGTH(N'tblInsureePolicy', N'PolicyId') IS NOT NULL
ALTER TABLE tblInsureePolicy 
ALTER COLUMN PolicyId INT NOT NULL
GO

CREATE NONCLUSTERED INDEX [missing_index_181] ON [dbo].[tblInsureePolicy]
(
	[InsureeId] ASC,
	[PolicyId] ASC
)
INCLUDE([EffectiveDate],[ExpiryDate],[ValidityTo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_250] ON [dbo].[tblInsureePolicy]
(
	[InsureeId] ASC,
	[ValidityTo] ASC,
	[EffectiveDate] ASC,
	[ExpiryDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [NCI_tblInsureePolicy_InsureeID] ON [dbo].[tblInsureePolicy]
(
	[InsureeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [tblInsureePolicy_ValidityTo_EffectiveDate_ExpiryDate] ON [dbo].[tblInsureePolicy]
(
	[ValidityTo] ASC,
	[EffectiveDate] ASC,
	[ExpiryDate] ASC
)
INCLUDE([InsureeId],[PolicyId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
GO

CREATE NONCLUSTERED INDEX [missing_index_203] ON [dbo].[tblInsureePolicy]
(
	[EffectiveDate] ASC,
	[ValidityTo] ASC
)
INCLUDE([PolicyId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_356] ON [dbo].[tblInsureePolicy]
(
	[PolicyId] ASC,
	[ValidityTo] ASC,
	[EffectiveDate] ASC,
	[ExpiryDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [NCI_tblInsureePolicy_PolicyID] ON [dbo].[tblInsureePolicy]
(
	[PolicyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

-- OTC-643 Update all idle policies (before payment/contribution) effective date from 1900-01-01 to NULL
UPDATE tblPolicy
SET EffectiveDate = NULL
WHERE ValidityTo IS NULL AND EffectiveDate = '1900-01-01' and PolicyStatus = 1
GO

--OTC-687

IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = N'missing_index_248' AND object_id = OBJECT_ID('tblClaimServices'))
ALTER INDEX  [missing_index_248] ON [dbo].[tblClaimServices] DISABLE
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = N'missing_index_275' AND object_id = OBJECT_ID('tblClaimServices'))
ALTER INDEX  [missing_index_275] ON [dbo].[tblClaimServices] DISABLE
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = N'missing_index_278' AND object_id = OBJECT_ID('tblClaimServices'))
ALTER INDEX  [missing_index_278] ON [dbo].[tblClaimServices] DISABLE
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = N'missing_index_323' AND object_id = OBJECT_ID('tblClaimServices'))
ALTER INDEX  [missing_index_323] ON [dbo].[tblClaimServices] DISABLE
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = N'missing_index_354' AND object_id = OBJECT_ID('tblClaimServices'))
ALTER INDEX  [missing_index_354] ON [dbo].[tblClaimServices] DISABLE
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = N'missing_index_384' AND object_id = OBJECT_ID('tblClaimServices'))
ALTER INDEX  [missing_index_384] ON [dbo].[tblClaimServices] DISABLE
GO

--OTC 697
DROP INDEX [missing_index_215] ON [dbo].[tblClaim]
GO

DROP INDEX [missing_index_218] ON [dbo].[tblClaim]
GO

DROP INDEX [missing_index_242] ON [dbo].[tblClaim]
GO

DROP INDEX [missing_index_245] ON [dbo].[tblClaim]
GO

DROP INDEX [missing_index_306] ON [dbo].[tblClaim]
GO

DROP INDEX [missing_index_4896] ON [dbo].[tblClaim]
GO

DROP INDEX [missing_index_50] ON [dbo].[tblClaim]
GO

DROP INDEX [NCI_tblClaim_DateProcessed] ON [dbo].[tblClaim]
GO

IF COL_LENGTH(N'tblClaim', N'DateProcessed') IS NOT NULL
ALTER TABLE tbLClaim
ALTER COLUMN DateProcessed DATE NULL
GO

CREATE NONCLUSTERED INDEX [missing_index_215] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[ValidityTo] ASC,
	[DateProcessed] ASC
)
INCLUDE([ClaimCode]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_218] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[ReviewStatus] ASC,
	[ValidityTo] ASC,
	[DateProcessed] ASC
)
INCLUDE([ClaimCode]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_242] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[ValidityTo] ASC,
	[HFID] ASC,
	[DateProcessed] ASC
)
INCLUDE([ClaimCode]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_245] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[ValidityTo] ASC,
	[HFID] ASC,
	[DateProcessed] ASC
)
INCLUDE([ClaimCode],[Claimed]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

/****** Object:  Index [missing_index_306]    Script Date: 16/09/2022 12:37:04 ******/
CREATE NONCLUSTERED INDEX [missing_index_306] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[ValidityTo] ASC,
	[DateProcessed] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_4896] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[DateProcessed] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [missing_index_50] ON [dbo].[tblClaim]
(
	[ClaimStatus] ASC,
	[ValidityTo] ASC,
	[DateProcessed] ASC
)
INCLUDE([ICDID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO

CREATE NONCLUSTERED INDEX [NCI_tblClaim_DateProcessed] ON [dbo].[tblClaim]
(
	[DateProcessed] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [IndexesFG]
GO
