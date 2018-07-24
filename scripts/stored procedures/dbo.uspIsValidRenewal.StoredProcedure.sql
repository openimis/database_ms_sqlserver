USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspIsValidRenewal]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspIsValidRenewal]
(
	@FileName NVARCHAR(100)
)
AS
BEGIN

	--DECLARE @FilePath NVARCHAR(250)
	DECLARE @XML XML
	DECLARE @RenewalId INT
	DECLARE @CHFID VARCHAR(12) 
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
	
	--SELECT @FilePath = 'C:/inetpub/wwwroot/IMIS' + FTPPolicyRenewalFolder + '/' + @FileName FROM tblIMISDefaults
	
	SET @Query =  (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')

	EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
	
	SELECT 
	@RenewalId = T.Policy.query('RenewalId').value('.','INT'),
	@CHFID = T.Policy.query('CHFID').value('.','VARCHAR(12)'),
	@ProductCode =  T.Policy.query('ProductCode').value('.','VARCHAR(15)'),
	@Officer = T.Policy.query('Officer').value('.','VARCHAR(15)') ,
	@Date = T.Policy.query('Date').value('.','DATE'),
	@Amount = T.Policy.query('Amount').value('.','DECIMAL(18,2)'),
	@Receipt = T.Policy.query('ReceiptNo').value('.','NVARCHAR(50)'),
	@Discontinue = T.policy.query('Discontinue').value('.','VARCHAR(10)'),
	@PayerId = NULLIF(T.policy.query('PayerId').value('.', 'INT'), 0)
	FROM 
	@XML.nodes('Policy') AS T(Policy);


	--Insert the file details in the tblFromPhone
	--Initially we keep to DocStatus REJECTED and once the renewal is accepted we will update the Status
	INSERT INTO tblFromPhone(DocType, DocName, DocStatus, OfficerCode, CHFID)
	SELECT N'R' DocType, @FileName DocName, N'R' DocStatus, @Officer OfficerCode, @CHFID CHFID;

	SELECT @FromPhoneId = SCOPE_IDENTITY();

	DECLARE @PreviousPolicyId INT = 0

	SELECT @PreviousPolicyId = PolicyId FROM tblPolicyRenewals WHERE ValidityTo IS NULL AND RenewalID = @RenewalId;


	DECLARE @Tbl TABLE(Id INT)

	INSERT INTO @Tbl(Id)
	SELECT TOP 1 I.InsureeID Result
	FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
	INNER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
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

	SELECT TOP 1 @ProdId = tblPolicy.ProdID, @ExpiryDate = tblPolicy.ExpiryDate from tblPolicy INNER JOIN tblProduct ON tblPolicy.ProdID = tblProduct.ProdID WHERE FamilyID = @FamilyID AND tblProduct.ProductCode = @ProductCode AND tblProduct.ValidityTo IS NULL ORDER BY ExpiryDate DESC
	
	IF EXISTS(SELECT 1 FROM tblPremium PR INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID 
				WHERE PR.Receipt = @Receipt 
				AND PL.ProdID = @ProdId
				AND PR.ValidityTo IS NULL)

				RETURN -1;
	
	--Check if the renewal is not after the grace period
	DECLARE @LastRenewalDate DATE
	SELECT @LastRenewalDate = DATEADD(MONTH,GracePeriodRenewal,DATEADD(DAY,1,@ExpiryDate))
	FROM tblProduct
	WHERE ValidityTo IS NULL
	AND ProdId = @ProdId;
	
	IF @LastRenewalDate < @Date
		RETURN -2
	
	SELECT @RecordCount = COUNT(1) FROM @Tbl;
	
	IF @RecordCount = 2
	BEGIN
		IF @Discontinue = 'false' OR @Discontinue = N''
			BEGIN

				--Get policy period
				DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)

				INSERT INTO @tblPeriod
				EXEC uspGetPolicyPeriod @ProdId, @ExpiryDate, @HasCycle OUTPUT;

				IF @HasCycle = 1
					SELECT @StartDate = StartDate, @ExpiryDate = ExpiryDate FROM @tblPeriod;
				ELSE
					SELECT @StartDate = @Date, @ExpiryDate = DATEADD(DAY,-1,DATEADD(MONTH,InsurancePeriod,@Date)) FROM tblProduct WHERE ProdID = @ProdId;


				DECLARE @OfficerID INT = (SELECT OfficerID FROM tblOfficer WHERE Code = @Officer AND ValidityTo IS NULL)
				DECLARE @PolicyValue DECIMAL(18,2) 
				--EXEC @PolicyValue = uspPolicyValue 0, 0,@FamilyID, @ProdId,@Date, 
				EXEC @PolicyValue = uspPolicyValue
										@FamilyId = @FamilyID,
										@ProdId = @ProdId,
										@EnrollDate = @Date,
										@PreviousPolicyId = @PreviousPolicyId,
										@PolicyStage = 'R';
		
				DECLARE @PolicyStatus TINYINT = 2
		
				IF @Amount < @PolicyValue SET @PolicyStatus = 1
		
				INSERT INTO tblPolicy(FamilyID, EnrollDate, StartDate, EffectiveDate, ExpiryDate, PolicyStatus, PolicyValue, ProdID, OfficerID, AuditUserID, PolicyStage)
								VALUES(@FamilyID, @Date, @StartDate, @StartDate,@ExpiryDate, @PolicyStatus, @PolicyValue, @ProdId, @OfficerID, 0, 'R')
		
				DECLARE @PolicyID INT = (SELECT SCOPE_IDENTITY())
		
				INSERT INTO tblPremium(PolicyID, Amount, Receipt, PayDate, PayType, AuditUserID, PayerID)
								Values(@PolicyID, @Amount, @Receipt, @Date, 'C',0, @PayerId)
				

				INSERT INTO tblInsureePolicy(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,AuditUserId,isOffline)
				SELECT I.InsureeID,PL.PolicyID,PL.EnrollDate,PL.StartDate,PL.EffectiveDate,PL.ExpiryDate,PL.AuditUserID,I.isOffline 
				FROM tblInsuree I INNER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID 
				WHERE(I.ValidityTo Is NULL) 
				AND PL.ValidityTo IS NULL 
				AND PL.PolicyID = @PolicyId;

				UPDATE tblPolicyRenewals SET ResponseStatus = 1, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId;
			END
		ELSE
			BEGIN
				UPDATE tblPolicyRenewals SET ResponseStatus = 2, ResponseDate = GETDATE() WHERE RenewalId = @RenewalId
			END

		UPDATE tblFromPhone SET DocStatus = N'A' WHERE FromPhoneId = @FromPhoneId;
		
		SELECT * FROM @Tbl;
	END
END
GO
