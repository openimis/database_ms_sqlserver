USE [IMIS]
GO
/****** Object:  UserDefinedTableType [dbo].[xClaimAdmin]    Script Date: 7/24/2018 6:49:09 AM ******/
CREATE TYPE [dbo].[xClaimAdmin] AS TABLE(
	[ClaimAdminId] [int] NOT NULL,
	[ClaimAdminCode] [nvarchar](8) NULL,
	[LastName] [nvarchar](100) NULL,
	[OtherNames] [nvarchar](100) NULL,
	[DOB] [date] NULL,
	[Phone] [nvarchar](50) NULL,
	[HFId] [int] NULL,
	[ValidityFrom] [datetime] NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyId] [int] NULL,
	[AuditUserId] [int] NULL,
	[EmailId] [nvarchar](200) NULL,
	PRIMARY KEY CLUSTERED 
(
	[ClaimAdminId] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
