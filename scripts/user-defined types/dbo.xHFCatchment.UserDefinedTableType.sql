USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xHFCatchment]    Script Date: 7/24/2018 6:49:09 AM ******/
CREATE TYPE [dbo].[xHFCatchment] AS TABLE(
	[HFCatchmentId] [int] NULL,
	[HFID] [int] NULL,
	[LocationId] [int] NULL,
	[Catchment] [int] NULL
)
GO
