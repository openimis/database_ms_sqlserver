USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPLServicesDetail]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xPLServicesDetail] AS TABLE(
	[PLServiceDetailID] [int] NOT NULL,
	[PLServiceID] [int] NOT NULL,
	[ServiceID] [int] NOT NULL,
	[PriceOverule] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLServiceDetailID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
