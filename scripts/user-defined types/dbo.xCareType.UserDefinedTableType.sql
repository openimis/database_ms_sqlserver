USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xCareType]    Script Date: 7/24/2018 6:49:09 AM ******/
CREATE TYPE [dbo].[xCareType] AS TABLE(
	[Code] [char](1) NOT NULL,
	[Name] [nvarchar](50) NULL,
	[AltLanguage] [nvarchar](50) NULL
)
GO
