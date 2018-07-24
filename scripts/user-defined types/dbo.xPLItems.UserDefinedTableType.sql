USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPLItems]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xPLItems] AS TABLE(
	[PLItemID] [int] NOT NULL,
	[PLItemName] [nvarchar](100) NOT NULL,
	[DatePL] [date] NOT NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLItemID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
