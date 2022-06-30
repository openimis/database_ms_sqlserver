IF OBJECT_ID('[dbo].[uspSSRSEnroledFamilies]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspSSRSEnroledFamilies]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspSSRSEnroledFamilies]
(
	@LocationId INT,
	@StartDate DATE,
	@EndDate DATE,
	@PolicyStatus INT =NULL,
	@dtPolicyStatus xAttribute READONLY
)
AS
BEGIN
	;WITH MainDetails AS
	(
		SELECT F.FamilyID, F.LocationId,R.RegionName, D.DistrictName,W.WardName,V.VillageName,I.IsHead,I.CHFID, I.LastName, I.OtherNames, CONVERT(DATE,I.ValidityFrom) EnrolDate
		FROM tblFamilies F 
		INNER JOIN tblInsuree I ON F.FamilyID = I.FamilyID
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		INNER JOIN tblRegions R ON R.RegionId = D.Region
		WHERE F.ValidityTo IS NULL
		AND I.ValidityTo IS NULL
		AND R.ValidityTo IS NULL
		AND D.ValidityTo IS  NULL
		AND W.ValidityTo IS NULL
		AND V.ValidityTo IS NULL
		AND CAST(I.ValidityFrom AS DATE) BETWEEN @StartDate AND @EndDate
		
	),Locations AS(
		SELECT LocationId, ParentLocationId FROM tblLocations WHERE ValidityTo IS NULL AND (LocationId = @LocationId OR CASE WHEN @LocationId IS NULL THEN ISNULL(ParentLocationId, 0) ELSE 0 END = ISNULL(@LocationId, 0))
		UNION ALL
		SELECT L.LocationId, L.ParentLocationId
		FROM tblLocations L 
		INNER JOIN Locations ON Locations.LocationId = L.ParentLocationId
		WHERE L.ValidityTo IS NULL
	),Policies AS
	(
		SELECT ROW_NUMBER() OVER(PARTITION BY PL.FamilyId ORDER BY PL.FamilyId, PL.PolicyStatus)RNo,PL.FamilyId,PL.PolicyStatus
		FROM tblPolicy PL
		WHERE PL.ValidityTo IS NULL
		--AND (PL.PolicyStatus = @PolicyStatus OR @PolicyStatus IS NULL)
		GROUP BY PL.FamilyId, PL.PolicyStatus
	) 
	SELECT MainDetails.*, Policies.PolicyStatus, 
	--CASE Policies.PolicyStatus WHEN 1 THEN N'Idle' WHEN 2 THEN N'Active' WHEN 4 THEN N'Suspended' WHEN 8 THEN N'Expired' ELSE N'No Policy' END 
	PS.Name PolicyStatusDesc
	FROM  MainDetails 
	INNER JOIN Locations ON Locations.LocationId = MainDetails.LocationId
	LEFT OUTER JOIN Policies ON MainDetails.FamilyID = Policies.FamilyID
	LEFT OUTER JOIN @dtPolicyStatus PS ON PS.ID = ISNULL(Policies.PolicyStatus, 0)
	WHERE (Policies.RNo = 1 OR Policies.PolicyStatus IS NULL) 
	AND (Policies.PolicyStatus = @PolicyStatus OR @PolicyStatus IS NULL)
	ORDER BY MainDetails.LocationId;
END
GO
