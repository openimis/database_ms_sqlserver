USE [IMIS]
GO
/****** Object:  Table [dbo].[tblCeilingInterpretation]    Script Date: 7/24/2018 6:46:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblCeilingInterpretation](
	[CeilingIntCode] [char](1) NOT NULL,
	[CeilingIntDesc] [nvarchar](100) NOT NULL,
	[AltLanguage] [nvarchar](100) NULL,
	[SortOrder] [int] NULL,
 CONSTRAINT [PK_tblCeilinginterpretation] PRIMARY KEY CLUSTERED 
(
	[CeilingIntCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
