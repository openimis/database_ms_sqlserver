USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xServices]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xServices] AS TABLE(
	[ServiceID] [int] NOT NULL,
	[ServCode] [nvarchar](6) NOT NULL,
	[ServName] [nvarchar](100) NOT NULL,
	[ServType] [char](1) NOT NULL,
	[ServLevel] [char](1) NOT NULL,
	[ServPrice] [decimal](18, 2) NOT NULL,
	[ServCareType] [char](1) NOT NULL,
	[ServFrequency] [smallint] NULL,
	[ServPatCat] [tinyint] NOT NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[ServCategory] [char](1) NULL,
	PRIMARY KEY CLUSTERED 
(
	[ServiceID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
