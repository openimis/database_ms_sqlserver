IF OBJECT_ID('uspSSRSPremiumDistribution', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSPremiumDistribution
GO

CREATE PROCEDURE [dbo].[uspSSRSPremiumDistribution]
	(
		@Month INT,
		@Year INT,
		@LocationId INT = 0,
		@ProductID INT = 0
	)
	AS
	BEGIN
		IF NOT OBJECT_ID('tempdb..#tmpResult') IS NULL DROP TABLE #tmpResult
	
		CREATE TABLE #tmpResult(
			MonthID INT,
			DistrictName NVARCHAR(50),
			ProductCode NVARCHAR(8),
			ProductName NVARCHAR(100),
			TotalCollected DECIMAL(18,4),
			NotAllocated DECIMAL(18,4),
			Allocated DECIMAL(18,4)
		)

		DECLARE @Date DATE,
				@DaysInMonth INT,
				@Counter INT = 1,
				@MaxCount INT = 12,
				@EndDate DATE

		IF @Month > 0
		BEGIN
			SET @Counter = @Month
			SET @MaxCount = @Month
		END

		IF @LocationId = -1
		SET @LocationId = NULL

		WHILE @Counter <> @MaxCount + 1
		BEGIN	
			SELECT @Date = CAST(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Counter AS VARCHAR(2)) + '-' + '01' AS DATE)
			SELECT @DaysInMonth = DATEDIFF(DAY,@Date,DATEADD(MONTH,1,@Date))
			SELECT @EndDate = CAST(CONVERT(VARCHAR(4),@Year) + '-' + CONVERT(VARCHAR(2),@Counter) + '-' + CONVERT(VARCHAR(2),@DaysInMonth) AS DATE)
				
			
			;WITH Locations AS
			(
				SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId
				UNION
				SELECT LocationId,LocationName, ISNULL(ParentLocationId, 0) FROM tblLocations WHERE ValidityTo IS NULL AND LocationId = @LocationId
				UNION ALL
				SELECT L.LocationId, L.LocationName, L.ParentLocationId 
				FROM tblLocations L 
				INNER JOIN Locations ON Locations.LocationId = L.ParentLocationId
				WHERE L.validityTo IS NULL
				AND L.LocationType IN ('R', 'D')
			)
			INSERT INTO #tmpResult
			SELECT MonthId,DistrictName,ProductCode,ProductName,SUM(ISNULL(TotalCollected,0))TotalCollected,SUM(ISNULL(NotAllocated,0))NotAllocated,SUM(ISNULL(Allocated,0))Allocated
			FROM 
			(
			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			SUM(PR.Amount) TotalCollected,
			0 NotAllocated,
			0 Allocated
			FROM tblPremium PR 
			RIGHT OUTER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations L ON  ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL
			AND PL.ValidityTo IS NULL
			AND Prod.ValidityTo IS NULL
			AND PL.PolicyStatus <> 1
			AND (Prod.ProdId = @ProductId OR @ProductId IS NULL)
			AND MONTH(PR.PayDate) = @Counter
			AND YEAR(PR.PayDate) = @Year
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate

			UNION ALL

			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			0 TotalCollected,
			SUM(PR.Amount) NotAllocated,
			0 Allocated
			FROM tblPremium AS PR INNER JOIN tblPolicy AS PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct AS Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations AS L ON ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL
			AND (MONTH(PR.PayDate ) = @Counter) 
			AND (YEAR(PR.PayDate) = @Year) 
			AND (Prod.ProdId = @ProductId OR @ProductId IS NULL) 
			AND (PL.PolicyStatus = 1)
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate

			UNION ALL

			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			0 TotalCollected,
			SUM(PR.Amount) NotAllocated,
			0 Allocated
			FROM tblPremium AS PR INNER JOIN tblPolicy AS PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct AS Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations AS L ON ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL
			AND (MONTH(PR.PayDate ) = @Counter) 
			AND (YEAR(PR.PayDate) = @Year) 
			AND (Prod.ProdId = @ProductId OR @ProductId IS NULL) 
			AND (PR.PayDate > PL.ExpiryDate)
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate

			UNION ALL

			SELECT @Counter MonthId,L.LocationName DistrictName,Prod.ProductCode,Prod.ProductName,
			0 TotalCollected,
			0 NotAllocated,
			CASE 
			WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Counter AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
			THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
			WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Counter AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
			THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
			WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
			THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
			END Allocated
			FROM tblPremium PR 
			INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId
			WHERE PR.ValidityTo IS NULL
			AND PL.ValidityTo IS NULL
			AND Prod.ValidityTo IS  NULL
			AND Prod.ProdID = @ProductID
			AND PL.PolicyStatus <> 1
			AND PR.PayDate <= PL.ExpiryDate
			GROUP BY L.LocationName,Prod.ProductCode,Prod.ProductName,PR.Amount,PR.PayDate,PL.ExpiryDate,PL.EffectiveDate
			)PremiumDistribution
			GROUP BY MonthId,DistrictName,ProductCode,ProductName		
			SET @Counter = @Counter + 1	
		END
		SELECT MonthId, DistrictName,ProductCode,ProductName,TotalCollected,NotAllocated,Allocated FROM #tmpResult
	END
GO