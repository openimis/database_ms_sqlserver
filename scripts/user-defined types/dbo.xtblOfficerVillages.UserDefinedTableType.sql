USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xtblOfficerVillages]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xtblOfficerVillages] AS TABLE(
	[OfficerId] [int] NULL,
	[VillageId] [int] NULL,
	[AuditUserId] [int] NULL,
	[Action] [char](1) NULL
)
GO
