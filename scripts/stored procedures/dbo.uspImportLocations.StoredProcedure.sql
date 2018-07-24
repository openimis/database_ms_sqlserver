USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspImportLocations]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspImportLocations]
(

	@RegionsFile NVARCHAR(255),
	@DistrictsFile NVARCHAR(255),
	@WardsFile NVARCHAR(255),
	@VillagesFile NVARCHAR(255)
)
AS
BEGIN
BEGIN TRY
	--CREATE TEMP TABLE FOR REGION
	IF OBJECT_ID('tempdb..#tempRegion') IS NOT NULL DROP TABLE #tempRegion
	CREATE TABLE #tempRegion(RegionName NVARCHAR(50), RegionCode NVARCHAR(8))

	--CREATE TEMP TABLE FOR DISTRICTS
	IF OBJECT_ID('tempdb..#tempDistricts') IS NOT NULL DROP TABLE #tempDistricts
	CREATE TABLE #tempDistricts(RegionName NVARCHAR(50),DistrictName NVARCHAR(50),DistrictCode NVARCHAR(8))

	--CREATE TEMP TABLE FOR WARDS
	IF OBJECT_ID('tempdb..#tempWards') IS NOT NULL DROP TABLE #tempWards
	CREATE TABLE #tempWards(DistrictName NVARCHAR(50),WardName NVARCHAR(50),WardCode NVARCHAR(8))

	--CREATE TEMP TABLE FOR VILLAGES
	IF OBJECT_ID('tempdb..#tempVillages') IS NOT NULL DROP TABLE #tempVillages
	CREATE TABLE #tempVillages(DistrictName NVARCHAR(50),WardName NVARCHAR(50),VillageName NVARCHAR(50), VillageCode NVARCHAR(8))



	--INSERT REGION IN TEMP TABLE
	DECLARE @InsertRegion NVARCHAR(2000)
	SET @InsertRegion = N'BULK INSERT #tempRegion FROM ''' + @RegionsFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertRegion

	--INSERT DISTRICTS IN TEMP TABLE
	DECLARE @InsertDistricts NVARCHAR(2000)
	SET @InsertDistricts = N'BULK INSERT #tempDistricts FROM ''' + @DistrictsFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertDistricts


	--INSERT WARDS IN TEMP TABLE
	DECLARE @InsertWards NVARCHAR(2000)
	SET @InsertWards = N'BULK INSERT #tempWards FROM ''' + @WardsFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertWards


	--INSERT VILLAGES IN TEMP TABLE
	DECLARE @InsertVillages NVARCHAR(2000)
	SET @InsertVillages = N'BULK INSERT #tempVillages FROM ''' + @VillagesFile + '''' +
		'WITH (
		FIELDTERMINATOR = ''	'',
		FIRSTROW = 2
		)'
	EXEC SP_EXECUTESQL @InsertVillages
    

	DECLARE @AllCodes AS TABLE(LocationCode NVARCHAR(8))
	;WITH AllCodes AS
	(
		SELECT RegionCode LocationCode FROM #tempRegion
		UNION ALL
		SELECT DistrictCode FROM #tempDistricts
		UNION ALL
		SELECT WardCode FROM #tempWards
		UNION ALL
		SELECT VillageCode FROM #tempVillages
	)
	INSERT INTO @AllCodes(LocationCode)
	SELECT LocationCode
	FROM AllCodes

	IF EXISTS(SELECT LocationCode FROM @AllCodes GROUP BY LocationCode HAVING COUNT(1) > 1)
		BEGIN
			SELECT LocationCode FROM @AllCodes GROUP BY LocationCode HAVING COUNT(1) > 1;
			RAISERROR ('Duplicate in excel', 16, 1)
		END

	;WITH AllLocations AS
	(
		SELECT RegionCode LocationCode FROM tblRegions
		UNION ALL
		SELECT DistrictCode FROM tblDistricts
		UNION ALL
		SELECT WardCode FROM tblWards
		UNION ALL
		SELECT VillageCode FROM tblVillages
	)
	SELECT AC.LocationCode
	FROM @AllCodes AC
	INNER JOIN AllLocations AL ON AC.LocationCode COLLATE DATABASE_DEFAULT = AL.LocationCode COLLATE DATABASE_DEFAULT

	IF @@ROWCOUNT > 0
		RAISERROR ('One or more location codes are already existing in database', 16, 1)
	
	BEGIN TRAN
	
 
	--INSERT REGION IN DATABASE
	IF EXISTS(SELECT * FROM tblRegions
			 INNER JOIN #tempRegion ON tblRegions.RegionName COLLATE DATABASE_DEFAULT = #tempRegion.RegionName COLLATE DATABASE_DEFAULT)
		BEGIN
			ROLLBACK TRAN

			RETURN -4
		END
	ELSE
		--INSERT INTO tblRegions(RegionName,RegionCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocatioNname, LocationType, AuditUserId)
		SELECT RegionCode, REPLACE(RegionName,CHAR(12),''),'R',-1 
		FROM #tempRegion
		WHERE RegionName IS NOT NULL

	--INSERT DISTRICTS IN DATABASE
	IF EXISTS(SELECT * FROM tblDistricts
			 INNER JOIN #tempDistricts ON tblDistricts.DistrictName COLLATE DATABASE_DEFAULT = #tempDistricts.DistrictName COLLATE DATABASE_DEFAULT)
		BEGIN
			ROLLBACK TRAN
			RETURN -1
		END
	ELSE
		--INSERT INTO tblDistricts(Region,DistrictName,DistrictCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserId)
		SELECT #tempDistricts.DistrictCode, REPLACE(#tempDistricts.DistrictName,CHAR(9),''),tblRegions.RegionId,'D', -1
		FROM #tempDistricts 
		INNER JOIN tblRegions ON #tempDistricts.RegionName COLLATE DATABASE_DEFAULT = tblRegions.RegionName COLLATE DATABASE_DEFAULT
		WHERE #tempDistricts.DistrictName is NOT NULL
		 
		
	--INSERT WARDS IN DATABASE
	IF EXISTS (SELECT * 
				FROM tblWards INNER JOIN tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID
				INNER JOIN #tempWards ON tblWards.WardName COLLATE DATABASE_DEFAULT = #tempWards.WardName COLLATE DATABASE_DEFAULT
				AND tblDistricts.DistrictName COLLATE DATABASE_DEFAULT = #tempWards.DistrictName COLLATE DATABASE_DEFAULT)	
		BEGIN
			ROLLBACK TRAN
			RETURN -2
		END
	ELSE
		--INSERT INTO tblWards(DistrictID,WardName,WardCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserId)
		SELECT WardCode, REPLACE(#tempWards.WardName,CHAR(9),''),tblDistricts.DistrictID,'W',-1
		FROM #tempWards INNER JOIN tblDistricts ON #tempWards.DistrictName COLLATE DATABASE_DEFAULT = tblDistricts.DistrictName COLLATE DATABASE_DEFAULT
		WHERE #tempWards.WardName is NOT NULL


	--INSERT VILLAGES IN DATABASE
	IF EXISTS (SELECT * FROM 
				tblVillages INNER JOIN tblWards ON tblVillages.WardID = tblWards.WardID
				INNER JOIN tblDistricts ON tblDistricts.DistrictID = tblWards.DistrictID
				INNER JOIN #tempVillages ON #tempVillages.VillageName COLLATE DATABASE_DEFAULT = tblVillages.VillageName COLLATE DATABASE_DEFAULT
				AND #tempVillages.WardName COLLATE DATABASE_DEFAULT = tblWards.WardName COLLATE DATABASE_DEFAULT
				AND #tempVillages.DistrictName COLLATE DATABASE_DEFAULT = tblDistricts.DistrictName COLLATE DATABASE_DEFAULT)
		BEGIN
			ROLLBACK TRAN
			RETURN -3
		END
	ELSE
		--INSERT INTO tblVillages(WardID,VillageName,VillageCode,AuditUserID)
		INSERT INTO tblLocations(LocationCode, LocationName, ParentLocationId, LocationType, AuditUserId)
		SELECT VillageCode,REPLACE(#tempVillages.VillageName,CHAR(9),''),tblWards.WardID,'V',-1
		FROM #tempVillages 
		INNER JOIN tblDistricts ON #tempVillages.DistrictName COLLATE DATABASE_DEFAULT = tblDistricts.DistrictName COLLATE DATABASE_DEFAULT
		INNER JOIN tblWards ON #tempVillages.WardName COLLATE DATABASE_DEFAULT = tblWards.WardName COLLATE DATABASE_DEFAULT AND tblDistricts.DistrictID = tblWards.DistrictID 
		WHERE VillageName IS NOT NULL
	COMMIT TRAN				
	
		--DROP ALL THE TEMP TABLES
		DROP TABLE #tempRegion
		DROP TABLE #tempDistricts
		DROP TABLE #tempWards
		DROP TABLE #tempVillages
	
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRAN;
		THROW SELECT ERROR_MESSAGE();
	END CATCH
	
END
GO
