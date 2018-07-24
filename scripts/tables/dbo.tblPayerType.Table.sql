USE [IMIS]
GO
/****** Object:  Table [dbo].[tblPayerType]    Script Date: 7/24/2018 6:46:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPayerType](
	[Code] [char](1) NOT NULL,
	[PayerType] [nvarchar](50) NOT NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_PayerType] PRIMARY KEY CLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
