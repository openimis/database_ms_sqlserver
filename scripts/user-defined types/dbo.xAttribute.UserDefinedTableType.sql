USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xAttribute]    Script Date: 7/24/2018 6:49:09 AM ******/
CREATE TYPE [dbo].[xAttribute] AS TABLE(
	[ID] [int] NOT NULL,
	[Name] [nvarchar](50) NULL
)
GO
