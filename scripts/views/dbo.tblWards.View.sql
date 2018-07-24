USE [IMIS]
GO
/****** Object:  View [dbo].[tblWards]    Script Date: 7/24/2018 6:47:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[tblWards] AS
SELECT LocationId WardId, ParentLocationId DistrictId, LocationCode WardCode, LocationName WardName, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId 
FROM tblLocations
WHERE ValidityTo IS NULL
AND LocationType = N'W'
GO
