USE [IMIS]
GO
/****** Object:  Table [dbo].[tblLegalForms]    Script Date: 7/24/2018 6:46:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLegalForms](
	[LegalFormCode] [char](1) NOT NULL,
	[LegalForms] [nvarchar](50) NOT NULL,
	[SortOrder] [int] NULL,
	[AltLanguage] [nvarchar](50) NULL,
 CONSTRAINT [PK_LegalForms] PRIMARY KEY CLUSTERED 
(
	[LegalFormCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
