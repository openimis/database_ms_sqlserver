USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xAttributeV]    Script Date: 7/24/2018 6:49:09 AM ******/
CREATE TYPE [dbo].[xAttributeV] AS TABLE(
	[Code] [nvarchar](15) NOT NULL,
	[Name] [nvarchar](50) NULL
)
GO
