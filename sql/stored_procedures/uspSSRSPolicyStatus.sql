IF OBJECT_ID('[dbo].[uspSSRSPolicyStatus]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspSSRSPolicyStatus]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspSSRSPolicyStatus]
	@RangeFrom datetime, --= getdate ,
	@RangeTo datetime, --= getdate ,
	@OfficerID int = 0,
	@RegionId INT = 0,
	@DistrictID as int = 0,
	@VillageID as int = 0, 
	@WardID as int = 0 ,
	@PolicyStatus as int = 0 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	DECLARE @RenewalID int
	DECLARE @PolicyID as int 
	DECLARE @FamilyID as int 
	DECLARE @RenewalDate as date
	DECLARE @InsureeID as int
	DECLARE @ProductID as int 
	DECLARE @ProductCode as nvarchar(8)
	DECLARE @ProductName as nvarchar(100)
	DECLARE @ProductFromDate as date 
	DECLARE @ProductToDate as date
	DECLARE @DistrictName as nvarchar(50)
	DECLARE @VillageName as nvarchar(50) 
	DECLARE @WardName as nvarchar(50)  
	DECLARE @CHFID as nvarchar(50)
	DECLARE @InsLastName as nvarchar(100)
	DECLARE @InsOtherNames as nvarchar(100)
	DECLARE @InsDOB as date
	DECLARE @ConvProdID as int    
	DECLARE @OffCode as nvarchar(15)
	DECLARE @OffLastName as nvarchar(50)
	DECLARE @OffOtherNames as nvarchar(50)
	DECLARE @OffPhone as nvarchar(50)
	DECLARE @OffSubstID as int 
	DECLARE @OffWorkTo as date 
	DECLARE @PolicyValue DECIMAL(18,4) = 0
	DECLARE @OfficerId1 INT


	DECLARE @SMSStatus as tinyint 
	DECLARE @iCount as int 


	DECLARE @tblResult TABLE(PolicyId INT, 
							FamilyId INT,
							RenewalDate DATE,
							PolicyValue DECIMAL(18,4),
							InsureeId INT,
							ProdId INT,
							ProductCode NVARCHAR(8),
							ProductName NVARCHAR(100),
							DateFrom DATE,
							DateTo DATE,
							DistrictName NVARCHAR(50),
							VillageName NVARCHAR(50),
							WardName NVARCHAR(50),
							CHFID NVARCHAR(50),
							LastName NVARCHAR(100),
							OtherNames NVARCHAR(100),
							DOB DATE,
							ConversionProdId INT,
							OfficerId INT,
							Code NVARCHAR(15),
							OffLastName NVARCHAR(50),
							OffOtherNames NVARCHAR(50),
							Phone NVARCHAR(50),
							OfficerIdSubst INT,
							WorksTo DATE)



	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR
	SELECT PL.PolicyID, PL.FamilyID, DATEADD(DAY, 1, PL.ExpiryDate) AS RenewalDate, 
			F.InsureeID, Prod.ProdID, Prod.ProductCode, Prod.ProductName,
			Prod.DateFrom, Prod.DateTo, D.DistrictName, V.VillageName, W.WardName, I.CHFID, I.LastName, I.OtherNames, I.DOB, Prod.ConversionProdID, 
			O.OfficerID, O.Code, O.LastName OffLastName, O.OtherNames OffOtherNames, O.Phone, O.OfficerIDSubst, O.WorksTo,
			PL.PolicyValue

			FROM tblPolicy PL INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
			INNER JOIN tblInsuree I ON F.InsureeId = I.InsureeID
			INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdID
			INNER JOIN tblVillages V ON V.VillageId = F.LocationId
			INNER JOIN tblWards W ON W.WardId = V.WardId
			INNER JOIN tblDistricts D ON D.DistrictID = W.DistrictID
			INNER JOIN tblRegions R ON R.RegionId = D.Region
			INNER JOIN tblOfficer O ON PL.OfficerId = O.OfficerID
			AND PL.ExpiryDate BETWEEN @RangeFrom AND @RangeTo
			WHERE PL.ValidityTo IS NULL
			AND F.ValidityTo IS NULL
			AND R.ValidityTo IS NULL
			AND D.ValidityTo IS NULL
			AND V.ValidityTo IS NULL
			AND W.ValidityTo IS NULL
			AND I.ValidityTo IS NULL
			AND O.ValidityTo IS NULL

			AND PL.ExpiryDate BETWEEN @RangeFrom AND @RangeTo
			--AND (O.OfficerId = @OfficerId OR @OfficerId = 0)
			AND (R.RegionId = @RegionId OR @RegionId = 0)
			AND (D.DistrictID = @DistrictID OR @DistrictID = 0)
			AND (V.VillageId = @VillageId  OR @VillageId = 0)
			AND (W.WardId = @WardId OR @WardId = 0)
			AND (PL.PolicyStatus = @PolicyStatus OR @PolicyStatus = 0)
			AND (PL.PolicyStatus > 1)	--Do not renew Idle policies
		ORDER BY RenewalDate DESC  --Added by Rogers


		OPEN LOOP1
		FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
								  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID1, @OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo,
								  @PolicyValue
	
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			
			--GET ProductCode or the substitution
			IF ISNULL(@ConvProdID,0) > 0 
			BEGIN
				SET @iCount = 0 
				WHILE @ConvProdID <> 0 AND @iCount < 20   --this to prevent a recursive loop by wrong datra entries 
				BEGIN
					--get new product info 
					SET @ProductID = @ConvProdID
					SELECT @ConvProdID = ConversionProdID FROM tblProduct WHERE ProdID = @ProductID
					IF ISNULL(@ConvProdID,0) = 0 
					BEGIN
						SELECT @ProductCode = ProductCode from tblProduct WHERE ProdID = @ProductID
						SELECT @ProductName = ProductName  from tblProduct WHERE ProdID = @ProductID
						SELECT @ProductFromDate = DateFrom from tblProduct WHERE ProdID = @ProductID
						SELECT @ProductToDate = DateTo  from tblProduct WHERE ProdID = @ProductID
					
					
					END
					SET @iCount = @iCount + 1
				END
			END 
		
			IF ISNULL(@OfficerID1 ,0) > 0 
			BEGIN
				--GET OfficerCode or the substitution
				IF ISNULL(@OffSubstID,0) > 0 
				BEGIN
					SET @iCount = 0 
					WHILE @OffSubstID <> 0 AND @iCount < 20 AND @OffWorkTo < @RenewalDate  --this to prevent a recursive loop by wrong datra entries 
					BEGIN
						--get new product info 
						SET @OfficerID1 = @OffSubstID
						SELECT @OffSubstID = OfficerIDSubst FROM tblOfficer  WHERE OfficerID  = @OfficerID1
						IF ISNULL(@OffSubstID,0) = 0 
						BEGIN
							SELECT @OffCode = Code from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffLastName = LastName  from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffOtherNames = OtherNames  from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffPhone = Phone  from tblOfficer  WHERE OfficerID  = @OfficerID1
							SELECT @OffWorkTo = WorksTo  from tblOfficer  WHERE OfficerID  = @OfficerID1
						
						
							
						END
						SET @iCount = @iCount + 1
					END
				END 
			END
		

			--Code added by Hiren to check if the policy has another following policy
			IF EXISTS(SELECT 1 FROM tblPolicy 
								WHERE FamilyId = @FamilyId 
								AND (ProdId = @ProductID OR ProdId = @ConvProdID) 
								AND StartDate >= @RenewalDate
								AND ValidityTo IS NULL
								)
					GOTO NextPolicy;
		--Added by Rogers to check if the policy is alread in a family
		IF EXISTS(SELECT 1 FROM @tblResult WHERE FamilyId = @FamilyID AND ProdId = @ProductID OR ProdId = @ConvProdID)
		GOTO NextPolicy;

		
		EXEC @PolicyValue = uspPolicyValue
							@FamilyId = @FamilyID,
							@ProdId = @ProductID,
							@EnrollDate = @RenewalDate,
							@PreviousPolicyId = @PolicyID,
							@PolicyStage = 'R';


		
		INSERT INTO @tblResult(PolicyId, FamilyId, RenewalDate, Policyvalue, InsureeId, ProdId,
		ProductCode, ProductName, DateFrom, DateTo, DistrictName, VillageName,
		WardName, CHFID, LastName, OtherNames, DOB, ConversionProdId,OfficerId,
		Code, OffLastName, OffOtherNames, Phone, OfficerIdSubst, WorksTo)
		SELECT @PolicyID PolicyId, @FamilyId FamilyId, @RenewalDate RenewalDate, @PolicyValue PolicyValue, @InsureeID InsureeId, @ProductID ProdId,
		@ProductCode ProductCode, @ProductName ProductName, @ProductFromDate DateFrom, @ProductToDate DateTo, @DistrictName DistrictName, @VillageName VillageName,
		@WardName WardName, @CHFID CHFID, @InsLastName LastName, @InsOtherNames OtherNames, @InsDOB DOB, @ConvProdID ConversionProdId, @OfficerID1 OfficerId,
		@OffCode Code, @OffLastName OffLastName, @OffOtherNames OffOtherNames, @OffPhone Phone, @OffSubstID OfficerIdSubst, @OffWorkTo WorksTo
	

           
	NextPolicy:
			FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
								  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID1,@OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo,
								  @PolicyValue
	
		END
		CLOSE LOOP1
		DEALLOCATE LOOP1

		SELECT PolicyId, FamilyId, RenewalDate, PolicyValue, InsureeId, ProdId, ProductCode, ProductName, DateFrom, DateTo, DistrictName,
		VillageName, WardName, CHFID, LastName, OtherNames, DOB, ConversionProdId, OfficerId, Code, OffLastName, OffOtherNames, Phone, OfficerIdSubst, WorksTo
		FROM @tblResult
		WHERE (OfficerId = @OfficerId OR @OfficerId = 0);
END
GO
