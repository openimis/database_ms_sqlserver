USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xICDCodes]    Script Date: 7/24/2018 6:49:09 AM ******/
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
