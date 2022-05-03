IF OBJECT_ID('uspInsertIndexMonthly', 'P') IS NOT NULL
    DROP PROCEDURE uspInsertIndexMonthly
GO

CREATE  PROCEDURE [dbo].[uspInsertIndexMonthly]
(
@Type varchar(1), -- I O B
@RelType INT, -- M 12, Q 4, Y 1 
@startDate date,    
@EndDate date,
@Period INT,
@LocationId INT = 0,
@ProductID INT = 0,
@PrdValue decimal(18,2) =0,
@AuditUser int = -1,
@RelIndex  decimal(18,4) OUTPUT
)

AS
BEGIN
BEGIN TRY 
	DECLARE @DistrPerc as decimal(18,2)
	DECLARE @ClaimValueItems as decimal(18,2)
	DECLARE @ClaimValueservices as decimal(18,2)
	DECLARE @CI as varchar(1)
	DECLARE @Level1  Char(1), @SubLevel1  Char(1), @Level2  Char(1), @SubLevel2  Char(1), @Level3  Char(1), @SubLevel3  Char(1), @Level4  Char(1), @SubLevel4  Char(1)
	
	SELECT @CI = ISNULL(CeilingInterpretation,'H'), @Level1 = Level1  , @SubLevel1 = SubLevel1 , @Level2 = Level2  , @SubLevel2 = SubLevel2  , @Level3 = Level3  , @SubLevel3 = SubLevel3 , @Level4 = Level4 , @SubLevel4 = SubLevel4 FROM tblProduct WHERE ProdID = @ProductID
	DECLARE @RtnStatus int = 1
	SELECT @DistrPerc = ISNULL(DistrPerc,1) FROM dbo.tblRelDistr WHERE ProdID = @ProductID AND Period = @Period AND DistrType = @RelType AND DistrCareType = @Type AND ValidityTo IS NULL
	
	-- sum of item value		
	SELECT @ClaimValueItems =  SUM(ISNULL(d.PriceValuated,0) )
	FROM 	tblClaimItems d 
	INNER JOIN tblClaim  c ON c.ClaimID = d.ClaimID AND (c.ValidityTo IS NULL)
	INNER JOIN tblHF HF ON c.HFID = HF.HfID
	WHERE     (d.ClaimItemStatus = 1)   and  d.PriceOrigin = 'R'
	AND (d.ValidityTo IS NULL) and ClaimStatus = 8
	AND	(d.ProdID = @ProductID) 
	AND(
		(@TYPE =  'B' and (c.ProcessStamp BETWEEN @startDate AND  @endDate)    )
		OR (@TYPE =  'I' and (c.ProcessStamp BETWEEN @startDate AND  @endDate) AND  
			CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END = 'H')
		OR (@TYPE =  'O'  and (c.ProcessStamp BETWEEN @startDate AND  @endDate) AND  
			CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END <> 'H')
	)
	AND NOT (HF.HFLevel = ISNULL(@Level1,'A') AND (HF.HFSublevel = ISNULL(@SubLevel1,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level2,'A') AND (HF.HFSublevel = ISNULL(@SubLevel2,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level3,'A') AND (HF.HFSublevel = ISNULL(@SubLevel3,HF.HFSublevel)))
	AND NOT (HF.HFLevel =ISNULL(@Level4,'A') AND (HF.HFSublevel = ISNULL(@SubLevel4,HF.HFSublevel)))

	-- sum of service value
	SELECT @ClaimValueservices = SUM(ISNULL(d.PriceValuated,0) )
	FROM 	tblClaimServices d 
	INNER JOIN tblClaim  c ON c.ClaimID = d.ClaimID AND (c.ValidityTo IS NULL)
	INNER JOIN tblHF HF ON c.HFID = HF.HfID
	WHERE     (d.ClaimServiceStatus = 1)    and  d.PriceOrigin = 'R'
	AND (d.ValidityTo IS NULL) and ClaimStatus = 8
	AND	(d.ProdID = @ProductID) 
	AND(
		(@TYPE =  'B' and (c.ProcessStamp BETWEEN @startDate AND  @endDate)    )
		OR (@TYPE =  'I' and (c.ProcessStamp BETWEEN @startDate AND  @endDate) AND  
			CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END = 'H')
		OR (@TYPE =  'O'  and (c.ProcessStamp BETWEEN @startDate AND  @endDate) AND  
			CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END <> 'H')
	)	AND NOT (HF.HFLevel = ISNULL(@Level1,'A') AND (HF.HFSublevel = ISNULL(@SubLevel1,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level2,'A') AND (HF.HFSublevel = ISNULL(@SubLevel2,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level3,'A') AND (HF.HFSublevel = ISNULL(@SubLevel3,HF.HFSublevel)))
	AND NOT (HF.HFLevel =ISNULL(@Level4,'A') AND (HF.HFSublevel = ISNULL(@SubLevel4,HF.HFSublevel)))

	
	SET @ClaimValueItems =ISNULL(@ClaimValueItems,0)
	SET @ClaimValueservices =ISNULL( @ClaimValueservices,0)

	IF @ClaimValueItems + @ClaimValueservices  = 0 
	BEGIN
		--basically all 100% is available
		SET @RtnStatus = 0 
		SET @RelIndex = 1.0
		INSERT INTO [tblRelIndex] ([ProdID],[RelType],[RelCareType],[RelYear],[RelPeriod],[CalcDate],[RelIndex],[AuditUserID],[LocationId] )
		VALUES (@ProductID,@RelType,@Type,YEAR(@startDate),@Period,GETDATE(),@RelIndex,@AuditUser,@LocationId )
	END
	ELSE
	BEGIN
		SET @RelIndex = CAST((@PrdValue * @DistrPerc) as Decimal(18,4)) / (@ClaimValueItems + @ClaimValueservices)
		INSERT INTO [tblRelIndex] ([ProdID],[RelType],[RelCareType],[RelYear],[RelPeriod],[CalcDate],[RelIndex],[AuditUserID],[LocationId])
		VALUES (@ProductID,@RelType,@Type,YEAR(@startDate),@Period,GETDATE(),@RelIndex,@AuditUser,@LocationId)
		SET @RtnStatus = 0
	END
	
	RETURN @RtnStatus
	END TRY
	BEGIN CATCH
	SELECT 'uspInsertIndexMonthly',
    ERROR_NUMBER() AS ErrorNumber,
    ERROR_STATE() AS ErrorState,
    ERROR_SEVERITY() AS ErrorSeverity,
    ERROR_PROCEDURE() AS ErrorProcedure,
    ERROR_LINE() AS ErrorLine,
    ERROR_MESSAGE() AS ErrorMessage
		SET @RtnStatus = 1 
		SET @RelIndex = 0.0
		RETURN @RtnStatus
	END CATCH 


	
END
GO
