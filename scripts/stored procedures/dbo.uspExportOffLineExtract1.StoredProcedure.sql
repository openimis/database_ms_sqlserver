USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspExportOffLineExtract1]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspExportOffLineExtract1]
	
	@RowID as bigint = 0
AS
BEGIN
	SET NOCOUNT ON

	SELECT LocationId, LocationCode, LocationName, ParentLocationId, LocationType, ValidityFrom, ValidityTo, LegacyId, AuditUserId 
	FROM tblLocations
	WHERE RowID > @RowID;

	
END
GO
