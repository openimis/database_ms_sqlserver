USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPolicy]    Script Date: 7/24/2018 6:49:10 AM ******/
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
