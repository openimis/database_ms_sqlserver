
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfAPIisValidMaritalStatus](
	@MaritalStatusCode NVARCHAR(1)
)

RETURNS BIT
AS
BEGIN
		DECLARE @tblMaritalStatus TABLE(MaritalStatusCode NVARCHAR(1))
		DECLARE @isValid BIT
		INSERT INTO @tblMaritalStatus(MaritalStatusCode) 
		VALUES ('N'),('W'),('S'),('D'),('M'),(NULL)

		IF EXISTS(SELECT 1 FROM @tblMaritalStatus WHERE MaritalStatusCode = @MaritalStatusCode)
			SET @isValid = 1
		ELSE 
			SET @isValid = 0

      RETURN(@isValid)
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[CREATE FUNCTION]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product Base, 2:Officer Mode
)
RETURNS @Result TABLE(ProdId INT, Allocated FLOAT,Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
	DECLARE @Date DATE,
		@DaysInMonth INT,
		@EndDate DATE

	SELECT @Date = CAST(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-' + '01' AS DATE)
	SELECT @DaysInMonth = DATEDIFF(DAY,@Date,DATEADD(MONTH,1,@Date))
	SELECT @EndDate = CAST(CONVERT(VARCHAR(4),@Year) + '-' + CONVERT(VARCHAR(2),@Month) + '-' + CONVERT(VARCHAR(2),@DaysInMonth) AS DATE)


	IF @Mode = 1
		BEGIN

			;WITH Allocation AS
			(
				SELECT PL.ProdID,
				CASE 
				WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
					THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
				WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
					THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
				WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
					THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
				END Allocated
				FROM tblPremium PR 
				INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
				INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
				INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
				INNER JOIN tblWards W ON W.WardId = V.WardId
				INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
				WHERE PR.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL
				AND PL.ProdID = @ProdId
				AND PL.PolicyStatus <> 1
				AND PR.PayDate <= PL.ExpiryDate
				AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
				GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate
			)
			INSERT INTO @Result(ProdId,Allocated)
			SELECT ProdId, ISNULL(SUM(Allocated), 0)Allocated
			FROM Allocation
			GROUP BY ProdId
		END
	ELSE IF @Mode = 2
		BEGIN
			;WITH Allocation AS
			(
				SELECT PL.ProdID,
				CASE 
				WHEN MONTH(DATEADD(D,-1,PL.ExpiryDate)) = @Month AND YEAR(DATEADD(D,-1,PL.ExpiryDate)) = @Year AND (DAY(PL.ExpiryDate)) > 1
					THEN CASE WHEN DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) = 0 THEN 1 ELSE DATEDIFF(D,CASE WHEN PR.PayDate < @Date THEN @Date ELSE PR.PayDate END,PL.ExpiryDate) END  * ((SUM(PR.Amount))/(CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate)) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END))
				WHEN MONTH(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Month AND YEAR(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END) = @Year
					THEN ((@DaysInMonth + 1 - DAY(CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END)) * ((SUM(PR.Amount))/CASE WHEN DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)) 
				WHEN PL.EffectiveDate < @Date AND PL.ExpiryDate > @EndDate AND PR.PayDate < @Date
					THEN @DaysInMonth * (SUM(PR.Amount)/CASE WHEN (DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,DATEADD(D,-1,PL.ExpiryDate))) <= 0 THEN 1 ELSE DATEDIFF(DAY,CASE WHEN PR.PayDate < PL.EffectiveDate THEN PL.EffectiveDate ELSE PR.PayDate END,PL.ExpiryDate) END)
				END Allocated,
				O.Code, O.LastName, O.OtherNames
				FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
				INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
				INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
				INNER JOIN tblWards W ON W.WardId = V.WardId
				INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
				INNER JOIN tblOfficer O ON PL.OfficerId = O.OfficerID
				WHERE PR.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL
				AND O.ValidityTo IS NULL
				AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
				AND PL.PolicyStatus <> 1
				AND PR.PayDate <= PL.ExpiryDate
				GROUP BY PL.ProdID, PL.ExpiryDate, PR.PayDate,PL.EffectiveDate, O.Code, O.LastName, O.OtherNames
			)
			INSERT INTO @Result(ProdId,Allocated,Officer,LastName,OtherNames)
			SELECT ProdId, ISNULL(SUM(Allocated), 0)Allocated, Code, LastName, OtherNames
			FROM Allocation
			GROUP BY ProdId, Code, LastName, OtherNames
		END
	RETURN
END	
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


	
CREATE FUNCTION [dbo].[udfCollectedContribution](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS DECIMAL(18,2)
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
	  SELECT SUM(Amount)  FROM tblPremium PR
INNER JOIN tblPolicy PL ON PL.PolicyID=PR.PolicyID
INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
WHERE 
PL.ValidityTo IS NULL
AND PR.ValidityTo IS NULL
AND PayDate >= @DateFrom
AND PayDate <=@DateTo

	  )
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfExpiredPolicies]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product base, 2: Officer Base
)
RETURNS @Resul TABLE(ProdId INT, ExpiredPolicies INT, Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Resul(ProdId,ExpiredPolicies)
	SELECT PL.ProdID, COUNT(PL.PolicyID) ExpiredPolicies
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE PL.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus >1  --Uncommented By Rogers for PrimaryIndicator1 Report
	AND MONTH(PL.ExpiryDate) = @Month AND YEAR(PL.ExpiryDate) = @Year
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID
ELSE IF @Mode = 2
	INSERT INTO @Resul(ProdId,ExpiredPolicies,Officer,LastName,OtherNames)
	SELECT PL.ProdID, COUNT(PL.PolicyID) ExpiredPolicies,O.Code,O.LastName,O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	WHERE PL.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus >1  --Uncommented By Rogers for PrimaryIndicator1 Report
	AND MONTH(PL.ExpiryDate) = @Month AND YEAR(PL.ExpiryDate) = @Year
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID,O.Code,O.LastName,O.OtherNames
	
RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[udfExpiredPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
			SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID OR(PL.ProdID = PR.ConversionProdID )
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate >= @DateFrom AND PL.ExpiryDate < = @DateTo)
			
	  )
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE FUNCTION [dbo].[udfGetSnapshotIndicators](
	@Date DATE, 
	@OfficerId INT
) RETURNS @tblSnapshotIndicators TABLE(ACtive INT,Expired INT,Idle INT,Suspended INT)
	AS
	BEGIN
		DECLARE @ACtive INT=0
		DECLARE @Expired INT=0
		DECLARE @Idle INT=0
		DECLARE @Suspended INT=0
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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


		SET @ACtive = (
						SELECT COUNT(DISTINCT P.FamilyID) ActivePolicies FROM tblPolicy P 
						INNER JOIN @tblOfficerSub O ON P.OfficerID = O.NewOfficer
						WHERE P.ValidityTo IS NULL AND PolicyStatus = 2 
						AND ExpiryDate >=@Date
					  )

		SET @Expired = (SELECT COUNT(1) ExpiredPolicies
			FROM tblPolicy PL
			LEFT OUTER JOIN (SELECT PL.PolicyID, F.FamilyID, PR.ProdID
			FROM tblPolicy PL 
			INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
			INNER JOIN tblProduct PR ON PR.ProdID= PL.ProdID OR (PL.ProdID = PR.ConversionProdID)
			WHERE 
			PL.ValidityTo IS NULL 
			AND F.ValidityTo IS NULL
			AND PR.ValidityTo IS NULL
			AND PL.PolicyStage='R'
			AND  PL.PolicyStatus = 2
			) R ON PL.ProdID=R.ProdID AND PL.FamilyID=R.FamilyID
			INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
			WHERE
			PL.ValidityTo IS NULL
			AND PL.PolicyStatus = 8
			AND R.PolicyID IS NULL
			AND (PL.ExpiryDate =@Date)
			)
		SET @Idle =		(
						SELECT COUNT(DISTINCT PL.FamilyID) IddlePolicies FROM tblPolicy PL 
						INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
						INNER JOIN tblProduct PR ON PR.ProdID = PL.ProdID
						LEFT OUTER JOIN (SELECT FamilyID, ProdID FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyStatus =2 AND  ExpiryDate >=@Date) ActivePolicies ON ActivePolicies.FamilyID = PL.FamilyID AND (ActivePolicies.ProdID = PL.ProdID OR ActivePolicies.ProdID = PR.ConversionProdID)
						WHERE PL.ValidityTo IS NULL AND PL.PolicyStatus = 1 
						AND ExpiryDate >=@Date
						AND ActivePolicies.ProdID IS NULL
						)
		SET @Suspended = (
						SELECT COUNT(DISTINCT PL.FamilyID) SuspendedPolicies FROM tblPolicy PL 
						INNER JOIN @tblOfficerSub O ON PL.OfficerID = O.NewOfficer
						INNER JOIN tblProduct PR ON PR.ProdID = PL.ProdID
						LEFT OUTER JOIN (SELECT FamilyID, ProdID FROM tblPolicy WHERE ValidityTo IS NULL AND PolicyStatus =2 AND  ExpiryDate >=@Date) ActivePolicies ON ActivePolicies.FamilyID = PL.FamilyID AND (ActivePolicies.ProdID = PL.ProdID OR ActivePolicies.ProdID = PR.ConversionProdID)
						WHERE PL.ValidityTo IS NULL AND PL.PolicyStatus = 4
						AND ExpiryDate >=@Date
						AND ActivePolicies.ProdID IS NULL
						)
		INSERT INTO @tblSnapshotIndicators(ACtive, Expired, Idle, Suspended) VALUES (@ACtive, @Expired, @Idle, @Suspended)
		  RETURN
	END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfNewlyPremiumCollected]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product Base, 2:Officer Base
)
RETURNS @Result TABLE(ProdId INT, PremiumCollection FLOAT,Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,PremiumCollection)	
	SELECT PL.ProdID,SUM(PR.Amount)PremiumCollection
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	LEFT OUTER JOIN tblPremium PR ON PL.PolicyID = PR.PolicyID 
	WHERE PR.ValidityTo IS NULL
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PR.PayDate) = @Month AND YEAR(PR.PayDate) = @Year
	GROUP BY PL.ProdID
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,PremiumCollection,Officer,LastName,OtherNames)
	SELECT PL.ProdID,SUM(PR.Amount)PremiumCollection,O.Code,O.LastName,O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	LEFT OUTER JOIN tblPremium PR ON PL.PolicyID = PR.PolicyID 
	WHERE PR.ValidityTo IS NULL
	AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND (D.Region = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PR.PayDate) = @Month AND YEAR(PR.PayDate) = @Year
	GROUP BY PL.ProdID,O.Code,O.LastName,O.OtherNames
	
RETURN
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfNewPolicies]
(
	@ProdID INT,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1: Product Base, 2: Enrollment Officer Base
)
RETURNS @Result TABLE(ProdId INT, Male INT,Female INT,Other INT, Officer VARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female,Other)
	SELECT ProdId, M Male, F Female, O Other
	FROM
	(SELECT PL.ProdId, I.Gender, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.InsureeId = Fam.InsureeID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt
	
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female,Other,Officer,LastName,OtherNames)
	SELECT ProdId, M Male, F Female, O Other, Officer, LastName, OtherNames
FROM
	(SELECT PL.ProdId, I.Gender, O.Code Officer, O.LastName, O.OtherNames, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.InsureeId = Fam.InsureeID
	INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND O.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt
	
	RETURN
END	
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfNewPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
	
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
	  SELECT COUNT(1)  
	  FROM 
	  tblPolicy PL
	  INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
	  WHERE PL.ValidityTo IS NULL  AND PolicyStage ='N' AND EnrollDate >= @DateFrom AND EnrollDate <=@DateTo
	  )
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfNewPolicyInsuree]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product base 2: Officer Base
)
RETURNS @Result TABLE(ProdId INT, Male INT, Female INT,Other INT, Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female,Other)	
	SELECT ProdId, M Male, F Female, O Other
	FROM
	(SELECT PL.ProdId, I.Gender, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.FamilyID = Fam.FamilyID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt

ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female,Other,Officer,LastName,OtherNames)
	SELECT ProdId, M Male, F Female, O Other, Officer, LastName, OtherNames
FROM
	(SELECT PL.ProdId, I.Gender, O.Code Officer, O.LastName, O.OtherNames, I.InsureeId
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	INNER JOIN tblInsuree I ON I.FamilyID = Fam.FamilyID
	INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND R.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND O.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'N'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (R.RegionId = @LocationId OR D.DistrictId = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	) NewPolicies
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN (M, F, O)
	)pvt
RETURN
END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfPolicyInsuree]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@LastDay DATE,
	@Mode INT	--1: Product Base 2: Officer Base
)
RETURNS @Result TABLE(ProdId INT, Male INT, Female INT, Other INT,Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female, Other)	
	SELECT ProdId, [M], [F], [O]
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.FamilyId = Fam.FamilyId
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicyInsurees
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female, Other,Officer,LastName,OtherNames)
	SELECT ProdId, [M], [F], [O], Officer, LastName, OtherNames
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID, O.Code Officer, O.LastName, O.OtherNames
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.FamilyId = Fam.FamilyId
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicyInsurees
	
RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfPolicyRenewal]
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT,
	@Mode INT	--1: Product Base, 2:Officer Base
)
RETURNS @Result TABLE(ProdId INT, Renewals INT, Officer NVARCHAR(50),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Renewals)
	SELECT PL.ProdId, COUNT(PL.PolicyId)Renewals
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'R'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (D.DistrictId = @LocationId OR D.Region = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	GROUP BY PL.ProdID

ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Renewals,Officer,LastName,OtherNames)
	SELECT PL.ProdId, COUNT(PL.PolicyId)Renewals, O.Code Officer, O.LastName, O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies Fam ON PL.FamilyID = Fam.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = Fam.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerId

	WHERE PL.ValidityTo IS NULL
	AND Fam.ValidityTo IS NULL
	AND PL.PolicyStatus > 1
	AND PL.PolicyStage = N'R'
	AND (PL.ProdId = @ProdID OR @ProdID = 0)
	AND (D.DistrictId = @LocationId OR D.Region = @LocationId OR @LocationId = 0)
	AND MONTH(PL.EnrollDate) = @Month
	AND YEAR(PL.EnrollDate) = @Year
	GROUP BY PL.ProdID, O.Code , O.LastName, O.OtherNames
	RETURN
	
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE FUNCTION [dbo].[udfPremiumComposition]
(	
	
)


RETURNS @Resul TABLE(PolicyId INT, AssFee DECIMAL(18,2),RegFee DECIMAL(18,2),PremFee DECIMAL(18,2) )
AS
BEGIN

	INSERT INTO @Resul(PolicyId,AssFee,RegFee,PremFee)
	SELECT tblPolicy.PolicyID, CASE WHEN ISNULL(tblProduct.GeneralAssemblyLumpSum,0) = 0 THEN  (COUNT(tblInsureePolicy.InsureeId) * ISNULL(tblProduct.GeneralAssemblyFee,0)) ELSE tblProduct.GeneralAssemblyLumpSum  END  as AssFee, CASE WHEN tblPolicy.PolicyStage = 'N' THEN (CASE WHEN ISNULL(tblProduct.RegistrationLumpSum ,0) = 0 THEN COUNT(tblInsureePolicy.InsureeId) * isnull(tblProduct.RegistrationFee,0) ELSE tblProduct.RegistrationLumpSum END) ELSE 0 END as RegFee, CASE WHEN ISNULL(tblProduct.LumpSum,0) = 0 THEN ( SUM (CASE WHEN (DATEDIFF(YY  ,tblInsuree.DOB,tblInsureePolicy.EffectiveDate) >= 18) THEN 1 ELSE 0 END) * tblProduct.PremiumAdult)  + ( SUM (CASE WHEN (DATEDIFF(YY  ,tblInsuree.DOB,tblInsureePolicy.EffectiveDate) < 18) THEN 1 ELSE 0 END) * tblProduct.PremiumChild ) ELSE tblproduct.LumpSum  END as PremFee
	
	FROM         tblPolicy INNER JOIN
						  tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId INNER JOIN
						  tblInsuree ON tblInsureePolicy.InsureeId = tblInsuree.InsureeID INNER JOIN tblProduct ON tblProduct.ProdID = tblPolicy.ProdID 
	WHERE     (tblInsureePolicy.ValidityTo IS NULL) AND (tblPolicy.ValidityTo IS NULL) AND (tblInsuree.ValidityTo IS NULL) AND tblInsureePolicy.EffectiveDate IS NOT NULL and tblProduct.ValidityTo is null
	GROUP BY tblPolicy.PolicyID, tblProduct.GeneralAssemblyFee , tblProduct.GeneralAssemblyLumpSum , tblProduct .RegistrationFee, tblProduct .RegistrationLumpSum   ,tblProduct .LumpSum , tblProduct .PremiumAdult ,tblProduct .PremiumChild ,tblPolicy.PolicyStage

	

RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[udfRenewedPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
	  SELECT COUNT(1)  FROM 
	  tblPolicy PL
	  INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
	  WHERE 
	  ValidityTo IS NULL AND PolicyStage ='R' AND EnrollDate >= @DateFrom AND EnrollDate <=@DateTo
	  )
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfSuspendedPolicies]
(
	@ProdID INT = 0,
	@LocationId INT ,
	@Month INT,
	@Year INT,
	@Mode INT	--1:Product base 2: Officer Base
)
RETURNS @Result TABLE(ProdId INT,SuspendedPolicies INT,Officer NVARCHAR(50),LastName NVARCHAR(50), OtherNames NVARCHAR(50))
AS
BEGIN

IF @Mode = 1
	INSERT INTO @Result(ProdId,SuspendedPolicies)
	SELECT  PL.ProdID,COUNT(PL.PolicyID)SuspendedPolicies
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	
	WHERE PL.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus = 4
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND MONTH(PL.ValidityFrom) = @Month AND YEAR(PL.ValidityFrom) = @Year 
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID
ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,SuspendedPolicies,Officer,LastName,OtherNames)
	SELECT  PL.ProdID,COUNT(PL.PolicyID)SuspendedPolicies,O.Code,O.LastName,O.OtherNames
	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON F.FamilyId = PL.FamilyId
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardId
	INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	WHERE PL.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND PL.PolicyStatus = 4
	AND (PL.ProdID = @ProdID OR @ProdID = 0)
	AND MONTH(PL.ValidityFrom) = @Month AND YEAR(PL.ValidityFrom) = @Year 
	AND (D.Region = @LocationId OR D.DistrictId= @LocationId OR @LocationId = 0)
	GROUP BY PL.ProdID,O.Code,O.LastName,O.OtherNames
	
RETURN
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfSuspendedPoliciesPhoneStatistics](
	@DateFrom DATE, 
	@DateTo DATE, 
	@OfficerId INT
)

RETURNS INT
AS
BEGIN
		DECLARE @LegacyOfficer INT
		DECLARE @tblOfficerSub TABLE(OldOfficer INT, NewOfficer INT)

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

      RETURN(
		SELECT  COUNT(1) SuspendedPolicies
		FROM tblPolicy PL 
		INNER JOIN @tblOfficerSub O ON O.NewOfficer = PL.OfficerID
		WHERE PL.ValidityTo IS NULL
		AND PL.PolicyStatus = 4
		AND (ExpiryDate >= @DateFrom AND ExpiryDate < = @DateTo)
		
	  )
END



GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfTotalPolicies] 
(
	@ProdID INT = 0,
	@LocationId INT = 0,
	@LastDay DATE,
	@Mode INT	--1: ON Product, 2: On Officer
)
RETURNS @Result TABLE(ProdId INT, Male INT,Female INT, Other INT, Officer NVARCHAR(8),LastName NVARCHAR(50),OtherNames NVARCHAR(50))
AS
BEGIN
IF @Mode = 1
	INSERT INTO @Result(ProdId,Male,Female, Other)
	SELECT ProdId, [M], [F], [O]
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.InsureeId = Fam.InsureeID
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0 OR @LocationId = 0) --@LocationId = 0 Added to get Country data
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicies

ELSE IF @Mode = 2
	INSERT INTO @Result(ProdId,Male,Female, Other,Officer,LastName,OtherNames)
	SELECT ProdId, [M], [F], [O], Officer, LastName, OtherNames
	FROM
	(
		SELECT Prod.ProdID, Ins.Gender, Ins.InsureeID, O.Code Officer, O.LastName, O.OtherNames
		FROM tblPolicy PL 
		INNER JOIN tblProduct Prod ON Prod.ProdId = PL.ProdID
		INNER JOIN tblOfficer O ON O.OfficerId = PL.OfficerID
		INNER JOIN tblFamilies Fam ON Fam.FamilyId = PL.FamilyID
		INNER JOIN tblInsuree Ins ON Ins.InsureeId = Fam.InsureeID
		INNER JOIN uvwLocations L ON L.VillageId = Fam.LocationId

		WHERE PL.ValidityTo IS NULL
		AND Prod.ValidityTo IS NULL
		AND Fam.ValidityTo IS NULL
		AND Ins.ValidityTo IS NULL
		AND PL.PolicyStatus > 1
		AND PL.EffectiveDate <= @LastDay
		AND PL.ExpiryDate >  @LastDay
		AND (Prod.ProdId = @ProdId OR @ProdId = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0 OR @LocationId = 0)
	)Base
	PIVOT
	(
		COUNT(InsureeId) FOR Gender IN ([M], [F], [O])
	)TotalPolicies
	
	RETURN
	
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dw].[udfNumberOfCurrentInsuree]()
RETURNS @Result TABLE(NumberOfCurrentInsuree INT, MonthTime INT, QuarterTime INT, YearTime INT, Age INT, Gender CHAR(1),Region NVARCHAR(20), InsureeDistrictName NVARCHAR(50), WardName NVARCHAR(50), VillageName NVARCHAR(50), ProdDistrictName NVARCHAR(50), ProductCode NVARCHAR(15), ProductName NVARCHAR(100), OfficeDistrict NVARCHAR(20), OfficerCode NVARCHAR(15), LastName NVARCHAR(100), OtherNames NVARCHAR(100), ProdRegion NVARCHAR(50))
AS
BEGIN

	DECLARE @StartDate DATE --= (SELECT MIN(EffectiveDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @EndDate DATE --= (SELECT Max(ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @LastDate DATE

	SET @StartDate = '2011-01-01'
	SET @EndDate = DATEADD(YEAR,3,GETDATE())

	DECLARE @tblLastDays TABLE(LastDate DATE)

	WHILE @StartDate <= @EndDate
	BEGIN
	SET @LastDate = DATEADD(DAY,-1,DATEADD(MONTH,DATEDIFF(MONTH,0,@StartDate) + 1,0));
	SET @StartDate = DATEADD(MONTH,1,@StartDate);
	INSERT INTO @tblLastDays(LastDate) VALUES(@LastDate)
	END

	INSERT INTO @Result(NumberOfCurrentInsuree,MonthTime,QuarterTime,YearTime,Age,Gender,Region,InsureeDistrictName,WardName,VillageName,
	ProdDistrictName,ProductCode,ProductName, OfficeDistrict, OfficerCode,LastName,OtherNames, ProdRegion)

	SELECT COUNT(I.InsureeID)NumberOfCurrentInsuree,MONTH(LD.LastDate)MonthTime,DATENAME(Q,LastDate)QuarterTime,YEAR(LD.LastDate)YearTime,
	DATEDIFF(YEAR,I.DOB,GETDATE()) Age,CAST(I.Gender AS VARCHAR(1)) Gender,R.RegionName Region,D.DistrictName, W.WardName,V.VillageName,
	ISNULL(PD.DistrictName, D.DistrictName) ProdDistrictName,Prod.ProductCode, Prod.ProductName, 
	ODist.DistrictName OfficerDistrict,O.Code, O.LastName,O.OtherNames, 
	--COALESCE(ISNULL(PD.DistrictName, R.RegionName) ,PR.RegionName, R.RegionName)ProdRegion
	COALESCE(R.RegionName, PR.RegionName)ProdRegion

	FROM tblPolicy PL INNER JOIN tblInsuree I ON PL.FamilyID = I.FamilyID
	INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardID = V.WardID
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	INNER JOIN tblDistricts ODist ON O.LocationId = ODist.DistrictID
	INNER JOIN tblInsureePolicy PIns ON I.InsureeID = PIns.InsureeId AND PL.PolicyID = PIns.PolicyId
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	LEFT OUTER JOIN tblDistricts PD ON PD.DistrictID = Prod.LocationId
	LEFT OUTER JOIN tblRegions PR ON PR.RegionId = Prod.LocationId
	CROSS APPLY @tblLastDays LD 

	WHERE PL.ValidityTo IS NULL 
	AND I.ValidityTo IS NULL 
	AND F.ValidityTo IS NULL
	AND D.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND Prod.ValidityTo IS NULL 
	AND O.ValidityTo IS NULL
	AND ODist.ValidityTo IS NULL
	AND PIns.ValidityTo IS NULL
	AND PIns.EffectiveDate <= LD.LastDate
	AND PIns.ExpiryDate  > LD.LastDate--= DATEADD(DAY, 1, DATEADD(MONTH,-1,EOMONTH(LD.LastDate,0))) 
	
	GROUP BY MONTH(LD.LastDate),DATENAME(Q,LastDate),YEAR(LD.LastDate),I.DOB,I.Gender, R.RegionName,D.DistrictName, W.WardName,V.VillageName,
	Prod.ProductCode, Prod.ProductName, ODist.DistrictName,O.Code, O.LastName,O.OtherNames, PD.DistrictName, PR.RegionName

	RETURN;

END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dw].[udfNumberOfCurrentPolicies]()
RETURNS @Result TABLE(NumberOfCurrentPolicies INT, MonthTime INT, QuarterTime INT, YearTime INT, Age INT, Gender CHAR(1),Region NVARCHAR(20), InsureeDistrictName NVARCHAR(50), WardName NVARCHAR(50), VillageName NVARCHAR(50), ProdDistrictName NVARCHAR(50), ProductCode NVARCHAR(15), ProductName NVARCHAR(100), OfficeDistrict NVARCHAR(20), OfficerCode NVARCHAR(15), LastName NVARCHAR(100), OtherNames NVARCHAR(100), ProdRegion NVARCHAR(50))
AS
BEGIN
	DECLARE @StartDate DATE --= (SELECT MIN(EffectiveDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @EndDate DATE--= (SELECT Max(ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL)
	DECLARE @LastDate DATE
	DECLARE @tblLastDays TABLE(LastDate DATE)

	DECLARE @Year INT,
		@MonthCounter INT = 1
	
	DECLARE Cur CURSOR FOR 
						SELECT Years FROM
						(SELECT YEAR(EffectiveDate) Years FROM tblPolicy WHERE ValidityTo IS NULL AND EffectiveDate IS NOT NULL GROUP BY YEAR(EffectiveDate) 
						UNION 
						SELECT YEAR(ExpiryDate) Years FROM tblPolicy WHERE ValidityTo IS NULL AND ExpiryDate IS NOT NULL GROUP BY YEAR(ExpiryDate)
						)Yrs ORDER BY Years
	OPEN Cur
		FETCH NEXT FROM Cur into @Year
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @StartDate = CAST(CAST(@Year AS VARCHAR(4))+ '-01-01' AS DATE)
			SET @MonthCounter = 1
			WHILE YEAR(@StartDate) = @Year
			BEGIN
				SET @LastDate = DATEADD(DAY,-1,DATEADD(MONTH,DATEDIFF(MONTH,0,@StartDate) + 1,0));
				SET @StartDate = DATEADD(MONTH,1,@StartDate);
				INSERT INTO @tblLastDays(LastDate) VALUES(@LastDate);
			END
			FETCH NEXT FROM Cur into @Year
		END
	CLOSE Cur
	DEALLOCATE Cur

	INSERT INTO @Result(NumberOfCurrentPolicies,MonthTime,QuarterTime,YearTime,Age,Gender,Region,InsureeDistrictName,WardName,VillageName,
	ProdDistrictName,ProductCode,ProductName, OfficeDistrict, OfficerCode,LastName,OtherNames, ProdRegion)
	SELECT COUNT(PolicyId) NumberOfCurrentPolicies, MONTH(LD.LastDate)MonthTime, DATENAME(Q,LD.LastDate)QuarterTime, YEAR(LD.LastDate)YearTime,
	DATEDIFF(YEAR, I.DOB,LD.LastDate)Age, I.Gender, R.RegionName Region, FD.DistrictName InsureeDistrictName, W.WardName, V.VillageName,
	ISNULL(PD.DistrictName, FD.DistrictName) ProdDistrictName, PR.ProductCode, PR.ProductName, OD.DistrictName OfficeDistrict, O.Code OfficerCode, O.LastName, O.OtherNames,
	--COALESCE(ISNULL(PD.DistrictName, R.RegionName) ,PRDR.RegionName, R.RegionName)ProdRegion
	COALESCE(R.RegionName, PRDR.RegionName)ProdRegion

	FROM tblPolicy PL 
	INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
	INNER JOIN tblInsuree I ON F.InsureeID = I.InsureeID
	INNER JOIN tblVillages V ON V.VillageId = F.LocationId
	INNER JOIN tblWards W ON W.WardId = V.WardID
	INNER JOIN tblDistricts FD ON FD.DistrictID = W.DistrictID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
	INNER JOIN tblOfficer O ON PL.OfficerId  = O.OfficerID
	INNER JOIN tblDistricts OD ON OD.DistrictId = O.LocationId
	INNER JOIN tblRegions R ON R.RegionId = FD.Region
	LEFT OUTER JOIN tblDistricts PD ON PD.DistrictId = PR.LocationId
	LEFT OUTER JOIN tblRegions PRDR ON PRDR.Regionid = PR.LocationId
	CROSS APPLY @tblLastDays LD
	WHERE PL.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND FD.ValidityTo IS NULL
	AND W.ValidityTo IS NULL
	AND V.ValidityTo IS NULL
	AND PR.ValidityTo IS NULL
	AND O.ValidityTo IS NULL
	AND OD.ValidityTo IS NULL
	AND PL.EffectiveDate <= LD.LastDate
	AND PL.ExpiryDate > LD.LastDate--DATEADD(DAY, 1, DATEADD(MONTH,-1,EOMONTH(LD.LastDate,0))) 
	AND PL.PolicyStatus > 1

	GROUP BY DATEDIFF(YEAR, I.DOB,LD.LastDate),MONTH(LD.LastDate), DATENAME(Q,LD.LastDate), YEAR(LD.LastDate),
	I.Gender, R.RegionName, FD.DistrictName, W.WardName, V.VillageName,PR.ProductCode, 
	PR.ProductName,OD.DistrictName, O.COde ,O.LastName, O.OtherNames, PD.DistrictName, PRDR.RegionName
	
	RETURN;
END

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udfDefaultLanguageCode]()
RETURNS NVARCHAR(5)
AS
BEGIN
	DECLARE @DefaultLanguageCode NVARCHAR(5)
	IF EXISTS (SELECT DISTINCT SortOrder from tblLanguages where SortOrder is not null)
	    SELECT TOP(1) @DefaultLanguageCode=LanguageCode FROM tblLanguages sort ORDER BY SortOrder ASC
	ELSE
	    SELECT TOP(1) @DefaultLanguageCode=LanguageCode FROM tblLanguages sort
	RETURN(@DefaultLanguageCode)
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dw].[udfNumberOfPoliciesExpired]()
	RETURNS @Result TABLE(ExpiredPolicy INT, MonthTime INT, QuarterTime INT, YearTime INT, Age INT, Gender CHAR(1),Region NVARCHAR(20), InsureeDistrictName NVARCHAR(50), WardName NVARCHAR(50), VillageName NVARCHAR(50), ProdDistrictName NVARCHAR(50), ProductCode NVARCHAR(15), ProductName NVARCHAR(100), OfficeDistrict NVARCHAR(20), OfficerCode NVARCHAR(15), LastName NVARCHAR(100), OtherNames NVARCHAR(100), ProdRegion NVARCHAR(50))
AS
BEGIN

	DECLARE @tbl TABLE(MonthId INT, YearId INT)
	INSERT INTO @tbl
	SELECT DISTINCT MONTH(ExpiryDate),YEAR(ExpiryDate) FROM tblPolicy WHERE ValidityTo IS NULL ORDER BY YEAR(ExpiryDate),MONTH(ExpiryDate)


	INSERT INTO @Result(ExpiredPolicy,MonthTime,QuarterTime,YearTime,Age,Gender,Region,InsureeDistrictName,WardName,VillageName,
				ProdDistrictName,ProductCode,ProductName, OfficeDistrict, OfficerCode,LastName,OtherNames, ProdRegion)
			
	SELECT COUNT(PL.PolicyID)ExpiredPolicy, MONTH(PL.ExpiryDate)MonthTime, DATENAME(Q,PL.ExpiryDate) QuarterTime, YEAR(PL.ExpiryDate)YearTime,
	DATEDIFF(YEAR,I.DOB,PL.ExpiryDate)Age, I.Gender, R.RegionName Region,D.DistrictName, W.WardName,V.VillageName,
	D.DistrictName ProdDistrictName,PR.ProductCode, PR.ProductName, 
	ODist.DistrictName OfficerDistrict,O.Code, O.LastName,O.OtherNames, R.RegionName ProdRegion


	FROM tblPolicy PL  INNER JOIN TblProduct PR ON PL.ProdID = PR.ProdID
	INNER JOIN tblOfficer O ON PL.OfficerID = O.OfficerID
	INNER JOIN tblInsuree I ON PL.FamilyID = I.FamilyID
	INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID
	INNER JOIN tblVillages V ON V.VillageID = F.LocationId
	INNER JOIN tblWards W ON W.WardID = V.WardID
	INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
	INNER JOIN tblDistricts ODist ON O.LocationId = ODist.DistrictID
	INNER JOIN tblRegions R ON R.RegionId = D.Region
	CROSS APPLY @tbl t

	WHERE PL.ValidityTo IS NULL 
	AND PR.ValidityTo IS NULL 
	AND I.ValidityTo IS NULL 
	AND O.ValidityTo IS NULL
	AND I.IsHead = 1
	AND MONTH(PL.ExpiryDate) = t.MonthId AND YEAR(PL.ExpiryDate) = t.YearId
	AND PL.PolicyStatus > 1

	GROUP BY MONTH(PL.ExpiryDate),DATENAME(Q,PL.ExpiryDate), YEAR(PL.ExpiryDate), DATEDIFF(YEAR,I.DOB,PL.ExpiryDate),
	I.Gender, R.RegionName,D.DistrictName, W.WardName,V.VillageName ,PR.ProductCode, PR.ProductName, 
	ODist.DistrictName,O.Code, O.LastName,O.OtherNames

	RETURN;
END
GO

CREATE FUNCTION [dbo].[udfRejectedClaims]
(
	@ProdID INT = 0,
	@HFID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT
)
RETURNS TABLE
AS
RETURN
	SELECT Claims.HFID,Claims.ProdID,COUNT(ClaimID)RejectedClaims FROM
	(
		SELECT C.ClaimID,HF.HfID,CI.ProdID
		FROM tblClaim C 
		INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId 
		WHERE C.ValidityTo IS NULL 
		AND CI.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL
		AND C.ClaimStatus = 1 
		AND (CI.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		GROUP BY C.ClaimID,HF.HfID,CI.ProdID
		UNION 
		SELECT C.ClaimID,HF.HfID,CS.ProdID
		FROM tblClaim C 
		INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId 
		WHERE C.ValidityTo IS NULL 
		AND CS.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL
		AND C.ClaimStatus = 1 
		AND (CS.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		GROUP BY C.ClaimID,HF.HfID,CS.ProdID
	)Claims
	GROUP BY Claims.HFID,Claims.ProdID
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[udfTotalClaims]
(
	@ProdID INT = 0,
	@HFID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT
)
RETURNS TABLE
AS
RETURN
  
	SELECT ClaimStat.ProdID, ClaimStat.HFID,COUNT(ClaimStat.ClaimID)TotalClaims
	FROM
	(
		 	SELECT CI.ProdId, HF.HFID, C.ClaimID
	FROM tblClaim C 
	INNER JOIN tblClaimItems CI ON CI.ClaimId = C.ClaimID
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN uvwLocations L ON L.DistrictId = HF.LocationId
	WHERE C.ValidityTo IS NULL
	AND CI.ValidityTo IS NULL
	AND HF.ValidityTo IS NULL
	AND MONTH(C.DateFrom) = @Month
	AND YEAR(C.DateFrom) = @Year
	AND (CI.ProdId = @ProdId OR @ProdId = 0)
	AND (HF.HFID = @HFId OR @HFId = 0)
	AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	GROUP BY ProdId, HF.HFID, C.ClaimID, C.ClaimCode
	UNION 
	SELECT CS.ProdId, HF.HFID ,C.ClaimID
	FROM tblClaim C 
	INNER JOIN tblClaimServices CS ON CS.ClaimId = C.ClaimID
	INNER JOIN tblHF HF ON HF.HFID = C.HFID
	INNER JOIN uvwLocations L ON L.DistrictId = HF.LocationId
	WHERE C.ValidityTo IS NULL
	AND CS.ValidityTo IS NULL
	AND HF.ValidityTo IS NULL
	AND MONTH(C.DateFrom) = @Month
	AND YEAR(C.DateFrom) = @Year
	AND (CS.ProdId = @ProdId OR @ProdId = 0)
	AND (HF.HFID = @HFId OR @HFId = 0)
	AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
	GROUP BY ProdId, HF.HFID, C.ClaimID
	)ClaimStat
	GROUP BY ClaimStat.ProdID, ClaimStat.HFID
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE  FUNCTION [dbo].[udfRemunerated]
(
	@HFID INT = 0,
	@ProdID INT = 0,
	@LocationId INT = 0,
	@Month INT,
	@Year INT
)
RETURNS TABLE
AS
RETURN
	
	SELECT Remunerated.ProdID, Remunerated.HFID,SUM(Rem)Remunerated FROM
	(
		SELECT CI.ProdID,HF.HfID,ISNULL(SUM(CI.RemuneratedAmount), 0) AS Rem
		FROM tblClaim C 
		INNER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId   --Changed From DistrictId to HFLocationId 29062017 Rogers
		WHERE C.ValidityTo IS NULL 
		AND CI.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL 
		AND (CI.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		AND CI.ClaimItemStatus = 1
		AND C.ClaimStatus = 16
		GROUP BY CI.ProdID,HF.HfID
		UNION ALL
		SELECT CS.ProdID,HF.HfID,ISNULL(SUM(CS.RemuneratedAmount), 0) AS Rem
		FROM tblClaim C 
		INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		INNER JOIN tblHF HF ON C.HFID = HF.HfID
		INNER JOIN uvwLocations L ON HF.LocationId = L.LocationId   --Changed From DistrictId to HFLocationId 29062017 Rogers
		WHERE C.ValidityTo IS NULL 
		AND CS.ValidityTo IS NULL 
		AND HF.ValidityTo IS NULL 
		AND (CS.ProdID = @ProdId OR @ProdId = 0)
		AND (HF.HfID = @HFID OR @HFID = 0)
		AND (L.RegionId = @LocationId OR L.DistrictId = @LocationId OR ISNULL(@LocationId, 0) = 0)
		AND MONTH(C.DateFrom) = @Month 
		AND YEAR(C.DateFrom) = @Year
		AND CS.ClaimServiceStatus = 1
		AND C.ClaimStatus = 16
		GROUP BY CS.ProdID,HF.HfID
	)Remunerated
	GROUP BY Remunerated.ProdID, Remunerated.HFID
GO
