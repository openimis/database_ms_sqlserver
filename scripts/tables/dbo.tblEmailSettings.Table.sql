USE [IMIS]
GO
/****** Object:  Table [dbo].[tblEmailSettings]    Script Date: 7/24/2018 6:46:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblEmailSettings](
	[EmailId] [nvarchar](200) NOT NULL,
	[EmailPassword] [nvarchar](200) NOT NULL,
	[SMTPHost] [nvarchar](200) NOT NULL,
	[Port] [int] NOT NULL,
	[EnableSSL] [bit] NOT NULL
) ON [PRIMARY]
GO
