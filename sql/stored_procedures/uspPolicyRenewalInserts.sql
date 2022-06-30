IF OBJECT_ID('[dbo].[uspPolicyRenewalInserts]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspPolicyRenewalInserts]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspPolicyRenewalInserts](
	--@RenewalWarning --> 1 = no valid product for renewal  2= No enrollment officer found (no photo)  4= INVALID Enrollment officer
	@RemindingInterval INT = NULL,
	@RegionId INT = NULL,
	@DistrictId INT = NULL,
	@WardId INT = NULL,
	@VillageId INT = NULL, 
	@OfficerId INT = NULL,
	@DateFrom DATE = NULL,
	@DateTo DATE = NULL
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @RenewalID int
	--DECLARE @RemindingInterval as int --days in advance
	
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
    --DECLARE @OfficerID as int               
	DECLARE @OffCode as nvarchar(6)
	DECLARE @OffLastName as nvarchar(100)
	DECLARE @OffOtherNames as nvarchar(100)
	DECLARE @OffPhone as nvarchar(50)
	DECLARE @OffSubstID as int 
	DECLARE @OffWorkTo as date 
	
	DECLARE @RenewalWarning as tinyint 

	DECLARE @SMSStatus as tinyint 
	DECLARE @iCount as int 
	
	IF @RemindingInterval IS NULL
		SELECT @RemindingInterval =  PolicyRenewalInterval from tblIMISDefaults  --later to be passed as parameter or reading from a default table 
	
	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR 
		--SELECT     tblPolicy.PolicyID, tblFamilies.FamilyID, DATEADD(d, 1, tblPolicy.ExpiryDate) AS RenewalDate, tblFamilies.InsureeID, tblProduct.ProdID, tblProduct.ProductCode, 
  --                    tblProduct.ProductName, tblProduct.DateFrom, tblProduct.DateTo, tblDistricts.DistrictName, tblVillages.VillageName, tblWards.WardName, tblInsuree.CHFID, 
  --                    tblInsuree.LastName, tblInsuree.OtherNames, tblInsuree.DOB, tblProduct.ConversionProdID,tblOfficer.OfficerID, tblOfficer.Code, tblOfficer.LastName AS OffLastName, 
  --                    tblOfficer.OtherNames AS OffOtherNames, tblOfficer.Phone, tblOfficer.OfficerIDSubst, tblOfficer.WorksTo
		--FROM         tblPhotos LEFT OUTER JOIN
		--					  tblOfficer ON tblPhotos.OfficerID = tblOfficer.OfficerID RIGHT OUTER JOIN
		--					  tblInsuree ON tblPhotos.PhotoID = tblInsuree.PhotoID RIGHT OUTER JOIN
		--					  tblDistricts RIGHT OUTER JOIN
		--					  tblPolicy INNER JOIN
		--					  tblProduct ON tblProduct.ProdID = tblPolicy.ProdID INNER JOIN
		--					  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID ON tblDistricts.DistrictID = tblFamilies.DistrictID ON 
		--					  tblInsuree.InsureeID = tblFamilies.InsureeID LEFT OUTER JOIN
		--					  tblVillages ON tblFamilies.VillageID = tblVillages.VillageID LEFT OUTER JOIN
		--					  tblWards ON tblFamilies.WardID = tblWards.WardID
		--WHERE     (tblPolicy.PolicyStatus = 2) AND (tblPolicy.ValidityTo IS NULL) AND (DATEDIFF(d, GETDATE(), tblPolicy.ExpiryDate) = @RemindingInterval)


		--============================================================================================
		--NEW QUERY BY HIREN
		--============================================================================================
		SELECT PL.PolicyID, PL.FamilyID, DATEADD(DAY, 1, PL.ExpiryDate) AS RenewalDate, F.InsureeID, Prod.ProdID, Prod.ProductCode, Prod.ProductName,
		Prod.DateFrom, Prod.DateTo, D.DistrictName, V.VillageName, W.WardName, I.CHFID, I.LastName, I.OtherNames, I.DOB, Prod.ConversionProdID, 
		O.OfficerID, O.Code, O.LastName OffLastName, O.OtherNames OffOtherNames, O.Phone, O.OfficerIDSubst, O.WorksTo
		FROM tblPolicy PL 
		INNER JOIN tblFamilies F ON PL.FamilyId = F.FamilyID
		INNER JOIN tblInsuree I ON F.InsureeId = I.InsureeID
		INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdID
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		INNER JOIN tblOfficer O ON PL.OfficerId = O.OfficerID
		LEFT OUTER JOIN tblPolicyRenewals PR ON PL.PolicyID = PR.PolicyID
											AND I.InsureeID = PR.InsureeID
		WHERE PL.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL
		AND PR.PolicyID IS NULL
		AND PL.PolicyStatus IN  (2, 8)
		AND (DATEDIFF(DAY, GETDATE(), PL.ExpiryDate) <= @RemindingInterval OR ISNULL(@RemindingInterval, 0) = 0)
		AND (V.VillageId = @VillageId OR @VillageId IS NULL)
		AND (W.WardId = @WardId OR @WardId IS NULL)
		AND (D.DistrictId = @DistrictId OR @DistrictId IS NULL)
		AND (D.Region = @RegionId OR @RegionId IS NULL)
		AND (O.OfficerId = @OfficerId OR @OfficerId IS NULL)
		AND (PL.ExpiryDate BETWEEN ISNULL(@DateFrom, '00010101') AND ISNULL(@DateTo, '30001231'))

	OPEN LOOP1
	FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
							  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID, @OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @RenewalWarning = 0
		--GET ProductCode or the substitution
		IF ISNULL(@ConvProdID,0) = 0 
		BEGIN
			IF NOT (@RenewalDate BETWEEN @ProductFromDate AND @ProductToDate) 
				SET @RenewalWarning = @RenewalWarning + 1
			
		END
		ELSE
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
					
					IF NOT (@RenewalDate BETWEEN @ProductFromDate AND @ProductToDate) 
						SET @RenewalWarning = @RenewalWarning + 1
						
				END
				SET @iCount = @iCount + 1
			END
		END 
		
		IF ISNULL(@OfficerID ,0) = 0 
		BEGIN
			SET @RenewalWarning = @RenewalWarning + 2
		
		END
		ELSE
		BEGIN
			--GET OfficerCode or the substitution
			IF ISNULL(@OffSubstID,0) = 0 
			BEGIN
				IF @OffWorkTo < @RenewalDate
					SET @RenewalWarning = @RenewalWarning + 4
			END
			ELSE
			BEGIN

				SET @iCount = 0 
				WHILE @OffSubstID <> 0 AND @iCount < 20 AND  @OffWorkTo < @RenewalDate  --this to prevent a recursive loop by wrong datra entries 
				BEGIN
					--get new product info 
					SET @OfficerID = @OffSubstID
					SELECT @OffSubstID = OfficerIDSubst FROM tblOfficer  WHERE OfficerID  = @OfficerID
					IF ISNULL(@OffSubstID,0) = 0 
					BEGIN
						SELECT @OffCode = Code from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffLastName = LastName  from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffOtherNames = OtherNames  from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffPhone = Phone  from tblOfficer  WHERE OfficerID  = @OfficerID
						SELECT @OffWorkTo = WorksTo  from tblOfficer  WHERE OfficerID  = @OfficerID
						
						IF @OffWorkTo < @RenewalDate
							SET @RenewalWarning = @RenewalWarning + 4
							
					END
					SET @iCount = @iCount + 1
				END
			END 
		END
		

		--Code added by Hiren to check if the policy has another following policy
		IF EXISTS(SELECT 1 FROM tblPolicy 
							WHERE ValidityTo IS NULL 
							AND FamilyId = @FamilyId 
							AND (ProdId = @ProductID OR ProdId = @ConvProdID) 
							AND StartDate >= @RenewalDate)

							GOTO NextPolicy;

		--Check for validity phone number
		SET @SMSStatus = 0   --later to be set as the status of sending !!

		--Insert only if it's not in the table
		IF NOT EXISTS(SELECT 1 FROM tblPolicyRenewals WHERE PolicyId = @PolicyId AND ValidityTo IS NULL)
		BEGIN
			INSERT INTO [dbo].[tblPolicyRenewals]
			   ([RenewalPromptDate]
			   ,[RenewalDate]
			   ,[NewOfficerID]
			   ,[PhoneNumber]
			   ,[SMSStatus]
			   ,[InsureeID]
			   ,[PolicyID]
			   ,[NewProdID]
			   ,[RenewalWarnings]
			   ,[ValidityFrom]
			   ,[AuditCreateUser])
			VALUES
			   (GETDATE()
			   ,@RenewalDate
			   ,@OfficerID
			   ,@OffPhone
			   ,@SMSStatus
			   ,@InsureeID
			   ,@PolicyID
			   ,@ProductID
			   ,@RenewalWarning
			   ,GETDATE()
			   ,0)
		
			--Now get all expired photographs
			SELECT @RenewalID = IDENT_CURRENT('tblPolicyRenewals')
		
			INSERT INTO [dbo].[tblPolicyRenewalDetails]
			   ([RenewalID]
			   ,[InsureeID]
			   ,[ValidityFrom]
			   ,[AuditCreateUser])
           
			   SELECT    @RenewalID,tblInsuree.InsureeID,GETDATE(),0
				FROM         tblFamilies INNER JOIN
						  tblInsuree ON tblFamilies.FamilyID = tblInsuree.FamilyID LEFT OUTER JOIN
						  tblPhotos ON tblInsuree.PhotoID = tblPhotos.PhotoID
						  WHERE tblFamilies.FamilyID = @FamilyID AND tblInsuree.ValidityTo IS NULL AND  
						  ((tblInsuree.PhotoDate IS NULL) 
						  OR
						  (
						   ((DATEDIFF (mm,tblInsuree.PhotoDate,@RenewalDate) >=60 ) 
						  OR ( 
						  DATEDIFF (mm,tblInsuree.PhotoDate,@RenewalDate) >=12 AND DATEDIFF (y,tblInsuree.DOB ,GETDATE() ) < 18
						   ) )
							))
        END
NextPolicy:
		FETCH NEXT FROM LOOP1 INTO @PolicyID,@FamilyID,@RenewalDate,@InsureeID,@ProductID, @ProductCode,@ProductName,@ProductFromDate,@ProductToDate,@DistrictName,@VillageName,@WardName,
							  @CHFID,@InsLastName,@InsOtherNames,@InsDOB,@ConvProdID,@OfficerID,@OffCode,@OffLastName,@OffOtherNames,@OffPhone,@OffSubstID,@OffWorkTo
	
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1

END
GO
