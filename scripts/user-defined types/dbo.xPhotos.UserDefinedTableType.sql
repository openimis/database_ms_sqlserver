USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xPhotos]    Script Date: 7/24/2018 6:49:10 AM ******/
CREATE TYPE [dbo].[xPhotos] AS TABLE(
	[PhotoID] [int] NULL,
	[InsureeID] [int] NULL,
	[CHFID] [char](12) NULL,
	[PhotoFolder] [nvarchar](255) NULL,
	[PhotoFileName] [nvarchar](250) NULL,
	[OfficerID] [int] NULL,
	[PhotoDate] [date] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[AuditUserID] [int] NULL
)
GO
