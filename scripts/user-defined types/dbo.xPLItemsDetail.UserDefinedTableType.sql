USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPLItemsDetail]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xPLItemsDetail] AS TABLE(
	[PLItemDetailID] [int] NOT NULL,
	[PLItemID] [int] NOT NULL,
	[ItemID] [int] NOT NULL,
	[PriceOverule] [decimal](18, 2) NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[PLItemDetailID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
