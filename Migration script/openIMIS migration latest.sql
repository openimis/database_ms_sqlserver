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
	AND (C.RunId IS NULL)
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
	AND (C.RunId IS NULL)
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
			-- check that end date is before today
		if   @LastDay >  GETDATE()
		BEGIN
			SELECT @ErrorMessage = 'End report date must be before today'
			RETURN
		END
		SELECT TOP(1) @ReportingId = ReportingId FROM tblReporting WHERE LocationId = @LocationId AND ISNULL(ProdId,0) = ISNULL(@ProdId,0) 
						AND StartDate = @FirstDay AND EndDate = @LastDay AND ISNULL(OfficerID,0) = ISNULL(@OfficerID,0) AND ReportMode = 0 AND ISNULL(PayerId,0) = ISNULL(@PayerId,0)
		IF @ReportingId is NULL
		BEGIN
			BEGIN TRY
				BEGIN TRAN
					-- if @Mode = 0 -- prescribed
						INSERT INTO tblReporting(ReportingDate,LocationId, ProdId, PayerId, StartDate, EndDate, RecordFound,OfficerID,ReportType,CommissionRate,ReportMode,Scope)
						SELECT GETDATE(),@LocationId,ISNULL(@ProdId,0), @PayerId, @FirstDay, @LastDay, 0,@OfficerId,2,@Rate,@Mode,@Scope; 
						--Get the last inserted reporting Id
						SELECT @ReportingId =  SCOPE_IDENTITY();
			
					UPDATE tblPremium SET ReportingCommissionID =  @ReportingId
						WHERE PremiumId IN (
						SELECT  Pr.PremiumId
						FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID -- AND (PL.PolicyStatus=1 OR PL.PolicyStatus=2)
						LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId
						LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID 
						INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
						INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
						INNER JOIN tblLocations V ON V.LocationId = F.LocationId
						INNER JOIN tblLocations W ON W.LocationId = V.ParentLocationId
						INNER JOIN tblLocations D ON D.LocationId = W.ParentLocationId
						INNER JOIN tblOfficer O ON O.LocationId = D.LocationId AND O.ValidityTo IS NULL AND O.Officerid = PL.OfficerID
						INNER JOIN tblInsuree Ins ON F.InsureeID = Ins.InsureeID  
						LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID 
						WHERE( (@Mode = 1 and PY.MatchedDate IS NOT NULL ) OR  (PY.MatchedDate IS NULL AND @Mode = 0))
						-- AND Year(Pr.PayDate) = @Year AND Month(Pr.paydate) = @Month -- To be change
						and ((Year(Py.[PaymentDate]) = @Year AND Month(Py.[PaymentDate]) = @Month and @Mode = 1 ) OR (Year(Pr.ValidityFrom) = @Year AND Month(Pr.ValidityFrom) = @Month and @Mode = 0 ) )
						AND D.LocationId = @LocationId	or D.ParentLocationId = @LocationId
						AND (ISNULL(Prod.ProdID,0) = ISNULL(@ProdId,0) OR @ProdId is null)
						AND (ISNULL(O.OfficerID,0) = ISNULL(@OfficerId,0) OR @OfficerId IS NULL)
						AND (ISNULL(Payer.PayerID,0) = ISNULL(@PayerId,0) OR @PayerId IS NULL)
						-- AND (Pr.ReportingId IS NULL OR Pr.ReportingId < 0 ) -- not matched will be with negative ID
						AND PR.PayType <> N'F'
						AND (Pr.ReportingCommissionID IS NULL)
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
	END
	      
					    
	-- FETCHT THE DATA FOR THE REPORT		
	-- OTC 70 - don-t put the familly details, insuree head, dob, pazer village and ward

		SELECT  
		Pr.PremiumId,Pr.Paydate, Pr.Receipt, ISNULL(Pr.Amount,0) PrescribedContribution, 
		CASE WHEN @Mode=1 THEN  ISNULL(PD.Amount,0) ELSE ISNULL(Pr.Amount,0) END * @CommissionRate as Commission,
		Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName Product,
		PL.PolicyID, PL.EnrollDate,PL.PolicyStage,
		F.FamilyID,
		D.LocationName DistrictName,
		--V.LocationName VillageName,W.LocationName  WardName,
		o.OfficerID, O.Code + ' ' + O.LastName Officer, OfficerCode,O.Phone PhoneNumber,
		-- Ins.DOB, Ins.IsHead, 
		Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName,	
		REP.ReportMode,Month(REP.StartDate)  [Month], 
		--CASE WHEN Ins.IsHead = 1 THEN ISNULL(Pr.Amount,0) ELSE NULL END Amount, CASE WHEN Ins.IsHead = 1 THEN Pr.Amount ELSE NULL END  PrescribedContribution,
		-- CASE WHEN IsHead = 1 THEN SUM(ISNULL(Pr.Amount,0.00)) * ISNULL(rep.CommissionRate,0.00) ELSE NULL END  CommissionRate,CASE WHEN Ins.IsHead = 1 THEN ISNULL(PD.Amount,0) ELSE NULL END ActualPayment
		PY.PaymentDate, ISNULL(PD.Amount,0) ActualPayment , PY.ExpectedAmount PaymentAmount, TransactionNo
		-- Payer.PayerName
		FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID  AND PL.ValidityTo IS NULL
		LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId AND PD.ValidityTo IS NULl AND PR.ValidityTo IS NULL
		LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID AND PY.ValidityTo IS NULL
		INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID AND Prod.ValidityTo IS NULL
		INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID AND F.ValidityTo IS NULL
		INNER JOIN tblLocations V ON V.LocationId = F.LocationId
		INNER JOIN tblLocations W ON W.LocationId = V.ParentLocationId
		INNER JOIN tblLocations D ON D.LocationId = W.ParentLocationId
		INNER JOIN tblOfficer O ON O.Officerid = PL.OfficerID AND  O.LocationId = D.LocationId AND O.ValidityTo IS NULL
		--  JUST the HEAD INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL
		LEFT JOIN tblInsuree Ins ON F.InsureeID = Ins.InsureeID  
		INNER JOIN tblReporting REP ON REP.ReportingId = @ReportingId
		-- LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID
		WHERE Pr.ReportingCommissionID = @ReportingId and Pr.ValidityTo is null
		GROUP BY Pr.PremiumId,Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName , PL.PolicyID ,  F.FamilyID, D.LocationName,D.LocationID,o.OfficerID , Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames ,O.Code + ' ' + O.LastName ,
		  PL.EnrollDate,REP.ReportMode,Month(REP.StartDate), Pr.Paydate, Pr.Receipt,Pr.Amount,Pr.Amount, PD.Amount , PY.PaymentDate, PY.ExpectedAmount,OfficerCode,PL.PolicyStage,TransactionNo,CommissionRate,O.Phone
		--  Ins.IsHead,Payer.PayerName,Ins.DOB,V.LocationName,W.LocationName,
		ORDER BY PremiumId, O.OfficerID,F.FamilyID DESC;



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

-- ready status support
IF OBJECT_ID('uspMatchPayment', 'P') IS NOT NULL
    DROP PROCEDURE uspMatchPayment
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
	DECLARE @CeilingInterpretation as varchar(1)
	SELECT @CeilingInterpretation = ISNULL(CeilingInterpretation,'H') FROM tblProduct WHERE ProdID = @ProductID

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
										AND ((@TYPE =  'O' and @CeilingInterpretation = 'H' AND tblHF.HFLevel <> 'H') 
										OR (@TYPE =  'O' and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1) 
										OR (@TYPE =  'I' and @CeilingInterpretation = 'H' AND tblHF.HFLevel = 'H')
										OR (@TYPE =  'I'and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)>=1)  
										OR @TYPE =  'B')

			
			SELECT @ClaimValueservices = ISNULL(SUM(tblClaimServices.PriceValuated) ,0)
										FROM tblClaim INNER JOIN
										tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN
										tblHF ON tblClaim.HFID = tblHF.HfID
										INNER JOIN tblProductServices ps on tblClaimServices.ProdID = ps.ProdID and ps.PriceOrigin = 'R'  AND ps.ValidityTo is null and tblClaimServices.ServiceID = ps.ServiceID
										WHERE     (tblClaimServices.ClaimServiceStatus = 1) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 16 OR
										tblClaim.ClaimStatus = 8) AND (ISNULL(MONTH(tblClaim.ProcessStamp) ,-1) BETWEEN @MStart AND @MEnd ) AND 
										(ISNULL(YEAR(tblClaim.ProcessStamp) ,-1) = @Year) AND
										(tblClaimServices.ProdID = @ProductID) 
										AND ((@TYPE =  'O' and @CeilingInterpretation = 'H' AND tblHF.HFLevel <> 'H') 
										OR (@TYPE =  'O' and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1) 
										OR (@TYPE =  'I' and @CeilingInterpretation = 'H' AND tblHF.HFLevel = 'H')
										OR (@TYPE =  'I'and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)>=1)  
										OR @TYPE =  'B')
			
			
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
IF OBJECT_ID('[uspBatchProcess]', 'P') IS NOT NULL
    DROP PROCEDURE [uspBatchProcess]
GO
CREATE PROCEDURE [dbo].[uspBatchProcess]
	
	@AuditUser as int = 0,
	@LocationId as int, 
	@Period as int,
	@Year as int,
	@RtnStatus as int = 0 OUTPUT 
	
	--@RtnStatus 0=OK --> 1 General fault  --> 2 = Already run before 
AS
BEGIN
	DECLARE @tblClaimIDs TABLE(ClaimID INT)

	IF @LocationId=-1
	BEGIN
	SET @LocationId=NULL
	END

	DECLARE @oReturnValue as INT
	SET @oReturnValue = 0 	
	
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

	DECLARE @CLAIMID as INT
	DECLARE @HFLevel as Char(1)
	DECLARE @ProdID as int 
	DECLARE @RP_G as Char(1)
	DECLARE @RP_IP as Char(1)
	DECLARE @RP_OP as Char(1)
	DECLARE @RP_Period as int
	DECLARE @RP_Year as int 
	DECLARE @Index as decimal(18,4)
	
	DECLARE @TargetMonth as int
	DECLARE @TargetQuarter as int
	DECLARE @TargetYear as int
	
	
	SELECT @RP_Period = RunMonth FROM tblBatchRun WHERE RunYear = @Year AND RunMonth = @Period AND ISNULL(LocationId,-1) = ISNULL(@LocationId,-1) AND ValidityTo IS NULL
	
	IF ISNULL(@RP_Period,0) <> 0 
	BEGIN
		SET @oReturnValue = 2 
		SELECT 'Already Run'
		IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
		RETURN @oReturnValue
	END
	
	
	EXEC @oReturnValue = [uspRelativeIndexCalculationMonthly] 12, @Period, @Year , @LocationId, 0, @AuditUser, @RtnStatus
	
	IF @Period = 3 
		EXEC @oReturnValue = [uspRelativeIndexCalculationMonthly] 4, 1, @Year , @LocationId, 0, @AuditUser, @RtnStatus
	IF @Period = 6 
		EXEC @oReturnValue = [uspRelativeIndexCalculationMonthly] 4, 2, @Year , @LocationId, 0, @AuditUser, @RtnStatus
	IF @Period = 9 
		EXEC @oReturnValue = [uspRelativeIndexCalculationMonthly] 4, 3, @Year , @LocationId, 0, @AuditUser, @RtnStatus
	IF @Period = 12
	BEGIN 
		EXEC @oReturnValue = [uspRelativeIndexCalculationMonthly] 4, 4, @Year , @LocationId, 0, @AuditUser, @RtnStatus
		EXEC @oReturnValue = [uspRelativeIndexCalculationMonthly] 1, 1, @Year , @LocationId, 0, @AuditUser, @RtnStatus
	END
	
	DECLARE PRODUCTLOOPITEMS CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT    tblHF.HFLevel, tblProduct.ProdID, tblProduct.PeriodRelPrices, tblProduct.PeriodRelPricesOP, tblProduct.PeriodRelPricesIP,ISNULL(MONTH(tblClaim.ProcessStamp) ,-1) 
										  AS Period, ISNULL(YEAR(tblClaim.ProcessStamp ), -1) AS [Year]
					FROM         tblClaim INNER JOIN
										  tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID INNER JOIN
										  tblHF ON tblClaim.HFID = tblHF.HfID INNER JOIN
										  tblProduct ON tblClaimItems.ProdID = tblProduct.ProdID
					WHERE     (tblClaim.ClaimStatus = 8) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.ClaimItemStatus = 1) AND 
										  (tblClaimItems.PriceOrigin = 'R') and ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId,-1) 
					GROUP BY tblHF.HFLevel, tblProduct.ProdID ,tblProduct.PeriodRelPrices, tblProduct.PeriodRelPricesOP, tblProduct.PeriodRelPricesIP, ISNULL(MONTH(tblClaim.ProcessStamp) ,-1)
										  , ISNULL(YEAR(tblClaim.ProcessStamp ), -1) 

	--DECLARE @Test as decimal(18,2)
	OPEN PRODUCTLOOPITEMS
	FETCH NEXT FROM PRODUCTLOOPITEMS INTO @HFLevel,@ProdID,@RP_G,@RP_OP,@RP_IP,@RP_Period,@RP_Year
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		--IF @ProdID = 108 
		--BEGIN
		--	SET @Test = 0
		--END
		
		SET @Index = -1
		--Determine the actual index for this combination 
		SET @TargetMonth = @RP_Period 
		SET @TargetYear = @RP_Year

		IF @RP_Period = 1 or @RP_Period = 2 OR @RP_Period = 3 
			SET @TargetQuarter = 1
		IF @RP_Period = 4 or @RP_Period = 5 OR @RP_Period = 6 
			SET @TargetQuarter = 2
		IF @RP_Period = 7 or @RP_Period = 8 OR @RP_Period = 9 
			SET @TargetQuarter = 3
		IF @RP_Period = 10 or @RP_Period = 11 OR @RP_Period = 12 
			SET @TargetQuarter = 4
		
		
		IF ISNULL(@RP_G,'') <> '' 
		BEGIN
			IF @RP_G = 'M' 
				SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'B' AND RelType = 12 AND RelPeriod = @TargetMonth  AND RelYear = @TargetYear AND ValidityTo IS NULL  
			IF @RP_G = 'Q' 
				SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'B' AND RelType = 4 AND RelPeriod = @TargetQuarter   AND RelYear = @TargetYear AND ValidityTo IS NULL
			IF @RP_G = 'Y' 
				SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'B' AND RelType = 1 AND RelPeriod = 1  AND RelYear = @TargetYear AND ValidityTo IS NULL
				
		END 	
		ELSE
		BEGIN
					
			IF @HFLevel = 'H' AND ISNULL(@RP_IP,'') <> ''
			BEGIN
				IF @RP_IP = 'M' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'I' AND RelType = 12 AND RelPeriod = @TargetMonth  AND RelYear = @TargetYear AND ValidityTo IS NULL  
				IF @RP_IP = 'Q' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'I' AND RelType = 4 AND RelPeriod = @TargetQuarter   AND RelYear = @TargetYear AND ValidityTo IS NULL
				IF @RP_IP = 'Y' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'I' AND RelType = 1 AND RelPeriod = 1  AND RelYear = @TargetYear AND ValidityTo IS NULL
			END
			
			IF @HFLevel <> 'H' AND ISNULL(@RP_OP,'') <> ''
			BEGIN
				IF @RP_OP = 'M' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'O' AND RelType = 12 AND RelPeriod = @TargetMonth  AND RelYear = @TargetYear AND ValidityTo IS NULL  
				IF @RP_OP = 'Q' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'O' AND RelType = 4 AND RelPeriod = @TargetQuarter   AND RelYear = @TargetYear AND ValidityTo IS NULL
				IF @RP_OP = 'Y' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'O' AND RelType = 1 AND RelPeriod = 1  AND RelYear = @TargetYear AND ValidityTo IS NULL
			END
		END
		
		--IF ISNULL(@Index,-1) = -1 
		--	SET @Index = 1   --> set index to use = 1 if no index could be found !
		
			--update claim items
		IF ISNULL(@Index,-1) > -1 
		BEGIN
			--IF @Index > 1 
				--SET @Index = 1   --> simply never pay more than claimed although index is higher than 1
			
			UPDATE tblClaimItems SET RemuneratedAmount = @Index * PriceValuated 
			OUTPUT Deleted.ClaimID into @tblClaimIDs
			FROM         tblClaim INNER JOIN
										  tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID INNER JOIN
										  tblHF ON tblClaim.HFID = tblHF.HfID INNER JOIN
										  tblProduct ON tblClaimItems.ProdID = tblProduct.ProdID
					WHERE     (tblClaim.ClaimStatus = 8) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.ClaimItemStatus = 1) AND 
										  (tblClaimItems.PriceOrigin = 'R') and ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId ,-1)
										  AND HFLevel = @HFLevel AND tblProduct.ProdID  = @ProdID 
										  AND ISNULL(MONTH(tblClaim.ProcessStamp) , -1) = @RP_Period
										  AND ISNULL(YEAR(tblClaim.ProcessStamp) , -1) = @RP_Year;


		

		END 
		
		
NextProdItems:
		FETCH NEXT FROM PRODUCTLOOPITEMS INTO @HFLevel,@ProdID,@RP_G,@RP_OP,@RP_IP,@RP_Period,@RP_Year
	END
	CLOSE PRODUCTLOOPITEMS
	DEALLOCATE PRODUCTLOOPITEMS
	
	--NOW RUN SERVICES 

	DECLARE PRODUCTLOOPSERVICES CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT    tblHF.HFLevel, tblProduct.ProdID, tblProduct.PeriodRelPrices, tblProduct.PeriodRelPricesOP, tblProduct.PeriodRelPricesIP, ISNULL(MONTH(tblClaim.ProcessStamp) , -1) 
										  AS Period, ISNULL(YEAR(tblClaim.ProcessStamp), -1) AS [Year]
					FROM         tblClaim INNER JOIN
										  tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN
										  tblHF ON tblClaim.HFID = tblHF.HfID INNER JOIN
										  tblProduct ON tblClaimServices.ProdID = tblProduct.ProdID
					WHERE     (tblClaim.ClaimStatus = 8) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.ClaimServiceStatus = 1) AND 
										  (tblClaimServices.PriceOrigin = 'R') and ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId ,-1)
					GROUP BY tblHF.HFLevel, tblProduct.ProdID ,tblProduct.PeriodRelPrices, tblProduct.PeriodRelPricesOP, tblProduct.PeriodRelPricesIP, ISNULL(MONTH(tblClaim.ProcessStamp) , -1) 
										  , ISNULL(YEAR(tblClaim.ProcessStamp), -1)

	OPEN PRODUCTLOOPSERVICES
	FETCH NEXT FROM PRODUCTLOOPSERVICES INTO @HFLevel,@ProdID,@RP_G,@RP_OP,@RP_IP,@RP_Period,@RP_Year
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--IF @ProdID = 108 
		--BEGIN
		--	SET @Test = 0
		--END
		SET @Index = -1
		--Determine the actual index for this combination 
		SET @TargetMonth = @RP_Period 
		SET @TargetYear = @RP_Year

		IF @RP_Period = 1 or @RP_Period = 2 OR @RP_Period = 3 
			SET @TargetQuarter = 1
		IF @RP_Period = 4 or @RP_Period = 5 OR @RP_Period = 6 
			SET @TargetQuarter = 2
		IF @RP_Period = 7 or @RP_Period = 8 OR @RP_Period = 9 
			SET @TargetQuarter = 3
		IF @RP_Period = 10 or @RP_Period = 11 OR @RP_Period = 12 
			SET @TargetQuarter = 4
		
		
		IF ISNULL(@RP_G,'') <> '' 
		BEGIN
			IF @RP_G = 'M' 
				SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'B' AND RelType = 12 AND RelPeriod = @TargetMonth  AND RelYear = @TargetYear AND ValidityTo IS NULL  
			IF @RP_G = 'Q' 
				SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'B' AND RelType = 4 AND RelPeriod = @TargetQuarter   AND RelYear = @TargetYear AND ValidityTo IS NULL
			IF @RP_G = 'Y' 
				SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'B' AND RelType = 1 AND RelPeriod = 1  AND RelYear = @TargetYear AND ValidityTo IS NULL
					
		END 	
		ELSE
		BEGIN
					
			IF @HFLevel = 'H' AND ISNULL(@RP_IP,'') <> ''
			BEGIN
				IF @RP_IP = 'M' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'I' AND RelType = 12 AND RelPeriod = @TargetMonth  AND RelYear = @TargetYear AND ValidityTo IS NULL  
				IF @RP_IP = 'Q' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'I' AND RelType = 4 AND RelPeriod = @TargetQuarter   AND RelYear = @TargetYear AND ValidityTo IS NULL
				IF @RP_IP = 'Y' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'I' AND RelType = 1 AND RelPeriod = 1  AND RelYear = @TargetYear AND ValidityTo IS NULL
			END
			
			IF @HFLevel <> 'H' AND ISNULL(@RP_OP,'') <> ''
			BEGIN
				IF @RP_OP = 'M' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'O' AND RelType = 12 AND RelPeriod = @TargetMonth  AND RelYear = @TargetYear AND ValidityTo IS NULL  
				IF @RP_OP = 'Q' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'O' AND RelType = 4 AND RelPeriod = @TargetQuarter   AND RelYear = @TargetYear AND ValidityTo IS NULL
				IF @RP_OP = 'Y' 
					SELECT @Index = RelIndex FROM dbo.tblRelIndex WHERE ProdID = @ProdID AND RelCareType = 'O' AND RelType = 1 AND RelPeriod = 1  AND RelYear = @TargetYear AND ValidityTo IS NULL
			END
		END
		
		--IF ISNULL(@Index,-1) = -1 
		--	SET @Index = 1   --> set index to use = 1 if no index could be found !
		IF ISNULL(@Index,-1) > -1 
		BEGIN
			
			--IF @Index > 1 
				--SET @Index = 1   --> simply never pay more than claimed altehough index is higher than 1
				
				
			UPDATE tblClaimServices SET RemuneratedAmount = @Index * PriceValuated 
			OUTPUT Deleted.ClaimID into @tblClaimIDs
			FROM         tblClaim INNER JOIN
										  tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN
										  tblHF ON tblClaim.HFID = tblHF.HfID INNER JOIN
										  tblProduct ON tblClaimServices.ProdID = tblProduct.ProdID
					
					WHERE     (tblClaim.ClaimStatus = 8) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.ClaimServiceStatus = 1) AND 
										  (tblClaimServices.PriceOrigin = 'R') and ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId , -1)
										  AND HFLevel = @HFLevel AND tblProduct.ProdID  = @ProdID 
										  AND ISNULL(MONTH(tblClaim.ProcessStamp) , -1) = @RP_Period
										  AND ISNULL(YEAR(tblClaim.ProcessStamp) , -1) = @RP_Year;


			
		
		END

NextProdServices:
		FETCH NEXT FROM PRODUCTLOOPSERVICES INTO @HFLevel,@ProdID,@RP_G,@RP_OP,@RP_IP,@RP_Period,@RP_Year
	END
	CLOSE PRODUCTLOOPSERVICES
	DEALLOCATE PRODUCTLOOPSERVICES


	--Get all the claims in valuated state with no Relative index /Services

	INSERT INTO @tblClaimIDs(ClaimID)

	SELECT tblClaim.ClaimId
	FROM  tblClaim 
	INNER JOIN 	tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID 
	INNER JOIN 	tblProduct ON tblClaimServices.ProdID = tblProduct.ProdID
	WHERE (tblClaim.ClaimStatus = 16) 
	AND (tblClaim.ValidityTo IS NULL) 
	AND (tblClaimServices.ValidityTo IS NULL) 
	AND (tblClaimServices.ClaimServiceStatus = 1) 
	AND (tblClaimServices.PriceOrigin <> 'R') 
	and ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId ,-1)
	AND tblClaim.RunId IS NULL
	AND ISNULL(MONTH(tblClaim.ProcessStamp) , -1) = @Period
	AND ISNULL(YEAR(tblClaim.ProcessStamp) , -1) = @Year
	GROUP BY tblClaim.ClaimID

	UNION

	SELECT tblClaim.ClaimId
	FROM  tblClaim 
	INNER JOIN 	tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID 
	INNER JOIN 	tblProduct ON tblClaimItems.ProdID = tblProduct.ProdID
	WHERE (tblClaim.ClaimStatus = 16) 
	AND (tblClaim.ValidityTo IS NULL) 
	AND (tblClaimItems.ValidityTo IS NULL) 
	AND (tblClaimItems.ClaimItemStatus = 1) 
	AND (tblClaimItems.PriceOrigin <> 'R') 
	and ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId ,-1)
	AND tblClaim.RunId IS NULL
	AND ISNULL(MONTH(tblClaim.ProcessStamp) , -1) = @Period
	AND ISNULL(YEAR(tblClaim.ProcessStamp) , -1) = @Year
	GROUP BY tblClaim.ClaimID;


	
	--NOW UPDATE the status of all Claims that have all remunerations values updated ==> set to 16
	UPDATE tblClaim SET ClaimStatus = 16 FROM tblClaim 
	INNER JOIN @tblClaimIDs UpdClaims on UpdClaims.ClaimID = tblClaim.ClaimID  WHERE ClaimStatus = 8 AND tblClaim.ValidityTo IS NULL AND
	tblClaim.ClaimID NOT IN 
	(SELECT tblClaim.ClaimID FROM tblClaim INNER JOIN tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID INNER JOIN tblProduct ON tblClaimItems.ProdID = tblProduct.ProdID 
	 WHERE tblClaim.ValidityTo IS NULL AND ISNULL(LocationId,-1) = ISNULL(@LocationId,-1) AND tblClaimItems.RemuneratedAmount IS NULL AND tblClaim.ClaimStatus = 8 AND tblClaimItems.ValidityTo IS NULL
	 AND tblClaimItems.ClaimItemStatus = 1
	 GROUP BY tblClaim.ClaimID 
	)
	AND 
	tblClaim.ClaimID NOT IN 
	(SELECT tblClaim.ClaimID FROM tblClaim
	INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID 
	INNER JOIN tblProduct  ON tblClaimServices.ProdID = tblProduct.ProdID  
	 WHERE tblClaim.ValidityTo IS NULL AND ISNULL(LocationId,-1) = ISNULL(@LocationId,-1) AND tblClaimServices.RemuneratedAmount IS NULL AND tblClaim.ClaimStatus = 8 AND tblClaimServices.ValidityTo IS NULL
	 AND tblClaimServices.ClaimServiceStatus  = 1
	 GROUP BY tblClaim.ClaimID  
	)
	
	--NOW insert a new batch run record and keep latest ID in memory
	INSERT INTO tblBatchRun
           ([LocationId],[RunYear],[RunMonth],[RunDate],[AuditUserID])
    VALUES (@LocationId ,@Year, @Period , GETDATE() ,@AuditUser )
    
    DECLARE @RunID as int
    
    SELECT @RunID = SCOPE_IDENTITY ()
    
	DECLARE @MStart as INT  = 0 
	DECLARE @MEnd as INT = 0 

	
	IF @Period = 3 
	BEGIN
		SET @MStart = 1 
		SET @MEnd = 3 
	END
	IF @Period = 6 
	BEGIN
		SET @MStart = 4
		SET @MEnd = 6
	END
	IF @Period = 9
	BEGIN
		SET @MStart = 7
		SET @MEnd = 9
	END
	IF @Period = 12
	BEGIN
		SET @MStart = 1
		SET @MEnd = 12
	END
	
	
	


	UPDATE tblClaim SET RunID = @RunID FROM tblClaim inner join @tblClaimIDs UpdClaims on UpdClaims.ClaimID = tblClaim.ClaimID
    WHERE tblClaim.ValidityTo IS NULL AND ClaimStatus = 16 AND RunID IS NULL AND ISNULL(MONTH(tblClaim.ProcessStamp) , -1) = @Period
										  AND ISNULL(YEAR(tblClaim.ProcessStamp) , -1) = @Year

	IF @MStart > 0 
	BEGIN
		-- we are running multiple batches e.g Quarterly or Yearly
		UPDATE tblClaim SET RunID = @RunID FROM tblClaim inner join @tblClaimIDs UpdClaims on UpdClaims.ClaimID = tblClaim.ClaimID
		WHERE tblClaim.ValidityTo IS NULL AND ClaimStatus = 16 AND RunID IS NULL AND (ISNULL(MONTH(tblClaim.ProcessStamp) , -1) BETWEEN @MStart  AND @MEnd )  AND ISNULL(YEAR(tblClaim.ProcessStamp) , -1) = @Year
	END
	
FINISH:
	IF @InTopIsolation = 0 COMMIT TRANSACTION PROCESSCLAIMS
	SET @oReturnValue = 0 
	RETURN @oReturnValue

	END TRY
	BEGIN CATCH
		SET @oReturnValue = 1 
		SELECT ERROR_MESSAGE () as ErrorMessage
		IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
		RETURN @oReturnValue
		
	END CATCH
	
ERR_HANDLER:

	SELECT ERROR_MESSAGE () as ErrorMessage
	IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
	RETURN @oReturnValue

	
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

IF OBJECT_ID('uspInsertPaymentIntent', 'P') IS NOT NULL
    DROP PROCEDURE uspInsertPaymentIntent
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

-- OTC-10: Changing the logic of user Roles
IF OBJECT_ID('uspCreateCapitationPaymentReportData', 'P') IS NOT NULL
    DROP PROCEDURE uspCreateCapitationPaymentReportData
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

IF OBJECT_ID('uspAPIGetClaims', 'P') IS NOT NULL
    DROP PROCEDURE uspAPIGetClaims
GO

CREATE PROCEDURE [dbo].[uspAPIGetClaims]
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


IF OBJECT_ID('uspReceivePayment', 'P') IS NOT NULL
    DROP PROCEDURE uspReceivePayment
GO
CREATE PROCEDURE [dbo].[uspReceivePayment]
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

IF OBJECT_ID('uspAPIGetCoverage', 'P') IS NOT NULL
    DROP PROCEDURE uspAPIGetCoverage
GO
CREATE PROCEDURE [dbo].[uspAPIGetCoverage]
(
	@InsureeNumber NVARCHAR(12),
	@MinDateService DATE = NULL  OUTPUT,
	@MinDateItem DATE = NULL OUTPUT,
	@ServiceLeft INT = 0 OUTPUT,
	@ItemLeft INT = 0 OUTPUT,
	@isItemOK BIT = 0 OUTPUT,
	@isServiceOK BIT = 0 OUTPUT
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
IF OBJECT_ID('uspUpdateClaimFromPhone', 'P') IS NOT NULL
    DROP PROCEDURE uspUpdateClaimFromPhone
GO
CREATE PROCEDURE [dbo].[uspUpdateClaimFromPhone]
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
			EXEC uspSubmitSingleClaim -1, @ClaimID,0, @RtnStatus=@ClaimRejectionStatus OUTPUT
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

IF NOT OBJECT_ID('uspPolicyRenewalInserts') IS NULL
	DROP PROCEDURE uspPolicyRenewalInserts
GO

CREATE PROCEDURE [dbo].[uspPolicyRenewalInserts](
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

IF NOT OBJECT_ID('uspIsValidRenewal') IS NULL
	DROP PROCEDURE uspIsValidRenewal
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
	--PAUL -24/04/2019 INSERTED  @@AND tblPolicy.ValidityTo@@ to ensure that query does not include deleted policies
	SELECT TOP 1 @ProdId = tblPolicy.ProdID, @ExpiryDate = tblPolicy.ExpiryDate from tblPolicy INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID  AND tblPolicy.ValidityTo IS NULL WHERE FamilyID = @FamilyID AND tblProduct.ProductCode = @ProductCode AND tblProduct.ValidityTo IS NULL ORDER BY ExpiryDate DESC
	
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



/****** Object:  StoredProcedure [dbo].[uspRestAPIConsumeEnrollments]    Script Date: 10/29/2021 3:23:56 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


IF OBJECT_ID('[uspRestAPIConsumeEnrollments]', 'P') IS NOT NULL
    DROP PROCEDURE [uspRestAPIConsumeEnrollments]
GO
CREATE PROCEDURE [dbo].[uspRestAPIConsumeEnrollments](
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

IF OBJECT_ID('[uspRestAPISubmitSingleClaim]', 'P') IS NOT NULL
    DROP PROCEDURE [uspRestAPISubmitSingleClaim]
GO
CREATE PROCEDURE [dbo].[uspRestAPISubmitSingleClaim]
	
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


GO

/****** Object:  StoredProcedure [dbo].[uspRestAPIUpdateClaimFromPhone]    Script Date: 10/29/2021 3:21:24 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[uspRestAPIUpdateClaimFromPhone]', 'P') IS NOT NULL
    DROP PROCEDURE [uspRestAPIUpdateClaimFromPhone]
GO
CREATE PROCEDURE [dbo].[uspRestAPIUpdateClaimFromPhone]
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


/****** Object:  StoredProcedure [dbo].[uspUpdateClaimFromPhone]    Script Date: 10/29/2021 4:09:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[uspUpdateClaimFromPhone]', 'P') IS NOT NULL
    DROP PROCEDURE [uspUpdateClaimFromPhone]
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


/****** Object:  StoredProcedure [dbo].[uspConsumeEnrollments]    Script Date: 10/29/2021 4:12:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


IF OBJECT_ID('[uspConsumeEnrollments]', 'P') IS NOT NULL
    DROP PROCEDURE [uspConsumeEnrollments]
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


/****** Object:  StoredProcedure [dbo].[uspSubmitSingleClaim]    Script Date: 10/29/2021 4:10:37 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[uspSubmitSingleClaim]', 'P') IS NOT NULL
    DROP PROCEDURE [uspSubmitSingleClaim]
GO
CREATE PROCEDURE [dbo].[uspSubmitSingleClaim]
	
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


GO

