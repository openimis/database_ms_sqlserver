USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xLocations]    Script Date: 7/24/2018 6:49:10 AM ******/
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
