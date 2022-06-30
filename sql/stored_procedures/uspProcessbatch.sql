IF OBJECT_ID('[dbo].[uspBatchProcess]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspBatchProcess]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
	DECLARE @RP_G_IN as Char(1)
	DECLARE @CI as Char(1)
	DECLARE @RP_Period as int
	DECLARE @RP_Year as int 
	
	DECLARE @Index as decimal(18,4)
	DECLARE @IndexIP as decimal(18,4)

	DECLARE @Level1  Char(1), @SubLevel1  Char(1), @Level2  Char(1), @SubLevel2  Char(1), @Level3  Char(1), @SubLevel3  Char(1), @Level4  Char(1), @SubLevel4  Char(1)
	
	DECLARE @tblClaimIDs TABLE(ClaimID INT)
	DECLARE @Months TABLE(monthnbr INT)
	DECLARE @tblProdIDs TABLE(ProdID INT)

	DECLARE @startDateMonth date = DATEFROMPARTS(@Year, @Period ,'01')
	DECLARE @startDateYear date = DATEFROMPARTS(@Year, '01' ,'01')
	DECLARE @endDate date = EOMONTH(@startDateMonth)


    -- if   @endDate >  GETDATE()
	-- BEGIN
	-- 	SELECT  'End report date must be before today'
	-- 	SET @oReturnValue = 2 
	-- 	RETURN @oReturnValue
	-- END
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
		SELECT prodID,  PeriodRelPrices ,  PeriodRelPricesOP,  PeriodRelPricesIP, CeilingInterpretation, Level1  , SubLevel1 , Level2  , SubLevel2  , Level3  , SubLevel3 , Level4 , SubLevel4 FROM tblProduct WHERE ValidityTo is NULL AND ISNULL(tblProduct.LocationId,-1) = ISNULL(@LocationId,-1)
	OPEN PRODUCTLOOPITEMS
	FETCH NEXT FROM PRODUCTLOOPITEMS INTO @ProdID,@RP_G,@RP_OP,@RP_IP,@CI, @Level1  , @SubLevel1 , @Level2  , @SubLevel2  , @Level3  , @SubLevel3 , @Level4 , @SubLevel4
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
		BEGIN
			EXEC  @oReturnValue = [uspRelativeIndexCalculationMonthly] @RelType=@RelTypeG, @startDate=@startDateIP, @endDate=@endDate ,@ProductID=@ProdID, @DistrType='I', @Period=@Period, @AuditUser=@AuditUser, @RelIndex=@IndexIP OUTPUT
			-- if there is no OPdefined then we use index = 1
			IF @RP_OP IS NULL
			BEGIN
				SET @Index = 1.0
				SET @RP_OP = @RP_IP
			END
		END
		IF  @startDateOP IS NOT null
		BEGIN
			EXEC  @oReturnValue = [uspRelativeIndexCalculationMonthly] @RelType=@RelTypeG, @startDate=@startDateOP, @endDate=@endDate ,@ProductID=@ProdID, @DistrType='O', @Period=@Period, @AuditUser=@AuditUser, @RelIndex=@Index OUTPUT
			IF @RP_IP IS NULL
			BEGIN
				SET @IndexIP = 1.0
				SET @RP_IP = @RP_OP
			END
		END
	END
	IF @RP_G is NULL and @RP_OP is NULL AND @RP_IP is NULL
	BEGIN
		SET @RP_G = 'M'
		SET @Index = 1.0
	END
		-- redining date for missing distibuiton
	SET @startDate  = CASE @RP_G WHEN 'M' THEN @startDateMonth WHEN 'Q' THEN @startDateQuarter WHEN 'Y' THEN @startDateYear ELSE NULL END
	SET @startDateIP  = CASE @RP_IP WHEN 'M' THEN @startDateMonth WHEN 'Q' THEN @startDateQuarter WHEN 'Y' THEN @startDateYear ELSE NULL END
	SET @startDateOP  = CASE @RP_OP WHEN 'M' THEN @startDateMonth WHEN 'Q' THEN @startDateQuarter WHEN 'Y' THEN @startDateYear ELSE NULL END


	IF ISNULL(@Index,0) > 0  OR ISNULL(@IndexIP,0) > 0 
		BEGIN
			UPDATE d SET RemuneratedAmount = CAST(
			CASE
			WHEN d.PriceOrigin <> 'R' THEN 1.0
			
				WHEN (CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END) <>'H' THEN @Index  
				ELSE @IndexIP END 
				 as decimal(18, 4))	*  isnull(d.PriceValuated, ISNULL(PriceApproved, PriceAdjusted) * isnull(QtyApproved,QtyProvided)) 
			FROM 	tblClaimItems d 
			INNER JOIN tblClaim  c ON c.ClaimID = d.ClaimID AND (c.ValidityTo IS NULL)
			INNER JOIN tblHF HF ON c.HFID = HF.HfID
			WHERE     (d.ClaimItemStatus = 1)    
			AND (d.ValidityTo IS NULL) 
			AND	(d.ProdID = @ProdID) 
			AND(
				(@startDate is not NULL and (c.ProcessStamp BETWEEN @startDate AND  @endDate)    )
				OR (@startDateIP is not NULL and (c.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND  
					CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END = 'H')
				OR (@startDateOP is not NULL  and (c.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND  
					CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END <> 'H')
			)	AND NOT (HF.HFLevel = ISNULL(@Level1,'A') AND (HF.HFSublevel = ISNULL(@SubLevel1,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level2,'A') AND (HF.HFSublevel = ISNULL(@SubLevel2,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level3,'A') AND (HF.HFSublevel = ISNULL(@SubLevel3,HF.HFSublevel)))
	AND NOT (HF.HFLevel =ISNULL(@Level4,'A') AND (HF.HFSublevel = ISNULL(@SubLevel4,HF.HFSublevel)))

 
			UPDATE d SET RemuneratedAmount = CAST(
			CASE 
			  WHEN d.PriceOrigin <> 'R' THEN 1.0
				
				WHEN (CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END) <>'H' THEN @Index  
				ELSE @IndexIP END 
				 as decimal(18, 4))	*  isnull(d.PriceValuated, ISNULL(PriceApproved, PriceAdjusted) * isnull(QtyApproved,QtyProvided)) 
			FROM 	tblClaimServices d 
			INNER JOIN tblClaim  c ON c.ClaimID = d.ClaimID AND (c.ValidityTo IS NULL)
			INNER JOIN tblHF  HF ON c.HFID = HF.HfID
			WHERE     (d.ClaimServiceStatus = 1)   
			AND (d.ValidityTo IS NULL) 
			AND	(d.ProdID = @ProdID) 
			AND(
				(@startDate is not NULL and (c.ProcessStamp BETWEEN @startDate AND  @endDate)    )
				OR (@startDateIP is not NULL and (c.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND  
					CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END = 'H')
				OR (@startDateOP is not NULL  and (c.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND  
					CASE WHEN  @CI='H' THEN  HF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END <> 'H')
			)	AND NOT (HF.HFLevel = ISNULL(@Level1,'A') AND (HF.HFSublevel = ISNULL(@SubLevel1,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level2,'A') AND (HF.HFSublevel = ISNULL(@SubLevel2,HF.HFSublevel)))
	AND NOT (HF.HFLevel = ISNULL(@Level3,'A') AND (HF.HFSublevel = ISNULL(@SubLevel3,HF.HFSublevel)))
	AND NOT (HF.HFLevel =ISNULL(@Level4,'A') AND (HF.HFSublevel = ISNULL(@SubLevel4,HF.HFSublevel)))

			 
		END


	-- update claim with runid and sum of remunerated amount form items ans services
	UPDATE c SET RunID = @RunID ,  ClaimStatus = 16, Remunerated = CDetails.RemuneratedAmount
	FROM  tblClaim c
	INNER JOIN (
	SELECT SUM(tolal.RemuneratedAmount) RemuneratedAmount, claimID FROM 
	       (SELECT c.ClaimID, ISNULL(RemuneratedAmount,0) RemuneratedAmount
			FROM 	tblClaimServices d 
			INNER JOIN tblClaim  c ON c.ClaimID = d.ClaimID AND (c.ValidityTo IS NULL)
			INNER JOIN tblHF ON c.HFID = tblHF.HfID
			WHERE     (d.ClaimServiceStatus = 1)   
			AND (d.ValidityTo IS NULL) 
			AND	(d.ProdID = @ProdID)
			AND( (@startDate is not NULL and (c.ProcessStamp BETWEEN @startDate AND  @endDate)    )
			OR (@startDateIP is not NULL and (c.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND  
				CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END = 'H')
			OR (@startDateOP is not NULL and (c.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND  
				CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END <> 'H')
			)	
			UNION ALL
			SELECT c.ClaimID, ISNULL(RemuneratedAmount,0) RemuneratedAmount
			FROM 	tblClaimItems d 
			INNER JOIN tblClaim  c ON c.ClaimID = d.ClaimID AND (c.ValidityTo IS NULL)
			INNER JOIN tblHF ON c.HFID = tblHF.HfID
			WHERE     (d.ClaimItemStatus = 1)    
			AND (d.ValidityTo IS NULL) 
			AND	(d.ProdID = @ProdID) 
			AND(
			(@startDate is not NULL and (c.ProcessStamp BETWEEN @startDate AND  @endDate)    )
			OR (@startDateIP is not NULL and (c.ProcessStamp BETWEEN @startDateIP AND  @endDate) AND  
				CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END = 'H')
			OR (@startDateOP is not NULL and (c.ProcessStamp BETWEEN @startDateOP AND  @endDate) AND  
				CASE WHEN  @CI='H' THEN  tblHF.HFLevel WHEN DATEDIFF(d,c.DateFrom,ISNULL(c.DateTo,c.DateFrom))<1 THEN 'D' ELSE 'H' END <> 'H')
			)		
			) as tolal GROUP BY claimID
	) as CDetails on c.ClaimID = CDetails.ClaimID
	
NextProdItems:
		FETCH NEXT FROM PRODUCTLOOPITEMS INTO @ProdID,@RP_G,@RP_OP,@RP_IP,@CI, @Level1  , @SubLevel1 , @Level2  , @SubLevel2  , @Level3  , @SubLevel3 , @Level4 , @SubLevel4
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
GO
