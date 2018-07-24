USE [IMIS]
GO
/****** Object:  Table [dbo].[tblIdentificationTypes]    Script Date: 7/24/2018 6:46:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblIdentificationTypes](
	[IdentificationCode] [nvarchar](1) NOT NULL,
	[IdentificationTypes] [nvarchar](50) NOT NULL,
	[AltLanguage] [nvarchar](50) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_tblIdentificationTypes] PRIMARY KEY CLUSTERED 
(
	[IdentificationCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
