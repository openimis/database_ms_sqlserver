USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xInsureePolicy]    Script Date: 7/24/2018 6:49:09 AM ******/
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
