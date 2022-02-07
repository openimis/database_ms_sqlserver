IF OBJECT_ID('uspInsertIndexMonthly', 'P') IS NOT NULL
    DROP PROCEDURE uspInsertIndexMonthly
GO

CREATE PROCEDURE [dbo].[uspInsertIndexMonthly]
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
	DECLARE @CeilingInterpretation as varchar(1)
	SELECT @CeilingInterpretation = ISNULL(CeilingInterpretation,'H') FROM tblProduct WHERE ProdID = @ProductID
	DECLARE @RtnStatus int = 1
	SELECT @DistrPerc = ISNULL(DistrPerc,1) FROM dbo.tblRelDistr WHERE ProdID = @ProductID AND Period = @Period AND DistrType = @RelType AND DistrCareType = @Type AND ValidityTo IS NULL
	
	-- sum of item value		
	SELECT @ClaimValueItems = ISNULL(SUM(d.PriceValuated),0) 
	FROM tblClaim 
	INNER JOIN tblClaimItems d ON tblClaim.ClaimID = d.ClaimID 
	INNER JOIN tblHF ON tblClaim.HFID = tblHF.HfID
	INNER JOIN tblProductItems pd on d.ProdID = pd.ProdID and pd.PriceOrigin = 'R' AND d.ItemID = pd.ItemID
	WHERE     (d.ClaimItemStatus = 1) AND (tblClaim.ValidityTo IS NULL) 
	AND (d.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 8) 
	AND tblClaim.ProcessStamp BETWEEN @startDate AND @EndDate 
	AND (d.ProdID = @ProductID) 
	AND (
		(@TYPE =  'O' and @CeilingInterpretation = 'H' AND tblHF.HFLevel <> 'H') 
		OR (@TYPE =  'O' and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,ISNULL(tblClaim.DateTo,tblClaim.DateFrom))<=1) 
		OR (@TYPE =  'I' and @CeilingInterpretation = 'H' AND tblHF.HFLevel = 'H')
		OR (@TYPE =  'I'and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,ISNULL(tblClaim.DateTo,tblClaim.DateFrom))>1)  
		OR @TYPE =  'B'
	)

	-- sum of service value
	SELECT @ClaimValueservices = ISNULL(SUM(d.PriceValuated) ,0)
	FROM tblClaim INNER JOIN
	tblClaimServices d ON tblClaim.ClaimID = d.ClaimID 
	INNER JOIN tblHF ON tblClaim.HFID = tblHF.HfID
	INNER JOIN tblProductServices ps on d.ProdID = ps.ProdID and ps.PriceOrigin = 'R'  AND d.ServiceID = ps.ServiceID
	WHERE     (d.ClaimServiceStatus = 1) AND (tblClaim.ValidityTo IS NULL) 
	AND (d.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 8) 
	AND tblClaim.ProcessStamp BETWEEN @startDate AND @EndDate 
	AND	(d.ProdID = @ProductID) 
	AND ((@TYPE =  'O' and @CeilingInterpretation = 'H' AND tblHF.HFLevel <> 'H') 
	OR (@TYPE =  'O' and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,ISNULL(tblClaim.DateTo,tblClaim.DateFrom))<=1) 
	OR (@TYPE =  'I' and @CeilingInterpretation = 'H' AND tblHF.HFLevel = 'H')
	OR (@TYPE =  'I'and @CeilingInterpretation = 'I' AND DATEDIFF(d,tblClaim.DateFrom,ISNULL(tblClaim.DateTo,tblClaim.DateFrom))>1)  
	OR @TYPE =  'B')
	
	
	IF @ClaimValueItems + @ClaimValueservices = 0 
	BEGIN
		--basically all 100% is available
		SET @RtnStatus = 0 
		SET @RelIndex = 1
		INSERT INTO [tblRelIndex] ([ProdID],[RelType],[RelCareType],[RelYear],[RelPeriod],[CalcDate],[RelIndex],[AuditUserID],[LocationId] )
		VALUES (@ProductID,@RelType,@Type,YEAR(@startDate),@Period,GETDATE(),@RelIndex,@AuditUser,@LocationId )
	END
	ELSE
	BEGIN
		SET @RelIndex = CAST((@PrdValue * @DistrPerc) as Decimal(18,4)) / (@ClaimValueItems + @ClaimValueservices)
		INSERT INTO [tblRelIndex] ([ProdID],[RelType],[RelCareType],[RelYear],[RelPeriod],[CalcDate],[RelIndex],[AuditUserID],[LocationId],PrdValue)
		VALUES (@ProductID,@RelType,@Type,YEAR(@startDate),@Period,GETDATE(),@RelIndex,@AuditUser,@LocationId, @PrdValue )
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


