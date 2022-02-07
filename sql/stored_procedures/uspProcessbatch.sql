
IF OBJECT_ID('uspBatchProcess', 'P') IS NOT NULL
    DROP PROCEDURE uspBatchProcess
GO

CREATE PROCEDURE [dbo].[uspBatchProcess]
	
	@AuditUser as int = 0,
	@LocationId as int, 
	@Period as int,
	@Year as int,
	@RtnStatus as int = 0 OUTPUT 
	
	--@RtnStatus 0=OK --> 1 General fault  --> 2 = Already run before 
AS
BEGIN
	IF @LocationId=-1
	SET @LocationId=NULL


	DECLARE @oReturnValue as INT
	SET @oReturnValue = 0 	
	
	DECLARE @InTopIsolation as bit 
	
	SET @InTopIsolation = -1 
	
	BEGIN TRY 
	-- manage isolation
	IF @@TRANCOUNT = 0 	
		SET @InTopIsolation =0
	ELSE
		SET @InTopIsolation =1
	IF @InTopIsolation = 0
		BEGIN TRANSACTION PROCESSCLAIMS

	DECLARE @CLAIMID as INT
	DECLARE @HFLevel as Char(1)
	DECLARE @ProdID as int 
	DECLARE @RP_G as Char(1)
	DECLARE @RP_IP as Char(1)
	DECLARE @RP_OP as Char(1)
	DECLARE @CI as Char(1)
	DECLARE @RP_Period as int
	DECLARE @RP_Year as int 
	
	DECLARE @Index as decimal(18,4)
	DECLARE @IndexIP as decimal(18,4)

	
	DECLARE @tblClaimIDs TABLE(ClaimID INT)
	DECLARE @Months TABLE(monthnbr INT)
	DECLARE @tblProdIDs TABLE(ProdID INT)


	-- check if already run
	SELECT @RP_Period = RunMonth FROM tblBatchRun WHERE RunYear = @Year AND RunMonth = @Period AND ISNULL(LocationId,-1) = ISNULL(@LocationId,-1) AND ValidityTo IS NULL
	IF ISNULL(@RP_Period,0) <> 0 
	BEGIN
		SET @oReturnValue = 2 
		SELECT 'Already Run'
		IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
		RETURN @oReturnValue
	END
	
	--NOW insert a new batch run record and keep latest ID in memory
	INSERT INTO tblBatchRun
           ([LocationId],[RunYear],[RunMonth],[RunDate],[AuditUserID])
    VALUES (@LocationId ,@Year, @Period , GETDATE() ,@AuditUser )
    DECLARE @RunID as int
    SELECT @RunID = SCOPE_IDENTITY ()


	-- loop all product for that location
	DECLARE PRODUCTLOOPITEMS CURSOR LOCAL FORWARD_ONLY FOR 
		SELECT prodID,  PeriodRelPrices ,  PeriodRelPricesOP,  PeriodRelPricesIP, CeilingInterpretation FROM tblProduct WHERE ValidityTo is NULL AND ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId,-1)
	OPEN PRODUCTLOOPITEMS
	FETCH NEXT FROM PRODUCTLOOPITEMS INTO @ProdID,@RP_G,@RP_OP,@RP_IP,@CI
	WHILE @@FETCH_STATUS = 0 
	BEGIN
	-- calculate the diferent start/stop dates
	DECLARE @TargetQuarter int  =0
	DECLARE @startDateQuarter date = NULL

	IF @Period = 3 or @Period = 6 OR @Period = 9 OR @Period = 12 
	BEGIN
		SET @TargetQuarter = @Period / 3
		SET @startDateQuarter = DATEFROMPARTS(@Year, (@TargetQuarter -1)*3+1 ,'01')
	END
	DECLARE @startDateMonth date = DATEFROMPARTS(@Year, @Period ,'01')
	DECLARE @startDateYear date = DATEFROMPARTS(@Year, '01' ,'01')
	DECLARE @endDate date = EOMONTH(@startDateMonth)
	-- assing the startdate based on product config
	DECLARE @startDate date = CASE @RP_G WHEN 'M' THEN @startDateMonth WHEN 'Q' THEN @startDateQuarter WHEN 'Y' THEN @startDateYear ELSE NULL END
	DECLARE @startDateIP date = CASE @RP_IP WHEN 'M' THEN @startDateMonth WHEN 'Q' THEN @startDateQuarter WHEN 'Y' THEN @startDateYear ELSE NULL END
	DECLARE @startDateOP date = CASE @RP_OP WHEN 'M' THEN @startDateMonth WHEN 'Q' THEN @startDateQuarter WHEN 'Y' THEN @startDateYear ELSE NULL END
	-- convert relType to int
	DECLARE @RelTypeG int = CASE @RP_G WHEN 'Y' THEN 1 WHEN 'Q' THEN 4 ELSE 12 END
	DECLARE @RelTypeIP int = CASE @RP_IP WHEN 'Y' THEN 1 WHEN 'Q' THEN 4 ELSE 12 END
	DECLARE @RelTypeOP int = CASE @RP_OP WHEN 'Y' THEN 1 WHEN 'Q' THEN 4 ELSE 12 END
	-- calculate the allocated contribution and the index
	IF @startDate IS NOT null
	BEGIN
		EXEC @oReturnValue =  [uspRelativeIndexCalculationMonthly] @RelType=@RelTypeG, @startDate=@startDate, @endDate=@endDate ,@ProductID=@ProdID, @DistrType='B', @Period=@Period, @AuditUser=@AuditUser, @RelIndex=@Index OUTPUT
		SET @IndexIP = @Index
	END
	ELSE 
	BEGIN
		IF  @startDateIP IS NOT null
			EXEC  @oReturnValue = [uspRelativeIndexCalculationMonthly] @RelType=@RelTypeG, @startDate=@startDateIP, @endDate=@endDate ,@ProductID=@ProdID, @DistrType='I', @Period=@Period, @AuditUser=@AuditUser, @RelIndex=@IndexIP OUTPUT
		IF  @startDateOP IS NOT null
			EXEC  @oReturnValue = [uspRelativeIndexCalculationMonthly] @RelType=@RelTypeG, @startDate=@startDateOP, @endDate=@endDate ,@ProductID=@ProdID, @DistrType='B', @Period=@Period, @AuditUser=@AuditUser, @RelIndex=@Index OUTPUT
	END
	IF ISNULL(@Index,0) > 0  OR ISNULL(@IndexIP,0) > 0 
	BEGIN
		-- apply index on claim items
		UPDATE tblClaimItems SET RemuneratedAmount = CASE WHEN CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END <>'H' THEN @Index ELSE @IndexIP END * PriceValuated 
		FROM tblClaim 
		INNER JOIN tblClaimItems d ON tblClaim.ClaimID = d.ClaimID 
		INNER JOIN tblHF ON tblClaim.HFID = tblHF.HfID
		INNER JOIN tblProductItems pd on d.ProdID = pd.ProdID and pd.PriceOrigin = 'R' AND d.ItemID = pd.ItemID
		WHERE     (d.ClaimItemStatus = 1) AND (tblClaim.ValidityTo IS NULL) 
		AND (d.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 8) 
					AND(
					((tblClaim.ProcessStamp BETWEEN @startDate AND  @endDate) AND @RP_G is not NULL  )
					OR ((tblClaim.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND @RP_IP is not NULL AND CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END <> 'H')
					OR ((tblClaim.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND @RP_OP is not NULL AND CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END = 'H')
					)
		AND (d.ProdID = @ProdID) 
		-- apply index on claim services
		UPDATE tblClaimServices SET RemuneratedAmount = CASE WHEN CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END <>'H' THEN @Index ELSE @IndexIP END * PriceValuated 
		FROM tblClaim 
		INNER JOIN tblClaimServices d ON tblClaim.ClaimID = d.ClaimID 
		INNER JOIN tblHF ON tblClaim.HFID = tblHF.HfID
		INNER JOIN tblProductServices pd on d.ProdID = pd.ProdID and pd.PriceOrigin = 'R' AND d.ServiceId = pd.ServiceID
		WHERE     (d.ClaimserviceStatus = 1) AND (tblClaim.ValidityTo IS NULL) 
		AND (d.ValidityTo IS NULL) AND (tblClaim.ClaimStatus = 8) 
					AND(
					((tblClaim.ProcessStamp BETWEEN @startDate AND  @endDate) AND @RP_G is not NULL  )
					OR ((tblClaim.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND @RP_IP is not NULL AND CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END <> 'H')
					OR ((tblClaim.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND @RP_OP is not NULL AND CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END = 'H')
					)
		AND (d.ProdID = @ProdID) 
	END
	-- update claim with runid and sum of remunerated amount form items ans services
	UPDATE tblClaim SET RunID = @RunID ,  ClaimStatus = 16, Remunerated = CDetails.Remunerated
	FROM         tblClaim 
	INNER JOIN (
		SELECT claimID, MAX(prodID) prodID, SUM(Remunerated)Remunerated FROM(
			SELECT tblClaimItems.ClaimID,ProdID, ( CASE PriceOrigin WHEN 'R' THEN RemuneratedAmount ELSE PriceValuated END) Remunerated 
			FROM tblClaimItems 
			WHERE  (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.ClaimItemStatus = 1) 
			UNION ALL
			SELECT  tblclaimServices.ClaimID,ProdID,  (CASE PriceOrigin WHEN 'R' THEN RemuneratedAmount ELSE PriceValuated END) Remunerated  
			FROM tblclaimServices 
			WHERE  (tblclaimServices.ValidityTo IS NULL) AND (tblclaimServices.ClaimServiceStatus = 1) 
		) as total WHERE ProdID  = @ProdID  GROUP BY claimID
	) as CDetails on tblClaim.ClaimID = CDetails.ClaimID

	JOIN tblHF on tblClaim.HFID = tblHF.HFID 
	-- claim with multiple productid will be on the batch on the product with highest productID (no business way defined)
	WHERE     tblClaim.ClaimStatus in (16, 8) AND (tblClaim.ValidityTo IS NULL)
		AND(
		((tblClaim.ProcessStamp BETWEEN @startDate AND  @endDate) AND @RP_G is not NULL  )
		OR ((tblClaim.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND @RP_IP is not NULL AND CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END <> 'H')
		OR ((tblClaim.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND @RP_OP is not NULL AND CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,tblClaim.DateFrom,tblClaim.DateTo)<1 THEN 'H' ELSE 'D' END = 'H')
		)
		AND  RunID is NULL;

		
NextProdItems:
		FETCH NEXT FROM PRODUCTLOOPITEMS INTO @ProdID,@RP_G,@RP_OP,@RP_IP,@CI
	END
	CLOSE PRODUCTLOOPITEMS
	DEALLOCATE PRODUCTLOOPITEMS


FINISH:
	IF @InTopIsolation = 0 
		COMMIT TRANSACTION PROCESSCLAIMS
	SET @oReturnValue = 0 
	RETURN @oReturnValue
		 
	END TRY
	BEGIN CATCH
		SET @oReturnValue = 1 
				SELECT 'uspBatchProcess',
				ERROR_NUMBER() AS ErrorNumber,
				ERROR_STATE() AS ErrorState,
				ERROR_SEVERITY() AS ErrorSeverity,
				ERROR_PROCEDURE() AS ErrorProcedure,
				ERROR_LINE() AS ErrorLine,
				ERROR_MESSAGE() AS ErrorMessage
		IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
		RETURN @oReturnValue

	END CATCH

	ERR_HANDLER:

	SELECT 'uspBatchProcess',
				ERROR_NUMBER() AS ErrorNumber,
				ERROR_STATE() AS ErrorState,
				ERROR_SEVERITY() AS ErrorSeverity,
				ERROR_PROCEDURE() AS ErrorProcedure,
				ERROR_LINE() AS ErrorLine,
				ERROR_MESSAGE() AS ErrorMessage
	IF @InTopIsolation = 0 ROLLBACK TRANSACTION PROCESSCLAIMS
	RETURN @oReturnValue

END
	



