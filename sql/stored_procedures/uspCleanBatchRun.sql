/****** Object:  StoredProcedure [dbo].[uspCleanBatchRun]    Script Date: 2/6/2022 12:22:44 AM ******/
IF OBJECT_ID('uspCleanBatchRun', 'P') IS NOT NULL
    DROP PROCEDURE uspCleanBatchRun
GO

CREATE PROCEDURE [dbo].[uspCleanBatchRun]( @runid int ) AS
BEGIN
	declare @ClaimID TABLE (ClaimID int)
	-- get the concerned claims
    INSERT INTO @ClaimID(ClaimID) 
		SELECT CLAIMID FROM tblClaim
		WHERE  RunID = @runid 
	--remove link and remunerated value for claims, items and services
	UPDATE tblClaim   SET RunID = NULL, Remunerated = NULL, ClaimStatus = 8  
	FROM tblClaim C WITH (NOLOCK)  inner JOIN @ClaimID tpc on tpc.claimID = C.claimID WHERE c.runid is not null
	UPDATE tblClaimItems  SET ClaimItemStatus = 1, RemuneratedAmount = NULL  
	FROM tblClaimItems  WITH (NOLOCK)  inner JOIN @ClaimID tpc on tpc.claimID = tblClaimItems.claimID
	WHERE  ValidityTo is NULL
    UPDATE tblClaimServices SET ClaimServiceStatus = 1, RemuneratedAmount = NULL  
	FROM tblClaimServices WITH (NOLOCK) inner JOIN @ClaimID tpc on tpc.claimID = tblClaimServices.claimID
	WHERE  ValidityTo is NULL
    -- remove the related indexes
	DELETE idx FROM  [tblRelIndex] idx
	INNER JOIN tblProduct p on idx.ProdID = p.ProdID
	LEFT JOIN tblBatchRun br on p.LocationId = br.LocationId and idx.RelPeriod = br.RunMonth and idx.RelYear = br.RunYear 
	WHERE br.RunID = @runid
	-- remove the run id
	DELETE FROM tblBatchRun WHERE tblBatchRun.RunID = @runid or tblBatchRun.LegacyID = @runid
END
GO
