IF NOT OBJECT_ID('uspProcessSingleClaimStep1') IS NULL
	DROP PROCEDURE uspProcessSingleClaimStep1
GO

CREATE PROCEDURE [dbo].[uspProcessSingleClaimStep1]
	
	@AuditUser as int = 0,
	@ClaimID as int,
	@InsureeID as int, 
	@HFCareType as char(1),
	@RowID as BIGINT = 0,
	@AdultChild as nvarchar(1),
	@RtnStatus as int = 0 OUTPUT
	
		
	/*
	Rejection reasons:
	0 = NOT REJECTED
	1 = Item/Service not in Registers
	2 = Item/Service not in HF Pricelist 
	3 = Item/Service not in Covering Product
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATED
	7 = CHFID Not valid / Family Not Valid 
	8 = ICD Code not in current ICD list 
	9 = Target date provision invalid
	10= Care type not consistant with Facility 
	11=
	12=
	*/
	
AS
BEGIN
	DECLARE @RtnItemsPassed as int 
	DECLARE @RtnServicesPassed as int 
	DECLARE @RtnItemsRejected as int 
	DECLARE @RtnServicesRejected as int 

	DECLARE @oReturnValue as int 
	SET @oReturnValue = 0 
	SET @RtnStatus = 0  
	DECLARE @HFID as int  
	DECLARE @FamilyID as int  
	DECLARE @TargetDate as Date 
	DECLARE @ClaimItemID as int 
	DECLARE @ClaimServiceID as int 
	DECLARE @ItemID as int
	DECLARE @ServiceID as int
	DECLARE @ProdItemID as int
	DECLARE @ProdServiceID as int
	DECLARE @ItemPatCat as int 
	DECLARE @ItemPrice as decimal(18,2)
	DECLARE @ServicePrice as decimal(18,2)
	DECLARE @ServicePatCat as int 
	DECLARE @Gender as nvarchar(1)
	DECLARE @Adult as bit
	DECLARE @DOB as date
	DECLARE @PatientMask as int
	DECLARE @CareType as Char
	DECLARE @PriceAsked as decimal(18,2)
	DECLARE @PriceApproved as decimal(18,2)
	DECLARE @PriceAdjusted as decimal(18,2)
	DECLARE @PriceValuated as decimal(18,2)
	DECLARE @PriceOrigin as Char
	DECLARE @ClaimPrice as Decimal(18,2)
	DECLARE @ProductID as int   
	DECLARE @PolicyID as int 
	DECLARE @ProdItemID_C as int 
	DECLARE @ProdItemID_F as int 
	DECLARE @ProdServiceID_C as int 
	DECLARE @ProdServiceID_F as int 
	DECLARE @CoSharingPerc as decimal(18,2)
	DECLARE @FixedLimit as decimal(18,2)
	DECLARE @ProdAmountOwnF as decimal(18,2)
	DECLARE @ProdAmountOwnC as decimal(18,2)
	DECLARE @ProdCareType as Char
		
		
	DECLARE @LimitationType as Char(1)
	DECLARE @LimitationValue as decimal(18,2)	
	
	DECLARE @VisitType as CHAR(1)

	SELECT @VisitType = ISNULL(VisitType,'O') from tblClaim where ClaimId = @ClaimID and ValidityTo IS NULL

	BEGIN TRY
	
	--***** PREPARE PHASE *****
	
	SELECT @FamilyID = tblFamilies.FamilyID FROM tblFamilies INNER JOIN tblInsuree ON tblFamilies.FamilyID = tblInsuree.FamilyID  WHERE tblFamilies.ValidityTo IS NULL AND tblInsuree.InsureeID = @InsureeID AND tblInsuree.ValidityTo IS NULL 

	IF ISNULL(@FamilyID,0)=0 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimServices.RejectionReason = 0 
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimItems.RejectionReason = 0 
		GOTO UPDATECLAIMDETAILS 
	END	
	
	SELECT @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom) FROM TblClaim WHERE ClaimID = @ClaimID 
	IF @TargetDate IS NULL 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 9 WHERE ClaimID = @ClaimID AND tblClaimServices.RejectionReason = 0 
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 9 WHERE ClaimID = @ClaimID  AND tblClaimItems.RejectionReason = 0 
		GOTO UPDATECLAIMDETAILS 
	END	
		
		  
	SET @PatientMask = 0 
	SELECT @Gender = Gender FROm tblInsuree WHERE InsureeID = @InsureeID 
	IF @Gender = 'M' OR @Gender = 'O'
		SET @PatientMask = @PatientMask + 1 
	ELSE
		SET @PatientMask = @PatientMask + 2 
	
	SELECT @DOB = DOB FROM tblInsuree WHERE InsureeID = @InsureeID 
	IF @AdultChild = 'A' 
		SET @PatientMask = @PatientMask + 4 
	ELSE
		SET @PatientMask = @PatientMask + 8 
		
	/*PREPARE HISTORIC TABLE WITh RELEVANT ITEMS AND SERVICES*/

	DECLARE  @DTBL_ITEMS TABLE (
							[ItemID] [int] NOT NULL,
							[ItemCode] [nvarchar](6) NOT NULL,
							[ItemType] [char](1) NOT NULL,
							[ItemPrice] [decimal](18, 2) NOT NULL,
							[ItemCareType] [char](1) NOT NULL,
							[ItemFrequency] [smallint] NULL,
							[ItemPatCat] [tinyint] NOT NULL
							)

	INSERT INTO @DTBL_ITEMS (ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat) 
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ItemId ORDER BY ValidityFrom DESC)RNo,AllItems.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom, ValidityTo, LegacyID from tblitems Where (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ItemID , ItemCode, ItemType , ItemPrice, ItemCaretype ,ItemFrequency, ItemPatCat , ValidityFrom,ValidityTo, LegacyID  FROM tblItems Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimItems.ItemID
	FROM            tblClaimItems 
	WHERE        (tblClaimItems.ValidityTo IS NULL) AND tblClaimItems.ClaimID = @ClaimID
	) Sub2 ON Sub1.ItemID = Sub2.ItemID 
	)  AllItems 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate 
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))  	

	DECLARE  @DTBL_SERVICES TABLE (
							[ServiceID] [int] NOT NULL,
							[ServCode] [nvarchar](6) NOT NULL,
							[ServType] [char](1) NOT NULL,
							[ServLevel] [char](1) NOT NULL,
							[ServPrice] [decimal](18, 2) NOT NULL,
							[ServCareType] [char](1) NOT NULL,
							[ServFrequency] [smallint] NULL,
							[ServPatCat] [tinyint] NOT NULL,
							[ServCategory] [char](1) NULL
							)

	INSERT INTO @DTBL_SERVICES (ServiceID , ServCode, ServType , ServLevel, ServPrice, ServCaretype ,ServFrequency, ServPatCat, ServCategory ) 
	SELECT ServiceID , ServCode, ServType , ServLevel ,ServPrice, ServCaretype ,ServFrequency, ServPatCat,ServCategory FROM 
	(SELECT  ROW_NUMBER() OVER(PARTITION BY ServiceId ORDER BY ValidityFrom DESC)RNo,AllServices.* FROM
	(
	SELECT Sub1.* FROM
	(
	SELECT ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory ,ValidityFrom, ValidityTo, LegacyID from tblServices WHere (ValidityTo IS NULL) OR ((NOT ValidityTo IS NULL) AND (LegacyID IS NULL))
	UNION ALL
	SELECT  LegacyID as ServiceID , ServCode, ServType , ServLevel  ,ServPrice, ServCaretype ,ServFrequency, ServPatCat , ServCategory , ValidityFrom, ValidityTo, LegacyID FROM tblServices Where  (NOT ValidityTo IS NULL) AND (NOT LegacyID IS NULL)
	) Sub1
	INNER JOIN 
	(
	SELECT        tblClaimServices.ServiceID 
	FROM            tblClaim INNER JOIN
							 tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID
	WHERE        (tblClaimServices.ValidityTo IS NULL) AND tblClaim.ClaimID = @ClaimID
	) Sub2 ON Sub1.ServiceID = Sub2.ServiceID 
	)  AllServices 
	WHERE CONVERT(date,ValidityFrom,103) <= @TargetDate
	)Result
	WHERE Rno = 1 AND ((ValidityTo IS NULL) OR (NOT ValidityTo IS NULL AND NOT LegacyID IS NULL ))   

	--***** CHECK 1 ***** --> UPDATE to REJECTED for Items/Services not in registers   REJECTION REASON = 1
	
	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimItems ON tblClaim.ClaimID = tblClaimItems.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL AND tblClaimItems.RejectionReason = 0 AND tblClaimItems.ItemID NOT IN 
                      (
                      SELECT     ItemID FROM @DTBL_ITEMS
                      )
                      
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL AND tblClaimServices.RejectionReason = 0  AND tblClaimServices.ServiceID  NOT IN 
                      (
                      SELECT     ServiceID FROM @DTBL_SERVICES  
                      )
	
	--***** CHECK 2 ***** --> UPDATE to REJECTED for Items/Services not in Pricelists  REJECTION REASON = 2
	SELECT @HFID = HFID from tblClaim WHERE ClaimID = @ClaimID 
	
	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 2
	FROM dbo.tblClaimItems 
	LEFT OUTER JOIN 
	(SELECT     tblPLItemsDetail.ItemID
	FROM tblHF 
	INNER JOIN tblPLItemsDetail ON tblHF.PLItemID = tblPLItemsDetail.PLItemID
								AND @TargetDate BETWEEN tblPLItemsDetail.ValidityFrom AND ISNULL(tblPLItemsDetail.ValidityTo, GETDATE())
	WHERE tblHF.HfID = @HFID) PLItems 
	ON tblClaimItems.ItemID = PLItems.ItemID 
	WHERE tblClaimItems.ClaimID = @ClaimID AND tblClaimItems.RejectionReason = 0 AND tblClaimItems.ValidityTo IS NULL AND PLItems.ItemID IS NULL
	
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 2 
	FROM dbo.tblClaimServices 
	LEFT OUTER JOIN 
	(SELECT tblPLServicesDetail.ServiceID 
	FROM tblHF 
	INNER JOIN tblPLServicesDetail ON tblHF.PLServiceID = tblPLServicesDetail.PLServiceID
								AND @TargetDate BETWEEN tblPLServicesDetail.ValidityFrom AND ISNULL(tblPLServicesDetail.ValidityTo, GETDATE())
	WHERE tblHF.HfID = @HFID) PLServices 
	ON tblClaimServices.ServiceID = PLServices.ServiceID  
	WHERE tblClaimServices.ClaimID = @ClaimID AND  tblClaimServices.RejectionReason = 0  AND tblClaimServices.ValidityTo IS NULL AND PLServices.ServiceID  IS NULL
	
	
	-- ** !!!!! ITEMS LOOPING !!!!! ** 
	
	--now loop through all (remaining) items and determine what is the matching product within valid policies using the rule least cost sharing for Insuree 
	-- at this stage we only check if any valid product itemline is found --> will not yet assign the line. 
	
	DECLARE CLAIMITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT     tblClaimItems.ClaimItemID, tblClaimItems.PriceAsked, PriceApproved, Items.ItemPrice, Items.ItemCareType, Items.ItemPatCat, Items.ItemID
														FROM         tblClaimItems INNER JOIN
																			  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID 
														WHERE     (tblClaimItems.ClaimID = @ClaimID) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0) ORDER BY tblClaimItems.ClaimItemID ASC
	OPEN CLAIMITEMLOOP
	FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID, @PriceAsked, @PriceApproved, @ItemPrice ,@CareType, @ItemPatCat,@ItemID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @ProdItemID_C = 0 
		SET @ProdItemID_F = 0 
		
		IF ISNULL(@PriceAsked,0) > ISNULL(@PriceApproved,0)
			SET @ClaimPrice = @PriceAsked
		ELSE
			SET @ClaimPrice = @PriceApproved
		
		-- **** START CHECK 4 --> Item/Service Limitation Fail (4)*****
		IF (@ItemPatCat  & @PatientMask) <> @PatientMask 	
		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimItems SET RejectionReason = 4 WHERE ClaimItemID   = @ClaimItemID 
			GOTO NextItem
		END
		-- **** END CHECK 4 *****	
		
		---- **** START CHECK 10 --> Item Care type / HF caretype Fail (10)*****
		--IF (@CareType = 'I' AND @HFCareType = 'O') OR (@CareType = 'O' AND @HFCareType = 'I')	
		--BEGIN
		--	--inconsistant patient type check 
		--	UPDATE tblClaimItems SET RejectionReason = 10 WHERE ClaimItemID   = @ClaimItemID 
		--	GOTO NextItem
		--END
		---- **** END CHECK 10 *****	
		
		-- **** START ASSIGNING PROD ID to ClaimITEMS *****	
		IF @AdultChild = 'A'
		BEGIN
			--Try to find co-sharing product with the least co-sharing --> better for insuree
			
			IF @VisitType = 'O' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitAdult DESC

				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitAdult WHEN 0 THEN 1000000000000 ELSE LimitAdult END) DESC
			END

			IF @VisitType = 'E' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitAdultE DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitAdultE WHEN 0 THEN 1000000000000 ELSE LimitAdultE END) DESC
			END


			IF @VisitType = 'R' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitAdultR DESC
				
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
					FROM         tblFamilies INNER JOIN
										  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
										  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
										  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
					WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
										  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
										  AND LimitationTypeR = 'F'
										  ORDER BY (CASE LimitAdultR WHEN 0 THEN 1000000000000 ELSE LimitAdultR END) DESC
			END

		END
		ELSE
		BEGIN
			IF @VisitType = 'O' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitChild DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitChild WHEN 0 THEN 1000000000000 ELSE LimitChild END) DESC		
			END
			IF @VisitType = 'E' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitChildE DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitChildE WHEN 0 THEN 1000000000000 ELSE LimitChildE END) DESC	
			END

			IF @VisitType = 'R' 
			BEGIN
				SELECT TOP 1 @ProdItemID_C = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitChildR DESC
			
				SELECT TOP 1 @ProdItemID_F = tblProductItems.ProdItemID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ItemID = @ItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'F'
									  ORDER BY (CASE LimitChildR WHEN 0 THEN 1000000000000 ELSE LimitChildR END) DESC	
			END

		END



		IF ISNULL(@ProdItemID_C,0) = 0 AND ISNULL(@ProdItemID_F,0) = 0 
		BEGIN
			-- No suitable product is found for this specific claim item 
			UPDATE tblClaimItems SET RejectionReason = 3 WHERE ClaimItemID = @ClaimItemID
			GOTO NextItem
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdItemID_F,0) <> 0
			BEGIN
				IF @VisitType = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdult,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChild,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
				END
				IF @VisitType = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
				END
				IF @VisitType = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_F  
				END
				
			END	
			IF ISNULL(@ProdItemID_C,0) <> 0
			BEGIN

				IF @VisitType = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdult,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChild,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
				END
				IF @VisitType = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildE,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
				END
				IF @VisitType = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildR,0) FROM tblProductItems WHERE ProdItemID  = @ProdItemID_C  
				END

				
			END
		END
		
		IF ISNULL(@ProdItemID_C,0) <> 0 AND ISNULL(@ProdItemID_F,0) <> 0 
		BEGIN
			--Need to check which product would be the best to choose CO-sharing or FIXED
			IF @FixedLimit = 0 OR @FixedLimit > @ClaimPrice 
			BEGIN --no limit or higher than claimed amount
				SET @ProdItemID = @ProdItemID_F
				SET @ProdItemID_C = 0 
			END
			ELSE  
			BEGIN
				SET @ProdAmountOwnF =  @ClaimPrice - @FixedLimit
				IF (100 - @CoSharingPerc) > 0 
				BEGIN
					--Insuree pays own part on co-sharing 
					SET @ProdAmountOwnF =  @ClaimPrice - @FixedLimit
					SET @ProdAmountOwnC = ((100 - @CoSharingPerc)/100) * @ClaimPrice 
					IF @ProdAmountOwnC > @ProdAmountOwnF 
					BEGIN
						SET @ProdItemID = @ProdItemID_F  
						SET @ProdItemID_C = 0 
					END
					ELSE
					BEGIN 
						SET @ProdItemID = @ProdItemID_C  	
						SET @ProdItemID_F = 0
					END
				END
				ELSE
				BEGIN
					SET @ProdItemID = @ProdItemID_C  
					SET @ProdItemID_F = 0
				END
			END
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdItemID_C,0) <> 0
			BEGIN
				-- Only Co-sharing 
				SET @ProdItemID = @ProdItemID_C
				SET @ProdItemID_F = 0 
			END
			ELSE
			BEGIN
				-- Only Fixed
				SET @ProdItemID = @ProdItemID_F 
				SET @ProdItemID_C = 0
			END 
		END
		
		
		SELECT @ProductID = tblProduct.ProdID FROM tblProduct INNER JOIN tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID WHERE tblProduct.ValidityTo IS NULL AND tblProductItems.ProdItemID = @ProdItemID 
		SELECT TOP 1 @PolicyID = tblPolicy.PolicyID 
			FROM         tblFamilies INNER JOIN
								  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
								  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
								  tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
			WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductItems.ValidityTo IS NULL) AND 
								  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductItems.ProdItemID = @ProdItemID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
								  
		-- **** END ASSIGNING PROD ID to CLAIM *****	
		
		-- **** START DETERMINE PRICE ITEM **** 
		SELECT @PriceOrigin = PriceOrigin FROM tblProductItems WHERE ProdItemID = @ProdItemID 
		
		IF @ProdItemID_C <> 0 
		BEGIN
			SET @LimitationType = 'C'
			SET @LimitationValue = @CoSharingPerc 		
		END
		ELSE
		BEGIN
			--FIXED LIMIT
			SET @LimitationType = 'F'
			SET @LimitationValue =@FixedLimit 
		END
		
		UPDATE tblClaimItems SET ProdID = @ProductID, PolicyID = @PolicyID , PriceAdjusted = @PriceAdjusted , PriceOrigin = @PriceOrigin, Limitation = @LimitationType , LimitationValue = @LimitationValue  WHERE ClaimItemID = @ClaimItemID 
		
		NextItem:
		FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID, @PriceAsked, @PriceApproved, @ItemPrice ,@CareType, @ItemPatCat,@ItemID
	END
	CLOSE CLAIMITEMLOOP
	DEALLOCATE CLAIMITEMLOOP
	
	-- ** !!!!! ITEMS LOOPING !!!!! ** 
	
	--now loop through all (remaining) Services and determine what is the matching product within valid policies using the rule least cost sharing for Insuree 
	-- at this stage we only check if any valid product Serviceline is found --> will not yet assign the line. 
	
	DECLARE CLAIMSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT     tblClaimServices.ClaimServiceID, tblClaimServices.PriceAsked, PriceApproved, Serv.ServPrice, Serv.ServCareType, Serv.ServPatCat, Serv.ServiceID
														FROM         tblClaimServices INNER JOIN
																			  @DTBL_SERVICES Serv
																			   ON tblClaimServices.ServiceID = Serv.ServiceID
														WHERE     (tblClaimServices.ClaimID = @ClaimID) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0) ORDER BY tblClaimServices.ClaimServiceID ASC
	OPEN CLAIMSERVICELOOP
	FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID, @PriceAsked, @PriceApproved, @ServicePrice ,@CareType, @ServicePatCat,@ServiceID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @ProdServiceID_C = 0 
		SET @ProdServiceID_F = 0 
		
		IF ISNULL(@PriceAsked,0) > ISNULL(@PriceApproved,0)
			SET @ClaimPrice = @PriceAsked
		ELSE
			SET @ClaimPrice = @PriceApproved
		
		-- **** START CHECK 4 --> Service/Service Limitation Fail (4)*****
		IF (@ServicePatCat  & @PatientMask) <> @PatientMask 	
		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimServices SET RejectionReason = 4 WHERE ClaimServiceID   = @ClaimServiceID 
			GOTO NextService
		END
		-- **** END CHECK 4 *****	
		
		-- **** START CHECK 10 --> Service Care type / HF caretype Fail (10)*****
		--IF (@CareType = 'I' AND @HFCareType = 'O') OR (@CareType = 'O' AND @HFCareType = 'I')	
		--BEGIN
		--	--inconsistant patient type check 
		--	UPDATE tblClaimServices SET RejectionReason = 10 WHERE ClaimServiceID   = @ClaimServiceID 
		--	GOTO NextService
		--END
		-- **** END CHECK 10 *****	
		
		-- **** START ASSIGNING PROD ID to ClaimServiceS *****	
		IF @AdultChild = 'A'
		BEGIN
			--Try to find co-sharing product with the least co-sharing --> better for insuree
			
			IF @VisitType = 'O'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitAdult DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitAdult WHEN 0 THEN 1000000000000 ELSE LimitAdult END) DESC
			END

			IF @VisitType = 'E'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitAdultE DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitAdultE WHEN 0 THEN 1000000000000 ELSE LimitAdultE END) DESC
			END
			
			
			IF @VisitType = 'R'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitAdultR DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'F'
									  ORDER BY (CASE LimitAdultR WHEN 0 THEN 1000000000000 ELSE LimitAdultR END) DESC
			END
			
		END
		ELSE
		BEGIN
			
			IF @VisitType = 'O'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'C'
									  ORDER BY LimitChild DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationType = 'F'
									  ORDER BY (CASE LimitChild WHEN 0 THEN 1000000000000 ELSE LimitChild END) DESC		
			END
			IF @VisitType = 'E'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'C'
									  ORDER BY LimitChildE DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeE = 'F'
									  ORDER BY (CASE LimitChildE WHEN 0 THEN 1000000000000 ELSE LimitChildE END) DESC		
			END


			IF @VisitType = 'R'
			BEGIN
				SELECT TOP 1 @ProdServiceID_C = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'C'
									  ORDER BY LimitChildR DESC
			
				SELECT TOP 1 @ProdServiceID_F = tblProductServices.ProdServiceID
				FROM         tblFamilies INNER JOIN
									  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
									  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
									  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
				WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
									  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ServiceID = @ServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
									  AND LimitationTypeR = 'F'
									  ORDER BY (CASE LimitChildR WHEN 0 THEN 1000000000000 ELSE LimitChildR END) DESC		
			END

		END
		
		
		
		IF ISNULL(@ProdServiceID_C,0) = 0 AND ISNULL(@ProdServiceID_F,0) = 0 
		BEGIN
			-- No suitable product is found for this specific claim Service 
			UPDATE tblClaimServices SET RejectionReason = 3 WHERE ClaimServiceID = @ClaimServiceID
			GOTO NextService
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdServiceID_F,0) <> 0
			BEGIN
				IF @VisitType = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdult,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChild,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F   
				END 
				IF @VisitType = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultE,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildE,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F   
				END
				IF @VisitType = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @FixedLimit = ISNULL(LimitAdultR,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F  
					ELSE
						SELECT @FixedLimit = ISNULL(LimitChildR,0) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_F   
				END
			END	
			IF ISNULL(@ProdServiceID_C,0) <> 0
			BEGIN
				IF @Visittype = 'O'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdult,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChild,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C 
				END
				IF @Visittype = 'E'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultE,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildE,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C 
				END 
				IF @Visittype = 'R'
				BEGIN
					IF @AdultChild = 'A'
						SELECT @CoSharingPerc = ISNULL(LimitAdultR,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C  
					ELSE
						SELECT @CoSharingPerc = ISNULL(LimitChildR,100) FROM tblProductServices WHERE ProdServiceID  = @ProdServiceID_C 
				END
			END

		END
		
		IF ISNULL(@ProdServiceID_C,0) <> 0 AND ISNULL(@ProdServiceID_F,0) <> 0 
		BEGIN
			--Need to check which product would be the best to choose CO-sharing or FIXED
			IF @FixedLimit = 0 OR @FixedLimit > @ClaimPrice 
			BEGIN --no limit or higher than claimed amount
				SET @ProdServiceID = @ProdServiceID_F
				SET @ProdServiceID_C = 0 
			END
			ELSE
			BEGIN
				SET @ProdAmountOwnF =  @ClaimPrice - ISNULL(@FixedLimit,0)
				IF (100 - @CoSharingPerc) > 0 
				BEGIN
					--Insuree pays own part on co-sharing 
					SET @ProdAmountOwnF =  @ClaimPrice - @FixedLimit
					SET @ProdAmountOwnC = ((100 - @CoSharingPerc)/100) * @ClaimPrice 
					IF @ProdAmountOwnC > @ProdAmountOwnF 
					BEGIN
						SET @ProdServiceID = @ProdServiceID_F  
						SET @ProdServiceID_C = 0 
					END
					ELSE
					BEGIN 
						SET @ProdServiceID = @ProdServiceID_C  	
						SET @ProdServiceID_F = 0
					END
				END
				ELSE
				BEGIN
					SET @ProdServiceID = @ProdServiceID_C  
					SET @ProdServiceID_F = 0
				END
			END
		END
		ELSE
		BEGIN
			IF ISNULL(@ProdServiceID_C,0) <> 0
			BEGIN
				-- Only Co-sharing 
				SET @ProdServiceID = @ProdServiceID_C
				SET @ProdServiceID_F = 0 
			END
			ELSE
			BEGIN
				-- Only Fixed
				SET @ProdServiceID = @ProdServiceID_F 
				SET @ProdServiceID_C = 0
			END 
		END
		
		SELECT @ProductID = tblProduct.ProdID FROM tblProduct INNER JOIN tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID WHERE tblProduct.ValidityTo IS NULL AND tblProductServices.ProdServiceID = @ProdServiceID 
		SELECT TOP 1 @PolicyID = tblPolicy.PolicyID 
			FROM         tblFamilies INNER JOIN
								  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
								  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID INNER JOIN
								  tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID
			WHERE     (tblPolicy.EffectiveDate <= @TargetDate) AND (tblPolicy.ExpiryDate >= @TargetDate) AND (tblPolicy.ValidityTo IS NULL) AND (tblProductServices.ValidityTo IS NULL) AND 
								  (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) AND (tblProductServices.ProdServiceID = @ProdServiceID) AND (tblFamilies.FamilyID = @FamilyID) AND (tblProduct.ValidityTo IS NULL)
								  
		-- **** END ASSIGNING PROD ID to CLAIM *****	
		
		-- **** START DETERMINE PRICE Service **** 
		SELECT @PriceOrigin = PriceOrigin FROM tblProductServices WHERE ProdServiceID = @ProdServiceID 
		
		IF @ProdServiceID_C <> 0 
		BEGIN
			SET @LimitationType = 'C'
			SET @LimitationValue = @CoSharingPerc 		
		END
		ELSE
		BEGIN
			--FIXED LIMIT
			SET @LimitationType = 'F'
			SET @LimitationValue =@FixedLimit 
		END
		
		UPDATE tblClaimServices SET ProdID = @ProductID, PolicyID = @PolicyID, PriceOrigin = @PriceOrigin, Limitation = @LimitationType , LimitationValue = @LimitationValue WHERE ClaimServiceID = @ClaimServiceID 
		
		NextService:
		FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID, @PriceAsked, @PriceApproved, @ServicePrice ,@CareType, @ServicePatCat,@ServiceID
	END
	CLOSE CLAIMSERVICELOOP
	DEALLOCATE CLAIMSERVICELOOP
	
	
	
	
	
UPDATECLAIMDETAILS:
	UPDATE tblClaimItems SET ClaimItemStatus = 2 WHERE ClaimID = @ClaimID AND RejectionReason <> 0 
	UPDATE tblClaimServices SET ClaimServiceStatus = 2 WHERE ClaimID = @ClaimID AND RejectionReason <> 0 
	
	SELECT @RtnItemsPassed = ISNULL(COUNT(ClaimItemID),0) FROM dbo.tblClaimItems WHERE ClaimID = @ClaimID AND ClaimItemStatus = 1 AND ValidityTo IS NULL
	SELECT @RtnServicesPassed  = ISNULL(COUNT(ClaimServiceID),0) FROM dbo.tblClaimServices  WHERE ClaimID = @ClaimID AND ClaimServiceStatus = 1  AND ValidityTo IS NULL
	
	IF @RtnItemsPassed <> 0  OR @RtnServicesPassed <> 0  --UPDATE CLAIM TO PASSED !! (default is not yet passed before checking procedure 
	BEGIN
		SET @RtnStatus = 1 
	END
	ELSE
	BEGIN
		UPDATE tblClaim SET ClaimStatus = 1 WHERE ClaimID = @ClaimID --> set rejected as all items ands services did not pass ! 
		SET @RtnStatus = 2 
	END
	
	
	
FINISH:
	RETURN @oReturnValue
	
	END TRY
	
	BEGIN CATCH
		SELECT 'Unexpected error encountered'
		SET @oReturnValue = 1 
		RETURN @oReturnValue
		
	END CATCH
END
GO
