USE [IMIS]
GO
/****** Object:  Table [dbo].[tblPLServices]    Script Date: 7/24/2018 6:46:46 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPLServices](
	[PLServiceID] [int] IDENTITY(1,1) NOT NULL,
	[PLServName] [nvarchar](100) NOT NULL,
	[DatePL] [date] NOT NULL,
	[LocationId] [int] NULL,
	[ValidityFrom] [datetime] NOT NULL,
	[ValidityTo] [datetime] NULL,
	[LegacyID] [int] NULL,
	[AuditUserID] [int] NOT NULL,
	[RowID] [timestamp] NULL,
 CONSTRAINT [PK_tblPLServices] PRIMARY KEY CLUSTERED 
(
	[PLServiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[tblPLServices] ADD  CONSTRAINT [DF_tblPLServices_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPLServices]  WITH CHECK ADD  CONSTRAINT [FK_tblPLServices_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblPLServices] CHECK CONSTRAINT [FK_tblPLServices_tblLocations]
GO
