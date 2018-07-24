USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xRegions]    Script Date: 7/24/2018 6:49:10 AM ******/
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
