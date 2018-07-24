USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xHF]    Script Date: 7/24/2018 6:49:09 AM ******/
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
