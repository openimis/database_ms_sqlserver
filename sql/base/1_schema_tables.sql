CREATE SCHEMA [dw]
GO
CREATE TYPE [dbo].[xClaimRejReasons] AS TABLE(
	[ID] [int] NOT NULL,
	[Name] [nvarchar](100) NULL
)
GO

CREATE TYPE [dbo].[xAttribute] AS TABLE(
	[ID] [int] NOT NULL,
	[Name] [nvarchar](50) NULL
)
GO

CREATE TYPE [dbo].[xAttributeV] AS TABLE(
	[Code] [nvarchar](15) NOT NULL,
	[Name] [nvarchar](50) NULL
)
GO

CREATE TYPE [dbo].[xCareType] AS TABLE(
	[Code] [char](1) NOT NULL,
	[Name] [nvarchar](50) NULL,
	[AltLanguage] [nvarchar](50) NULL
)
GO

CREATE TYPE [dbo].[xClaimAdmin] AS TABLE(
	[ClaimAdminId] [int] NOT NULL,
	[ClaimAdminCode] [nvarchar](8) NULL,
	[LastName] [nvarchar](100) NULL,
	[OtherNames] [nvarchar](100) NULL,
	[DOB] [date] NULL,
	[Phone] [nvarchar](50) NULL,
	[HFId] [int] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[EmailId] [nvarchar](200) NULL,
	PRIMARY KEY CLUSTERED 
(
	[ClaimAdminId] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xClaimProcess] AS TABLE(
	[ClaimID] [int] NOT NULL,
	[RowID] [bigint] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ClaimID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xClaimSelection] AS TABLE(
	[ClaimID] [int] NOT NULL
)
GO

CREATE TYPE [dbo].[xClaimSubmit] AS TABLE(
	[ClaimID] [int] NOT NULL,
	[RowID] [bigint] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ClaimID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xDistricts] AS TABLE(
	[DistrictID] [int] NOT NULL,
	[DistrictName] [nvarchar](50) NOT NULL,
	[DistrictCode] [nvarchar](8) NULL,
	[Region] [nvarchar](50) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[Prefix] [smallint] NULL,
	PRIMARY KEY CLUSTERED 
(
	[DistrictID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xFamilies] AS TABLE(
	[FamilyID] [int] NULL,
	[InsureeID] [int] NULL,
	[LocationID] [int] NULL,
	[Poverty] [bit] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[FamilyType] [nvarchar](2) NULL,
	[FamilyAddress] [nvarchar](200) NULL,
	[Ethnicity] [nvarchar](1) NULL,
	[isOffline] [bit] NULL,
	[ConfirmationNo] [nvarchar](12) NULL,
	[ConfirmationType] [nvarchar](3) NULL
)
GO

CREATE TYPE [dbo].[xGender] AS TABLE(
	[Code] [char](1) NULL,
	[Gender] [nvarchar](50) NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL
)
GO

CREATE TYPE [dbo].[xHF] AS TABLE(
	[HfID] [int] NOT NULL,
	[HFCode] [nvarchar](8) NOT NULL,
	[HFName] [nvarchar](100) NOT NULL,
	[LegalForm] [char](1) NOT NULL,
	[HFLevel] [char](1) NOT NULL,
	[HFSublevel] [char](1) NULL,
	[HFAddress] [nvarchar](100) NULL,
	[LocationId] [int] NOT NULL,
	[Phone] [nvarchar](50) NULL,
	[Fax] [nvarchar](50) NULL,
	[eMail] [nvarchar](50) NULL,
	[HFCareType] [char](1) NOT NULL,
	[PLServiceID] [int] NULL,
	[PLItemID] [int] NULL,
	[AccCode] [nvarchar](25) NULL,
	[OffLine] [bit] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[HfID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xHFCatchment] AS TABLE(
	[HFCatchmentId] [int] NULL,
	[HFID] [int] NULL,
	[LocationId] [int] NULL,
	[Catchment] [int] NULL
)
GO

CREATE TYPE [dbo].[xICDCodes] AS TABLE(
	[ICDID] [int] NOT NULL,
	[ICDCode] [nvarchar](6) NOT NULL,
	[ICDName] [nvarchar](255) NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ICDID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
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

CREATE TYPE [dbo].[xInsureePolicy] AS TABLE(
	[InsureePolicyId] [int] NULL,
	[InsureeId] [int] NULL,
	[PolicyId] [int] NULL,
	[EnrollmentDate] [date] NULL,
	[StartDate] [date] NULL,
	[EffectiveDate] [date] NULL,
	[ExpiryDate] [date] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[isOffline] [bit] NULL
)
GO

CREATE TYPE [dbo].[xItems] AS TABLE(
	[ItemID] [int] NOT NULL,
	[ItemCode] [nvarchar](6) NOT NULL,
	[ItemName] [nvarchar](100) NOT NULL,
	[ItemType] [char](1) NOT NULL,
	[ItemPackage] [nvarchar](255) NULL,
	[ItemPrice] [decimal](18, 2) NOT NULL,
	[ItemCareType] [char](1) NOT NULL,
	[ItemFrequency] [smallint] NULL,
	[ItemPatCat] [tinyint] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ItemID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xLocations] AS TABLE(
	[LocationId] [int] NOT NULL,
	[LocationCode] [nvarchar](8) NULL,
	[LocationName] [nvarchar](50) NULL,
	[ParentLocationId] [int] NULL,
	[LocationType] [nchar](1) NOT NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL
)
GO

CREATE TYPE [dbo].[xOfficers] AS TABLE(
	[OfficerID] [int] NULL,
	[Code] [nvarchar](8) NULL,
	[LastName] [nvarchar](100) NULL,
	[OtherNames] [nvarchar](100) NULL,
	[DOB] [date] NULL,
	[Phone] [nvarchar](50) NULL,
	[LocationId] [int] NULL,
	[OfficerIDSubst] [int] NULL,
	[WorksTo] [smalldatetime] NULL,
	[VEOCode] [nvarchar](25) NULL,
	[VEOLastName] [nvarchar](100) NULL,
	[VEOOtherNames] [nvarchar](100) NULL,
	[VEODOB] [date] NULL,
	[VEOPhone] [nvarchar](25) NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[EmailId] [nvarchar](200) NULL,
	[PhoneCommunication] [bit] NULL,
	[PermanentAddress] [nvarchar](100) NULL
)
GO

CREATE TYPE [dbo].[xOfficerVillages] AS TABLE(
	[OfficerVillageId] [int] NULL,
	[OfficerId] [int] NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL
)
GO

CREATE TYPE [dbo].[xPayementStatus] AS TABLE(
	[StatusID] [int] NULL,
	[PaymenyStatusName] [nvarchar](40) NULL
)
GO

CREATE TYPE [dbo].[xPayers] AS TABLE(
	[PayerID] [int] NOT NULL,
	[PayerType] [char](1) NOT NULL,
	[PayerName] [nvarchar](100) NOT NULL,
	[PayerAddress] [nvarchar](100) NULL,
	[LocationId] [int] NULL,
	[Phone] [nvarchar](50) NULL,
	[Fax] [nvarchar](50) NULL,
	[eMail] [nvarchar](50) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PayerID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xPhotos] AS TABLE(
	[PhotoID] [int] NULL,
	[InsureeID] [int] NULL,
	[CHFID] [char](12) NULL,
	[PhotoFolder] [nvarchar](255) NULL,
	[PhotoFileName] [nvarchar](250) NULL,
	[OfficerID] [int] NULL,
	[PhotoDate] [date] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[AuditUserID] [int] NULL
)
GO

CREATE TYPE [dbo].[xPLItems] AS TABLE(
	[PLItemID] [int] NOT NULL,
	[PLItemName] [nvarchar](100) NOT NULL,
	[DatePL] [date] NOT NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLItemID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xPLItemsDetail] AS TABLE(
	[PLItemDetailID] [int] NOT NULL,
	[PLItemID] [int] NOT NULL,
	[ItemID] [int] NOT NULL,
	[PriceOverule] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLItemDetailID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xPLServices] AS TABLE(
	[PLServiceID] [int] NOT NULL,
	[PLServName] [nvarchar](100) NOT NULL,
	[DatePL] [date] NOT NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLServiceID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xPLServicesDetail] AS TABLE(
	[PLServiceDetailID] [int] NOT NULL,
	[PLServiceID] [int] NOT NULL,
	[ServiceID] [int] NOT NULL,
	[PriceOverule] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLServiceDetailID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xPolicy] AS TABLE(
	[PolicyID] [int] NULL,
	[FamilyID] [int] NULL,
	[EnrollDate] [date] NULL,
	[StartDate] [date] NULL,
	[EffectiveDate] [date] NULL,
	[ExpiryDate] [date] NULL,
	[PolicyStatus] [tinyint] NULL,
	[PolicyValue] [decimal](18, 2) NULL,
	[ProdID] [int] NULL,
	[OfficerID] [int] NULL,
	[PolicyStage] [char](1) NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[isOffline] [bit] NULL
)
GO

CREATE TYPE [dbo].[xPremium] AS TABLE(
	[PremiumId] [int] NULL,
	[PolicyID] [int] NULL,
	[PayerID] [int] NULL,
	[Amount] [decimal](18, 2) NULL,
	[Receipt] [nvarchar](50) NULL,
	[PayDate] [date] NULL,
	[PayType] [char](1) NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[isPhotoFee] [bit] NULL,
	[ReportingId] [int] NULL,
	[isOffline] [bit] NULL
)
GO

CREATE TYPE [dbo].[xProduct] AS TABLE(
	[ProdID] [int] NOT NULL,
	[ProductCode] [nvarchar](8) NOT NULL,
	[ProductName] [nvarchar](100) NOT NULL,
	[LocationId] [int] NULL,
	[InsurancePeriod] [tinyint] NOT NULL,
	[DateFrom] [smalldatetime] NOT NULL,
	[DateTo] [smalldatetime] NOT NULL,
	[ConversionProdID] [int] NULL,
	[LumpSum] [decimal](18, 2) NOT NULL,
	[MemberCount] [smallint] NOT NULL,
	[PremiumAdult] [decimal](18, 2) NULL,
	[PremiumChild] [decimal](18, 2) NULL,
	[DedInsuree] [decimal](18, 2) NULL,
	[DedOPInsuree] [decimal](18, 2) NULL,
	[DedIPInsuree] [decimal](18, 2) NULL,
	[MaxInsuree] [decimal](18, 2) NULL,
	[MaxOPInsuree] [decimal](18, 2) NULL,
	[MaxIPInsuree] [decimal](18, 2) NULL,
	[PeriodRelPrices] [char](1) NULL,
	[PeriodRelPricesOP] [char](1) NULL,
	[PeriodRelPricesIP] [char](1) NULL,
	[AccCodePremiums] [nvarchar](25) NULL,
	[AccCodeRemuneration] [nvarchar](25) NULL,
	[DedTreatment] [decimal](18, 2) NULL,
	[DedOPTreatment] [decimal](18, 2) NULL,
	[DedIPTreatment] [decimal](18, 2) NULL,
	[MaxTreatment] [decimal](18, 2) NULL,
	[MaxOPTreatment] [decimal](18, 2) NULL,
	[MaxIPTreatment] [decimal](18, 2) NULL,
	[DedPolicy] [decimal](18, 2) NULL,
	[DedOPPolicy] [decimal](18, 2) NULL,
	[DedIPPolicy] [decimal](18, 2) NULL,
	[MaxPolicy] [decimal](18, 2) NULL,
	[MaxOPPolicy] [decimal](18, 2) NULL,
	[MaxIPPolicy] [decimal](18, 2) NULL,
	[GracePeriod] [int] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RegistrationLumpSum] [decimal](18, 2) NULL,
	[RegistrationFee] [decimal](18, 2) NULL,
	[GeneralAssemblyLumpSum] [decimal](18, 2) NULL,
	[GeneralAssemblyFee] [decimal](18, 2) NULL,
	[StartCycle1] [nvarchar](5) NULL,
	[StartCycle2] [nvarchar](5) NULL,
	[MaxNoConsultation] [int] NULL,
	[MaxNoSurgery] [int] NULL,
	[MaxNoDelivery] [int] NULL,
	[MaxNoHospitalizaion] [int] NULL,
	[MaxNoVisits] [int] NULL,
	[MaxAmountConsultation] [decimal](18, 2) NULL,
	[MaxAmountSurgery] [decimal](18, 2) NULL,
	[MaxAmountDelivery] [decimal](18, 2) NULL,
	[MaxAmountHospitalization] [decimal](18, 2) NULL,
	[GracePeriodRenewal] [int] NULL,
	[MaxInstallments] [int] NULL,
	[WaitingPeriod] [int] NULL,
	[RenewalDiscountPerc] [int] NULL,
	[RenewalDiscountPeriod] [int] NULL,
	[StartCycle3] [nvarchar](5) NULL,
	[StartCycle4] [nvarchar](5) NULL,
	[AdministrationPeriod] [int] NULL,
	[Threshold] [int] NULL,
	[MaxPolicyExtraMember] [decimal](18, 2) NULL,
	[MaxPolicyExtraMemberIP] [decimal](18, 2) NULL,
	[MaxPolicyExtraMemberOP] [decimal](18, 2) NULL,
	[MaxCeilingPolicy] [decimal](18, 2) NULL,
	[MaxCeilingPolicyIP] [decimal](18, 2) NULL,
	[MaxCeilingPolicyOP] [decimal](18, 2) NULL,
	[EnrolmentDiscountPerc] [int] NULL,
	[EnrolmentDiscountPeriod] [int] NULL,
	[MaxAmountAntenatal] [decimal](18, 2) NULL,
	[MaxNoAntenatal] [int] NULL,
	[CeilingInterpretation] [char](1) NULL,
	[Level1] [char](1) NULL,
	[Sublevel1] [char](1) NULL,
	[Level2] [char](1) NULL,
	[Sublevel2] [char](1) NULL,
	[Level3] [char](1) NULL,
	[Sublevel3] [char](1) NULL,
	[Level4] [char](1) NULL,
	[Sublevel4] [char](1) NULL,
	[ShareContribution] [decimal](5, 2) NULL DEFAULT ((100.00)),
	[WeightPopulation] [decimal](5, 2) NULL DEFAULT ((0.00)),
	[WeightNumberFamilies] [decimal](5, 2) NULL DEFAULT ((0.00)),
	[WeightInsuredPopulation] [decimal](5, 2) NULL DEFAULT ((100.00)),
	[WeightNumberInsuredFamilies] [decimal](5, 2) NULL DEFAULT ((0.00)),
	[WeightNumberVisits] [decimal](5, 2) NULL DEFAULT ((0.00)),
	[WeightAdjustedAmount] [decimal](5, 2) NULL DEFAULT ((0.00))
)
GO

CREATE TYPE [dbo].[xProductItems] AS TABLE(
	[ProdItemID] [int] NOT NULL,
	[ProdID] [int] NOT NULL,
	[ItemID] [int] NOT NULL,
	[LimitationType] [char](1) NOT NULL,
	[PriceOrigin] [char](1) NOT NULL,
	[LimitAdult] [decimal](18, 2) NULL,
	[LimitChild] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[WaitingPeriodAdult] [int] NULL,
	[WaitingPeriodChild] [int] NULL,
	[LimitNoAdult] [int] NULL,
	[LimitNoChild] [int] NULL,
	[LimitationTypeR] [char](1) NULL,
	[LimitationTypeE] [char](1) NULL,
	[LimitAdultR] [decimal](18, 2) NULL,
	[LimitAdultE] [decimal](18, 2) NULL,
	[LimitChildR] [decimal](18, 2) NULL,
	[LimitChildE] [decimal](18, 2) NULL,
	[CeilingExclusionAdult] [nvarchar](1) NULL,
	[CeilingExclusionChild] [nvarchar](1) NULL,
	PRIMARY KEY CLUSTERED 
(
	[ProdItemID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xProductServices] AS TABLE(
	[ProdServiceID] [int] NOT NULL,
	[ProdID] [int] NOT NULL,
	[ServiceID] [int] NOT NULL,
	[LimitationType] [char](1) NOT NULL,
	[PriceOrigin] [char](1) NOT NULL,
	[LimitAdult] [decimal](18, 2) NULL,
	[LimitChild] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[WaitingPeriodAdult] [int] NULL,
	[WaitingPeriodChild] [int] NULL,
	[LimitNoAdult] [int] NULL,
	[LimitNoChild] [int] NULL,
	[LimitationTypeR] [char](1) NULL,
	[LimitationTypeE] [char](1) NULL,
	[LimitAdultR] [decimal](18, 2) NULL,
	[LimitAdultE] [decimal](18, 2) NULL,
	[LimitChildR] [decimal](18, 2) NULL,
	[LimitChildE] [decimal](18, 2) NULL,
	[CeilingExclusionAdult] [nvarchar](1) NULL,
	[CeilingExclusionChild] [nvarchar](1) NULL,
	PRIMARY KEY CLUSTERED 
(
	[ProdServiceID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xRegions] AS TABLE(
	[RegionId] [int] NOT NULL,
	[RegionName] [nvarchar](50) NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[RegionCode] [nvarchar](8) NULL,
	PRIMARY KEY CLUSTERED 
(
	[RegionId] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xRelDistr] AS TABLE(
	[DistrID] [int] NOT NULL,
	[DistrType] [tinyint] NOT NULL,
	[DistrCareType] [char](1) NOT NULL,
	[ProdID] [int] NOT NULL,
	[Period] [tinyint] NOT NULL,
	[DistrPerc] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[DistrID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xServices] AS TABLE(
	[ServiceID] [int] NOT NULL,
	[ServCode] [nvarchar](6) NOT NULL,
	[ServName] [nvarchar](100) NOT NULL,
	[ServType] [char](1) NOT NULL,
	[ServLevel] [char](1) NOT NULL,
	[ServPrice] [decimal](18, 2) NOT NULL,
	[ServCareType] [char](1) NOT NULL,
	[ServFrequency] [smallint] NULL,
	[ServPatCat] [tinyint] NOT NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[ServCategory] [char](1) NULL,
	PRIMARY KEY CLUSTERED 
(
	[ServiceID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xtblOfficerVillages] AS TABLE(
	[OfficerId] [int] NULL,
	[VillageId] [int] NULL,
	[AuditUserId] [int] NULL,
	[Action] [char](1) NULL
)
GO

-- Last updated 15.10.2020
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
GO


CREATE TYPE [dbo].[xVillages] AS TABLE(
	[VillageID] [int] NOT NULL,
	[WardID] [int] NOT NULL,
	[VillageName] [nvarchar](50) NOT NULL,
	[VillageCode] [nvarchar](8) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[VillageID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

CREATE TYPE [dbo].[xWards] AS TABLE(
	[WardID] [int] NOT NULL,
	[DistrictID] [int] NOT NULL,
	[WardName] [nvarchar](50) NOT NULL,
	[WardCode] [nvarchar](8) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[WardID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfAPIisValidMaritalStatus](
	@MaritalStatusCode NVARCHAR(1)
)

RETURNS BIT
AS
BEGIN
		DECLARE @tblMaritalStatus TABLE(MaritalStatusCode NVARCHAR(1))
		DECLARE @isValid BIT
		INSERT INTO @tblMaritalStatus(MaritalStatusCode) 
		VALUES ('N'),('W'),('S'),('D'),('M'),(NULL)

		IF EXISTS(SELECT 1 FROM @tblMaritalStatus WHERE MaritalStatusCode = @MaritalStatusCode)
			SET @isValid = 1
		ELSE 
			SET @isValid = 0

      RETURN(@isValid)
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfAvailablePremium]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product Base, 2:Officer Mode
)
RETURNS @Result TABLE(ProdId INT, Allocated FLOAT,Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
	DECLARE @Date DATE,
		@DaysInMonth INT,
		@EndDate DATE

	SELECT @Date = CAST(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-' + '01' AS DATE)
	SELECT @DaysInMonth = DATEDIFF(DAY,@Date,DATEADD(MONTH,1,@Date))
	SELECT @EndDate = CAST(CONVERT(VARCHAR(4),@Year) + '-' + CONVERT(VARCHAR(2),@Month) + '-' + CONVERT(VARCHAR(2),@DaysInMonth) AS DATE)


	IF @Mode = 1
		BEGIN

			;WITH Allocation AS
			(
				SELECT PL.ProdID,
				CASE 
				WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
					THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
				WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
					THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
				WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
					THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
				END Allocated
				FROM tblPremium PR 
				INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
				INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
				INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
				INNER JOIN tblWards W ON W.WardId = V.WardId
				INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
				WHERE PR.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL
				AND PL.ProdID = @ProdId
				AND PL.PolicyStatus <> 1
				AND PR.PayDate <= PL.ExpiryDate
				AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
				GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate
			)
			INSERT INTO @Result(ProdId,Allocated)
			SELECT ProdId, ISNULL(SUM(Allocated), 0)Allocated
			FROM Allocation
			GROUP BY ProdId
		END
	ELSE IF @Mode = 2
		BEGIN
			;WITH Allocation AS
			(
				SELECT PL.ProdID,
				CASE 
				WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
					THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
				WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
					THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
				WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
					THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
				END Allocated,
				O.Code, O.LastName, O.OtherNames
				FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
				INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
				INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
				INNER JOIN tblWards W ON W.WardId = V.WardId
				INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
				INNER JOIN tblOfficer O ON PL.OfficerId = O.OfficerID
				WHERE PR.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL
				AND O.ValidityTo IS NULL
				AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
				AND PL.PolicyStatus <> 1
				AND PR.PayDate <= PL.ExpiryDate
				GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate, O.Code, O.LastName, O.OtherNames
			)
			INSERT INTO @Result(ProdId,Allocated,Officer,LastName,OtherNames)
			SELECT ProdId, ISNULL(SUM(Allocated), 0)Allocated, Code, LastName, OtherNames
			FROM Allocation
			GROUP BY ProdId, Code, LastName, OtherNames
		END
	RETURN
END	
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfExpiredPolicies]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product base, 2: Officer Base
)
RETURNS @Resul TABLE(ProdId INT, ExpiredPolicies INT, Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Resul(ProdId,ExpiredPolicies)
	SELECT PL.ProdID, COUNT(PL.PolicyID) ExpiredPolicies
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE PL.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus >1  --Uncommented By Rogers for PrimaryIndicator1 Report
	AND MONTH(PL.ExpiryDate) = @Month AND YEAR(PL.ExpiryDate) = @Year
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID
ELSE IF @Mode = 2
	INSERT INTO @Resul(ProdId,ExpiredPolicies,Officer,LastName,OtherNames)
	SELECT PL.ProdID, COUNT(PL.PolicyID) ExpiredPolicies,O.Code,O.LastName,O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	WHERE PL.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus >1  --Uncommented By Rogers for PrimaryIndicator1 Report
	AND MONTH(PL.ExpiryDate) = @Month AND YEAR(PL.ExpiryDate) = @Year
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID,O.Code,O.LastName,O.OtherNames
	
RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfNewlyPremiumCollected]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product Base, 2:Officer Base
)
RETURNS @Result TABLE(ProdId INT, PremiumCollection FLOAT,Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,PremiumCollection)	
	SELECT PL.ProdID,SUM(PR.Amount)PremiumCollection
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	LEFT OUTER JOIN tblPremium PR ON PL.PolicyID = PR.PolicyID 
	WHERE PR.ValidityTo IS NULL
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PR.PayDate) = @Month AND YEAR(PR.PayDate) = @Year
	GROUP BY PL.ProdID
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,PremiumCollection,Officer,LastName,OtherNames)
	SELECT PL.ProdID,SUM(PR.Amount)PremiumCollection,O.Code,O.LastName,O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	LEFT OUTER JOIN tblPremium PR ON PL.PolicyID = PR.PolicyID 
	WHERE PR.ValidityTo IS NULL
	AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PR.PayDate) = @Month AND YEAR(PR.PayDate) = @Year
	GROUP BY PL.ProdID,O.Code,O.LastName,O.OtherNames
	
RETURN
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfNewPolicies]
(
	@ProdID INT,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1: Product Base, 2: Enrollment Officer Base
)
RETURNS @Result TABLE(ProdId INT, Male INT,Female INT,Other INT, Officer VARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female,Other)
	SELECT ProdId, M Male, F Female, O Other
	FROM
	(SELECT PL.ProdId, I.Gender, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.InsureeId = Fam.InsureeID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt
	
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female,Other,Officer,LastName,OtherNames)
	SELECT ProdId, M Male, F Female, O Other, Officer, LastName, OtherNames
FROM
	(SELECT PL.ProdId, I.Gender, O.Code Officer, O.LastName, O.OtherNames, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.InsureeId = Fam.InsureeID
	INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND O.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt
	
	RETURN
END	
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfNewPolicyInsuree]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product base 2: Officer Base
)
RETURNS @Result TABLE(ProdId INT, Male INT, Female INT,Other INT, Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female,Other)	
	SELECT ProdId, M Male, F Female, O Other
	FROM
	(SELECT PL.ProdId, I.Gender, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.FamilyID = Fam.FamilyID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt

ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female,Other,Officer,LastName,OtherNames)
	SELECT ProdId, M Male, F Female, O Other, Officer, LastName, OtherNames
FROM
	(SELECT PL.ProdId, I.Gender, O.Code Officer, O.LastName, O.OtherNames, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.FamilyID = Fam.FamilyID
	INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND O.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt
RETURN
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfPolicyInsuree]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@LastDay DATE,
	@Mode INT	--1: Product Base 2: Officer Base
)
RETURNS @Result TABLE(ProdId INT, Male INT, Female INT, Other INT,Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female, Other)	
	SELECT ProdId, [M], [F], [O]
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.FamilyId = Fam.FamilyId
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicyInsurees
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female, Other,Officer,LastName,OtherNames)
	SELECT ProdId, [M], [F], [O], Officer, LastName, OtherNames
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID, O.Code Officer, O.LastName, O.OtherNames
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.FamilyId = Fam.FamilyId
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicyInsurees
	
RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfPolicyRenewal]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1: Product Base, 2:Officer Base
)
RETURNS @Result TABLE(ProdId INT, Renewals INT, Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Renewals)
	SELECT PL.ProdId, COUNT(PL.PolicyId)Renewals
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'R'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (D.DistrictId = @LocationId OR D.Region = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	GROUP BY PL.ProdID

ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Renewals,Officer,LastName,OtherNames)
	SELECT PL.ProdId, COUNT(PL.PolicyId)Renewals, O.Code Officer, O.LastName, O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerId

	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'R'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (D.DistrictId = @LocationId OR D.Region = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	GROUP BY PL.ProdID, O.Code , O.LastName, O.OtherNames
	RETURN
	
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
CREATE FUNCTION [dbo].[udfPremiumComposition]
(	
	
)


RETURNS @Resul TABLE(PolicyId INT, AssFee DECIMAL(18,2),RegFee DECIMAL(18,2),PremFee DECIMAL(18,2) )
AS
BEGIN

	INSERT INTO @Resul(PolicyId,AssFee,RegFee,PremFee)
	SELECT tblPolicy.PolicyID, CASE WHEN ISNULL(tblProduct.GeneralAssemblyLumpSum,0) = 0 THEN  (COUNT(tblInsureePolicy.InsureeId) * ISNULL(tblProduct.GeneralAssemblyFee,0)) ELSE tblProduct.GeneralAssemblyLumpSum  END  as AssFee, CASE WHEN tblPolicy.PolicyStage = 'N' THEN (CASE WHEN ISNULL(tblProduct.RegistrationLumpSum ,0) = 0 THEN COUNT(tblInsureePolicy.InsureeId) * isnull(tblProduct.RegistrationFee,0) ELSE tblProduct.RegistrationLumpSum END) ELSE 0 END as RegFee, CASE WHEN ISNULL(tblProduct.LumpSum,0) = 0 THEN ( SUM (CASE WHEN (DATEDIFF(YY  ,tblInsuree.DOB,tblInsureePolicy.EffectiveDate) >= 18) THEN 1 ELSE 0 END) * tblProduct.PremiumAdult)  + ( SUM (CASE WHEN (DATEDIFF(YY  ,tblInsuree.DOB,tblInsureePolicy.EffectiveDate) < 18) THEN 1 ELSE 0 END) * tblProduct.PremiumChild ) ELSE tblproduct.LumpSum  END as PremFee
	
	FROM         tblPolicy INNER JOIN
						  tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId INNER JOIN
						  tblInsuree ON tblInsureePolicy.InsureeId = tblInsuree.InsureeID INNER JOIN tblProduct ON tblProduct.ProdID = tblPolicy.ProdID 
	WHERE     (tblInsureePolicy.ValidityTo IS NULL) AND (tblPolicy.ValidityTo IS NULL) AND (tblInsuree.ValidityTo IS NULL) AND tblInsureePolicy.EffectiveDate IS NOT NULL and tblProduct.ValidityTo is null
	GROUP BY tblPolicy.PolicyID, tblProduct.GeneralAssemblyFee , tblProduct.GeneralAssemblyLumpSum , tblProduct .RegistrationFee, tblProduct .RegistrationLumpSum   ,tblProduct .LumpSum , tblProduct .PremiumAdult ,tblProduct .PremiumChild ,tblPolicy.PolicyStage

	

RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfSuspendedPolicies]
(
	@ProdID INT = 0,
	@LocationId INT ,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product base 2: Officer Base
)
RETURNS @Result TABLE(ProdId INT,SuspendedPolicies INT,Officer NVARCHAR(50),LastName NVARCHAR(50), OtherNames NVARCHAR(50))
AS
BEGIN

IF @Mode = 1
	INSERT INTO @Result(ProdId,SuspendedPolicies)
	SELECT  PL.ProdID,COUNT(PL.PolicyID)SuspendedPolicies
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	
	WHERE PL.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus = 4
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND MONTH(PL.ValidityFrom) = @Month AND YEAR(PL.ValidityFrom) = @Year 
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,SuspendedPolicies,Officer,LastName,OtherNames)
	SELECT  PL.ProdID,COUNT(PL.PolicyID)SuspendedPolicies,O.Code,O.LastName,O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	WHERE PL.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus = 4
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND MONTH(PL.ValidityFrom) = @Month AND YEAR(PL.ValidityFrom) = @Year 
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID,O.Code,O.LastName,O.OtherNames
	
RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfTotalPolicies] 
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@LastDay DATE,
	@Mode INT	--1: ON Product, 2: On Officer
)
RETURNS @Result TABLE(ProdId INT, Male INT,Female INT, Other INT, Officer NVARCHAR(8),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female, Other)
	SELECT ProdId, [M], [F], [O]
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.InsureeId = Fam.InsureeID
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0 OR @LocationId = 0) --@LocationId = 0 Added to get Country data
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicies

ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female, Other,Officer,LastName,OtherNames)
	SELECT ProdId, [M], [F], [O], Officer, LastName, OtherNames
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID, O.Code Officer, O.LastName, O.OtherNames
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.InsureeId = Fam.InsureeID
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0 OR @LocationId = 0)
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicies
	
	RETURN
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dw].[udfNumberOfPoliciesExpired]()
	RETURNS @Result TABLE(ExpiredPolicy INT, MonthTime INT, QuarterTime INT, YearTime INT, Age INT, Gender CHAR(1),Region NVARCHAR(20), InsureeDistrictName NVARCHAR(50), WardName NVARCHAR(50), VillageName NVARCHAR(50), ProdDistrictName NVARCHAR(50), ProductCode NVARCHAR(15), ProductName NVARCHAR(100), OfficeDistrict NVARCHAR(20), OfficerCode NVARCHAR(15), LastName NVARCHAR(100), OtherNames NVARCHAR(100), ProdRegion NVARCHAR(50))
AS
BEGIN

	DECLARE @tbl TABLE(MonthId INT, YearId INT)
	INSERT INTO @tbl
	SELECT DISTINCT MONTH(ExpiryDate),YEAR(ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL ORDER BY YEAR(ExpiryDate),MONTH(ExpiryDate)


	INSERT INTO @Result(ExpiredPolicy,MonthTime,QuarterTime,YearTime,Age,Gender,Region,InsureeDistrictName,WardName,VillageName,
				ProdDistrictName,ProductCode,ProductName, OfficeDistrict, OfficerCode,LastName,OtherNames, ProdRegion)
			
	SELECT COUNT(PL.PolicyID)ExpiredPolicy, MONTH(PL.ExpiryDate)MonthTime, DATENAME(Q,PL.ExpiryDate) QuarterTime, YEAR(PL.ExpiryDate)YearTime,
	DATEDIFF(YEAR,I.DOB,PL.ExpiryDate)Age, I.Gender, R.RegionName Region,D.DistrictName, W.WardName,V.VillageName,
	D.DistrictName ProdDistrictName,PR.ProductCode, PR.ProductName, 
	ODist.DistrictName OfficerDistrict,O.Code, O.LastName,O.OtherNames, R.RegionName ProdRegion


	FROM tblPolicy PL  INNER JOIN TblProduct PR ON PL.ProdID = PR.ProdID
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	INNER JOIN tblInsuree I ON PL.FamilyID = I.FamilyID
	INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardID = V.WardID
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
	INNER JOIN tblDistricts ODist ON O.LocationId = ODist.DistrictID
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	CROSS APPLY @tbl t

	WHERE PL.ValidityTo IS NULL 
	AND PR.ValidityTo IS NULL 
	AND I.ValidityTo IS NULL 
	AND O.ValidityTo IS NULL
	AND I.IsHead = 1
	AND MONTH(PL.ExpiryDate) = t.MonthId AND YEAR(PL.ExpiryDate) = t.YearId
	AND PL.PolicyStatus > 1

	GROUP BY MONTH(PL.ExpiryDate),DATENAME(Q,PL.ExpiryDate), YEAR(PL.ExpiryDate), DATEDIFF(YEAR,I.DOB,PL.ExpiryDate),
	I.Gender, R.RegionName,D.DistrictName, W.WardName,V.VillageName ,PR.ProductCode, PR.ProductName, 
	ODist.DistrictName,O.Code, O.LastName,O.OtherNames

	RETURN;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblBatchRun](
	[RunID] [int] IDENTITY(1,1) NOT NULL,
	[LocationId] [int] NULL,
	[RunDate] [datetime] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RunYear] [int] NOT NULL,
	[RunMonth] [tinyint] NOT NULL,
 CONSTRAINT [PK_tblMonthlyRuns] PRIMARY KEY CLUSTERED 
(
	[RunID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblCeilingInterpretation](
	[CeilingIntCode] [char](1) NOT NULL,
	[CeilingIntDesc] [nvarchar](100) NOT NULL,
	[AltLanguage] [nvarchar](100) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_tblCeilinginterpretation] PRIMARY KEY CLUSTERED 
(
	[CeilingIntCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblClaim](
	[ClaimID] [int] IDENTITY(1,1) NOT NULL,
	[ClaimUUID] [uniqueidentifier] NOT NULL,
	[InsureeID] [int] NOT NULL,
	[ClaimCode] [nvarchar](8) NOT NULL,
	[DateFrom] [smalldatetime] NOT NULL,
	[DateTo] [smalldatetime] NULL,
	[ICDID] [int] NOT NULL,
	[ClaimStatus] [tinyint] NOT NULL,
	[Adjuster] [int] NULL,
	[Adjustment] [ntext] NULL,
	[Claimed] [decimal](18, 2) NULL,
	[Approved] [decimal](18, 2) NULL,
	[Reinsured] [decimal](18, 2) NULL,
	[Valuated] [decimal](18, 2) NULL,
	[DateClaimed] [date] NOT NULL,
	[DateProcessed] [smalldatetime] NULL,
	[Feedback] [bit] NOT NULL,
	[FeedbackID] [int] NULL,
	[Explanation] [ntext] NULL,
	[FeedbackStatus] [tinyint] NULL,
	[ReviewStatus] [tinyint] NULL,
	[ApprovalStatus] [tinyint] NULL,
	[RejectionReason] [tinyint] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[ValidityFromReview] [datetime] NULL,
	[ValidityToReview] [datetime] NULL,
	[AuditUserIDReview] [int] NULL,
	[RowID] [timestamp] NULL,
	[HFID] [int] NOT NULL,
	[RunID] [int] NULL,
	[AuditUserIDSubmit] [int] NULL,
	[AuditUserIDProcess] [int] NULL,
	[SubmitStamp] [datetime] NULL,
	[ProcessStamp] [datetime] NULL,
	[Remunerated] [decimal](18, 2) NULL,
	[GuaranteeId] [nvarchar](50) NULL,
	[ClaimAdminId] [int] NULL,
	[ICDID1] [int] NULL,
	[ICDID2] [int] NULL,
	[ICDID3] [int] NULL,
	[ICDID4] [int] NULL,
	[VisitType] [char](1) NULL,
	[ClaimCategory] [char](1) NULL,
 CONSTRAINT [PK_tblClaim] PRIMARY KEY CLUSTERED 
(
	[ClaimID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblClaimAdmin](
	[ClaimAdminId] [int] IDENTITY(1,1) NOT NULL,
	[ClaimAdminUUID] [uniqueidentifier] NOT NULL,
	[ClaimAdminCode] [nvarchar](8) NULL,
	[LastName] [nvarchar](100) NULL,
	[OtherNames] [nvarchar](100) NULL,
	[DOB] [date] NULL,
	[Phone] [nvarchar](50) NULL,
	[HFId] [int] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[RowId] [timestamp] NULL,
	[EmailId] [nvarchar](200) NULL,
	[HasLogin] [bit] NULL,
 CONSTRAINT [PK_tblClaimAdmin] PRIMARY KEY CLUSTERED 
(
	[ClaimAdminId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblClaimDedRem](
	[ExpenditureID] [int] IDENTITY(1,1) NOT NULL,
	[PolicyID] [int] NOT NULL,
	[InsureeID] [int] NOT NULL,
	[ClaimID] [int] NOT NULL,
	[DedG] [decimal](18, 2) NULL,
	[DedOP] [decimal](18, 2) NULL,
	[DedIP] [decimal](18, 2) NULL,
	[RemG] [decimal](18, 2) NULL,
	[RemIP] [decimal](18, 2) NULL,
	[RemOP] [decimal](18, 2) NULL,
	[RemConsult] [decimal](18, 2) NULL,
	[RemSurgery] [decimal](18, 2) NULL,
	[RemDelivery] [decimal](18, 2) NULL,
	[RemHospitalization] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RemAntenatal] [decimal](18, 2) NULL,
 CONSTRAINT [PK_tblClaimDedRem] PRIMARY KEY CLUSTERED 
(
	[ExpenditureID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblClaimItems](
	[ClaimItemID] [int] IDENTITY(1,1) NOT NULL,
	[ClaimID] [int] NOT NULL,
	[ItemID] [int] NOT NULL,
	[ProdID] [int] NULL,
	[ClaimItemStatus] [tinyint] NOT NULL,
	[Availability] [bit] NOT NULL,
	[QtyProvided] [decimal](18, 2) NOT NULL,
	[QtyApproved] [decimal](18, 2) NULL,
	[PriceAsked] [decimal](18, 2) NOT NULL,
	[PriceAdjusted] [decimal](18, 2) NULL,
	[PriceApproved] [decimal](18, 2) NULL,
	[PriceValuated] [decimal](18, 2) NULL,
	[Explanation] [ntext] NULL,
	[Justification] [ntext] NULL,
	[RejectionReason] [smallint] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[ValidityFromReview] [datetime] NULL,
	[ValidityToReview] [datetime] NULL,
	[AuditUserIDReview] [int] NULL,
	[LimitationValue] [decimal](18, 2) NULL,
	[Limitation] [char](1) NULL,
	[PolicyID] [int] NULL,
	[RemuneratedAmount] [decimal](18, 2) NULL,
	[DeductableAmount] [decimal](18, 2) NULL,
	[ExceedCeilingAmount] [decimal](18, 2) NULL,
	[PriceOrigin] [char](1) NULL,
	[ExceedCeilingAmountCategory] [decimal](18, 2) NULL,
 CONSTRAINT [PK_tblClaimItems] PRIMARY KEY CLUSTERED 
(
	[ClaimItemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblClaimServices](
	[ClaimServiceID] [int] IDENTITY(1,1) NOT NULL,
	[ClaimID] [int] NOT NULL,
	[ServiceID] [int] NOT NULL,
	[ProdID] [int] NULL,
	[ClaimServiceStatus] [tinyint] NOT NULL,
	[QtyProvided] [decimal](18, 2) NOT NULL,
	[QtyApproved] [decimal](18, 2) NULL,
	[PriceAsked] [decimal](18, 2) NOT NULL,
	[PriceAdjusted] [decimal](18, 2) NULL,
	[PriceApproved] [decimal](18, 2) NULL,
	[PriceValuated] [decimal](18, 2) NULL,
	[Explanation] [ntext] NULL,
	[Justification] [ntext] NULL,
	[RejectionReason] [smallint] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[ValidityFromReview] [datetime] NULL,
	[ValidityToReview] [datetime] NULL,
	[AuditUserIDReview] [int] NULL,
	[LimitationValue] [decimal](18, 2) NULL,
	[Limitation] [char](1) NULL,
	[PolicyID] [int] NULL,
	[RemuneratedAmount] [decimal](18, 2) NULL,
	[DeductableAmount] [decimal](18, 2) NULL,
	[ExceedCeilingAmount] [decimal](18, 2) NULL,
	[PriceOrigin] [char](1) NULL,
	[ExceedCeilingAmountCategory] [decimal](18, 2) NULL,
 CONSTRAINT [PK_tblClaimServices] PRIMARY KEY CLUSTERED 
(
	[ClaimServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblConfirmationTypes](
	[ConfirmationTypeCode] [nvarchar](3) NOT NULL,
	[ConfirmationType] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_ConfirmationType] PRIMARY KEY CLUSTERED 
(
	[ConfirmationTypeCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblControlNumber](
	[ControlNumberID] [bigint] IDENTITY(1,1) NOT NULL,
	[RequestedDate] [datetime] NULL,
	[ReceivedDate] [datetime] NULL,
	[RequestOrigin] [nvarchar](50) NULL,
	[ResponseOrigin] [nvarchar](50) NULL,
	[Status] [int] NULL,
	[LegacyID] [bigint] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[AuditedUserID] [int] NULL,
	[PaymentID] [bigint] NULL,
	[ControlNumber] [nvarchar](50) NULL,
	[IssuedDate] [datetime] NULL,
	[Comment] [nvarchar](max) NULL,
 CONSTRAINT [PK_tblControlNumber] PRIMARY KEY CLUSTERED 
(
	[ControlNumberID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblControls](
	[FieldName] [nvarchar](50) NOT NULL,
	[Adjustibility] [nvarchar](1) NOT NULL,
	[Usage] [nvarchar](200) NULL,
 CONSTRAINT [PK_tblControls] PRIMARY KEY CLUSTERED 
(
	[FieldName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblEducations](
	[EducationId] [smallint] NOT NULL,
	[Education] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_Education] PRIMARY KEY CLUSTERED 
(
	[EducationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblEmailSettings](
	[EmailId] [nvarchar](200) NOT NULL,
	[EmailPassword] [nvarchar](200) NOT NULL,
	[SMTPHost] [nvarchar](200) NOT NULL,
	[Port] [int] NOT NULL,
	[EnableSSL] [bit] NOT NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblExtracts](
	[ExtractID] [int] IDENTITY(1,1) NOT NULL,
	[ExtractUUID] [uniqueidentifier] NOT NULL,
	[ExtractDirection] [tinyint] NOT NULL,
	[ExtractType] [tinyint] NOT NULL,
	[ExtractSequence] [int] NOT NULL,
	[ExtractDate] [datetime] NOT NULL,
	[ExtractFileName] [nvarchar](255) NULL,
	[ExtractFolder] [nvarchar](255) NULL,
	[LocationId] [int] NOT NULL,
	[HFID] [int] NULL,
	[AppVersionBackend] [decimal](3, 1) NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [bigint] NULL,
 CONSTRAINT [PK_tblExtracts] PRIMARY KEY CLUSTERED 
(
	[ExtractID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLanguages](
	[LanguageCode] [nvarchar](5) NOT NULL,
	[LanguageName] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_Language] PRIMARY KEY CLUSTERED 
(
	[LanguageCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblFamilies](
	[FamilyID] [int] IDENTITY(1,1) NOT NULL,
	[FamilyUUID] [uniqueidentifier] NOT NULL,
	[InsureeID] [int] NOT NULL,
	[LocationId] [int] NULL,
	[Poverty] [bit] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[FamilyType] [nvarchar](2) NULL,
	[FamilyAddress] [nvarchar](200) NULL,
	[isOffline] [bit] NULL,
	[Ethnicity] [nvarchar](1) NULL,
	[ConfirmationNo] [nvarchar](12) NULL,
	[ConfirmationType] [nvarchar](3) NULL
 CONSTRAINT [PK_tblFamilies] PRIMARY KEY CLUSTERED 
(
	[FamilyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO 
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblFamilySMS](
	[FamilyID] [int] NOT NULL, 
	[ApprovalOfSMS] [bit] NULL,
	[LanguageOfSMS] [nvarchar](5) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL, 
	CONSTRAINT UC_FamilySMS UNIQUE (FamilyID,ValidityTo)
)
GO 

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblFamilyTypes](
	[FamilyTypeCode] [nvarchar](2) NOT NULL,
	[FamilyType] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_FamilyType] PRIMARY KEY CLUSTERED 
(
	[FamilyTypeCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblFeedback](
	[FeedbackID] [int] IDENTITY(1,1) NOT NULL,
	[FeedbackUUID] [uniqueidentifier] NOT NULL,
	[ClaimID] [int] NOT NULL,
	[CareRendered] [bit] NULL,
	[PaymentAsked] [bit] NULL,
	[DrugPrescribed] [bit] NULL,
	[DrugReceived] [bit] NULL,
	[Asessment] [tinyint] NULL,
	[CHFOfficerCode] [int] NULL,
	[FeedbackDate] [datetime] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
 CONSTRAINT [PK_tblFeedback] PRIMARY KEY CLUSTERED 
(
	[FeedbackID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblFeedbackPrompt](
	[FeedbackPromptID] [int] IDENTITY(1,1) NOT NULL,
	[FeedbackPromptDate] [date] NOT NULL,
	[ClaimID] [int] NULL,
	[OfficerID] [int] NULL,
	[PhoneNumber] [nvarchar](25) NULL,
	[SMSStatus] [tinyint] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
 CONSTRAINT [PK_tblFeedbackPrompt] PRIMARY KEY CLUSTERED 
(
	[FeedbackPromptID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblFromPhone](
	[FromPhoneId] [int] IDENTITY(1,1) NOT NULL,
	[DocType] [nvarchar](3) NOT NULL,
	[DocName] [nvarchar](200) NOT NULL,
	[DocStatus] [nvarchar](3) NULL,
	[LandedDate] [datetime] NOT NULL,
	[OfficerCode] [nvarchar](8) NULL,
	[CHFID] [nvarchar](12) NULL,
	[PhotoSumittedDate] [datetime] NULL,
	[ClaimId] [int] NULL,
 CONSTRAINT [PK_tblFromPhone] PRIMARY KEY CLUSTERED 
(
	[FromPhoneId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblGender](
	[Code] [char](1) NOT NULL,
	[Gender] [nvarchar](50) NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_tblGender] PRIMARY KEY CLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblHealthStatus](
	[HealthStatusID] [int] IDENTITY(1,1) NOT NULL,
	[InsureeID] [int] NOT NULL,
	[Description] [nvarchar](255) NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[AuditUserID] [int] NULL,
	[LegacyID] [int] NULL,
 CONSTRAINT [PK_tblHealthStatus] PRIMARY KEY CLUSTERED 
(
	[HealthStatusID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblHF](
	[HfID] [int] IDENTITY(1,1) NOT NULL,
	[HfUUID] [uniqueidentifier] NOT NULL,
	[HFCode] [nvarchar](8) NOT NULL,
	[HFName] [nvarchar](100) NOT NULL,
	[LegalForm] [char](1) NOT NULL,
	[HFLevel] [char](1) NOT NULL,
	[HFSublevel] [char](1) NULL,
	[HFAddress] [nvarchar](100) NULL,
	[LocationId] [int] NOT NULL,
	[Phone] [nvarchar](50) NULL,
	[Fax] [nvarchar](50) NULL,
	[eMail] [nvarchar](50) NULL,
	[HFCareType] [char](1) NOT NULL,
	[PLServiceID] [int] NULL,
	[PLItemID] [int] NULL,
	[AccCode] [nvarchar](25) NULL,
	[OffLine] [bit] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblHF] PRIMARY KEY CLUSTERED 
(
	[HfID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblHFCatchment](
	[HFCatchmentId] [int] IDENTITY(1,1) NOT NULL,
	[HFID] [int] NOT NULL,
	[LocationId] [int] NOT NULL,
	[Catchment] [int] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
 CONSTRAINT [PK_tblHFCatchment] PRIMARY KEY CLUSTERED 
(
	[HFCatchmentId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblHFSublevel](
	[HFSublevel] [char](1) NOT NULL,
	[HFSublevelDesc] [nvarchar](50) NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_tblHFSublevel] PRIMARY KEY CLUSTERED 
(
	[HFSublevel] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblICDCodes](
	[ICDID] [int] IDENTITY(1,1) NOT NULL,
	[ICDCode] [nvarchar](6) NOT NULL,
	[ICDName] [nvarchar](255) NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblICDCodes] PRIMARY KEY CLUSTERED 
(
	[ICDID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblIdentificationTypes](
	[IdentificationCode] [nvarchar](1) NOT NULL,
	[IdentificationTypes] [nvarchar](50) NOT NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_tblIdentificationTypes] PRIMARY KEY CLUSTERED 
(
	[IdentificationCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Last updated 15.10.2020
CREATE TABLE [dbo].[tblIMISDefaults](
	[DefaultID] [int] IDENTITY(1,1) NOT NULL,
	[PolicyRenewalInterval] [int] NULL,
	[FTPHost] [nvarchar](50) NULL,
	[FTPUser] [nvarchar](50) NULL,
	[FTPPassword] [nvarchar](20) NULL,
	[FTPPort] [int] NULL,
	[FTPEnrollmentFolder] [nvarchar](255) NULL,
	[AssociatedPhotoFolder] [nvarchar](255) NULL,
	[FTPClaimFolder] [nvarchar](255) NULL,
	[FTPFeedbackFolder] [nvarchar](255) NULL,
	[FTPPolicyRenewalFolder] [nvarchar](255) NULL,
	[FTPPhoneExtractFolder] [nvarchar](255) NULL,
	[FTPOffLineExtractFolder] [nvarchar](255) NULL,
	[AppVersionBackEnd] [decimal](3, 1) NULL,
	[AppVersionEnquire] [decimal](3, 1) NULL,
	[AppVersionEnroll] [decimal](3, 1) NULL,
	[AppVersionRenewal] [decimal](3, 1) NULL,
	[AppVersionFeedback] [decimal](3, 1) NULL,
	[AppVersionClaim] [decimal](3, 1) NULL,
	[OffLineHF] [int] NULL,
	[WinRarFolder] [nvarchar](255) NULL,
	[DatabaseBackupFolder] [nvarchar](255) NULL,
	[OfflineCHF] [int] NULL,
	[SMSLink] [nvarchar](500) NULL,
	[SMSIP] [nvarchar](15) NULL,
	[SMSUserName] [nvarchar](15) NULL,
	[SMSPassword] [nvarchar](50) NULL,
	[SMSSource] [nvarchar](15) NULL,
	[SMSDlr] [int] NULL,
	[SMSType] [int] NULL,
	[AppVersionFeedbackRenewal] [decimal](3, 1) NULL,
	[AppVersionImis] [decimal](3, 1) NULL,
	[APIKey] [nvarchar](100) NULL,
	[ActivationOption] tinyint NOT NULL 
 CONSTRAINT [PK_tblIMISDefaults] PRIMARY KEY CLUSTERED 
(
	[DefaultID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [tblIMISDefaults] ADD CONSTRAINT ActivationOptionDefaultConstraint DEFAULT ((2)) FOR [ActivationOption]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblIMISDefaultsPhone](
	[RuleName] [nvarchar](100) NULL,
	[RuleValue] [bit] NULL,
	[Usage] [nvarchar](200) NULL
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblInsuree](
	[InsureeID] [int] IDENTITY(1,1) NOT NULL,
	[InsureeUUID] [uniqueidentifier] NOT NULL,
	[FamilyID] [int] NULL,
	[CHFID] [nvarchar](12) NULL,
	[LastName] [nvarchar](100) NOT NULL,
	[OtherNames] [nvarchar](100) NOT NULL,
	[DOB] [date] NOT NULL,
	[Gender] [char](1) NULL,
	[Marital] [char](1) NULL,
	[IsHead] [bit] NOT NULL,
	[passport] [nvarchar](25) NULL,
	[Phone] [nvarchar](50) NULL,
	[PhotoID] [int] NULL,
	[PhotoDate] [date] NULL,
	[CardIssued] [bit] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[Relationship] [smallint] NULL,
	[Profession] [smallint] NULL,
	[Education] [smallint] NULL,
	[Email] [nvarchar](100) NULL,
	[isOffline] [bit] NULL,
	[TypeOfId] [nvarchar](1) NULL,
	[HFID] [int] NULL,
	[CurrentAddress] [nvarchar](200) NULL,
	[GeoLocation] [nvarchar](250) NULL,
	[CurrentVillage] [int] NULL,
	[Vulnerability] [bit] NOT NULL DEFAULT 0,
 CONSTRAINT [PK_tblInsuree] PRIMARY KEY CLUSTERED 
(
	[InsureeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblInsureePolicy](
	[InsureePolicyId] [int] IDENTITY(1,1) NOT NULL,
	[InsureeId] [int] NULL,
	[PolicyId] [int] NULL,
	[EnrollmentDate] [date] NULL,
	[StartDate] [date] NULL,
	[EffectiveDate] [date] NULL,
	[ExpiryDate] [date] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[isOffline] [bit] NULL,
	[RowId] [timestamp] NULL,
 CONSTRAINT [PK_tblInsureePolicy] PRIMARY KEY CLUSTERED 
(
	[InsureePolicyId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblItems](
	[ItemID] [int] IDENTITY(1,1) NOT NULL,
	[ItemUUID] [uniqueidentifier] NOT NULL,
	[ItemCode] [nvarchar](6) NOT NULL,
	[ItemName] [nvarchar](100) NOT NULL,
	[ItemType] [char](1) NOT NULL,
	[Quantity] [decimal](18,2) NULL,
	[ItemPackage] [nvarchar](255) NULL,
	[ItemPrice] [decimal](18, 2) NOT NULL,
	[ItemCareType] [char](1) NOT NULL,
	[ItemFrequency] [smallint] NULL,
	[ItemPatCat] [tinyint] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblItems] PRIMARY KEY CLUSTERED 
(
	[ItemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLegalForms](
	[LegalFormCode] [char](1) NOT NULL,
	[LegalForms] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_LegalForms] PRIMARY KEY CLUSTERED 
(
	[LegalFormCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLocations](
	[LocationId] [int] IDENTITY(1,1) NOT NULL,
	[LocationUUID] [uniqueidentifier] NOT NULL,
	[LocationCode] [nvarchar](8) NULL,
	[LocationName] [nvarchar](50) NULL,
	[ParentLocationId] [int] NULL,
	[LocationType] [nchar](1) NOT NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[RowId] [timestamp] NOT NULL,
	[MalePopulation] [int] NULL,
	[FemalePopulation] [int] NULL,
	[OtherPopulation] [int] NULL,
	[Families] [int] NULL,
 CONSTRAINT [PK_tblLocations] PRIMARY KEY CLUSTERED 
(
	[LocationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLogins](
	[LoginId] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[LogTime] [datetime] NULL,
	[LogAction] [int] NULL,
 CONSTRAINT [PK_tblLogins] PRIMARY KEY CLUSTERED 
(
	[LoginId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblOfficer](
	[OfficerID] [int] IDENTITY(1,1) NOT NULL,
	[OfficerUUID] [uniqueidentifier] NOT NULL,
	[Code] [nvarchar](8) NOT NULL,
	[LastName] [nvarchar](100) NOT NULL,
	[OtherNames] [nvarchar](100) NOT NULL,
	[DOB] [date] NULL,
	[Phone] [nvarchar](50) NULL,
	[LocationId] [int] NULL,
	[OfficerIDSubst] [int] NULL,
	[WorksTo] [smalldatetime] NULL,
	[VEOCode] [nvarchar](8) NULL,
	[VEOLastName] [nvarchar](100) NULL,
	[VEOOtherNames] [nvarchar](100) NULL,
	[VEODOB] [date] NULL,
	[VEOPhone] [nvarchar](25) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[EmailId] [nvarchar](200) NULL,
	[PhoneCommunication] [bit] NULL,
	[permanentaddress] [nvarchar](100) NULL,
	[HasLogin] [bit] NULL,
 CONSTRAINT [PK_tblOfficer] PRIMARY KEY CLUSTERED 
(
	[OfficerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblOfficerVillages](
	[OfficerVillageId] [int] IDENTITY(1,1) NOT NULL,
	[OfficerId] [int] NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[RowId] [timestamp] NOT NULL,
 CONSTRAINT [PK_tblOfficerVillages] PRIMARY KEY CLUSTERED 
(
	[OfficerVillageId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPayer](
	[PayerID] [int] IDENTITY(1,1) NOT NULL,
	[PayerUUID] [uniqueidentifier] NOT NULL,
	[PayerType] [char](1) NOT NULL,
	[PayerName] [nvarchar](100) NOT NULL,
	[PayerAddress] [nvarchar](100) NULL,
	[LocationId] [int] NULL,
	[Phone] [nvarchar](50) NULL,
	[Fax] [nvarchar](50) NULL,
	[eMail] [nvarchar](50) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPayer] PRIMARY KEY CLUSTERED 
(
	[PayerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPayerType](
	[Code] [char](1) NOT NULL,
	[PayerType] [nvarchar](50) NOT NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_PayerType] PRIMARY KEY CLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPayment](
	[PaymentID] [bigint] IDENTITY(1,1) NOT NULL,
	[PaymentUUID] [uniqueidentifier] NOT NULL,
	[ExpectedAmount] [decimal](18, 2) NULL,
	[ReceivedAmount] [decimal](18, 2) NULL,
	[OfficerCode] [nvarchar](50) NULL,
	[PhoneNumber] [nvarchar](15) NULL,
	[PayerPhoneNumber] [nvarchar](15) NULL,
	[RequestDate] [datetime] NULL,
	[ReceivedDate] [datetime] NULL,
	[PaymentStatus] [int] NULL,
	[LegacyID] [bigint] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[RowID] [timestamp] NOT NULL,
	[AuditedUSerID] [int] NULL,
	[TransactionNo] [nvarchar](50) NULL,
	[PaymentOrigin] [nvarchar](50) NULL,
	[MatchedDate] [datetime] NULL,
	[ReceiptNo] [nvarchar](100) NULL,
	[PaymentDate] [datetime] NULL,
	[RejectedReason] [nvarchar](255) NULL,
	[DateLastSMS] [datetime] NULL,
	[LanguageName] [nvarchar](10) NULL,
	[TypeOfPayment] [nvarchar](50) NULL,
	[TransferFee] [decimal](18, 2) NULL,
	[SmsRequired] [bit] NULL,
	[SpReconcReqId] [nvarchar](30) NULL,
	[ReconciliationDate] [datetime] NULL
 CONSTRAINT [PK_tblPayment] PRIMARY KEY CLUSTERED 
(
	[PaymentID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPaymentDetails](
	[PaymentDetailsID] [bigint] IDENTITY(1,1) NOT NULL,
	[PaymentID] [bigint] NOT NULL,
	[ProductCode] [nvarchar](8) NULL,
	[InsuranceNumber] [nvarchar](12) NULL,
	[PolicyStage] [nvarchar](1) NULL,
	[Amount] [decimal](18, 2) NULL,
	[LegacyID] [bigint] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[RowID] [timestamp] NULL,
	[PremiumID] [int] NULL,
	[AuditedUserId] [int] NULL,
	[enrollmentDate] [date] NULL,
	[ExpectedAmount] [decimal](18, 2) NULL,
 CONSTRAINT [PK_tblPaymentDetails] PRIMARY KEY CLUSTERED 
(
	[PaymentDetailsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPhotos](
	[PhotoID] [int] IDENTITY(1,1) NOT NULL,
	[PhotoUUID] [uniqueidentifier] NOT NULL,
	[InsureeID] [int] NULL,
	[CHFID] [nvarchar](12) NULL,
	[PhotoFolder] [nvarchar](255) NOT NULL,
	[PhotoFileName] [nvarchar](250) NULL,
	[OfficerID] [int] NOT NULL,
	[PhotoDate] [date] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[AuditUserID] [int] NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPhotos] PRIMARY KEY CLUSTERED 
(
	[PhotoID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPLItems](
	[PLItemID] [int] IDENTITY(1,1) NOT NULL,
	[PLItemUUID] [uniqueidentifier] NOT NULL,
	[PLItemName] [nvarchar](100) NOT NULL,
	[DatePL] [date] NOT NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPLItems] PRIMARY KEY CLUSTERED 
(
	[PLItemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPLItemsDetail](
	[PLItemDetailID] [int] IDENTITY(1,1) NOT NULL,
	[PLItemID] [int] NOT NULL,
	[ItemID] [int] NOT NULL,
	[PriceOverule] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPLItemsDetail] PRIMARY KEY CLUSTERED 
(
	[PLItemDetailID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPLServices](
	[PLServiceID] [int] IDENTITY(1,1) NOT NULL,
	[PLServiceUUID] [uniqueidentifier] NOT NULL,
	[PLServName] [nvarchar](100) NOT NULL,
	[DatePL] [date] NOT NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPLServices] PRIMARY KEY CLUSTERED 
(
	[PLServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPLServicesDetail](
	[PLServiceDetailID] [int] IDENTITY(1,1) NOT NULL,
	[PLServiceID] [int] NOT NULL,
	[ServiceID] [int] NOT NULL,
	[PriceOverule] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPLServiceDetail] PRIMARY KEY CLUSTERED 
(
	[PLServiceDetailID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPolicy](
	[PolicyID] [int] IDENTITY(1,1) NOT NULL,
	[PolicyUUID] [uniqueidentifier] NOT NULL,
	[FamilyID] [int] NOT NULL,
	[EnrollDate] [date] NOT NULL,
	[StartDate] [date] NOT NULL,
	[EffectiveDate] [date] NULL,
	[ExpiryDate] [date] NULL,
	[PolicyStatus] [tinyint] NULL,
	[PolicyValue] [decimal](18, 2) NULL,
	[ProdID] [int] NOT NULL,
	[OfficerID] [int] NULL,
	[PolicyStage] [char](1) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[isOffline] [bit] NULL,
	[RenewalOrder] [int] NULL,
	[SelfRenewed] [bit] NOT NULL DEFAULT 0
 CONSTRAINT [PK_tblPolicy] PRIMARY KEY CLUSTERED 
(
	[PolicyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPolicyRenewalDetails](
	[RenewalDetailID] [int] IDENTITY(1,1) NOT NULL,
	[RenewalID] [int] NOT NULL,
	[InsureeID] [int] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditCreateUser] [int] NOT NULL,
 CONSTRAINT [PK_tblPolicyRenewalDetails] PRIMARY KEY CLUSTERED 
(
	[RenewalDetailID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPolicyRenewals](
	[RenewalID] [int] IDENTITY(1,1) NOT NULL,
	[RenewalUUID] [uniqueidentifier] NOT NULL,
	[RenewalPromptDate] [date] NOT NULL,
	[RenewalDate] [date] NOT NULL,
	[NewOfficerID] [int] NULL,
	[PhoneNumber] [nvarchar](25) NULL,
	[SMSStatus] [tinyint] NOT NULL,
	[InsureeID] [int] NOT NULL,
	[PolicyID] [int] NOT NULL,
	[NewProdID] [int] NOT NULL,
	[RenewalWarnings] [tinyint] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditCreateUser] [int] NULL,
	[ResponseStatus] [int] NULL,
	[ResponseDate] [datetime] NULL,
 CONSTRAINT [PK_tblPolicyRenewals] PRIMARY KEY CLUSTERED 
(
	[RenewalID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPremium](
	[PremiumId] [int] IDENTITY(1,1) NOT NULL,
	[PremiumUUID] [uniqueidentifier] NOT NULL,
	[PolicyID] [int] NOT NULL,
	[PayerID] [int] NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[Receipt] [nvarchar](50) NOT NULL,
	[PayDate] [date] NOT NULL,
	[PayType] [char](1) NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[isPhotoFee] [bit] NULL,
	[isOffline] [bit] NULL,
	[ReportingId] [int] NULL,
	[OverviewCommissionReport] datetime NULL,
	[AllDetailsCommissionReport] datetime NULL,
	[ReportingCommissionID] [int] NULL
 CONSTRAINT [PK_tblPremium] PRIMARY KEY CLUSTERED 
(
	[PremiumId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblProduct](
	[ProdID] [int] IDENTITY(1,1) NOT NULL,
	[ProdUUID] [uniqueidentifier] NOT NULL,
	[ProductCode] [nvarchar](8) NOT NULL,
	[ProductName] [nvarchar](100) NOT NULL,
	[LocationId] [int] NULL,
	[InsurancePeriod] [tinyint] NOT NULL,
	[DateFrom] [smalldatetime] NOT NULL,
	[DateTo] [smalldatetime] NOT NULL,
	[ConversionProdID] [int] NULL,
	[LumpSum] [decimal](18, 2) NOT NULL,
	[MemberCount] [smallint] NOT NULL,
	[PremiumAdult] [decimal](18, 2) NULL,
	[PremiumChild] [decimal](18, 2) NULL,
	[DedInsuree] [decimal](18, 2) NULL,
	[DedOPInsuree] [decimal](18, 2) NULL,
	[DedIPInsuree] [decimal](18, 2) NULL,
	[MaxInsuree] [decimal](18, 2) NULL,
	[MaxOPInsuree] [decimal](18, 2) NULL,
	[MaxIPInsuree] [decimal](18, 2) NULL,
	[PeriodRelPrices] [char](1) NULL,
	[PeriodRelPricesOP] [char](1) NULL,
	[PeriodRelPricesIP] [char](1) NULL,
	[AccCodePremiums] [nvarchar](25) NULL,
	[AccCodeRemuneration] [nvarchar](25) NULL,
	[DedTreatment] [decimal](18, 2) NULL,
	[DedOPTreatment] [decimal](18, 2) NULL,
	[DedIPTreatment] [decimal](18, 2) NULL,
	[MaxTreatment] [decimal](18, 2) NULL,
	[MaxOPTreatment] [decimal](18, 2) NULL,
	[MaxIPTreatment] [decimal](18, 2) NULL,
	[DedPolicy] [decimal](18, 2) NULL,
	[DedOPPolicy] [decimal](18, 2) NULL,
	[DedIPPolicy] [decimal](18, 2) NULL,
	[MaxPolicy] [decimal](18, 2) NULL,
	[MaxOPPolicy] [decimal](18, 2) NULL,
	[MaxIPPolicy] [decimal](18, 2) NULL,
	[GracePeriod] [int] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[RegistrationLumpSum] [decimal](18, 2) NULL,
	[RegistrationFee] [decimal](18, 2) NULL,
	[GeneralAssemblyLumpSum] [decimal](18, 2) NULL,
	[GeneralAssemblyFee] [decimal](18, 2) NULL,
	[StartCycle1] [nvarchar](5) NULL,
	[StartCycle2] [nvarchar](5) NULL,
	[MaxNoConsultation] [int] NULL,
	[MaxNoSurgery] [int] NULL,
	[MaxNoDelivery] [int] NULL,
	[MaxNoHospitalizaion] [int] NULL,
	[MaxNoVisits] [int] NULL,
	[MaxAmountConsultation] [decimal](18, 2) NULL,
	[MaxAmountSurgery] [decimal](18, 2) NULL,
	[MaxAmountDelivery] [decimal](18, 2) NULL,
	[MaxAmountHospitalization] [decimal](18, 2) NULL,
	[GracePeriodRenewal] [int] NULL,
	[MaxInstallments] [int] NULL,
	[WaitingPeriod] [int] NULL,
	[Threshold] [int] NULL,
	[RenewalDiscountPerc] [int] NULL,
	[RenewalDiscountPeriod] [int] NULL,
	[StartCycle3] [nvarchar](5) NULL,
	[StartCycle4] [nvarchar](5) NULL,
	[AdministrationPeriod] [int] NULL,
	[MaxPolicyExtraMember] [decimal](18, 2) NULL,
	[MaxPolicyExtraMemberIP] [decimal](18, 2) NULL,
	[MaxPolicyExtraMemberOP] [decimal](18, 2) NULL,
	[MaxCeilingPolicy] [decimal](18, 2) NULL,
	[MaxCeilingPolicyIP] [decimal](18, 2) NULL,
	[MaxCeilingPolicyOP] [decimal](18, 2) NULL,
	[EnrolmentDiscountPerc] [int] NULL,
	[EnrolmentDiscountPeriod] [int] NULL,
	[MaxAmountAntenatal] [decimal](18, 2) NULL,
	[MaxNoAntenatal] [int] NULL,
	[CeilingInterpretation] [char](1) NULL,
	[Level1] [char](1) NULL,
	[Sublevel1] [char](1) NULL,
	[Level2] [char](1) NULL,
	[Sublevel2] [char](1) NULL,
	[Level3] [char](1) NULL,
	[Sublevel3] [char](1) NULL,
	[Level4] [char](1) NULL,
	[Sublevel4] [char](1) NULL,
	[ShareContribution] [decimal](5, 2) NULL,
	[WeightPopulation] [decimal](5, 2) NULL,
	[WeightNumberFamilies] [decimal](5, 2) NULL,
	[WeightInsuredPopulation] [decimal](5, 2) NULL,
	[WeightNumberInsuredFamilies] [decimal](5, 2) NULL,
	[WeightNumberVisits] [decimal](5, 2) NULL,
	[WeightAdjustedAmount] [decimal](5, 2) NULL,
	[Recurrence] [tinyint] NULL
 CONSTRAINT [PK_tblProduct_1] PRIMARY KEY CLUSTERED 
(
	[ProdID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblProductItems](
	[ProdItemID] [int] IDENTITY(1,1) NOT NULL,
	[ProdID] [int] NOT NULL,
	[ItemID] [int] NOT NULL,
	[LimitationType] [char](1) NOT NULL,
	[PriceOrigin] [char](1) NOT NULL,
	[LimitAdult] [decimal](18, 2) NULL,
	[LimitChild] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[WaitingPeriodAdult] [int] NULL,
	[WaitingPeriodChild] [int] NULL,
	[LimitNoAdult] [int] NULL,
	[LimitNoChild] [int] NULL,
	[LimitationTypeR] [char](1) NULL,
	[LimitationTypeE] [char](1) NULL,
	[LimitAdultR] [decimal](18, 2) NULL,
	[LimitAdultE] [decimal](18, 2) NULL,
	[LimitChildR] [decimal](18, 2) NULL,
	[LimitChildE] [decimal](18, 2) NULL,
	[CeilingExclusionAdult] [nvarchar](1) NULL,
	[CeilingExclusionChild] [nvarchar](1) NULL,
 CONSTRAINT [PK_tblProductItems] PRIMARY KEY CLUSTERED 
(
	[ProdItemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblProductServices](
	[ProdServiceID] [int] IDENTITY(1,1) NOT NULL,
	[ProdID] [int] NOT NULL,
	[ServiceID] [int] NOT NULL,
	[LimitationType] [char](1) NOT NULL,
	[PriceOrigin] [char](1) NOT NULL,
	[LimitAdult] [decimal](18, 2) NULL,
	[LimitChild] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
	[WaitingPeriodAdult] [int] NULL,
	[WaitingPeriodChild] [int] NULL,
	[LimitNoAdult] [int] NULL,
	[LimitNoChild] [int] NULL,
	[LimitationTypeR] [char](1) NULL,
	[LimitationTypeE] [char](1) NULL,
	[LimitAdultR] [decimal](18, 2) NULL,
	[LimitAdultE] [decimal](18, 2) NULL,
	[LimitChildR] [decimal](18, 2) NULL,
	[LimitChildE] [decimal](18, 2) NULL,
	[CeilingExclusionAdult] [nvarchar](1) NULL,
	[CeilingExclusionChild] [nvarchar](1) NULL,
 CONSTRAINT [PK_tblProductServices] PRIMARY KEY CLUSTERED 
(
	[ProdServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblProfessions](
	[ProfessionId] [smallint] NOT NULL,
	[Profession] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_Profession] PRIMARY KEY CLUSTERED 
(
	[ProfessionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblRelations](
	[RelationId] [smallint] NOT NULL,
	[Relation] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_Relation] PRIMARY KEY CLUSTERED 
(
	[RelationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblRelDistr](
	[DistrID] [int] IDENTITY(1,1) NOT NULL,
	[DistrType] [tinyint] NOT NULL,
	[DistrCareType] [char](1) NOT NULL,
	[ProdID] [int] NOT NULL,
	[Period] [tinyint] NOT NULL,
	[DistrPerc] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblRelDistr] PRIMARY KEY CLUSTERED 
(
	[DistrID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblRelIndex](
	[RelIndexID] [int] IDENTITY(1,1) NOT NULL,
	[ProdID] [int] NOT NULL,
	[RelType] [tinyint] NOT NULL,
	[RelCareType] [char](1) NOT NULL,
	[RelYear] [int] NOT NULL,
	[RelPeriod] [tinyint] NOT NULL,
	[CalcDate] [datetime] NOT NULL,
	[RelIndex] [decimal](18, 4) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[LocationId] [int] NULL,
 CONSTRAINT [PK_tblRelIndex] PRIMARY KEY CLUSTERED 
(
	[RelIndexID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Last updated 15.10.2020
CREATE TABLE [dbo].[tblReporting](
	[ReportingId] [int] IDENTITY(1,1) NOT NULL,
	[ReportingDate] [datetime] NOT NULL,
	[LocationId] [int] NOT NULL,
	[ProdId] [int] NOT NULL,
	[PayerId] [int] NULL,
	[StartDate] [date] NOT NULL,
	[EndDate] [date] NOT NULL,
	[RecordFound] [int] NOT NULL,
	[OfficerID] [int] NULL,
	[ReportType] [int] NULL,
	[CammissionRate] [decimal](18, 2) NULL,
	[CommissionRate] [decimal](18, 2) NULL,
	[ReportMode] [int] NULL,
	[Scope] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ReportingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [tblReporting] ADD CONSTRAINT ReportModeDefaultConstraint DEFAULT ((0)) FOR [ReportMode]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblRole](
	[RoleID] [int] IDENTITY(1,1) NOT NULL,
	[RoleUUID] [uniqueidentifier] NOT NULL,
	[RoleName] [nvarchar](50) NOT NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[IsSystem] [int] NOT NULL,
	[IsBlocked] [bit] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[AuditUserID] [int] NULL,
	[LegacyID] [int] NULL,
 CONSTRAINT [PK_tblRole] PRIMARY KEY CLUSTERED 
(
	[RoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblRoleRight](
	[RoleRightID] [int] IDENTITY(1,1) NOT NULL,
	[RoleID] [int] NOT NULL,
	[RightID] [int] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[AuditUserId] [int] NULL,
	[LegacyID] [int] NULL,
 CONSTRAINT [PK_tblRoleRight] PRIMARY KEY CLUSTERED 
(
	[RoleRightID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblServices](
	[ServiceID] [int] IDENTITY(1,1) NOT NULL,
	[ServiceUUID] [uniqueidentifier] NOT NULL,
	[ServCode] [nvarchar](6) NOT NULL,
	[ServName] [nvarchar](100) NOT NULL,
	[ServType] [char](1) NOT NULL,
	[ServLevel] [char](1) NOT NULL,
	[ServPrice] [decimal](18, 2) NOT NULL,
	[ServCareType] [char](1) NOT NULL,
	[ServFrequency] [smallint] NULL,
	[ServPatCat] [tinyint] NOT NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[RowID] [timestamp] NULL,
	[ServCategory] [char](1) NULL,
 CONSTRAINT [PK_tblServices] PRIMARY KEY CLUSTERED 
(
	[ServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblSubmittedPhotos](
	[PhotoId] [int] IDENTITY(1,1) NOT NULL,
	[ImageName] [nvarchar](50) NULL,
	[CHFID] [nvarchar](12) NULL,
	[OfficerCode] [nvarchar](8) NULL,
	[PhotoDate] [date] NULL,
	[RegisterDate] [datetime] NULL,
 CONSTRAINT [PK_tblSubmittedPhotos] PRIMARY KEY CLUSTERED 
(
	[PhotoId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Last updated 15.10.2020
CREATE TABLE [dbo].[tblUserRole](
	[UserRoleID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
	[RoleID] [int] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[AudituserID] [int] NULL,
	[LegacyID] [int] NULL,
	[Assign] int NULL,
 CONSTRAINT [PK_tblUserRole] PRIMARY KEY CLUSTERED 
(
	[UserRoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE tblUserRole ADD CONSTRAINT AssignDefaultConstraint DEFAULT ((3)) FOR [Assign]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblUsers](
	[UserID] [int] IDENTITY(1,1) NOT NULL,
	[UserUUID] [uniqueidentifier] NOT NULL,
	[LanguageID] [nvarchar](5) NOT NULL,
	[LastName] [nvarchar](100) NOT NULL,
	[OtherNames] [nvarchar](100) NOT NULL,
	[Phone] [nvarchar](50) NULL,
	[LoginName] [nvarchar](25) NOT NULL,
	[RoleID] [int] NOT NULL,
	[HFID] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[password] [varbinary](256) NULL,
	[DummyPwd] [nvarchar](25) NULL,
	[EmailId] [nvarchar](200) NULL,
	[PrivateKey] [nvarchar](256) NULL,
	[StoredPassword] [nvarchar](256) NULL,
	[PasswordValidity] [datetime] NULL,
	[IsAssociated] [bit] NULL,
 CONSTRAINT [PK_tblUsers] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblUsersDistricts](
	[UserDistrictID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
	[LocationId] [int] NOT NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
 CONSTRAINT [PK_tblUsersDistricts] PRIMARY KEY CLUSTERED 
(
	[UserDistrictID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
