USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPremium]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xPremium] AS TABLE(
	[PremiumId] [int] NULL,
	[PolicyID] [int] NULL,
	[PayerID] [int] NULL,
	[Amount] [decimal](18, 2) NULL,
	[Receipt] [nvarchar](50) NULL,
	[PayDate] [date] NULL,
	[PayType] [char](1) NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NULL,
	[isPhotoFee] [bit] NULL,
	[ReportingId] [int] NULL,
	[isOffline] [bit] NULL
)
GO
