IF NOT OBJECT_ID('[dbo].[uspSubmitSingleClaim]') IS NULL
	DROP PROCEDURE [dbo].[uspSubmitSingleClaim]
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[uspSubmitSingleClaim]
	
	@AuditUser as int = 0,
	@ClaimID as int,
	@RowID as bigint = 0,
	@RtnStatus as int = 0 OUTPUT,
	@RtnItemsPassed as int = 0 OUTPUT,
	@RtnServicesPassed as int = 0 OUTPUT,
	@RtnItemsRejected as int = 0 OUTPUT,
	@RtnServicesRejected as int = 0 OUTPUT
	
	
	/*
	Rejection reasons:
	0 = NOT REJECTED
	1 = Item/Service not in Registers
	2 = Item/Service not in HF Pricelist 
	3 = Item/Service not in Covering Product/policy
	4 = Item/Service Limitation Fail
	5 = Item/Service Frequency Fail
	6 = Item/Service DUPLICATED
	7 = CHFID Not valid / Family Not Valid 
	8 = ICD Code not in current ICD list 
	9 = Target date provision invalid
	10= Care type not consistant with Facility 
	11= Maximum Hospital admissions
	12= Maximim visits (OP)
	13= Maximum consulations
	14= Maximum Surgeries
	15= Maximum Deliveries
	16= Item/Service Maximum provision
	17= Item/Service waiting period violation
	19= Maximum Antenatal
	*/
	
AS
BEGIN
	DECLARE @oReturnValue as int 
	SET @oReturnValue = 0 
	SET @RtnStatus = 0  
	DECLARE @HFID as int  
	DECLARE @InsureeID as int 
	DECLARE @FamilyID as int  
	DECLARE @TargetDate as Date 
	DECLARE @ClaimItemID as int 
	DECLARE @ClaimServiceID as int 
	DECLARE @ItemID as int
	DECLARE @ServiceID as int
	DECLARE @ProdItemID as int
	DECLARE @ProdServiceID as int
	DECLARE @ItemPatCat as int 
	DECLARE @ServicePatCat as int 
	DECLARE @Gender as nvarchar(1)
	DECLARE @Adult as bit
	DECLARE @DOB as date 
	DECLARE @PatientMask as int 
	DECLARE @WaitingPeriod as int 
	DECLARE @LimitNo as decimal(18,2) 
	DECLARE @EffectiveDateInsuree as datetime
	DECLARE @EffectiveDatePolicy as datetime
	DECLARE @ExpiryDateInsuree as datetime
	DECLARE @PolicyStage as CHAR
	DECLARE @Count as INT
	DECLARE @ServCategory as CHAR
	DECLARE @ServLevel as CHAR
	DECLARE @ProductID as int 
	DECLARE @ClaimStartDate as datetime
	DECLARE @ClaimEndDate as datetime
	DECLARE @CareType as CHAR(1)
	DECLARE @HFCareType as CHAR(1)

	BEGIN TRY
	
	DECLARE @BaseCategory as CHAR(1)  = 'V'
	DECLARE @ClaimDateFrom date
	DECLARE @ClaimDateTo date 
	-- S = Surgery
	-- D = Delivery
	-- A = Antenatal care
	-- H = Hospitalization
	-- C = Consultation
	-- O = Other
	-- V = Visit 
	SELECT @ClaimDateFrom = DateFrom,  @ClaimDateTo = DateTo FROM tblClaim Where ClaimID = @ClaimID 
	IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
		WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'S') AND 
							 (tblServices.ValidityTo IS NULL))
	BEGIN
		SET @BaseCategory = 'S'
	END
	ELSE
	BEGIN
		IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
		WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'D') AND 
							 (tblServices.ValidityTo IS NULL))
		BEGIN
			SET @BaseCategory = 'D'
		END
		ELSE
		BEGIN
			IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
			WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'A') AND 
								 (tblServices.ValidityTo IS NULL))
			BEGIN
				SET @BaseCategory = 'A'
			END
			ELSE
			BEGIN
				IF ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom 
				BEGIN
					SET @BaseCategory = 'H'
				END
				ELSE
				BEGIN
					IF  EXISTS (SELECT tblClaimServices.ClaimServiceID FROM tblClaim INNER JOIN tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID INNER JOIN tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
					WHERE        (tblClaim.ClaimID = @ClaimID) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND (tblServices.ServCategory = 'C') AND 
										 (tblServices.ValidityTo IS NULL))
					BEGIN
						SET @BaseCategory = 'C'
					END
					ELSE
					BEGIN
						SET @BaseCategory = 'V'
					END
				END
			END
		END
	END

	--***** PREPARE PHASE *****
	SELECT @InsureeID = InsureeID, @ClaimStartDate = DateFrom , @ClaimEndDate = DateTo  FROM tblClaim WHERE ClaimID = @ClaimID 
	SELECT @FamilyID = tblFamilies.FamilyID FROM tblFamilies INNER JOIN tblInsuree ON tblFamilies.FamilyID = tblInsuree.FamilyID  WHERE tblFamilies.ValidityTo IS NULL AND tblInsuree.InsureeID = @InsureeID AND tblInsuree.ValidityTo IS NULL 

	IF ISNULL(@FamilyID,0)=0 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 7 WHERE ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL
		GOTO UPDATECLAIM 
	END	
	
	SELECT @TargetDate = ISNULL(TblClaim.DateTo,TblClaim.DateFrom) FROM TblClaim WHERE ClaimID = @ClaimID 
	IF @TargetDate IS NULL 
	BEGIN
		UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 9 WHERE ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL
		UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 9 WHERE ClaimID = @ClaimID  AND tblClaimItems.ValidityTo IS NULL
		GOTO UPDATECLAIM 
	END	
	  
	SET @PatientMask = 0 
	SELECT @Gender = Gender FROm tblInsuree WHERE InsureeID = @InsureeID 
	IF @Gender = 'M' OR @Gender = 'O'
		SET @PatientMask = @PatientMask + 1 
	ELSE
		SET @PatientMask = @PatientMask + 2 
	
	SELECT @DOB = DOB FROM tblInsuree WHERE InsureeID = @InsureeID 
	IF DATEDIFF(YY  ,@DOB,@TargetDate ) >=18 
	BEGIN
		SET @Adult = 1
		SET @PatientMask = @PatientMask + 4 
	END
	ELSE
	BEGIN
		SET @Adult = 0
		SET @PatientMask = @PatientMask + 8 
	END

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
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL AND tblClaimItems.ItemID NOT IN 
                      (
                      SELECT     ItemID FROM @DTBL_ITEMS
                      )
                      
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 1     
	FROM         tblClaim INNER JOIN
                      tblClaimServices ON tblClaim.ClaimID = tblClaimServices.ClaimID 
                      WHERE tblClaim.ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL  AND tblClaimServices.ServiceID  NOT IN 
                      (
                      SELECT     ServiceID FROM @DTBL_SERVICES  
                      )
	
	--***** CHECK 2 ***** --> UPDATE to REJECTED for Items/Services not in Pricelists  REJECTION REASON = 2
	
	SELECT @HFID = HFID from tblClaim WHERE ClaimID = @ClaimID 
	SELECT @HFCareType = ISNULL(HFCareType,'B')  from tblHF where HFID = @HFID 

	UPDATE tblClaimItems SET tblClaimItems.RejectionReason = 2
	FROM dbo.tblClaimItems 
	LEFT OUTER JOIN 
	(SELECT tblPLItemsDetail.ItemID
	FROM tblHF 
	INNER JOIN tblPLItems ON tblHF.PLItemID = tblPLItems.PLItemID 
	INNER JOIN tblPLItemsDetail ON tblPLItems.PLItemID = tblPLItemsDetail.PLItemID
								AND @TargetDate BETWEEN tblPLItemsDetail.ValidityFrom AND ISNULL(tblPLItemsDetail.ValidityTo, GETDATE())
	WHERE tblHF.HFID = @HFID) PLItems 
	ON tblClaimItems.ItemID = PLItems.ItemID 
	WHERE tblClaimItems.ClaimID = @ClaimID AND tblClaimItems.ValidityTo IS NULL AND PLItems.ItemID IS NULL
	
	UPDATE tblClaimServices SET tblClaimServices.RejectionReason = 2 
	FROM dbo.tblClaimServices 
	LEFT OUTER JOIN 
	(SELECT   tblPLServicesDetail.ServiceID 
	FROM tblHF 
	INNER JOIN tblPLServicesDetail ON tblHF.PLServiceID = tblPLServicesDetail.PLServiceID
								AND @TargetDate BETWEEN tblPLServicesDetail.ValidityFrom AND ISNULL(tblPLServicesDetail.ValidityTo, GETDATE())
	WHERE tblHF.HfID = @HFID) PLServices 
	ON tblClaimServices.ServiceID = PLServices.ServiceID  
	WHERE tblClaimServices.ClaimID = @ClaimID AND tblClaimServices.ValidityTo IS NULL AND PLServices.ServiceID  IS NULL
	
	
	-- ** !!!!! ITEMS LOOPING !!!!! ** 
	
	--now loop through all (remaining) items and determine what is the matching product within valid policies using the rule least cost sharing for Insuree 
	-- at this stage we only check if any valid product itemline is found --> will not yet assign the line. 
	
	DECLARE @FAULTCODE as INT 
	DECLARE @ProdFound as BIT

	
	-- ** !!!!! SERVICES LOOPING !!!!! **

	DECLARE CLAIMSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT ClaimServiceID,ServiceID FROM TblClaimServices WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 
	OPEN CLAIMSERVICELOOP
	FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID,@ServiceID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
					SELECT @CareType =  ServCareType , @ServCategory = [ServCategory],  @ServLevel = [ServLevel] FROM @DTBL_SERVICES WHERE [ServiceID] = @ServiceID

							-- **** START CHECK 10 --> Item Care type / HF caretype Fail (10)*****
					IF  (@CareType = 'I' AND (@HFCareType = 'O' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) = @ClaimDateFrom)  )) 
					OR  (@CareType = 'O' AND (@HFCareType = 'I' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom)))	

					BEGIN
						--inconsistant patient type check 
						UPDATE tblClaimServices SET RejectionReason = 10 WHERE ClaimServiceID  = @ClaimServiceID
						GOTO NextService
					END
					-- **** END CHECK 10 *****	
		
					-- **** START CHECK 4 --> Item/Service Limitation Fail (4)*****	
					SELECT TOP 1 @ServicePatCat = ServPatCat FROM @DTBL_SERVICES WHERE ServiceID = @ServiceID 
					IF (@ServicePatCat & @PatientMask) <> @PatientMask 	
					BEGIN
						--inconsistant patient type check 
						UPDATE tblClaimServices SET RejectionReason = 4 WHERE ClaimServiceID  = @ClaimServiceID
						GOTO NextService
					END
					-- **** END CHECK 4 *****
		
					SET @FAULTCODE = 0 
					SET @ProdFound = 0

					IF @Adult = 1 
							DECLARE PRODSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR 
							SELECT  TblProduct.ProdID , tblProductServices.ProdServiceID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
							FROM tblFamilies 
							INNER JOIN tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID 
							INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID 
							INNER JOIN tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID 
														AND @TargetDate BETWEEN tblProductServices.ValidityFrom AND ISNULL(tblProductServices.ValidityTo, GETDATE())
							INNER JOIN tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
							WHERE tblPolicy.EffectiveDate <= @TargetDate 
							AND tblPolicy.ExpiryDate >= @TargetDate 
							AND tblPolicy.ValidityTo IS NULL 
							AND (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) 
							AND tblProductServices.ServiceID = @ServiceID 
							AND tblFamilies.FamilyID = @FamilyID 
							AND tblProduct.ValidityTo IS NULL 
							AND tblInsureePolicy.EffectiveDate <= @TargetDate 
							AND tblInsureePolicy.ExpiryDate >= @TargetDate 
							AND tblInsureePolicy.InsureeId = @InsureeID 
							AND tblInsureePolicy.ValidityTo IS NULL
							ORDER BY DATEADD(m,ISNULL(tblProductServices.WaitingPeriodAdult, 0), tblInsureePolicy.EffectiveDate)
					ELSE
							DECLARE PRODSERVICELOOP CURSOR LOCAL FORWARD_ONLY FOR 
							SELECT  TblProduct.ProdID , tblProductServices.ProdServiceID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
							FROM tblFamilies 
							INNER JOIN tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID 
							INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID 
							INNER JOIN tblProductServices ON tblProduct.ProdID = tblProductServices.ProdID 
														AND @TargetDate BETWEEN tblProductServices.ValidityFrom AND ISNULL(tblProductServices.ValidityTo, GETDATE())
							INNER JOIN tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
							WHERE tblPolicy.EffectiveDate <= @TargetDate 
							AND tblPolicy.ExpiryDate >= @TargetDate 
							AND tblPolicy.ValidityTo IS NULL 
							AND (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) 
							AND tblProductServices.ServiceID = @ServiceID 
							AND tblFamilies.FamilyID = @FamilyID 
							AND tblProduct.ValidityTo IS NULL 
							AND tblInsureePolicy.EffectiveDate <= @TargetDate 
							AND tblInsureePolicy.ExpiryDate >= @TargetDate 
							AND tblInsureePolicy.InsureeId = @InsureeID
							AND tblInsureePolicy.ValidityTo IS NULL
							ORDER BY DATEADD(m,ISNULL(tblProductServices.WaitingPeriodChild, 0), tblInsureePolicy.EffectiveDate)

		
					OPEN PRODSERVICELOOP
					FETCH NEXT FROM PRODSERVICELOOP INTO @ProductID ,@ProdServiceID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
					WHILE @@FETCH_STATUS = 0 
					BEGIN
						SET @ProdFound= 1 --at least there is a product that would cover --> still to check on waiting period!
			
						-- **** START CHECK 17 --> Item/Service waiting period violation (17)*****	
						IF @PolicyStage = 'N' or (@EffectiveDatePolicy < @EffectiveDateInsuree )     --new policy or Insuree was added after policy was defined.
 						BEGIN
							IF @Adult = 1 
								SELECT TOP 1 @WaitingPeriod = [WaitingPeriodAdult] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
							ELSE
								SELECT TOP 1 @WaitingPeriod = [WaitingPeriodChild] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
		

							IF @TargetDate < DATEADD(m,@WaitingPeriod,@EffectiveDateInsuree)	
							BEGIN
								--Item/Service waiting period violation
								IF @FAULTCODE = 0 
									SET @FAULTCODE = 17
								GOTO ProdServiceNext --ProdLoopFinish
							END
						END
						-- **** END CHECK 17 *****


						-- **** START CHECK 16 --> Item/Service Maximum provision (16)*****	
						SET @LimitNo = -1 
						IF @Adult = 1 
							SELECT  @LimitNo = [LimitNoAdult] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
						ELSE
							SELECT  @LimitNo = [LimitNoChild] FROM [dbo].[tblProductServices] WHERE [ProdServiceID] = @ProdServiceID 
		

						IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
						BEGIN
							SET @Count = 0 
							SELECT @COUNT = SUM(tblClaimServices.QtyProvided )  
							FROM         tblClaimServices INNER JOIN
												  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID
							WHERE     (tblClaim.InsureeID = @InsureeID) AND (tblClaimServices.ServiceID = @ServiceID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND 
												  @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND  tblClaimServices.RejectionReason  = 0 
			
							IF ISNULL(@Count,0) >= @LimitNo 
							BEGIN
								--Over Item/Service Maximum Number allowed  (16)
								IF @FAULTCODE = 0 
									SET @FAULTCODE = 16
								GOTO ProdServiceNext --ProdLoopFinish
							END
						END
					-- **** END CHECK 16 *****

					-- **** START CHECK 13 --> Maximum consulations (13)*****
						IF @BaseCategory  = 'C'
						BEGIN
							SET @LimitNo = -1
							SELECT TOP 1 @LimitNo = MaxNoConsultation FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID 
								--FROM         tblClaimServices INNER JOIN
								--					  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--					  tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--					  @EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--					  (tblServices.ServCategory = 'C') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID  
								--) Sub

								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'C'


								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									--Over Maximum consulations (13)
									SET @FAULTCODE = 13
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 13 *****

						-- **** START CHECK 14 --> Maximum Surgeries (14)*****	
						IF @BaseCategory = 'S'
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoSurgery FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID
								--FROM         tblClaimServices INNER JOIN
								--						tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--						tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--						(tblServices.ServCategory = 'S') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID 
								--) Sub

								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'S'

								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									----Over  Maximum Surgeries (14)
									SET @FAULTCODE = 14
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 14 *****

						-- **** START CHECK 15 --> Maximum Deliveries (15)*****	
						IF @BaseCategory = 'D'
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoDelivery FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID
								--FROM         tblClaimServices INNER JOIN
								--						tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--						tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND  (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--						(tblServices.ServCategory = 'D') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID
								--) Sub
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'D'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									----Over  Maximum deliveries (15)
									SET @FAULTCODE = 15
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 15 *****

						-- **** START CHECK 19 --> Maximum Antenatal  (19)*****	
						IF @BaseCategory = 'A'
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoAntenatal  FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
							BEGIN
								SET @Count = 0 
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(
								--SELECT tblClaim.ClaimID
								--FROM         tblClaimServices INNER JOIN
								--						tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--						tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--						(tblServices.ServCategory = 'A') AND tblClaimServices.RejectionReason  = 0
								--GROUP BY tblClaim.ClaimID
								--) Sub
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'A'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									----Over  Maximum Antenatal (19)
									SET @FAULTCODE = 19
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END


						-- **** START CHECK 11 --> Maximum Hospital admissions (11)*****

						IF (@BaseCategory  = 'H') --(@ClaimStartDate < @ClaimEndDate )
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = MaxNoHospitalizaion FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check    A hospital stay is defined as a differnece between the datefrom and dateto on Claim level (not looking at items/Services !!)
							BEGIN		
								SET @Count = 0 
			
								--SELECT @COUNT = COUNT(tblClaim.ClaimID) 
								--FROM        
								--						tblClaim
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--						@EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ( ISNULL(tblClaim.DateTo, tblClaim.DateFrom) > tblClaim.DateFrom)
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'H'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									--Over Maximum Hospital admissions(11)
									
									SET @FAULTCODE = 11
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 11 *****


						-- **** START CHECK 12 --> Maximum Visits (OP) (12)*****	
						--IF (@ServCategory = 'C' OR @ServCategory = 'D') AND (ISNULL(@ClaimEndDate,@ClaimStartDate) = @ClaimStartDate )
						IF (@BaseCategory  = 'V') 
						BEGIN
							SET @LimitNo = -1 
							SELECT TOP 1 @LimitNo = [MaxNoVisits] FROM [dbo].[tblProduct] WHERE [ProdID] = @ProductID 

							IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check    A visit  is defined as the datefrom and dateto the same AND having at least one oitem of service category S or C 
							BEGIN		
								SET @Count = 0 
							
								--SELECT @COUNT = COUNT(ClaimID)
								--FROM
								--(SELECT tblClaim.ClaimID
								-- FROM         tblClaimServices INNER JOIN
								--					  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
								--					  tblServices ON tblClaimServices.ServiceID = tblServices.ServiceID
								--WHERE     (tblClaim.InsureeID = @InsureeID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN 
								--					  @EffectiveDateInsuree AND @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ValidityTo IS NULL) AND 
								--					  (tblServices.ServCategory = 'C' OR
								--					  tblServices.ServCategory = 'S') AND (tblClaimServices.RejectionReason = 0) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) = tblClaim.DateFrom)
								--GROUP BY tblClaim.ClaimID) Sub
								SELECT @Count = COUNT(ClaimID) from tblClaim WHERE  (tblClaim.InsureeID = @InsureeID)  AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND @ExpiryDateInsuree) 
												AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND ISNULL(ClaimCategory,'V') = 'V'
								IF ISNULL(@Count,0) >= @LimitNo 
								BEGIN
									--Over Maximum Visits (12)
									
									SET @FAULTCODE = 12
									CLOSE PRODSERVICELOOP
									DEALLOCATE PRODSERVICELOOP
									CLOSE CLAIMSERVICELOOP
									DEALLOCATE CLAIMSERVICELOOP
									GOTO UPDATECLAIM
								END
							END
						END
						-- **** END CHECK 12 *****
						
						SET @FAULTCODE = 0
						GOTO ProdLoopFinishServices


			ProdServiceNext:
						FETCH NEXT FROM PRODSERVICELOOP INTO @ProductID ,@ProdServiceID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
					END
		
				ProdLoopFinishServices:

					CLOSE PRODSERVICELOOP
					DEALLOCATE PRODSERVICELOOP
		
					IF @ProdFound = 0 
						SET @FAULTCODE = 3 
		
					IF @FAULTCODE <> 0
					BEGIN
						UPDATE tblClaimServices SET RejectionReason = @FAULTCODE WHERE ClaimServiceID = @ClaimServiceID
						GOTO NextService
					END


		NextService:	
		FETCH NEXT FROM CLAIMSERVICELOOP INTO @ClaimServiceID,@ServiceID
	END
	CLOSE CLAIMSERVICELOOP
	DEALLOCATE CLAIMSERVICELOOP
	
	DECLARE CLAIMITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR SELECT ClaimItemID,ItemID FROM TblClaimItems WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 
	OPEN CLAIMITEMLOOP
	FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID,@ItemID
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
		SELECT @CareType =  ItemCareType  FROM @DTBL_ITEMS WHERE [ItemID] = @ItemID
		-- **** START CHECK 10 --> Item Care type / HF caretype Fail (10)*****
		
		IF  (@CareType = 'I' AND (@HFCareType = 'O' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) = @ClaimDateFrom)  )) 
					OR  (@CareType = 'O' AND (@HFCareType = 'I' OR (ISNULL(@ClaimDateTo,@ClaimDateFrom) <> @ClaimDateFrom)))	

		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimItems SET RejectionReason = 10 WHERE ClaimItemID   = @ClaimItemID 
			GOTO NextItem
		END
		-- **** END CHECK 10 *****	

		-- **** START CHECK 4 --> Item/Service Limitation Fail (4)*****
		SELECT TOP 1 @ItemPatCat = ItemPatCat FROM @DTBL_ITEMS WHERE ItemID  = @ItemID  
		IF (@ItemPatCat  & @PatientMask) <> @PatientMask 	
		BEGIN
			--inconsistant patient type check 
			UPDATE tblClaimItems SET RejectionReason = 4 WHERE ClaimItemID   = @ClaimItemID 
			GOTO NextItem
		END
		-- **** END CHECK 4 *****	
		
		SET @FAULTCODE = 0 
		SET @ProdFound = 0

		IF @Adult = 1 
				DECLARE PRODITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR 
				SELECT  TblProduct.ProdID , tblProductItems.ProdItemID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
				FROM tblFamilies 
				INNER JOIN tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID 
				INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID 
				INNER JOIN tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID
											AND @TargetDate BETWEEN tblProductItems.ValidityFrom AND ISNULL(tblProductItems.ValidityTo, GETDATE())
				INNER JOIN tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
				WHERE tblPolicy.EffectiveDate <= @TargetDate 
				AND tblPolicy.ExpiryDate >= @TargetDate
				AND tblPolicy.ValidityTo IS NULL
				--AND tblProductItems.ValidityTo IS NULL
				AND (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8)
				AND tblProductItems.ItemID = @ItemID 
				AND tblFamilies.FamilyID = @FamilyID 
				AND tblProduct.ValidityTo IS NULL
				AND tblInsureePolicy.EffectiveDate <= @TargetDate
				AND tblInsureePolicy.ExpiryDate >= @TargetDate 
				AND tblInsureePolicy.InsureeId = @InsureeID
				AND tblInsureePolicy.ValidityTo IS NULL
				ORDER BY DATEADD(m,ISNULL(tblProductItems.WaitingPeriodAdult, 0), tblInsureePolicy.EffectiveDate)
		ELSE
				DECLARE PRODITEMLOOP CURSOR LOCAL FORWARD_ONLY FOR 
				SELECT  TblProduct.ProdID , tblProductItems.ProdItemID , tblInsureePolicy.EffectiveDate,  tblPolicy.EffectiveDate, tblInsureePolicy.ExpiryDate  , tblPolicy.PolicyStage
				FROM tblFamilies 
				INNER JOIN tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID 
				INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID 
				INNER JOIN tblProductItems ON tblProduct.ProdID = tblProductItems.ProdID 
										AND @TargetDate BETWEEN tblProductItems.ValidityFrom AND ISNULL(tblProductItems.ValidityTo, GETDATE())
				INNER JOIN tblInsureePolicy ON tblPolicy.PolicyID = tblInsureePolicy.PolicyId
				WHERE tblPolicy.EffectiveDate <= @TargetDate 
				AND tblPolicy.ExpiryDate >= @TargetDate 
				AND tblPolicy.ValidityTo IS NULL
				AND (tblPolicy.PolicyStatus = 2 OR tblPolicy.PolicyStatus = 8) 
				AND tblProductItems.ItemID = @ItemID 
				AND tblFamilies.FamilyID = @FamilyID 
				AND (tblProduct.ValidityTo IS NULL) 
				AND tblInsureePolicy.EffectiveDate <= @TargetDate 
				AND tblInsureePolicy.ExpiryDate >= @TargetDate 
				AND tblInsureePolicy.InsureeId = @InsureeID 
				AND tblInsureePolicy.ValidityTo IS NULL
				ORDER BY DATEADD(m,ISNULL(tblProductItems.WaitingPeriodChild, 0), tblInsureePolicy.EffectiveDate)

		
		OPEN PRODITEMLOOP
		FETCH NEXT FROM PRODITEMLOOP INTO @ProductID ,@ProdItemID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SET @ProdFound= 1 --at least there is a product that would cover --> still to check on waiting period!
			
			-- **** START CHECK 17 --> Item/Service waiting period violation (17)*****	
			IF @PolicyStage = 'N' or (@EffectiveDatePolicy < @EffectiveDateInsuree )     --new policy or Insuree was added after policy was defined.
 			BEGIN
				IF @Adult = 1 
					SELECT  @WaitingPeriod = [WaitingPeriodAdult] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
				ELSE
					SELECT  @WaitingPeriod = [WaitingPeriodChild] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
		

				IF @TargetDate < DATEADD(m,@WaitingPeriod,@EffectiveDateInsuree)	
				BEGIN
					--Item/Service waiting period violation (17)
					IF @FAULTCODE = 0 
						SET @FAULTCODE = 17
					GOTO ProdItemNext --ProdLoopFinish
				END
			
			END
			-- **** END CHECK 17 *****

			-- **** START CHECK 16 --> Item/Service Maximum provision (16)*****	
			SET @LimitNo = -1
			IF @Adult = 1 
				SELECT  @LimitNo = [LimitNoAdult] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
			ELSE
				SELECT  @LimitNo = [LimitNoChild] FROM [dbo].[tblProductItems] WHERE [ProdItemID] = @ProdItemID 
		

			IF ISNULL(@LimitNo,-1) > -1   --limits are defined --> we need to check 
			BEGIN
				SET @Count = 0 
				SELECT @COUNT = SUM(tblClaimItems.QtyProvided)  
				FROM         tblClaimItems INNER JOIN
									  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID
				WHERE     (tblClaim.InsureeID = @InsureeID) AND (tblClaimItems.ItemID = @ItemID) AND (ISNULL(tblClaim.DateTo, tblClaim.DateFrom) BETWEEN @EffectiveDateInsuree AND 
									  @ExpiryDateInsuree) AND (tblClaim.ClaimStatus > 2) AND (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ValidityTo IS NULL) AND tblClaimItems.RejectionReason  = 0  
			
				IF ISNULL(@Count,0) >= @LimitNo  
				BEGIN
					--Over Item/Service Maximum Number allowed  (16)
					IF @FAULTCODE = 0 
						SET @FAULTCODE = 16
					GOTO ProdItemNext --ProdLoopFinish
				END
			END
		-- **** END CHECK 16 *****

		    SET @FAULTCODE = 0
			GOTO ProdLoopFinishItems

ProdItemNext:
			FETCH NEXT FROM PRODITEMLOOP INTO @ProductID ,@ProdItemID,@EffectiveDateInsuree,@EffectiveDatePolicy,@ExpiryDateInsuree,@PolicyStage
		END
		
	ProdLoopFinishItems:

		CLOSE PRODITEMLOOP
		DEALLOCATE PRODITEMLOOP
		
		IF @ProdFound = 0 
			SET @FAULTCODE = 3 
		
		IF @FAULTCODE <> 0
		BEGIN
			UPDATE tblClaimItems SET RejectionReason = @FAULTCODE WHERE ClaimItemID = @ClaimItemID
			GOTO NextItem
		END
		
		NextItem:
		FETCH NEXT FROM CLAIMITEMLOOP INTO @ClaimItemID,@ItemID
	END
	CLOSE CLAIMITEMLOOP
	DEALLOCATE CLAIMITEMLOOP
		
	--***** START CHECK 5 ITEMS ***** --> Item/Service Limitation Fail (5)
	UPDATE tblClaimItems SET RejectionReason = 5 WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 AND ItemID IN
	(
	SELECT ClaimedItems.ItemID FROM
	(
	SELECT     Items.ItemFrequency, tblClaim.InsureeID, tblClaimItems.ItemID
	FROM         tblClaimItems INNER JOIN
				  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID
	WHERE     (Items.ItemFrequency > 0) AND (tblClaim.ClaimID = @ClaimID) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0)
	) ClaimedItems 
	INNER JOIN 
	(
	SELECT     Items.ItemFrequency, tblClaim.InsureeID, tblClaimItems.ItemID
	FROM         tblClaimItems INNER JOIN
				  tblClaim ON tblClaimItems.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_ITEMS Items ON tblClaimItems.ItemID = Items.ItemID
	WHERE     (Items.ItemFrequency > 0) AND (tblClaimItems.ValidityTo IS NULL) AND (tblClaimItems.RejectionReason = 0) AND (tblClaim.InsureeID = @InsureeID) AND 
				  (tblClaim.ValidityTo IS NULL) AND (tblClaimItems.ClaimItemStatus = 1) AND (tblClaim.ClaimStatus > 2)
				  AND ABS(DATEDIFF(DD  ,ISNULL(tblClaim.DateTo,tblClaim.DateFrom) ,@TargetDate )) < ItemFrequency
	) ClaimedPrevious  --already checked,processed or valuated claims with passed items within frequency limit of days from the claim to be checked for certain Insuree
	ON ClaimedItems.InsureeID = ClaimedPrevious.InsureeID AND ClaimedItems.ItemID = ClaimedPrevious.ItemID 
	)
	-- **** END CHECK 5 ITEMS *****
	
	--***** START CHECK 5 SERVICESS ***** --> Item/Service Limitation Fail (5)
	UPDATE tblClaimServices SET RejectionReason = 5 WHERE ClaimID = @ClaimID AND ValidityTo IS NULL AND RejectionReason = 0 AND ServiceID IN
	(
	SELECT ClaimedServices.ServiceID FROM
	(
	SELECT     [Services].ServFrequency, tblClaim.InsureeID, tblClaimServices.ServiceID
	FROM         tblClaimServices INNER JOIN
				  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_SERVICES [Services] ON tblClaimServices.ServiceID = [Services].ServiceID
	WHERE     ([Services].ServFrequency > 0) AND (tblClaim.ClaimID = @ClaimID) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0)
	) ClaimedServices 
	INNER JOIN 
	(
	SELECT     [Services].ServFrequency, tblClaim.InsureeID, tblClaimServices.ServiceID
	FROM         tblClaimServices INNER JOIN
				  tblClaim ON tblClaimServices.ClaimID = tblClaim.ClaimID INNER JOIN
				  @DTBL_SERVICES [Services] ON tblClaimServices.ServiceID = [Services].ServiceID
	WHERE     ([Services].ServFrequency > 0) AND (tblClaimServices.ValidityTo IS NULL) AND (tblClaimServices.RejectionReason = 0) AND (tblClaim.InsureeID = @InsureeID) AND 
				  (tblClaim.ValidityTo IS NULL) AND (tblClaimServices.ClaimServiceStatus = 1) AND (tblClaim.ClaimStatus > 2)
				  AND ABS(DATEDIFF(DD  ,ISNULL(tblClaim.DateTo,tblClaim.DateFrom) ,@TargetDate )) < ServFrequency
	) ClaimedPrevious  --already checked,processed or valuated claims with passed services within frequency limit of days from the claim to be checked for certain Insuree
	ON ClaimedServices.InsureeID = ClaimedPrevious.InsureeID AND ClaimedServices.ServiceID = ClaimedPrevious.ServiceID 
	)
	-- **** END CHECK 5 SERVICES *****




UPDATECLAIM:

	IF @FAULTCODE IN (11,12,13,14,15,19) 
	BEGIN
		--we went over themaximum of a category --> all items and services in the claim are rejected !!
		UPDATE tblClaimItems SET ClaimItemStatus = 2, QtyApproved = 0 , RejectionReason = @FAULTCODE  WHERE ClaimID = @ClaimID  
		UPDATE tblClaimServices SET ClaimServiceStatus = 2, QtyApproved = 0,  RejectionReason = @FAULTCODE  WHERE ClaimID = @ClaimID 
		
	END
	ELSE
	BEGIN
		UPDATE tblClaimItems SET ClaimItemStatus = 2, QtyApproved = 0 WHERE ClaimID = @ClaimID  AND  RejectionReason <> 0 
		UPDATE tblClaimServices SET ClaimServiceStatus = 2, QtyApproved = 0 WHERE ClaimID = @ClaimID AND RejectionReason <> 0 
	
	END

	
	SELECT @RtnItemsPassed = ISNULL(COUNT(ClaimItemID),0) FROM dbo.tblClaimItems WHERE ClaimID = @ClaimID AND ClaimItemStatus = 1 AND ValidityTo IS NULL
	SELECT @RtnServicesPassed  = ISNULL(COUNT(ClaimServiceID),0) FROM dbo.tblClaimServices  WHERE ClaimID = @ClaimID AND ClaimServiceStatus = 1 AND ValidityTo IS NULL
	SELECT @RtnItemsRejected = ISNULL(COUNT(ClaimItemID),0) FROM dbo.tblClaimItems WHERE ClaimID = @ClaimID AND ClaimItemStatus = 2 AND ValidityTo IS NULL
	SELECT @RtnServicesRejected  = ISNULL(COUNT(ClaimServiceID),0) FROM dbo.tblClaimServices  WHERE ClaimID = @ClaimID AND ClaimServiceStatus = 2 AND ValidityTo IS NULL
	
	DECLARE @AppItemValue as decimal(18,2)
	DECLARE @AppServiceValue as decimal(18,2)
	SET @AppItemValue = 0 
	SET @AppServiceValue = 0 
	
	IF @RtnItemsPassed > 0  OR @RtnServicesPassed > 0  --UPDATE CLAIM TO PASSED !! (default is not yet passed before checking procedure 
	BEGIN
		IF @RtnItemsRejected > 0 OR @RtnServicesRejected > 0
		BEGIN
			--Update Claim Approved Value 
			SELECT @AppItemValue = ISNULL(SUM((ISNULL(QtyProvided,QtyApproved) * ISNULL(PriceAsked ,PriceApproved))), 0) 
									FROM tblClaimItems WHERE 
										  (tblClaimItems.ValidityTo IS NULL )
										  AND (tblClaimItems.ClaimItemStatus = 1) 
										  AND (tblClaimItems.ClaimID  = @ClaimID)
									
			SELECT @AppServiceValue = ISNULL(SUM((ISNULL(QtyProvided,QtyApproved) * ISNULL(PriceAsked ,PriceApproved))), 0) 
									FROM tblClaimServices WHERE 
										  (tblClaimServices.ValidityTo IS NULL )
										  AND (tblClaimServices.ClaimServiceStatus = 1) 
										  AND (tblClaimServices.ClaimID  = @ClaimID)
			
			--update claim approved value due to some rejections (not all rejected!)
			UPDATE tblClaim SET ClaimStatus = 4, Approved = (@AppItemValue + @AppServiceValue) , AuditUserIDSubmit = @AuditUser , SubmitStamp = GETDATE() ,  ClaimCategory = @BaseCategory WHERE ClaimID = @ClaimID 
		END
		ELSE
		BEGIN
			--no rejections 
			UPDATE tblClaim SET ClaimStatus = 4, AuditUserIDSubmit = @AuditUser , SubmitStamp = GETDATE() ,  ClaimCategory = @BaseCategory WHERE ClaimID = @ClaimID 
		END
		SET @RtnStatus = 1 
	END
	ELSE
	BEGIN
		UPDATE tblClaim SET ClaimStatus = 1, AuditUserIDSubmit = @AuditUser , SubmitStamp = GETDATE() ,  ClaimCategory = @BaseCategory WHERE ClaimID = @ClaimID --> set rejected as all items ands services did not pass ! 
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
