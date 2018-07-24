USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xDistricts]    Script Date: 7/24/2018 6:49:09 AM ******/
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
