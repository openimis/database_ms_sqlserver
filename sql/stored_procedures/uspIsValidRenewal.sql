IF OBJECT_ID('[dbo].[uspIsValidRenewal]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspIsValidRenewal]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(200) = '',
	@XML XML
)
/*
	-5: Fatal Error
	 0: All OK
	-1: Duplicate Receipt found
	-2: Grace Period is over
	-3: Renewal was alredy rejected
	-4: Renewal was alredy accepted
	
*/
AS
BEGIN
	BEGIN TRY

	--DECLARE @FilePath NVARCHAR(250)
	--DECLARE @XML XML
	DECLARE @RenewalId INT
	DECLARE @CHFID VARCHAR(50) 
	DECLARE @ProductCode VARCHAR(15)
	DECLARE @Officer VARCHAR(15)
	DECLARE @Date DATE
	DECLARE @Amount DECIMAL(18,2)
	DECLARE @Receipt NVARCHAR(50)
	DECLARE @Discontinue VARCHAR(10)
	DECLARE @PayerId INT
	DECLARE @Query NVARCHAR(3000)
	
	DECLARE @FromPhoneId INT = 0;
	DECLARE @RecordCount INT = 0
	DECLARE @RenewalOrder INT = 0
	DECLARE @ResponseStatus INT = 0
	
	SELECT 
	@RenewalId = T.Policy.query('RenewalId').value('.','INT'),
	@CHFID = T.Policy.query('CHFID').value('.','VARCHAR(50)'),
	@ProductCode =  T.Policy.query('ProductCode').value('.','VARCHAR(15)'),
	@Officer = T.Policy.query('Officer').value('.','VARCHAR(15)') ,
	@Date = T.Policy.query('Date').value('.','DATE'),
	@Amount = T.Policy.query('Amount').value('.','DECIMAL(18,2)'),
	@Receipt = T.Policy.query('ReceiptNo').value('.','NVARCHAR(50)'),
	@Discontinue = T.policy.query('Discontinue').value('.','VARCHAR(10)'),
	@PayerId = NULLIF(T.policy.query('PayerId').value('.', 'INT'), 0)
	FROM 
	@XML.nodes('Policy') AS T(Policy);

	IF NOT ( @XML.exist('(Policy/RenewalId)')=1 )
		RETURN -5


	--Checking if the renewal already exists and get the status
	DECLARE @DocStatus NVARCHAR(1)
	SELECT @DocStatus = FP.DocStatus FROM tblPolicyRenewals PR
			INNER JOIN tblOfficer O ON PR.NewOfficerID = O.OfficerID
			INNER JOIN tblFromPhone FP ON FP.OfficerCode = O.Code
			WHERE O.ValidityTo IS NULL 
			AND OfficerCode = @Officer AND CHFID = @CHFID AND PR.RenewalID = @RenewalId
	
	
	
	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId,@ResponseStatus=ResponseStatus FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;
	IF @ResponseStatus = 1 
		BEGIN
			RETURN - 4
		END


	DECLARE @Tbl TABLE(Id INT)

	
	;WITH PrevProducts
	AS
	(
		SELECT Prod.ProductCode, Prod.ProdId, OldProd.ProdID PrevProd
		FROM tblProduct Prod
		LEFT OUTER JOIN tblProduct OldProd ON Prod.ProdId = OldProd.ConversionProdId
		WHERE Prod.ValidityTo IS NULL
		AND OldProd.ValidityTo IS NULL
		AND Prod.ProductCode = @ProductCode
	)
	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN PrevProducts PR ON PL.ProdId = PR.ProdId OR PL.ProdId = PR.PrevProd --PL.ProdID = PR.ProdID
	WHERE CHFID = @CHFID
	AND PR.ProductCode = @ProductCode
	AND I.ValidityTo IS NULL
	AND PL.ValidityTo IS NULL
	UNION ALL
		SELECT OfficerID
		FROM tblOfficer
		WHERE Code =@Officer
		AND ValidityTo IS NULL
	
	
	DECLARE @FamilyID INT = (SELECT FamilyId from tblInsuree WHERE CHFID = @CHFID AND ValidityTo IS NULL)
	DECLARE @ProdId INT
	DECLARE @StartDate DATE
	DECLARE @ExpiryDate DATE
	DECLARE @HasCycle BIT
	--PAUL -24/04/2019 INSERTED  @@AND tblPolicy.ValidityTo@@ to ensure that query does not include deleted policies
	;WITH PrevProducts
	AS
	(
		SELECT Prod.ProductCode, Prod.ProdId, OldProd.ProdID PrevProd
		FROM tblProduct Prod
		LEFT OUTER JOIN tblProduct OldProd ON Prod.ProdId = OldProd.ConversionProdId
		WHERE Prod.ValidityTo IS NULL
		AND OldProd.ValidityTo IS NULL
		AND Prod.ProductCode = @ProductCode
	)
	SELECT TOP 1 @ProdId = PR.ProdId, @ExpiryDate = PL.ExpiryDate
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN PrevProducts PR ON PL.ProdId = PR.ProdId OR PL.ProdId = PR.PrevProd 
	WHERE CHFID = @CHFID
	AND PR.ProductCode = @ProductCode
	AND I.ValidityTo IS NULL
	AND PL.ValidityTo IS NULL
	ORDER BY PL.ExpiryDate DESC;

	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL
				AND LEN(PR.Receipt) > 0)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	
		--IF EXISTS(SELECT 1 FROM tblProduct WHERE ProdId = @ProdId AND LEN(StartCycle1) > 0)
		--	--CHECK IF IT IS A FREE PRODUCT AND IGNORE GRACE PERIOD RENEWAL, IF IS NOT A FREE PRODUCT RETURN -2	
		--	IF @LastRenewalDate < @Date 
		--		BEGIN					  
		--			RETURN -2
		--		END
		SELECT @RecordCount = COUNT(1) FROM @Tbl;
		
	
	IF @RecordCount = 2
		BEGIN
			IF @Discontinue = 'false' OR @Discontinue = N''
				BEGIN
					
					DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)
					DECLARE @EnrolmentDate DATE =DATEADD(D,1,@ExpiryDate)
					INSERT INTO @tblPeriod
					EXEC uspGetPolicyPeriod @ProdId, @Date, @HasCycle OUTPUT,'R';

					DECLARE @ExpiryDatePreviousPolicy DATE
				
					SELECT @ExpiryDatePreviousPolicy = ExpiryDate FROM tblPolicy WHERE PolicyID=@PreviousPolicyId AND ValidityTo IS NULL
					
				
					IF @HasCycle = 1
						BEGIN
							SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
							IF @StartDate < @ExpiryDatePreviousPolicy
								BEGIN
									UPDATE @tblPeriod SET StartDate=DATEADD(DAY, 1, @ExpiryDatePreviousPolicy)
									SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
								END	
						END
					ELSE
						BEGIN
					
						IF @Date < @ExpiryDate						 
							SELECT @StartDate =DATEADD(D,1,@ExpiryDate), @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,DATEADD(D,1,@ExpiryDate))) FROM tblProduct WHERE ProdID = @ProdId;
						ELSE
							SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;
						END
					


					DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
					DECLARE @PolicyValue DECIMAL(18,2) 
				
						SET @EnrolmentDate = @Date
					EXEC @PolicyValue = uspPolicyValue
											@FamilyId = @FamilyID,
											@ProdId = @ProdId,
											@EnrollDate = @EnrolmentDate,
											@PreviousPolicyId = @PreviousPolicyId,
											@PolicyStage = 'R';
		
					DECLARE @PolicyStatus TINYINT = 2
		
					IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
					INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
									VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
					DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
					
					-- No need to create if the payment is not made yet
					IF @Amount > 0
					BEGIN
						INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
										Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
					END

				
					DECLARE @InsureeId INT
								DECLARE CurNewPolicy CURSOR FOR SELECT I.InsureeID FROM tblInsuree I 
								INNER JOIN tblFamilies F ON I.FamilyID = F.FamilyID 
								INNER JOIN tblPolicy P ON P.FamilyID = F.FamilyID 
								WHERE P.PolicyId = @PolicyId 
								AND I.ValidityTo IS NULL 
								AND F.ValidityTo IS NULL
								AND P.ValidityTo IS NULL
								OPEN CurNewPolicy;
								FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
								WHILE @@FETCH_STATUS = 0
								BEGIN
									EXEC uspAddInsureePolicy @InsureeId;
									FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
								END
								CLOSE CurNewPolicy;
								DEALLOCATE CurNewPolicy; 

					UPDATE tblPolicyRenewals SET ResponseStatus = 1, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId;
				END
			ELSE
				BEGIN
					UPDATE tblPolicyRenewals SET ResponseStatus = 2, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId
				END

				UPDATE tblFromPhone SET DocStatus = N'A' WHERE FromPhoneId = @FromPhoneId;
		
				SELECT * FROM @Tbl;
		END
	ELSE
		BEGIN
			RETURN -5
		END
END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END
GO
