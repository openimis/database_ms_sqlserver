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
	[CountryCode] [nvarchar](10) NULL,
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
	[ActivationOption] tinyint NOT NULL,
	[BypassReviewClaim] BIT NOT NULL
 CONSTRAINT [PK_tblIMISDefaults] PRIMARY KEY CLUSTERED 
(
	[DefaultID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [tblIMISDefaults] ADD CONSTRAINT ActivationOptionDefaultConstraint DEFAULT ((2)) FOR [ActivationOption]
GO

ALTER TABLE [tblIMISDefaults] ADD CONSTRAINT DF_BypassReviewClaim DEFAULT ((0)) FOR [BypassReviewClaim]
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
	[PhoneNumber] [nvarchar](50) NULL,
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
	[ReportingCommissionID] [int] NULL,
	[CreatedDate] [datetime] NULL CONSTRAINT DF_tblPremium_CreatedDate DEFAULT GETDATE()
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
