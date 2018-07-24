USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspSSRSPaymentCategoryOverview]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspSSRSPaymentCategoryOverview]
(
	@DateFrom DATE,
	@DateTo DATE,
	@LocationId INT = 0,
	@ProductId INT= 0
)
AS
BEGIN	
DECLARE @tbl TABLE(PolicyId INT,ProdId INT,PayDate DATE,Amount DECIMAL(18,2),PayType CHAR(1))

	DECLARE @FamilyId INT,
			@PremiumId INT,
			@ProdId INT,
			@PolicyId INT,
			@TotalAmount DECIMAL(18,2) = 0,
			@Amount DECIMAL(18,2) = 0,
			@TotalMembers INT,
			@AssemblyLumpSum DECIMAL(18,2),
			@RegistrationLumpSum DECIMAL(18,2),
			@AssemblyFee DECIMAL(18,2),
			@RegistrationFee DECIMAL(18,2),
			@Contribution DECIMAL(18,2),
			@Assembly DECIMAL(18,2),
			@Registration DECIMAL(18,2),
			@PayDate DATE,
			@Balance DECIMAL(18,2) = 0,
			@isAssembly BIT,
			@isRegistration BIT,
			@PayType CHAR(1)

	DECLARE Cur CURSOR FOR
		SELECT PL.PolicyID,PL.ProdId, PR.PayType
		FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
		WHERE PR.ValidityTo IS NULL AND PL.ValidityTo IS NULL
		AND PR.isPhotoFee = 0
		AND PL.PolicyID IN 
			(SELECT PolicyID FROM tblPremium WHERE ValidityTo IS NULL AND PayDate BETWEEN @DateFrom AND @DateTo)
		GROUP BY PL.PolicyId,PL.ProdId, PR.PayType
		


	OPEN Cur
	FETCH NEXT FROM Cur INTO @PolicyId,@ProdId, @PayType
	WHILE @@FETCH_STATUS = 0
		BEGIN

			SET @Assembly = 0;
			SET @Registration = 0;

			SET @TotalMembers = (SELECT COUNT(*) FROM tblInsureePolicy WHERE ValidityTo IS NULL AND PolicyId = @PolicyId)
			--SET @TotalAmount = (SELECT SUM(Amount) FROM tblPremium WHERE ValidityTo IS NULL AND isPhotoFee = 0 AND PolicyID = @PolicyId)
			SELECT @AssemblyLumpSum = ISNULL(GeneralAssemblyLumpSum,0),@AssemblyFee = ISNULL(GeneralAssemblyFee,0), @RegistrationLumpSum = ISNULL(RegistrationLumpSum,0),@RegistrationFee = ISNULL(RegistrationFee,0) FROM tblProduct WHERE ProdID = @ProdId
			
			--GET Assembly Info from product
			IF @PayType <> 'F'
				IF @AssemblyLumpSum > 0 
					SET @Assembly = @AssemblyLumpSum
				ELSE
					SET @Assembly = @AssemblyFee * @TotalMembers
				
			--Get Registration info from product
			IF @PayType <> 'F'
				IF @RegistrationLumpSum > 0 
					SET @Registration = @RegistrationLumpSum
				ELSE
					SET @Registration = @RegistrationFee * @TotalMembers 		

			--Open New cursor to get all the payments
			DECLARE CurPayHist CURSOR FOR
				SELECT PayDate,SUM(Amount)Amount FROM tblPremium WHERE ValidityTo IS NULL AND PolicyID = @PolicyId AND isPhotoFee = 0 GROUP BY PayDate ORDER BY PayDate
			
			SET @Balance = @Registration
			
			DECLARE @StartAssembly BIT = 0,
					@StartRegistration BIT = 1,
					@StartContribution BIT = 0
					
			
			OPEN CurPayHist
			FETCH NEXT FROM CurPayHist INTO @PayDate,@TotalAmount
			WHILE @@FETCH_STATUS = 0
			BEGIN
				
				
				IF @StartRegistration = 1
					BEGIN
						IF @TotalAmount - @Balance >= 0 
							BEGIN
								SET @Amount = @Balance
								SET @StartAssembly = 1
								SET @StartRegistration = 0
								SET @StartContribution = 0
								SET @TotalAmount = @TotalAmount - @Balance
								SET @Balance = @Assembly
							END
						ELSE
							BEGIN
								SET @Amount = @TotalAmount
								SET @Balance = @Balance - @Amount
							END
						
						INSERT INTO @tbl(PolicyId,ProdId,PayDate,Amount,PayType)
							SELECT @PolicyId,@ProdId,@PayDate, @Amount, 'R'
						
					END
				
				--Insert Assembly
				 			
				--WHILE @Balance > 0
				--BEGIN 
					IF @StartAssembly = 1 AND @TotalAmount > 0
					BEGIN
						IF @TotalAmount - @Balance >= 0
							BEGIN
								
								SET @Amount = @Balance
								SET @StartAssembly = 0
								SET @StartRegistration = 0
								SET @StartContribution = 1
								SET @TotalAmount = @TotalAmount - @Balance
							END
							
						ELSE
							BEGIN
								SET @Amount = @TotalAmount
								SET @Balance = @Balance - @Amount
							END
							
						INSERT INTO @tbl(PolicyId,ProdId,PayDate,Amount,PayType)
							SELECT @PolicyId,@ProdId,@PayDate, @Amount, 'A'
						
						
					END
					
					IF @StartContribution = 1
						INSERT INTO @tbl(PolicyId,ProdId,PayDate,Amount,PayType)
							SELECT @PolicyId,@ProdId,@PayDate, @TotalAmount , 'C'
							
										
				FETCH NEXT FROM CurPayHist INTO @PayDate,@TotalAmount
				--SET @Amount = @TotalAmount
			END
			CLOSE CurPayHist
			DEALLOCATE CurPayHist
					
			FETCH NEXT FROM Cur INTO @PolicyId,@ProdId, @PayType
		END
	CLOSE Cur 
	DEALLOCATE Cur 


	

	SELECT PivotResult.ProdID,PivotResult.ProductCode,PivotResult.ProductName,PivotResult.DistrictName,PivotResult.R,PivotResult.A,PivotResult.C,PivotResult.P 
	FROM
	(
	SELECT Prod.ProdID,Prod.ProductCode,Prod.ProductName,temp.PayType,L.DistrictName,SUM(Amount)Amount
	FROM @tbl temp INNER JOIN tblPolicy PL ON temp.PolicyId = PL.PolicyID
	INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
	INNER JOIN tblProduct Prod ON temp.ProdId = Prod.ProdID
	--INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	--INNER JOIN tblWards W ON W.WardId = V.WardId
	--INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN uvwLocations L ON L.VillageId = F.LocationId
	WHERE F.ValidityTo IS NULL
	AND temp.PayDate BETWEEN @DateFrom AND @DateTo
	AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR @LocationId = 0)
	AND (PL.ProdID = @ProductId OR @ProductId = 0)
	GROUP BY Prod.ProdID,Prod.ProductCode,Prod.ProductName,temp.PayType,L.DistrictName
	UNION ALL
	SELECT Prod.ProdID,Prod.ProductCode,Prod.ProductName,'P'PayType,L.DistrictName,SUM(Amount)Amount
	FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
	INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyId
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	--INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	--INNER JOIN tblWards W ON W.WardId = V.WardId
	--INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN uvwLocations L ON L.LocationId = F.LocationId
	WHERE PR.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL AND F.ValidityTo IS NULL
	AND PR.PayDate BETWEEN @DateFrom AND @DateTo
	AND PR.isPhotoFee = 1
	AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR @LocationId = 0)
	AND (PL.ProdID = @ProductId OR @ProductId = 0)
	GROUP BY Prod.ProdID,Prod.ProductCode,Prod.ProductName,PayType,L.DistrictName
	)Base
	PIVOT
	(SUM(Amount) FOR Base.PayType IN (R,A,C,P)) AS PivotResult

 END

GO
