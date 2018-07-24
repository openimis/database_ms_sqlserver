USE [IMIS]
GO
/****** Object:  View [dbo].[tblDistricts]    Script Date: 7/24/2018 6:47:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[tblDistricts] AS
SELECT LocationId DistrictId, LocationCode DistrictCode, LocationName DistrictName, ParentLocationId Region, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId
FROM tblLocations
WHERE ValidityTo IS NULL
AND LocationType = N'D'
GO
