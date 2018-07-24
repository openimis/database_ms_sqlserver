USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xClaimSubmit]    Script Date: 7/24/2018 6:49:09 AM ******/
CREATE TYPE [dbo].[xClaimSubmit] AS TABLE(
	[ClaimID] [int] NOT NULL,
	[RowID] [bigint] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[ClaimID] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
