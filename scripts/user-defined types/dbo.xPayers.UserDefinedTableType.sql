USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPayers]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xPayers] AS TABLE(
	[PayerID] [int] NOT NULL,
	[PayerType] [char](1) NOT NULL,
	[PayerName] [nvarchar](100) NOT NULL,
	[PayerAddress] [nvarchar](100) NULL,
	[LocationId] [int] NULL,
	[Phone] [nvarchar](50) NULL,
	[Fax] [nvarchar](50) NULL,
	[eMail] [nvarchar](50) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PayerID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
