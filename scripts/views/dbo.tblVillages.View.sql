USE [IMIS]
GO
/****** Object:  View [dbo].[tblVillages]    Script Date: 7/24/2018 6:47:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[tblVillages] AS
SELECT LocationId VillageId, ParentLocationId WardId, LocationCode VillageCode, LocationName VillageName,MalePopulation, FemalePopulation, OtherPopulation, Families, ValidityFrom, ValidityTo, LegacyId, AuditUserId, RowId
FROM tblLocations 
WHERE ValidityTo IS NULL
AND LocationType = N'V'
GO
