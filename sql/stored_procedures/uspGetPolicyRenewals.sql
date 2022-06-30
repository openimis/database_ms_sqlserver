IF OBJECT_ID('[uspGetPolicyRenewals]', 'P') IS NOT NULL
    DROP PROCEDURE [uspGetPolicyRenewals]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspGetPolicyRenewals]
(
	@OfficerCode NVARCHAR(8)
)
AS
BEGIN
	DECLARE @OfficerId INT
	DECLARE @LegacyOfficer INT
	DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

	SELECT @OfficerId = OfficerID FROM tblOfficer WHERE Code= @OfficerCode AND ValidityTo IS NULL
	INSERT INTO @tblOfficerSub(OldOfficer, NewOfficer)
	SELECT DISTINCT @OfficerID, @OfficerID

	SET @LegacyOfficer = (SELECT OfficerID FROM tblOfficer WHERE ValidityTo IS NULL AND OfficerIDSubst = @OfficerID)
	WHILE @LegacyOfficer IS NOT NULL
		BEGIN
			INSERT INTO @tblOfficerSub(OldOfficer, NewOfficer)
			SELECT DISTINCT @OfficerID, @LegacyOfficer
			IF EXISTS(SELECT 1 FROM @tblOfficerSub  GROUP BY NewOfficer HAVING COUNT(1) > 1)
				BREAK;
			SET @LegacyOfficer = (SELECT OfficerID FROM tblOfficer WHERE ValidityTo IS NULL AND OfficerIDSubst = @LegacyOfficer)
		END;


	;WITH FollowingPolicies AS
	(
		SELECT P.PolicyId, P.FamilyId, ISNULL(Prod.ConversionProdId, Prod.ProdId)ProdID, P.StartDate
		FROM tblPolicy P
		INNER JOIN tblProduct Prod ON P.ProdId = ISNULL(Prod.ConversionProdId, Prod.ProdId)
		WHERE P.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
	)

	SELECT R.RenewalUUID, R.RenewalId,R.PolicyId, O.OfficerId, O.Code OfficerCode, I.CHFID, I.LastName, I.OtherNames, Prod.ProductCode, Prod.ProductName,F.LocationId, V.VillageName, R.RenewalpromptDate RenewalpromptDate, O.Phone,  RenewalDate EnrollDate, 'R' PolicyStage, F.FamilyID, Prod.ProdID, R.ResponseDate, R.ResponseStatus
	FROM tblPolicyRenewals R
	INNER JOIN tblOfficer O ON R.NewOfficerId = O.OfficerId
	INNER JOIN tblInsuree I ON R.InsureeId = I.InsureeId
	LEFT OUTER JOIN tblProduct Prod ON R.NewProdId = Prod.ProdId
	INNER JOIN tblFamilies F ON I.FamilyId = F.Familyid
	INNER JOIN tblVillages V ON F.LocationId = V.VillageId
	INNER JOIN tblPolicy Po ON Po.PolicyID = R.PolicyID
	INNER JOIN @tblOfficerSub OS ON OS.NewOfficer = R.NewOfficerID
	LEFT OUTER JOIN FollowingPolicies FP ON FP.FamilyID = F.FamilyId
										AND FP.ProdId = Po.ProdID
										AND FP.PolicyId <> R.PolicyID
										AND FP.PolicyId IS NULL
	WHERE R.ValidityTo Is NULL
	AND ISNULL(R.ResponseStatus, 0) = 0
END
GO
