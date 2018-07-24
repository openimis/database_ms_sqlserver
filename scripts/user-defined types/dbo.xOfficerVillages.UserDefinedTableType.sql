USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xOfficerVillages]    Script Date: 7/24/2018 6:49:10 AM ******/
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
