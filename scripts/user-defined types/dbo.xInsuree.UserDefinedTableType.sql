USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xInsuree]    Script Date: 7/24/2018 6:49:09 AM ******/
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
	[GeoLocation] [nvarchar](250) NULL
)
GO
