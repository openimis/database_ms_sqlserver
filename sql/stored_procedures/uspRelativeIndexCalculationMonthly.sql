/****** Object:  StoredProcedure [dbo].[uspRelativeIndexCalculationMonthly]    Script Date: 2/4/2022 8:10:59 PM ******/
IF OBJECT_ID('uspRelativeIndexCalculationMonthly', 'P') IS NOT NULL
    DROP PROCEDURE uspRelativeIndexCalculationMonthly
GO


CREATE PROCEDURE [dbo].[uspRelativeIndexCalculationMonthly]
(
@RelType INT,   --1 ,4 12  
@startDate date,    
@EndDate date,
@ProductID INT ,
@DistrType  char(1) ,
@Period int ,
@AuditUser int = -1,
@RelIndex  decimal(18,4) OUTPUT
)

AS
BEGIN
	DECLARE @oReturnValue as int 
	SET @oReturnValue = 0 
	BEGIN TRY
	
	DECLARE @DaysInCovered as int
	DECLARE @PrdValue as decimal(18,2)

	SELECT @DaysInCovered = DATEDIFF(DAY,@startDate,@EndDate)
	SELECT  @PrdValue = ISNULL(SUM(NumValue.Allocated),0)  
	FROM 
	(	
	SELECT
	(CAST(1+DATEDIFF(DAY,
		CASE WHEN @startDate >  PR.PayDate and  @startDate >  PL.EffectiveDate  THEN  @startDate  WHEN PR.PayDate > PL.EffectiveDate THEN PR.PayDate ELSE  PL.EffectiveDate  END
		,CASE WHEN PL.ExpiryDate < @EndDate THEN PL.ExpiryDate ELSE @EndDate END)
		as decimal(18,4)) / DATEDIFF (DAY,(CASE WHEN PR.PayDate > PL.EffectiveDate THEN PR.PayDate ELSE  PL.EffectiveDate  END), PL.ExpiryDate ) * PR.Amount 
	) Allocated
	FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
	LEFT JOIN tblLocations L ON ISNULL(Prod.LocationId,-1) = ISNULL(L.LocationId,-1)
	WHERE PR.ValidityTo IS NULL
	AND PL.ValidityTo IS NULL
	AND Prod.ValidityTo IS  NULL
	AND (Prod.ProdID = @ProductID OR @ProductId = 0)
	AND PL.PolicyStatus <> 1
	AND PR.PayDate < PL.ExpiryDate
	AND PL.EffectiveDate < PL.ExpiryDate
	AND PL.ExpiryDate >= @startDate
	AND (PR.PayDate <=  @EndDate AND PL.EffectiveDate <= @EndDate) 
	) NumValue


	EXEC  @oReturnValue =[dbo].[uspInsertIndexMonthly] @Type = @DistrType,
		@RelType = @RelType, 
		@startDate = @startDate, 
		@EndDate = @EndDate, 
		@Period = @Period,
		@LocationId = 0 ,
		@ProductID = @ProductID ,
		@PrdValue = @PrdValue ,
		@AuditUser = @AuditUser , 
		@RelIndex =  @RelIndex OUTPUT;



FINISH:
	
	RETURN @oReturnValue
END TRY
	
	BEGIN CATCH
		SELECT 'uspRelativeIndexCalculationMonthly',
    ERROR_NUMBER() AS ErrorNumber,
    ERROR_STATE() AS ErrorState,
    ERROR_SEVERITY() AS ErrorSeverity,
    ERROR_PROCEDURE() AS ErrorProcedure,
    ERROR_LINE() AS ErrorLine,
    ERROR_MESSAGE() AS ErrorMessage
		SET @oReturnValue = 1 
		SET @RelIndex = 0.0
		RETURN @oReturnValue
		
	END CATCH
	
END

/****** Object:  StoredProcedure [dbo].[uspBatchProcess]    Script Date: 10/25/2021 2:50:08 PM ******/
SET ANSI_NULLS ON
