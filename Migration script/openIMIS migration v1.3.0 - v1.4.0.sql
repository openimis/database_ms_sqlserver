--- MIGRATION Script from v1.3.0 to v1.4.0

-- OS-13: Preparing the migration script for an existing database

IF COL_LENGTH('tblUsers', 'UserUUID') IS NULL
BEGIN
	ALTER TABLE tblUsers ADD UserUUID uniqueidentifier NOT NULL DEFAULT NEWID() 
END

IF COL_LENGTH('tblLocations', 'LocationUUID') IS NULL
BEGIN
	ALTER TABLE tblLocations ADD LocationUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblHF', 'HfUUID') IS NULL
BEGIN
	ALTER TABLE tblHF ADD HfUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblClaim', 'ClaimUUID') IS NULL
BEGIN
	ALTER TABLE tblClaim ADD ClaimUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblProduct', 'ProdUUID') IS NULL
BEGIN
	ALTER TABLE tblProduct ADD ProdUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblFamilies', 'FamilyUUID') IS NULL
BEGIN
	ALTER TABLE tblFamilies ADD FamilyUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblServices', 'ServiceUUID') IS NULL
BEGIN
	ALTER TABLE tblServices ADD ServiceUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblInsuree', 'InsureeUUID') IS NULL
BEGIN
	ALTER TABLE tblInsuree ADD InsureeUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPolicy', 'PolicyUUID') IS NULL
BEGIN
	ALTER TABLE tblPolicy ADD PolicyUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblItems', 'ItemUUID') IS NULL
BEGIN
	ALTER TABLE tblItems ADD ItemUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblFeedback', 'FeedbackUUID') IS NULL
BEGIN
	ALTER TABLE tblFeedback ADD FeedbackUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblOfficer', 'OfficerUUID') IS NULL
BEGIN
	ALTER TABLE tblOfficer ADD OfficerUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPayer', 'PayerUUID') IS NULL
BEGIN
	ALTER TABLE tblPayer ADD PayerUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPremium', 'PremiumUUID') IS NULL
BEGIN
	ALTER TABLE tblPremium ADD PremiumUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblClaimAdmin', 'ClaimAdminUUID') IS NULL
BEGIN
	ALTER TABLE tblClaimAdmin ADD ClaimAdminUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblExtracts', 'ExtractUUID') IS NULL
BEGIN
	ALTER TABLE tblExtracts ADD ExtractUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPhotos', 'PhotoUUID') IS NULL
BEGIN
	ALTER TABLE tblPhotos ADD PhotoUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPLItems', 'PLItemUUID') IS NULL
BEGIN
	ALTER TABLE tblPLItems ADD PLItemUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPLServices', 'PLServiceUUID') IS NULL
BEGIN
	ALTER TABLE tblPLServices ADD PLServiceUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPolicyRenewals', 'RenewalUUID') IS NULL
BEGIN
	ALTER TABLE tblPolicyRenewals ADD RenewalUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblRole', 'RoleUUID') IS NULL
BEGIN
	ALTER TABLE tblRole ADD RoleUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END


-- *******************************************************************************************************************************************************
-- OS-29: Preparing database for modules (Payment, Claim, Coverage, Insuree)


IF COL_LENGTH('tblReporting', 'OfficerID') IS NULL
BEGIN
	ALTER TABLE tblReporting ADD OfficerID int NULL
END

IF COL_LENGTH('tblReporting', 'ReportType') IS NULL
BEGIN
	ALTER TABLE tblReporting ADD ReportType int NULL
END

IF COL_LENGTH('tblReporting', 'CammissionRate') IS NULL
BEGIN
	ALTER TABLE tblReporting ADD CammissionRate decimal(18,2) NULL
END

IF COL_LENGTH('tblReporting', 'CommissionRate') IS NULL
BEGIN
	ALTER TABLE tblReporting ADD CommissionRate decimal(18,2) NULL
END

IF COL_LENGTH('tblPremium', 'ReportingCommissionID') IS NULL
BEGIN
	ALTER TABLE tblPremium ADD ReportingCommissionID int NULL
END

IF COL_LENGTH('tblPremium', 'ReportingCommisionID') IS NULL
BEGIN
	ALTER TABLE tblPremium ADD ReportingCommisionID int NULL
END

IF TYPE_ID(N'xPayementStatus') IS NULL
BEGIN
	CREATE TYPE [dbo].[xPayementStatus] AS TABLE(
		[StatusID] [int] NULL,
		[PaymenyStatusName] [nvarchar](40) NULL
	)
END

GO

IF OBJECT_ID('tblControlNumber') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblControlNumber](
		[ControlNumberID] [bigint] IDENTITY(1,1) NOT NULL,
		[RequestedDate] [datetime] NULL,
		[ReceivedDate] [datetime] NULL,
		[RequestOrigin] [nvarchar](50) NULL,
		[ResponseOrigin] [nvarchar](50) NULL,
		[Status] [int] NULL,
		[LegacyID] [bigint] NULL,
		[ValidityFrom] [datetime] NULL,
		[ValidityTo] [datetime] NULL,
		[AuditedUserID] [int] NULL,
		[PaymentID] [bigint] NULL,
		[ControlNumber] [nvarchar](50) NULL,
		[IssuedDate] [datetime] NULL,
		[Comment] [nvarchar](max) NULL,
	 CONSTRAINT [PK_tblControlNumber] PRIMARY KEY CLUSTERED 
	(
		[ControlNumberID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END

GO

IF OBJECT_ID('tblPayment') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblPayment](
		[PaymentID] [bigint] IDENTITY(1,1) NOT NULL,
		[ExpectedAmount] [decimal](18, 2) NULL,
		[ReceivedAmount] [decimal](18, 2) NULL,
		[OfficerCode] [nvarchar](50) NULL,
		[PhoneNumber] [nvarchar](12) NULL,
		[RequestDate] [datetime] NULL,
		[ReceivedDate] [datetime] NULL,
		[PaymentStatus] [int] NULL,
		[LegacyID] [bigint] NULL,
		[ValidityFrom] [datetime] NULL,
		[ValidityTo] [datetime] NULL,
		[RowID] [timestamp] NOT NULL,
		[AuditedUSerID] [int] NULL,
		[TransactionNo] [nvarchar](50) NULL,
		[PaymentOrigin] [nvarchar](50) NULL,
		[MatchedDate] [datetime] NULL,
		[ReceiptNo] [nvarchar](100) NULL,
		[PaymentDate] [datetime] NULL,
		[RejectedReason] [nvarchar](255) NULL,
		[DateLastSMS] [datetime] NULL,
		[LanguageName] [nvarchar](10) NULL,
		[TypeOfPayment] [nvarchar](50) NULL,
		[TransferFee] [decimal](18, 2) NULL,
	 CONSTRAINT [PK_tblPayment] PRIMARY KEY CLUSTERED 
	(
		[PaymentID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END

GO

IF OBJECT_ID('tblPaymentDetails') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblPaymentDetails](
		[PaymentDetailsID] [bigint] IDENTITY(1,1) NOT NULL,
		[PaymentID] [bigint] NOT NULL,
		[ProductCode] [nvarchar](8) NULL,
		[InsuranceNumber] [nvarchar](12) NULL,
		[PolicyStage] [nvarchar](1) NULL,
		[Amount] [decimal](18, 2) NULL,
		[LegacyID] [bigint] NULL,
		[ValidityFrom] [datetime] NULL,
		[ValidityTo] [datetime] NULL,
		[RowID] [timestamp] NULL,
		[PremiumID] [int] NULL,
		[AuditedUserId] [int] NULL,
		[enrollmentDate] [date] NULL,
		[ExpectedAmount] [decimal](18, 2) NULL,
	 CONSTRAINT [PK_tblPaymentDetails] PRIMARY KEY CLUSTERED 
	(
		[PaymentDetailsID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END

GO

IF NOT OBJECT_ID('uspAcknowledgeControlNumberRequest') IS NULL
DROP PROCEDURE uspAcknowledgeControlNumberRequest
GO
CREATE PROCEDURE [dbo].[uspAcknowledgeControlNumberRequest]
(
	
	@XML XML
)
AS
BEGIN

	DECLARE
	@PaymentID INT,
    @Success BIT,
    @Comment  NVARCHAR(MAX)
	SELECT @PaymentID = NULLIF(T.H.value('(PaymentID)[1]','INT'),''),
		   @Success = NULLIF(T.H.value('(Success)[1]','BIT'),''),
		   @Comment = NULLIF(T.H.value('(Comment)[1]','NVARCHAR(MAX)'),'')
	FROM @XML.nodes('ControlNumberAcknowledge') AS T(H)

				BEGIN TRY

				UPDATE tblPayment SET PaymentStatus =  CASE @Success WHEN 1 THEN 2 ELSE-3 END, RejectedReason = CASE @Success WHEN 0 THEN  @Comment ELSE NULL END,  ValidityFrom = GETDATE(),AuditedUserID =-1 WHERE PaymentID = @PaymentID  AND ValidityTo IS NULL 

				RETURN 0
			END TRY
			BEGIN CATCH
				ROLLBACK TRAN GETCONTROLNUMBER
				SELECT ERROR_MESSAGE()
				RETURN -1
			END CATCH
	

	
END

GO

IF NOT OBJECT_ID('uspRequestGetControlNumber') IS NULL
DROP PROCEDURE uspRequestGetControlNumber
GO
CREATE PROCEDURE [dbo].[uspRequestGetControlNumber]
(
	
	@PaymentID INT= 0,
	@RequestOrigin NVARCHAR(50) = NULL,
	@Failed BIT = 0
)
AS
BEGIN

		IF NOT EXISTS(SELECT 1 FROM tblPayment WHERE PaymentID = @PaymentID)
		RETURN 1 --Payment Does not exists
	
	IF EXISTS(SELECT 1 FROM tblControlNumber  WHERE PaymentID = @PaymentID  AND [Status] = 0 AND ValidityTo IS NULL)
		RETURN 2 --Request Already exists

			BEGIN TRY
				BEGIN TRAN GETCONTROLNUMBER
						INSERT INTO [dbo].[tblControlNumber]
						 ([RequestedDate],[RequestOrigin],[Status],[ValidityFrom],[AuditedUserID],[PaymentID])
							 SELECT GETDATE(), @RequestOrigin,0, GETDATE(), -1, @PaymentID
							 IF @Failed = 0
							 UPDATE tblPayment SET PaymentStatus =1 WHERE PaymentID = @PaymentID
				COMMIT TRAN GETCONTROLNUMBER
				RETURN 0
			END TRY
			BEGIN CATCH
				ROLLBACK TRAN GETCONTROLNUMBER
				SELECT ERROR_MESSAGE()
				RETURN -1
			END CATCH
	

	
END

GO

IF NOT OBJECT_ID('uspPolicyValueProxyFamily') IS NULL
DROP PROCEDURE uspPolicyValueProxyFamily
GO
CREATE PROCEDURE [dbo].[uspPolicyValueProxyFamily]
(
	@ProductCode NVARCHAR(8),			
	@AdultMembers INT ,
	@ChildMembers INT ,
	@OAdultMembers INT =0,
	@OChildMembers INT = 0
)
AS

/*
********ERROR CODE***********
-1	:	Policy does not exists at the time of enrolment
-2	:	Policy was deleted at the time of enrolment

*/

BEGIN

	DECLARE @LumpSum DECIMAL(18,2) = 0,
			@PremiumAdult DECIMAL(18,2) = 0,
			@PremiumChild DECIMAL(18,2) = 0,
			@RegistrationLumpSum DECIMAL(18,2) = 0,
			@RegistrationFee DECIMAL(18,2) = 0,
			@GeneralAssemblyLumpSum DECIMAL(18,2) = 0,
			@GeneralAssemblyFee DECIMAL(18,2) = 0,
			@Threshold SMALLINT = 0,
			@MemberCount INT = 0,
			@Registration DECIMAL(18,2) = 0,
			@GeneralAssembly DECIMAL(18,2) = 0,
			@Contribution DECIMAL(18,2) = 0,
			@PolicyValue DECIMAL(18,2) = 0,
			@ExtraAdult INT = 0,
			@ExtraChild INT = 0,
			@AddonAdult DECIMAL(18,2) = 0,
			@AddonChild DECIMAL(18,2) = 0,
			@DiscountPeriodR INT = 0,
			@DiscountPercentR DECIMAL(18,2) =0,
			@DiscountPeriodN INT = 0,
			@DiscountPercentN DECIMAL(18,2) =0,
			@ExpiryDate DATE,
			@ProdId INT =0,
			@PolicyStage NVARCHAR(1) ='N',
			@ErrorCode INT=0,
			@ValidityTo DATE = NULL,
			@LegacyId INT = NULL,
			@EnrollDate DATE = GETDATE();


			SET @ProdId = ( SELECT ProdID FROM tblProduct WHERE ProductCode = @ProductCode AND ValidityTo IS NULL	)
	


	/*--Get all the required fiedls from product (Valide product at the enrollment time)--*/
		SELECT TOP 1 @LumpSum = ISNULL(LumpSum,0),@PremiumAdult = ISNULL(PremiumAdult,0),@PremiumChild = ISNULL(PremiumChild,0),@RegistrationLumpSum = ISNULL(RegistrationLumpSum,0),
		@RegistrationFee = ISNULL(RegistrationFee,0),@GeneralAssemblyLumpSum = ISNULL(GeneralAssemblyLumpSum,0), @GeneralAssemblyFee = ISNULL(GeneralAssemblyFee,0), 
		@Threshold = ISNULL(Threshold ,0),@MemberCount = ISNULL(MemberCount,0), @ValidityTo = ValidityTo, @LegacyId = LegacyID, @DiscountPeriodR = ISNULL(RenewalDiscountPeriod, 0), @DiscountPercentR = ISNULL(RenewalDiscountPerc,0)
		, @DiscountPeriodN = ISNULL(EnrolmentDiscountPeriod, 0), @DiscountPercentN = ISNULL(EnrolmentDiscountPerc,0)
		FROM tblProduct 
		WHERE (ProdID = @ProdId OR LegacyID = @ProdId)
		AND CONVERT(DATE,ValidityFrom,103) <= @EnrollDate
		ORDER BY ValidityFrom Desc

		IF @@ROWCOUNT = 0	--No policy found
			SET @ErrorCode = -1
		IF NOT @ValidityTo IS NULL AND @LegacyId IS NULL	--Policy is deleted by the time of enrollment
			SET @ErrorCode = -2
			

	

	--Get extra members in family
		IF @Threshold > 0 AND @AdultMembers > @Threshold
			SET @ExtraAdult = @AdultMembers - @Threshold
		IF @Threshold > 0 AND @ChildMembers > (@Threshold - @AdultMembers + @ExtraAdult )
					SET @ExtraChild = @ChildMembers - ((@Threshold - @AdultMembers + @ExtraAdult))
			

	--Get the Contribution
		IF @LumpSum > 0
			SET @Contribution = @LumpSum
		ELSE
			SET @Contribution = (@AdultMembers * @PremiumAdult) + (@ChildMembers * @PremiumChild)

	--Get the Assembly
		IF @GeneralAssemblyLumpSum > 0
			SET @GeneralAssembly = @GeneralAssemblyLumpSum
		ELSE
			SET @GeneralAssembly = (@AdultMembers + @ChildMembers + @OAdultMembers + @OChildMembers) * @GeneralAssemblyFee;

	--Get the Registration
		IF @PolicyStage = N'N'	--Don't calculate if it's renewal
		BEGIN
			IF @RegistrationLumpSum > 0
				SET @Registration = @RegistrationLumpSum
			ELSE
				SET @Registration = (@AdultMembers + @ChildMembers  + @OAdultMembers + @OChildMembers) * @RegistrationFee;
		END

	/* Any member above the maximum member count  or with excluded relationship calculate the extra addon amount */

		SET @AddonAdult = (@ExtraAdult + @OAdultMembers) * @PremiumAdult;
		SET @AddonChild = (@ExtraChild + @OChildMembers) * @PremiumChild;

		SET @Contribution += @AddonAdult + @AddonChild;
		
		--Line below was a mistake, All adults and children are already included in GeneralAssembly and Registration
		--SET @GeneralAssembly += (@OAdultMembers + @OChildMembers + @ExtraAdult + @ExtraChild) * @GeneralAssemblyFee;
		
		--IF @PolicyStage = N'N'
		--	SET @Registration += (@OAdultMembers + @OChildMembers + @ExtraAdult + @ExtraChild) * @RegistrationFee;


	SET @PolicyValue = @Contribution + @GeneralAssembly + @Registration;


	--The total policy value is calculated, So if the enroldate is earlier than the discount period then apply discount
	DECLARE @HasCycle BIT
	DECLARE @tblPeriod TABLE(StartDate DATE, ExpiryDate DATE, HasCycle BIT)
	INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
	EXEC uspGetPolicyPeriod @ProdId, @EnrollDate, @HasCycle OUTPUT, @PolicyStage;

	DECLARE @StartDate DATE =(SELECT StartDate FROM @tblPeriod);


	DECLARE @MinDiscountDateR DATE,
			@MinDiscountDateN DATE

	IF @PolicyStage = N'N'
	BEGIN
		SET @MinDiscountDateN = DATEADD(MONTH,-(@DiscountPeriodN),@StartDate);
		IF @EnrollDate <= @MinDiscountDateN AND @HasCycle = 1
			SET @PolicyValue -=  (@PolicyValue * 0.01 * @DiscountPercentN);
	END
	ELSE IF @PolicyStage  = N'R'
	BEGIN
		DECLARE @PreviousExpiryDate DATE = NULL

	
		BEGIN
			SET @PreviousExpiryDate = @StartDate;
		END

		SET @MinDiscountDateR = DATEADD(MONTH,-(@DiscountPeriodR),@PreviousExpiryDate);
		IF @EnrollDate <= @MinDiscountDateR
			SET @PolicyValue -=  (@PolicyValue * 0.01 * @DiscountPercentR);
	END

	SELECT @PolicyValue PolicyValue;

	

	
	RETURN @PolicyValue;

END

GO

IF NOT OBJECT_ID('uspInsertPaymentIntent') IS NULL
DROP PROCEDURE uspInsertPaymentIntent
GO
CREATE PROCEDURE [dbo].[uspInsertPaymentIntent]
(
	@XML XML,
	@ExpectedAmount DECIMAL(18,2) = 0 OUT, 
	@PaymentID INT = 0 OUT,
	@ErrorNumber INT = 0,
	@ErrorMsg NVARCHAR(255)=NULL,
	@ProvidedAmount decimal(18,2) = 0,
	@PriorEnrollment BIT = 0 
	
)

AS
BEGIN
	DECLARE @tblHeader TABLE(officerCode nvarchar(12),requestDate DATE, phoneNumber NVARCHAR(50),LanguageName NVARCHAR(10), AuditUSerID INT)
	DECLARE @tblDetail TABLE(InsuranceNumber nvarchar(12),productCode nvarchar(8), PolicyStage NVARCHAR(1),  isRenewal BIT, PolicyValue DECIMAL(18,2), isExisting BIT)
	DECLARE @OfficerLocationID INT
	DECLARE @OfficerParentLocationID INT
	DECLARE @AdultMembers INT 
	DECLARE @ChildMembers INT 
	DECLARE @oAdultMembers INT 
	DECLARE @oChildMembers INT


	DECLARE @isEO BIT
		INSERT INTO @tblHeader(officerCode, requestDate, phoneNumber,LanguageName, AuditUSerID)
		SELECT 
		LEFT(NULLIF(T.H.value('(OfficerCode)[1]','NVARCHAR(50)'),''),12),
		NULLIF(T.H.value('(RequestDate)[1]','NVARCHAR(50)'),''),
		LEFT(NULLIF(T.H.value('(PhoneNumber)[1]','NVARCHAR(50)'),''),50),
		NULLIF(T.H.value('(LanguageName)[1]','NVARCHAR(10)'),''),
		NULLIF(T.H.value('(AuditUserId)[1]','INT'),'')
		FROM @XML.nodes('PaymentIntent/Header') AS T(H)

		INSERT INTO @tblDetail(InsuranceNumber, productCode, isRenewal)
		SELECT 
		LEFT(NULLIF(T.D.value('(InsuranceNumber)[1]','NVARCHAR(12)'),''),12),
		LEFT(NULLIF(T.D.value('(ProductCode)[1]','NVARCHAR(8)'),''),8),
		T.D.value('(IsRenewal)[1]','BIT')
		FROM @XML.nodes('PaymentIntent/Details/Detail') AS T(D)
		
		IF @ErrorNumber != 0
		BEGIN
			GOTO Start_Transaction;
		END

		SELECT @AdultMembers =T.P.value('(AdultMembers)[1]','INT'), @ChildMembers = T.P.value('(ChildMembers)[1]','INT') , @oAdultMembers =T.P.value('(oAdultMembers)[1]','INT') , @oChildMembers = T.P.value('(oChildMembers)[1]','INT') FROM @XML.nodes('PaymentIntent/ProxySettings') AS T(P)
		
		SELECT @AdultMembers= ISNULL(@AdultMembers,0), @ChildMembers= ISNULL(@ChildMembers,0), @oAdultMembers= ISNULL(@oAdultMembers,0), @oChildMembers= ISNULL(@oChildMembers,0)
		

		UPDATE D SET D.isExisting = 1 FROM @tblDetail D 
		INNER JOIN  tblInsuree I ON D.InsuranceNumber = I.CHFID 
		WHERE I.ValidityTo IS NULL
	
		UPDATE  @tblDetail SET isExisting = 0 WHERE isExisting IS NULL

		IF EXISTS(SELECT 1 FROM @tblHeader WHERE officerCode IS NOT NULL)
			SET @isEO = 1
	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	/*Error Codes
	2- Not valid insurance or missing product code
	3- Not valid enrolment officer code
	4 –Enrolment officer code and insurance product code are not compatible
	5- Beneficiary has no policy of specified insurance product for renewal
	6- Can not issue a control number as default indicated prior enrollment and Insuree has not been enrolled yet 

	7 - 'Insuree not enrolled and prior enrolement mandatory'


	-1. Unexpected error
	0. Success
	*/

	--2. Insurance number missing
		IF EXISTS(SELECT 1 FROM @tblDetail WHERE LEN(ISNULL(InsuranceNumber,'')) =0)
		BEGIN
			SET @ErrorNumber = 2
			SET @ErrorMsg ='Not valid insurance or missing product code'
			GOTO Start_Transaction;
		END

		--4. Missing product or Product does not exists
		IF EXISTS(SELECT 1 FROM @tblDetail D 
				LEFT OUTER JOIN tblProduct P ON P.ProductCode = D.productCode
				WHERE 
				(P.ValidityTo IS NULL AND P.ProductCode IS NULL) 
				OR D.productCode IS NULL
				)
		BEGIN
			SET @ErrorNumber = 4
			SET @ErrorMsg ='Not valid insurance or missing product code'
			GOTO Start_Transaction;
		END


	--3. Invalid Officer Code
		IF EXISTS(SELECT 1 FROM @tblHeader H
				LEFT JOIN tblOfficer O ON H.officerCode = O.Code
				WHERE O.ValidityTo IS NULL
				AND H.officerCode IS NOT NULL
				AND O.Code IS NULL
		)
		BEGIN
			SET @ErrorNumber = 3
			SET @ErrorMsg ='Not valid enrolment officer code'
			GOTO Start_Transaction;
		END

		
		--4. Wrong match of Enrollment Officer agaists Product
		SELECT @OfficerLocationID= L.LocationId, @OfficerParentLocationID = L.ParentLocationId FROM tblLocations L 
		INNER JOIN tblOfficer O ON O.LocationId = L.LocationId AND O.Code = (SELECT officerCode FROM @tblHeader WHERE officerCode IS NOT NULL)
		WHERE 
		L.ValidityTo IS NULL
		AND O.ValidityTo IS NULL


		IF EXISTS(SELECT D.productCode, P.ProductCode FROM @tblDetail D
			LEFT OUTER JOIN tblProduct P ON P.ProductCode = D.productCode AND (P.LocationId IS NULL OR P.LocationId = @OfficerLocationID OR P.LocationId = @OfficerParentLocationID)
			WHERE
			P.ValidityTo IS NULL
			AND P.ProductCode IS NULL
			) AND EXISTS(SELECT 1 FROM @tblHeader WHERE officerCode IS NOT NULL)
		BEGIN
			SET @ErrorNumber = 4
			SET @ErrorMsg ='Enrolment officer code and insurance product code are not compatible'
			GOTO Start_Transaction;
		END
		
		
		--The family does't contain this product for renewal
		IF EXISTS(SELECT 1 FROM @tblDetail D
				LEFT OUTER JOIN tblProduct PR ON PR.ProductCode = D.productCode
				LEFT OUTER JOIN tblInsuree I ON I.CHFID = D.InsuranceNumber
				LEFT OUTER JOIN tblPolicy PL ON PL.FamilyID = I.FamilyID  AND PL.ProdID = PR.ProdID
				WHERE PR.ValidityTo IS NULL
				AND D.isRenewal = 1 AND D.isExisting = 1
				AND I.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL AND PL.PolicyID IS NULL)
		BEGIN
			SET @ErrorNumber = 5
			SET @ErrorMsg ='Beneficiary has no policy of specified insurance product for renewal'
			GOTO Start_Transaction;
		END

		

		--5. Proxy family can not renew
		IF EXISTS(SELECT 1 FROM @tblDetail WHERE isExisting =0 AND isRenewal= 1)
		BEGIN
			SET @ErrorNumber = 5
			SET @ErrorMsg ='Beneficiary has no policy of specified insurance product for renewal'
			GOTO Start_Transaction;
		END


		--7. Insurance number not existing in system 
		IF @PriorEnrollment = 1 AND EXISTS(SELECT 1 FROM @tblDetail D
				LEFT OUTER JOIN tblProduct PR ON PR.ProductCode = D.productCode
				LEFT OUTER JOIN tblInsuree I ON I.CHFID = D.InsuranceNumber
				LEFT OUTER JOIN tblPolicy PL ON PL.FamilyID = I.FamilyID  AND PL.ProdID = PR.ProdID
				WHERE PR.ValidityTo IS NULL
				AND I.ValidityTo IS NULL
				AND PL.ValidityTo IS NULL AND PL.PolicyID IS NULL)
		BEGIN
			SET @ErrorNumber = 7
			SET @ErrorMsg ='Insuree not enrolled and prior enrollment mandatory'
			GOTO Start_Transaction;
		END




	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/
	/**********************************************************************************************************************
			CALCULATIONS STARTS
	*********************************************************************************************************************/
	
	DECLARE @FamilyId INT, @ProductId INT, @PrevPolicyID INT, @PolicyID INT, @PremiumID INT
	DECLARE @PolicyStatus TINYINT=1
	DECLARE @PolicyValue DECIMAL(18,2), @PolicyStage NVARCHAR(1), @InsuranceNumber nvarchar(12), @productCode nvarchar(8), @enrollmentDate DATE, @isRenewal BIT, @isExisting BIT, @ErrorCode NVARCHAR(50)

	IF @ProvidedAmount = 0 
	BEGIN
		--only calcuylate if we want the system to provide a value to settle
		DECLARE CurFamily CURSOR FOR SELECT InsuranceNumber, productCode, isRenewal, isExisting FROM @tblDetail
		OPEN CurFamily
		FETCH NEXT FROM CurFamily INTO @InsuranceNumber, @productCode, @isRenewal, @isExisting;
		WHILE @@FETCH_STATUS = 0
		BEGIN
									
			SET @PolicyStatus=1
			SET @FamilyId = NULL
			SET @ProductId = NULL
			SET @PolicyID = NULL


			IF @isRenewal = 1
				SET @PolicyStage = 'R'
			ELSE 
				SET @PolicyStage ='N'

			IF @isExisting = 1
			BEGIN
											
				SELECT @FamilyId = FamilyId FROM tblInsuree I WHERE IsHead = 1 AND CHFID = @InsuranceNumber  AND ValidityTo IS NULL
				SELECT @ProductId = ProdID FROM tblProduct WHERE ProductCode = @productCode  AND ValidityTo IS NULL
				SELECT TOP 1 @PolicyID =  PolicyID FROM tblPolicy WHERE FamilyID = @FamilyId  AND ProdID = @ProductId AND PolicyStage = @PolicyStage AND ValidityTo IS NULL ORDER BY EnrollDate DESC
											
				IF @isEO = 1
					IF EXISTS(SELECT 1 FROM tblPremium WHERE PolicyID = @PolicyID AND ValidityTo IS NULL)
					BEGIN
						SELECT @PolicyValue =  ISNULL(PR.Amount - ISNULL(MatchedAmount,0),0) FROM tblPremium PR
														INNER JOIN tblPolicy PL ON PL.PolicyID = PR.PolicyID
														LEFT OUTER JOIN (SELECT PremiumID, SUM (Amount) MatchedAmount from tblPaymentDetails WHERE ValidityTo IS NULL GROUP BY PremiumID ) PD ON PD.PremiumID = PR.PremiumId
														WHERE
														PR.ValidityTo IS NULL
														AND PL.ValidityTo IS NULL AND PL.PolicyID = @PolicyID
														IF @PolicyValue < 0
														SET @PolicyValue = 0.00
					END
					ELSE
					BEGIN
						EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProductId, 0, @PolicyStage, NULL, 0;
					END
												
				ELSE IF @PolicyStage ='N'
				BEGIN
					EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProductId, 0, 'N', NULL, 0;
				END
				ELSE
				BEGIN
					SELECT TOP 1 @PrevPolicyID = PolicyID, @PolicyStatus = PolicyStatus FROM tblPolicy  WHERE ProdID = @ProductId AND FamilyID = @FamilyId AND ValidityTo IS NULL AND PolicyStatus != 4 ORDER BY EnrollDate DESC
					IF @PolicyStatus = 1
					BEGIN
						SELECT @PolicyValue =  (ISNULL(SUM(PL.PolicyValue),0) - ISNULL(SUM(Amount),0)) FROM tblPolicy PL 
						LEFT OUTER JOIN tblPremium PR ON PR.PolicyID = PL.PolicyID
						WHERE PL.ValidityTo IS NULL
						AND PR.ValidityTo IS NULL
						AND PL.PolicyID = @PrevPolicyID
						IF @PolicyValue < 0
							SET @PolicyValue =0
					END
					ELSE
					BEGIN 
						EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProductId, 0, 'R', @enrollmentDate, @PrevPolicyID, @ErrorCode OUTPUT;
					END
				END
			END
			ELSE
			BEGIN
				EXEC @PolicyValue = uspPolicyValueProxyFamily @productCode, @AdultMembers, @ChildMembers,@oAdultMembers,@oChildMembers
			END
			UPDATE @tblDetail SET PolicyValue = ISNULL(@PolicyValue,0), PolicyStage = @PolicyStage  WHERE InsuranceNumber = @InsuranceNumber AND productCode = @productCode AND isRenewal = @isRenewal
			FETCH NEXT FROM CurFamily INTO @InsuranceNumber, @productCode, @isRenewal, @isExisting;
		END
		CLOSE CurFamily
		DEALLOCATE CurFamily;

	

	END

	
	
		
	--IF IT REACHES UP TO THIS POINT THEN THERE IS NO ERROR
	SET @ErrorNumber = 0
	SET @ErrorMsg = NULL


	/**********************************************************************************************************************
			CALCULATIONS ENDS
	 *********************************************************************************************************************/

	 /**********************************************************************************************************************
			INSERTION STARTS
	 *********************************************************************************************************************/
		Start_Transaction:
		BEGIN TRY
			BEGIN TRANSACTION INSERTPAYMENTINTENT
				
				IF @ProvidedAmount > 0 
					SET @ExpectedAmount = @ProvidedAmount 
				ELSE
					SELECT @ExpectedAmount = SUM(ISNULL(PolicyValue,0)) FROM @tblDetail
				
				SET @ErrorMsg = ISNULL(CONVERT(NVARCHAR(5),@ErrorNumber)+': '+ @ErrorMsg,NULL)
				--Inserting Payment
				INSERT INTO [dbo].[tblPayment]
				 ([ExpectedAmount],[OfficerCode],[PhoneNumber],[RequestDate],[PaymentStatus],[ValidityFrom],[AuditedUSerID],[RejectedReason],[LanguageName]) 
				 SELECT
				 @ExpectedAmount, officerCode, phoneNumber, GETDATE(),CASE @ErrorNumber WHEN 0 THEN 0 ELSE -1 END, GETDATE(), AuditUSerID, @ErrorMsg,LanguageName
				 FROM @tblHeader
				 SELECT @PaymentID= SCOPE_IDENTITY();

				 --Inserting Payment Details
				 DECLARE @AuditedUSerID INT
				 SELECT @AuditedUSerID = AuditUSerID FROM @tblHeader
				INSERT INTO [dbo].[tblPaymentDetails]
			   ([PaymentID],[ProductCode],[InsuranceNumber],[PolicyStage],[ValidityFrom],[AuditedUserId], ExpectedAmount) SELECT
				@PaymentID, productCode, InsuranceNumber,  CASE isRenewal WHEN 0 THEN 'N' ELSE 'R' END, GETDATE(), @AuditedUSerID, PolicyValue
				FROM @tblDetail D
				


			COMMIT TRANSACTION INSERTPAYMENTINTENT
			RETURN @ErrorNumber
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION INSERTPAYMENTINTENT
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH

	 /**********************************************************************************************************************
			INSERTION ENDS
	 *********************************************************************************************************************/

END

GO

IF NOT OBJECT_ID('uspReceiveControlNumber') IS NULL
DROP PROCEDURE uspReceiveControlNumber
GO
CREATE PROCEDURE [dbo].[uspReceiveControlNumber]
(
	@PaymentID INT,
	@ControlNumber NVARCHAR(50),
	@ResponseOrigin NVARCHAR(50) = NULL,
	@Failed BIT = 0
)
AS
	BEGIN
		BEGIN TRY
			IF EXISTS(SELECT 1 FROM tblControlNumber  WHERE PaymentID = @PaymentID AND ValidityTo IS NULL )
			BEGIN
				IF @Failed = 0
				BEGIN
					UPDATE tblPayment SET PaymentStatus = 3 WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
					UPDATE tblControlNumber SET ReceivedDate = GETDATE(), ResponseOrigin = @ResponseOrigin,  ValidityFrom = GETDATE() ,AuditedUserID =-1,ControlNumber = @ControlNumber  WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
					RETURN 0 
				END
				ELSE
				BEGIN
					UPDATE tblPayment SET PaymentStatus = -3, RejectedReason ='8: Duplicated control number assigned' WHERE PaymentID = @PaymentID AND ValidityTo IS NULL
					RETURN 2
				END
			END
			ELSE
			BEGIN
				RETURN 1
			END


				
		END TRY
		BEGIN CATCH
			RETURN -1
		END CATCH

	
END

GO

IF NOT OBJECT_ID('uspReceivePayment') IS NULL
DROP PROCEDURE uspReceivePayment
GO
CREATE PROCEDURE [dbo].[uspReceivePayment]
(
	
	@XML XML,
	@Payment_ID BIGINT =NULL OUTPUT
)
AS
BEGIN

	DECLARE
	@PaymentID BIGINT =NULL,
	@ControlNumberID BIGINT=NULL,
	@PaymentDate DATE,
	@ReceiveDate DATE,
    @ControlNumber NVARCHAR(50),
    @TransactionNo NVARCHAR(50),
    @ReceiptNo NVARCHAR(100),
    @PaymentOrigin NVARCHAR(50),
    @PhoneNumber NVARCHAR(50),
    @OfficerCode NVARCHAR(50),
    @InsuranceNumber NVARCHAR(12),
    @productCode NVARCHAR(8),
    @Amount  DECIMAL(18,2),
    @isRenewal  BIT,
	@ExpectedAmount DECIMAL(18,2),
	@ErrorMsg NVARCHAR(50)
	

		

	
				
	BEGIN TRY

		DECLARE @tblDetail TABLE(InsuranceNumber nvarchar(12),productCode nvarchar(8), isRenewal BIT)

		SELECT @PaymentID = NULLIF(T.H.value('(PaymentID)[1]','INT'),''),
			   @PaymentDate = NULLIF(T.H.value('(PaymentDate)[1]','DATE'),''),
			   @ReceiveDate = NULLIF(T.H.value('(ReceiveDate)[1]','DATE'),''),
			   @ControlNumber = NULLIF(T.H.value('(ControlNumber)[1]','NVARCHAR(50)'),''),
			   @ReceiptNo = NULLIF(T.H.value('(ReceiptNo)[1]','NVARCHAR(100)'),''),
			   @TransactionNo = NULLIF(T.H.value('(TransactionNo)[1]','NVARCHAR(50)'),''),
			   @PaymentOrigin = NULLIF(T.H.value('(PaymentOrigin)[1]','NVARCHAR(50)'),''),
			   @PhoneNumber = NULLIF(T.H.value('(PhoneNumber)[1]','NVARCHAR(25)'),''),
			   @OfficerCode = NULLIF(T.H.value('(OfficerCode)[1]','NVARCHAR(50)'),''),
			   @Amount = T.H.value('(Amount)[1]','DECIMAL(18,2)')
		FROM @XML.nodes('PaymentData') AS T(H)
	

		DECLARE @MyAmount Decimal(18,2)
		DECLARE @MyControlNumber nvarchar(50)
		DECLARE @MyReceivedAmount decimal(18,2) = 0 
		DECLARE @MyStatus INT = 0 
		DECLARE @ResultCode AS INT = 0 

		INSERT INTO @tblDetail(InsuranceNumber, productCode, isRenewal)
		SELECT 
		LEFT(NULLIF(T.D.value('(InsureeNumber)[1]','NVARCHAR(12)'),''),12),
		LEFT(NULLIF(T.D.value('(ProductCode)[1]','NVARCHAR(8)'),''),8),
		T.D.value('(IsRenewal)[1]','BIT')
		FROM @XML.nodes('PaymentData/Detail') AS T(D)
	
		--VERIFICATION START
		IF ISNULL(@PaymentID,'') <> ''
		BEGIN
			--lets see if all element are matching

			SELECT @MyControlNumber = ControlNumber , @MyAmount = P.ExpectedAmount, @MyReceivedAmount = ISNULL(ReceivedAmount,0) , @MyStatus = PaymentStatus  from tblPayment P left outer join tblControlNumber CN ON P.PaymentID = CN.PaymentID  WHERE CN.ValidityTo IS NULL and P.ValidityTo IS NULL AND P.PaymentID = @PaymentID 


			--CONTROl NUMBER CHECK
			IF ISNULL(@MyControlNumber,'') <> ISNULL(@ControlNumber,'') 
			BEGIN
				--Control Nr mismatch
				SET @ErrorMsg = 'Wrong Control Number'
				SET @ResultCode = 3
			END 

			--AMOUNT VALE CHECK
			IF ISNULL(@MyAmount,0) <> ISNULL(@Amount ,0) 
			BEGIN
				--Amount mismatch
				SET @ErrorMsg = 'Wrong Payment Amount'
				SET @ResultCode = 4
			END 

			--DUPLICATION OF PAYMENT
			IF @MyReceivedAmount = @Amount 
			BEGIN
				SET @ErrorMsg = 'Duplicated Payment'
				SET @ResultCode = 5
			END

			
		END
		--VERIFICATION END

		IF @ResultCode <> 0
		BEGIN
			--ERROR OCCURRED
	
			INSERT INTO [dbo].[tblPayment]
			(PaymentDate, ReceivedDate, ReceivedAmount, ReceiptNo, TransactionNo, PaymentOrigin, PhoneNumber, PaymentStatus, OfficerCode, ValidityFrom, AuditedUSerID, RejectedReason) 
			VALUES (@PaymentDate, @ReceiveDate,  @Amount, @ReceiptNo, @TransactionNo, @PaymentOrigin, @PhoneNumber, -3, @OfficerCode,  GETDATE(), -1,@ErrorMsg)
			SET @PaymentID= SCOPE_IDENTITY();

			INSERT INTO [dbo].[tblPaymentDetails]
				([PaymentID],[ProductCode],[InsuranceNumber],[PolicyStage],[ValidityFrom],[AuditedUserId]) SELECT
				@PaymentID, productCode, InsuranceNumber,  CASE isRenewal WHEN 0 THEN 'N' ELSE 'R' END, GETDATE(), -1
				FROM @tblDetail D

			SET @Payment_ID = @PaymentID
			SELECT @Payment_ID
			RETURN @ResultCode

		END
		ELSE
		BEGIN
			--ALL WENT OK SO FAR
		
		
			IF ISNULL(@PaymentID ,0) <> 0 
			BEGIN
				--REQUEST/INTEND WAS FOUND
				UPDATE tblPayment SET ReceivedAmount = @Amount, PaymentDate = @PaymentDate, ReceivedDate = GETDATE(), PaymentStatus = 4, TransactionNo = @TransactionNo, ReceiptNo= @ReceiptNo, PaymentOrigin = @PaymentOrigin, ValidityFrom = GETDATE(),AuditedUserID =-1 WHERE PaymentID = @PaymentID  AND ValidityTo IS NULL AND PaymentStatus = 3
				SET @Payment_ID = @PaymentID
				RETURN 0 
			END
			ELSE
			BEGIN
				--PAYMENT WITHOUT INTEND TP PAY
				INSERT INTO [dbo].[tblPayment]
					(PaymentDate, ReceivedDate, ReceivedAmount, ReceiptNo, TransactionNo, PaymentOrigin, PhoneNumber, PaymentStatus, OfficerCode, ValidityFrom, AuditedUSerID) 
					VALUES (@PaymentDate, @ReceiveDate,  @Amount, @ReceiptNo, @TransactionNo, @PaymentOrigin, @PhoneNumber, 4, @OfficerCode,  GETDATE(), -1)
				SET @PaymentID= SCOPE_IDENTITY();
							
				INSERT INTO [dbo].[tblPaymentDetails]
				([PaymentID],[ProductCode],[InsuranceNumber],[PolicyStage],[ValidityFrom],[AuditedUserId]) SELECT
				@PaymentID, productCode, InsuranceNumber,  CASE isRenewal WHEN 0 THEN 'N' ELSE 'R' END, GETDATE(), -1
				FROM @tblDetail D
				SET @Payment_ID = @PaymentID
				RETURN 0 

			END
		 
		
			
		END

		RETURN 0

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	

	
END

GO

IF NOT OBJECT_ID('uspMatchPayment') IS NULL
DROP PROCEDURE uspMatchPayment
GO
CREATE PROCEDURE [dbo].[uspMatchPayment]
	@PaymentID INT = NULL,
	@AuditUserId INT = NULL
AS
BEGIN

BEGIN TRY
---CHECK IF PAYMENTID EXISTS
	IF NOT @PaymentID IS NULL
	BEGIN
	     IF NOT EXISTS ( SELECT PaymentID FROM tblPayment WHERE PaymentID = @PaymentID AND ValidityTo IS NULL)
			RETURN 1
	END

	SET @AuditUserId =ISNULL(@AuditUserId, -1)

	DECLARE @InTopIsolation as bit 
	SET @InTopIsolation = -1 
	IF @@TRANCOUNT = 0 	
		SET @InTopIsolation =0
	ELSE
		SET @InTopIsolation =1
	IF @InTopIsolation = 0
	BEGIN
		BEGIN TRANSACTION MATCHPAYMENT
	END
	
	

	DECLARE @tblHeader TABLE(PaymentID BIGINT, officerCode nvarchar(12),PhoneNumber nvarchar(12),paymentDate DATE,ReceivedAmount DECIMAL(18,2),TotalPolicyValue DECIMAL(18,2), isValid BIT, TransactionNo NVARCHAR(50))
	DECLARE @tblDetail TABLE(PaymentDetailsID BIGINT, PaymentID BIGINT, InsuranceNumber nvarchar(12),productCode nvarchar(8),  enrollmentDate DATE,PolicyStage CHAR(1), MatchedDate DATE, PolicyValue DECIMAL(18,2),DistributedValue DECIMAL(18,2), policyID INT, RenewalpolicyID INT, PremiumID INT)
	DECLARE @tblResult TABLE(policyID INT, PremiumId INT)
	DECLARE @tblFeedback TABLE(fdMsg NVARCHAR(MAX), fdType NVARCHAR(1),paymentID INT,InsuranceNumber nvarchar(12),PhoneNumber nvarchar(12),productCode nvarchar(8), Balance DECIMAL(18,2), isActivated BIT, PaymentFound INT, PaymentMatched INT, APIKey NVARCHAR(100))
	DECLARE @tblPaidPolicies TABLE(PolicyID INT, Amount DECIMAL(18,2), PolicyValue DECIMAL(18,2))
	DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
	DECLARE @paymentFound INT
	DECLARE @paymentMatched INT


	--GET ALL UNMATCHED RECEIVED PAYMENTS
	INSERT INTO @tblDetail(PaymentDetailsID, PaymentID, InsuranceNumber, ProductCode, enrollmentDate, policyID, PolicyStage, PolicyValue, PremiumID)
	SELECT PaymentDetailsID, PaymentID, InsuranceNumber, ProductCode, EnrollDate,  PolicyID, PolicyStage, PolicyValue, PremiumId FROM(
	SELECT ROW_NUMBER() OVER(PARTITION BY PR.ProductCode,I.CHFID ORDER BY PL.EnrollDate DESC) RN, PD.PaymentDetailsID, PY.PaymentID,PD.InsuranceNumber, PD.ProductCode,PL.EnrollDate,  PL.PolicyID, PD.PolicyStage, PL.PolicyValue, PRM.PremiumId FROM tblPaymentDetails PD 
	LEFT OUTER JOIN tblInsuree I ON I.CHFID = PD.InsuranceNumber
	LEFT OUTER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
	LEFT OUTER JOIN tblProduct PR ON PR.ProductCode = PD.ProductCode
	LEFT OUTER JOIN (SELECT  PolicyID, EnrollDate, PolicyValue,FamilyID, ProdID,PolicyStatus FROM tblPolicy WHERE ProdID = ProdID AND FamilyID = FamilyID AND ValidityTo IS NULL AND PolicyStatus NOT IN (4,8)  ) PL ON PL.ProdID = PR.ProdID  AND PL.FamilyID = I.FamilyID
	LEFT OUTER JOIN ( SELECT MAX(PremiumId) PremiumId , PolicyID FROM  tblPremium WHERE ValidityTo IS NULL GROUP BY PolicyID ) PRM ON PRM.PolicyID = PL.PolicyID
	INNER JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID
	WHERE PD.PremiumID IS NULL 
	AND PD.ValidityTo IS NULL
	AND I.ValidityTo IS NULL
	AND PR.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND PY.ValidityTo IS NULL
	AND PY.PaymentStatus = 4 --Received Payment
	AND PD.PaymentID = ISNULL(@PaymentID,PD.PaymentID)
	)XX --WHERE RN =1
	
	INSERT INTO @tblHeader(PaymentID, ReceivedAmount, PhoneNumber, TotalPolicyValue, TransactionNo, officerCode)
	SELECT P.PaymentID, P.ReceivedAmount, P.PhoneNumber, D.TotalPolicyValue, P.TransactionNo, P.OfficerCode FROM tblPayment P
	INNER JOIN (SELECT PaymentID, SUM(PolicyValue) TotalPolicyValue FROM @tblDetail GROUP BY PaymentID)  D ON P.PaymentID = D.PaymentID
	WHERE P.ValidityTo IS NULL AND P.PaymentStatus = 4

	IF EXISTS(SELECT COUNT(1) FROM @tblHeader PH )
		BEGIN
			SET @paymentFound= (SELECT COUNT(1)  FROM @tblHeader PH )
			INSERT INTO @tblFeedback(fdMsg, fdType )
			SELECT CONVERT(NVARCHAR(4), ISNULL(@paymentFound,0))  +' Unmatched Payment(s) found ', 'I' 
		END


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	
	--1. Insurance number is missing on tblPaymentDetails
	IF EXISTS(SELECT 1 FROM @tblDetail WHERE LEN(ISNULL(InsuranceNumber,'')) = 0)
		BEGIN
			INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
			SELECT CONVERT(NVARCHAR(4), COUNT(1) OVER(PARTITION BY InsuranceNumber)) +' Insurance number(s) missing in tblPaymentDetails ', 'E', PaymentID FROM @tblDetail WHERE LEN(ISNULL(InsuranceNumber,'')) = 0
		END

		--2. Product code is missing on tblPaymentDetails
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
		SELECT 'Family with Insurance Number ' + QUOTENAME(PD.InsuranceNumber) + ' is missing product code ', 'E', PD.PaymentID FROM @tblDetail PD WHERE LEN(ISNULL(productCode,'')) = 0

	--2. Insurance number is missing in tblinsuree
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
		SELECT 'Family with Insurance Number' + QUOTENAME(PD.InsuranceNumber) + ' does not exists', 'E', PD.PaymentID FROM @tblDetail PD 
		LEFT OUTER JOIN tblInsuree I ON I.CHFID = PD.InsuranceNumber
		WHERE I.ValidityTo  IS NULL
		AND I.CHFID IS NULL
		
	--1. Policy/Prevous Policy not found
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID )
		SELECT 'Family with Insurance Number ' + QUOTENAME(PD.InsuranceNumber) + ' does not have Policy or Previous Policy for the product '+QUOTENAME(PD.productCode), 'E', PD.PaymentID FROM @tblDetail PD 
		WHERE policyID IS NULL
		AND ISNULL(LEN(PD.productCode),'') > 0
		AND ISNULL(LEN(PD.InsuranceNumber),'') > 0

	 --3. Invalid Product
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
		SELECT  'Family with insurance number '+ QUOTENAME(PD.InsuranceNumber) +' can not enroll to product '+ QUOTENAME(PD.productCode),'E',PD.PaymentID FROM @tblDetail PD 
		INNER JOIN tblInsuree I ON I.CHFID = PD.InsuranceNumber
		INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		INNER JOIN tblRegions R ON R.RegionId =  D.Region
		LEFT OUTER JOIN tblProduct PR ON (PR.LocationId IS NULL OR PR.LocationId = D.Region OR PR.LocationId = D.DistrictId) AND (GETDATE()  BETWEEN PR.DateFrom AND PR.DateTo) AND PR.ProductCode = PD.ProductCode
		WHERE 
		I.ValidityTo IS NULL
		AND F.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL
		AND PR.ProdID IS NULL
		AND ISNULL(LEN(PD.productCode),'') > 0
		AND ISNULL(LEN(PD.InsuranceNumber),'') > 0


	--4. Invalid Officer
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
		SELECT 'Enrollment officer '+ QUOTENAME(PY.officerCode) +' does not exists ' ,'E',PD.PaymentID  FROM @tblDetail PD
		INNER JOIN @tblHeader PY ON PY.PaymentID = PD.PaymentID
		LEFT OUTER JOIN tblOfficer O ON O.Code = PY.OfficerCode
		WHERE
		O.ValidityTo IS NULL
		AND PY.OfficerCode IS NOT NULL
		AND O.Code IS NULL


	--4. Invalid Officer/Product Match
		INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
		SELECT 'Enrollment officer '+ QUOTENAME(PY.officerCode) +' can not sell the product '+ QUOTENAME(PD.productCode),'E',PD.PaymentID  FROM @tblDetail PD
		INNER JOIN @tblHeader PY ON PY.PaymentID = PD.PaymentID
		LEFT OUTER JOIN tblOfficer O ON O.Code = PY.OfficerCode
		INNER JOIN tblDistricts D ON D.DistrictId = O.LocationId
		LEFT JOIN tblProduct PR ON PR.ProductCode = PD.ProductCode AND (PR.LocationId IS NULL OR PR.LocationID = D.Region OR PR.LocationId = D.DistrictId)
		WHERE
		O.ValidityTo IS NULL
		AND PY.OfficerCode IS NOT NULL
		AND PR.ValidityTo IS NULL
		AND D.ValidityTo IS NULL
		AND PR.ProdID IS NULL
		
	--5. Premiums not available
	INSERT INTO @tblFeedback(fdMsg, fdType, paymentID)
	SELECT 'Premium from Enrollment officer '+ QUOTENAME(PY.officerCode) +' is not yet available ','E',PD.PaymentID FROM @tblDetail PD 
	INNER JOIN @tblHeader PY ON PY.PaymentID = PD.PaymentID
	WHERE
	PD.PremiumID IS NULL
	AND PY.officerCode IS NOT NULL




	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/
	

	---DELETE ALL INVALID PAYMENTS
		DELETE PY FROM @tblHeader PY
		INNER JOIN @tblFeedback F ON F.paymentID = PY.PaymentID
		WHERE F.fdType ='E'


		DELETE PD FROM @tblDetail PD
		INNER JOIN @tblFeedback F ON F.paymentID = PD.PaymentID
		WHERE F.fdType ='E'

		IF NOT EXISTS(SELECT 1 FROM @tblHeader)
			INSERT INTO @tblFeedback(fdMsg, fdType )
			SELECT 'No Payment matched  ', 'I' FROM @tblHeader P

		--DISTRIBUTE PAYMENTS EVENLY
		UPDATE PD SET PD.DistributedValue = PH.ReceivedAmount*( PD.PolicyValue/PH.TotalPolicyValue) FROM @tblDetail PD
		INNER JOIN @tblHeader PH ON PH.PaymentID = PD.PaymentID

		--INSERT ONLY RENEWALS
		DECLARE @DistributedValue DECIMAL(18, 2)
		DECLARE @InsuranceNumber NVARCHAR(12)
		DECLARE @productCode NVARCHAR(8)
		DECLARE @PhoneNumber NVARCHAR(12)
		DECLARE @PaymentDetailsID INT

		--loop below only for SELF PAYER
		DECLARE @PreviousPolicyID INT
		IF EXISTS(SELECT 1 FROM @tblDetail PD INNER JOIN @tblHeader P ON PD.PaymentID = P.PaymentID WHERE PD.PolicyStage ='R' AND P.PhoneNumber IS NOT NULL AND P.officerCode IS NULL AND PD.policyID IS NOT NULL)
			BEGIN
			DECLARE CurPolicies CURSOR FOR SELECT PaymentDetailsID, InsuranceNumber, productCode, PhoneNumber, DistributedValue, policyID FROM @tblDetail PD INNER JOIN @tblHeader P ON PD.PaymentID = P.PaymentID WHERE PD.PolicyStage ='R' AND P.PhoneNumber IS NOT NULL AND P.officerCode IS NULL 
			OPEN CurPolicies;
			FETCH NEXT FROM CurPolicies INTO @PaymentDetailsID,  @InsuranceNumber, @productCode, @PhoneNumber, @DistributedValue, @PreviousPolicyID
			WHILE @@FETCH_STATUS = 0
			BEGIN			
						DECLARE @ProdId INT
						DECLARE @FamilyId INT
						DECLARE @OfficerID INT
						DECLARE @PolicyId INT
						DECLARE @PremiumId INT
						DECLARE @StartDate DATE
						DECLARE @ExpiryDate DATE
						DECLARE @EffectiveDate DATE
						DECLARE @EnrollmentDate DATE = GETDATE()
						DECLARE @PolicyStatus TINYINT=1
						DECLARE @PreviousPolicyStatus TINYINT=1
						DECLARE @PolicyValue DECIMAL(18, 2)
						DECLARE @PaidAmount DECIMAL(18, 2)
						DECLARE @Balance DECIMAL(18, 2)
						DECLARE @ErrorCode INT
						DECLARE @HasCycle BIT
						DECLARE @isActivated BIT = 0
						DECLARE @TransactionNo NVARCHAR(50)
						SELECT @ProdId = ProdID, @FamilyId = FamilyID, @OfficerID = OfficerID, @PreviousPolicyStatus = PolicyStatus  FROM tblPolicy WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL
							EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, 'R', @enrollmentDate, @PreviousPolicyID, @ErrorCode OUTPUT;
							DELETE FROM @tblPeriod
							
							SET @TransactionNo = (SELECT ISNULL(PY.TransactionNo,'') FROM @tblHeader PY INNER JOIN @tblDetail PD ON PD.PaymentID = PY.PaymentID AND PD.policyID = @PreviousPolicyID)
							
							
							IF @PreviousPolicyStatus = 1 
								BEGIN
									--Get the previous paid amount for only Iddle policy
									SELECT @PaidAmount =  ISNULL(SUM(Amount),0) FROM tblPremium  PR 
									LEFT OUTER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID  
									WHERE PR.PolicyID = @PreviousPolicyID 
									AND PR.ValidityTo IS NULL 
									AND PL.ValidityTo IS NULL
									AND PL.PolicyStatus = 1
									
									SELECT @PolicyValue = ISNULL(PolicyValue,0) FROM tblPolicy WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL

									IF (ISNULL(@DistributedValue,0) + ISNULL(@PaidAmount,0)) - ISNULL(@PolicyValue,0) >= 0
										BEGIN
											SET @PolicyStatus=2
											SET @EffectiveDate = (SELECT StartDate FROM tblPolicy WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL)
											SET @isActivated = 1
											SET @Balance = 0

											INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom, ValidityTo, LegacyID,  AuditUserID, isOffline)
														 SELECT FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,GETDATE(), PolicyID, AuditUserID, isOffline FROM tblPolicy WHERE PolicyID = @PreviousPolicyID

									
											INSERT INTO tblInsureePolicy
											(InsureeId,PolicyId,EnrollmentDate,StartDate,EffectiveDate,ExpiryDate,ValidityFrom,ValidityTo,LegacyId,AuditUserId,isOffline)
											SELECT InsureeId, PolicyId, EnrollmentDate, StartDate, EffectiveDate,ExpiryDate,ValidityFrom,GETDATE(),PolicyId,AuditUserId,isOffline FROM tblInsureePolicy 
											WHERE PolicyID = @PreviousPolicyID AND ValidityTo IS NULL

											UPDATE tblPolicy SET PolicyStatus = @PolicyStatus,  EffectiveDate  = @EffectiveDate, ExpiryDate = @ExpiryDate, ValidityFrom = GETDATE(), AuditUserID = @AuditUserId WHERE PolicyID = @PreviousPolicyID

											UPDATE tblInsureePolicy SET EffectiveDate = @EffectiveDate, ValidityFrom = GETDATE(), AuditUserID = @AuditUserId WHERE ValidityTo IS NULL AND PolicyId = @PreviousPolicyID  AND EffectiveDate IS NULL
											SET @PolicyId = @PreviousPolicyID

										END
									ELSE
										BEGIN
											SET @Balance = ISNULL(@PolicyValue,0) - (ISNULL(@DistributedValue,0) + ISNULL(@PaidAmount,0))
											SET @isActivated = 0
											SET @PolicyId = @PreviousPolicyID
										END
								END
							ELSE
								BEGIN --insert new Renewals if the policy is not Iddle
								DECLARE @StartCycle NVARCHAR(5)
									SELECT @StartCycle= ISNULL(StartCycle1, ISNULL(StartCycle2,ISNULL(StartCycle3,StartCycle4))) FROM tblProduct WHERE ProdID = @PreviousPolicyID
									IF @StartCycle IS NOT NULL
									SET @HasCycle = 1
									ELSE
									SET @HasCycle = 0
									SET @EnrollmentDate = (SELECT DATEADD(DAY,1,expiryDate) FROM tblPolicy WHERE PolicyID = @PreviousPolicyID  AND ValidityTo IS NULL)
									INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
									EXEC uspGetPolicyPeriod @ProdId, @EnrollmentDate, @HasCycle;
									SET @StartDate = (SELECT startDate FROM @tblPeriod)
									SET @ExpiryDate =(SELECT expiryDate FROM @tblPeriod)
									IF ISNULL(@DistributedValue,0) - ISNULL(@PolicyValue,0) >= 0
										BEGIN
											SET @PolicyStatus=2
											SET @EffectiveDate = @StartDate
											SET @isActivated = 1
											SET @Balance = 0
										END
										ELSE
										BEGIN
											SET @Balance = ISNULL(@PolicyValue,0) - (ISNULL(@DistributedValue,0))
											SET @isActivated = 0
											SET @PolicyStatus=1

										END

									INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
									SELECT	@FamilyId, GETDATE(),@StartDate,@EffectiveDate,@ExpiryDate,@PolicyStatus,@PolicyValue,@ProdID,@OfficerID,'R',GETDATE(),@AuditUserId, 0 isOffline 
									SELECT @PolicyId = SCOPE_IDENTITY()

									UPDATE @tblDetail SET policyID  = @PolicyId WHERE policyID = @PreviousPolicyID

									DECLARE @InsureeId INT
									DECLARE CurNewPolicy CURSOR FOR SELECT I.InsureeID FROM tblInsuree I WHERE I.FamilyID = @FamilyId AND I.ValidityTo IS NULL
									OPEN CurNewPolicy;
									FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
									WHILE @@FETCH_STATUS = 0
									BEGIN
										EXEC uspAddInsureePolicy @InsureeId;
										FETCH NEXT FROM CurNewPolicy INTO @InsureeId;
									END
									CLOSE CurNewPolicy;
									DEALLOCATE CurNewPolicy; 

									
								END	
				
				--INSERT PREMIUMS FOR INDIVIDUAL RENEWALS ONLY
				INSERT INTO tblPremium(PolicyID, Amount, PayType, Receipt, PayDate, ValidityFrom, AuditUserID)
				SELECT @PolicyId, @DistributedValue, 'C',@TransactionNo, GETDATE() PayDate, GETDATE() ValidityFrom, @AuditUserId AuditUserID 
				SELECT @PremiumId = SCOPE_IDENTITY()

				UPDATE @tblDetail SET PremiumID = @PremiumId  WHERE PaymentDetailsID = @PaymentDetailsID

				INSERT INTO @tblFeedback(InsuranceNumber, productCode, PhoneNumber, isActivated ,Balance, fdType)
				SELECT @InsuranceNumber, @productCode, @PhoneNumber, @isActivated,@Balance, 'A'

			FETCH NEXT FROM CurPolicies INTO @PaymentDetailsID,  @InsuranceNumber, @productCode, @PhoneNumber, @DistributedValue, @PreviousPolicyID;
			END
			CLOSE CurPolicies;
			DEALLOCATE CurPolicies; 
			END
			
			-- ABOVE LOOP SELF PAYER ONLY

		--Update the actual tblpayment & tblPaymentDetails
			UPDATE PD SET PD.PremiumID = TPD.PremiumId, PD.Amount = TPD.DistributedValue,  ValidityFrom =GETDATE(), AuditedUserId = @AuditUserId 
			FROM @tblDetail TPD
			INNER JOIN tblPaymentDetails PD ON PD.PaymentDetailsID = TPD.PaymentDetailsID 
			

			UPDATE P SET P.PaymentStatus = 5, P.MatchedDate = GETDATE(),  ValidityFrom = GETDATE(), AuditedUSerID = @AuditUserId FROM tblPayment P
			INNER JOIN @tblDetail PD ON PD.PaymentID = P.PaymentID

			IF EXISTS(SELECT COUNT(1) FROM @tblHeader PH )
			BEGIN
				SET @paymentMatched= (SELECT COUNT(1)  FROM @tblHeader PH )
				INSERT INTO @tblFeedback(fdMsg, fdType )
				SELECT CONVERT(NVARCHAR(4), ISNULL(@paymentMatched,0))  +' Payment(s) matched ', 'I' 
			END

			UPDATE @tblFeedback SET PaymentFound =ISNULL(@paymentFound,0), PaymentMatched = ISNULL(@paymentMatched,0),APIKey = (SELECT APIKey FROM tblIMISDefaults)

		IF @InTopIsolation = 0 
			COMMIT TRANSACTION MATCHPAYMENT
		
		SELECT fdMsg, fdType, productCode, InsuranceNumber, PhoneNumber, isActivated, Balance,PaymentFound, PaymentMatched, APIKey FROM @tblFeedback
		RETURN 0
		END TRY
		BEGIN CATCH
			IF @InTopIsolation = 0
				ROLLBACK TRANSACTION MATCHPAYMENT
			SELECT fdMsg, fdType FROM @tblFeedback
			SELECT ERROR_MESSAGE ()
			RETURN -1
		END CATCH
	

END

GO

IF NOT OBJECT_ID('uspAPIGetCoverage') IS NULL
DROP PROCEDURE uspAPIGetCoverage
GO
CREATE PROCEDURE [dbo].[uspAPIGetCoverage]
(
	
	@InsureeNumber NVARCHAR(12),
	@MinDateService DATE=NULL  OUTPUT,
	@MinDateItem DATE=NULL OUTPUT,
	@ServiceLeft INT=0 OUTPUT,
	@ItemLeft INT =0 OUTPUT,
	@isItemOK BIT =0 OUTPUT,
	@isServiceOK BIT=0 OUTPUT
)

AS

BEGIN



	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of head
		2-Insurance number of head not found
		
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1- Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3

	--2 - Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
		RETURN 4



	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/
	DECLARE @LocationId int =  0
	IF NOT OBJECT_ID('tempdb..#tempBase') IS NULL DROP TABLE #tempBase

		SELECT PL.PolicyValue,PL.EffectiveDate, PR.ProdID,PL.PolicyID,I.CHFID,P.PhotoFolder + case when RIGHT(P.PhotoFolder,1) = '\' then '' else '\' end + P.PhotoFileName PhotoPath,I.LastName, I.OtherNames,
		CONVERT(VARCHAR,DOB,103) DOB, CASE WHEN I.Gender = 'M' THEN 'Male' ELSE 'Female' END Gender,PR.ProductCode,PR.ProductName,
		CONVERT(VARCHAR(12),IP.ExpiryDate,103) ExpiryDate, 
		CASE WHEN IP.EffectiveDate IS NULL OR CAST(GETDATE() AS DATE) < IP.EffectiveDate  THEN 'I' WHEN CAST(GETDATE() AS DATE) NOT BETWEEN IP.EffectiveDate AND IP.ExpiryDate THEN 'E' ELSE 
		CASE PL.PolicyStatus WHEN 1 THEN 'I' WHEN 2 THEN 'A' WHEN 4 THEN 'S' ELSE 'E' END
		END  AS [Status]
		INTO #tempBase
		FROM tblInsuree I LEFT OUTER JOIN tblPhotos P ON I.PhotoID = P.PhotoID
		INNER JOIN tblFamilies F ON I.FamilyId = F.FamilyId 
		INNER JOIN tblVillages V ON V.VillageId = F.LocationId
		INNER JOIN tblWards W ON W.WardId = V.WardId
		INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId
		LEFT OUTER JOIN tblPolicy PL ON I.FamilyID = PL.FamilyID
		LEFT OUTER JOIN tblProduct PR ON PL.ProdID = PR.ProdID
		LEFT OUTER JOIN tblInsureePolicy IP ON IP.InsureeId = I.InsureeId AND IP.PolicyId = PL.PolicyID
		WHERE I.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND P.ValidityTo IS NULL AND PR.ValidityTo IS NULL AND IP.ValidityTo IS NULL AND F.ValidityTo IS NULL
		AND (I.CHFID = @InsureeNumber OR @InsureeNumber = '')
		AND (D.DistrictID = @LocationId or @LocationId= 0)


	DECLARE @Members INT = (SELECT COUNT(1) FROM tblInsuree WHERE FamilyID = (SELECT TOP 1 FamilyId FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL) AND ValidityTo IS NULL); 		
	DECLARE @InsureeId INT = (SELECT InsureeId FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
	DECLARE @FamilyId INT = (SELECT FamilyId FROM tblInsuree WHERE ValidityTO IS NULL AND CHFID = @InsureeNumber);

		
	IF NOT OBJECT_ID('tempdb..#tempDedRem')IS NULL DROP TABLE #tempDedRem
	CREATE TABLE #tempDedRem (PolicyId INT,ProdID INT,DedInsuree DECIMAL(18,2),DedOPInsuree DECIMAL(18,2),DedIPInsuree DECIMAL(18,2),MaxInsuree DECIMAL(18,2),MaxOPInsuree DECIMAL(18,2),MaxIPInsuree DECIMAL(18,2),DedTreatment DECIMAL(18,2),DedOPTreatment DECIMAL(18,2),DedIPTreatment DECIMAL(18,2),MaxTreatment DECIMAL(18,2),MaxOPTreatment DECIMAL(18,2),MaxIPTreatment DECIMAL(18,2),DedPolicy DECIMAL(18,2),DedOPPolicy DECIMAL(18,2),DedIPPolicy DECIMAL(18,2),MaxPolicy DECIMAL(18,2),MaxOPPolicy DECIMAL(18,2),MaxIPPolicy DECIMAL(18,2))

	INSERT INTO #tempDedRem(PolicyId, ProdID ,DedInsuree ,DedOPInsuree ,DedIPInsuree ,MaxInsuree ,MaxOPInsuree ,MaxIPInsuree ,DedTreatment ,DedOPTreatment ,DedIPTreatment ,MaxTreatment ,MaxOPTreatment ,MaxIPTreatment ,DedPolicy ,DedOPPolicy ,DedIPPolicy ,MaxPolicy ,MaxOPPolicy ,MaxIPPolicy)
					SELECT #tempBase.PolicyId, #tempBase.ProdID,
					DedInsuree ,DedOPInsuree ,DedIPInsuree ,
					MaxInsuree,MaxOPInsuree,MaxIPInsuree ,
					DedTreatment ,DedOPTreatment ,DedIPTreatment,
					MaxTreatment ,MaxOPTreatment ,MaxIPTreatment,
					DedPolicy ,DedOPPolicy ,DedIPPolicy , 
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy > MaxCeilingPolicy THEN MaxCeilingPolicy ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMember, 0)) + MaxPolicy END MaxPolicy ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy > MaxCeilingPolicyOP THEN MaxCeilingPolicyOP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberOP, 0)) + MaxOPPolicy END MaxOPPolicy ,
					CASE WHEN ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy > MaxCeilingPolicyIP THEN MaxCeilingPolicyIP ELSE ISNULL(NULLIF(SIGN(((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0))),-1),0) * ((CASE WHEN MemberCount - @Members < 0 THEN MemberCount ELSE @Members END - Threshold) * ISNULL(MaxPolicyExtraMemberIP, 0)) + MaxIPPolicy END MaxIPPolicy
					FROM tblProduct INNER JOIN #tempBase ON tblProduct.ProdID = #tempBase.ProdID
					WHERE ValidityTo IS NULL



IF EXISTS(SELECT 1 FROM tblClaimDedRem WHERE InsureeID = @InsureeId AND ValidityTo IS NULL)
BEGIN			
	UPDATE #tempDedRem
	SET 
	DedInsuree = (SELECT DedInsuree - ISNULL(SUM(DedG),0) 
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyID = #tempDedRem.PolicyId
			AND InsureeId = @InsureeId
			GROUP BY DedInsuree),
	DedOPInsuree = (select DedOPInsuree - ISNULL(SUM(DedOP),0) 
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND InsureeId = @InsureeId
			GROUP BY DedOPInsuree),
	DedIPInsuree = (SELECT DedIPInsuree - ISNULL(SUM(DedIP),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND InsureeId = @InsureeId
			GROUP BY DedIPInsuree) ,
	MaxInsuree = (SELECT MaxInsuree - ISNULL(SUM(RemG),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND InsureeId = @InsureeId
			GROUP BY MaxInsuree ),
	MaxOPInsuree = (SELECT MaxOPInsuree - ISNULL(SUM(RemOP),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND InsureeId = @InsureeId
			GROUP BY MaxOPInsuree ) ,
	MaxIPInsuree = (SELECT MaxIPInsuree - ISNULL(SUM(RemIP),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND InsureeId = @InsureeId
			GROUP BY MaxIPInsuree),
	DedTreatment = (SELECT DedTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID ) ,
	DedOPTreatment = (SELECT DedOPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
	DedIPTreatment = (SELECT DedIPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
	MaxTreatment = (SELECT MaxTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
	MaxOPTreatment = (SELECT MaxOPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) ,
	MaxIPTreatment = (SELECT MaxIPTreatment FROM tblProduct WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID) 
	
END



IF EXISTS(SELECT 1
			FROM tblInsuree I INNER JOIN tblClaimDedRem DR ON I.InsureeId = DR.InsureeId
			WHERE I.ValidityTo IS NULL
			AND DR.ValidityTO IS NULL
			AND I.FamilyId = @FamilyId)			
BEGIN
	UPDATE #tempDedRem SET
	DedPolicy = (SELECT DedPolicy - ISNULL(SUM(DedG),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND FamilyId = @FamilyId
			GROUP BY DedPolicy),
	DedOPPolicy = (SELECT DedOPPolicy - ISNULL(SUM(DedOP),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND FamilyId = @FamilyId
			GROUP BY DedOPPolicy),
	DedIPPolicy = (SELECT DedIPPolicy - ISNULL(SUM(DedIP),0)
			FROM tblProduct INNER JOIN tblPolicy ON tblProduct.ProdID = tblPolicy.ProdID
			LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID
			WHERE tblProduct.ValidityTo IS NULL 
			AND tblProduct.ProdID = #tempDedRem.ProdID
			AND tblClaimDedRem.PolicyId = #tempDedRem.PolicyId
			AND FamilyId = @FamilyId
			GROUP BY DedIPPolicy)


	UPDATE t SET MaxPolicy = MaxPolicyLeft, MaxOPPolicy = MaxOPLeft, MaxIPPolicy = MaxIPLeft
	FROM #tempDedRem t LEFT OUTER JOIN
	(SELECT t.PolicyId, t.ProdId, t.MaxPolicy - ISNULL(SUM(RemG),0)MaxPolicyLeft
	FROM #tempDedRem t INNER JOIN tblPolicy ON t.ProdID = tblPolicy.ProdID --AND tblPolicy.PolicyStatus = 2 
	LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID AND tblClaimDedRem.PolicyId = t.PolicyId
	WHERE FamilyId = @FamilyId
	
	--AND Prod.ValidityTo IS NULL AND Prod.ProdID = t.ProdID
	GROUP BY t.ProdId, t.MaxPolicy, t.PolicyId)MP ON t.ProdID = MP.ProdID AND t.PolicyId = MP.PolicyId
	LEFT OUTER JOIN
	--UPDATE t SET MaxOPPolicy = MaxOPLeft
	--FROM #tempDedRem t LEFT OUTER JOIN
	(SELECT t.PolicyId, t.ProdId, MaxOPPolicy - ISNULL(SUM(RemOP),0) MaxOPLeft
	FROM #tempDedRem t INNER JOIN tblPolicy ON t.ProdID = tblPolicy.ProdID  --AND tblPolicy.PolicyStatus = 2
	LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID AND tblClaimDedRem.PolicyId = t.PolicyId
	WHERE FamilyId = @FamilyId
	
	--WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID
	GROUP BY t.ProdId, MaxOPPolicy, t.PolicyId)MOP ON t.ProdId = MOP.ProdID AND t.PolicyId = MOP.PolicyId
	LEFT OUTER JOIN
	(SELECT t.PolicyId, t.ProdId, MaxIPPolicy - ISNULL(SUM(RemIP),0) MaxIPLeft
	FROM #tempDedRem t INNER JOIN tblPolicy ON t.ProdID = tblPolicy.ProdID  --AND tblPolicy.PolicyStatus = 2
	LEFT OUTER JOIN tblClaimDedRem ON tblPolicy.PolicyID = tblClaimDedRem.PolicyID AND tblClaimDedRem.PolicyId = t.PolicyId
	WHERE FamilyId = @FamilyId
	
	--WHERE tblProduct.ValidityTo IS NULL AND tblProduct.ProdID = #tempDedRem.ProdID
	GROUP BY t.ProdId, MaxIPPolicy, t.PolicyId)MIP ON t.ProdId = MIP.ProdID AND t.PolicyId = MIP.PolicyId	
END
 
 BEGIN


	-- @InsureeId  = (SELECT InsureeId FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
	DECLARE @Age INT = (SELECT DATEDIFF(YEAR,DOB,GETDATE()) FROM tblInsuree WHERE InsureeID = @InsureeId)
	
	DECLARE @ServiceCode NVARCHAR(6) = N''
	DECLARE @ItemCode NVARCHAR(6) = N''

	SET NOCOUNT ON

	--Service Information
	
	IF LEN(@ServiceCode) > 0
	BEGIN
		DECLARE @ServiceId INT = (SELECT ServiceId FROM tblServices WHERE ServCode = @ServiceCode AND ValidityTo IS NULL)
		DECLARE @ServiceCategory CHAR(1) = (SELECT ServCategory FROM tblServices WHERE ServiceID = @ServiceId)
		
		DECLARE @tblService TABLE(EffectiveDate DATE,ProdId INT,MinDate DATE,ServiceLeft INT)
		
		INSERT INTO @tblService
		SELECT IP.EffectiveDate, PL.ProdID,
		DATEADD(MONTH,CASE WHEN @Age >= 18 THEN  PS.WaitingPeriodAdult ELSE PS.WaitingPeriodChild END,IP.EffectiveDate) MinDate,
		(CASE WHEN @Age >= 18 THEN NULLIF(PS.LimitNoAdult,0) ELSE NULLIF(PS.LimitNoChild,0) END) - COUNT(CS.ServiceID) ServicesLeft
		FROM tblInsureePolicy IP INNER JOIN tblPolicy PL ON IP.PolicyId = PL.PolicyID
		INNER JOIN tblProductServices PS ON PL.ProdID = PS.ProdID
		LEFT OUTER JOIN tblClaim C ON IP.InsureeId = C.InsureeID
		LEFT JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		WHERE IP.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND PS.ValidityTo IS NULL AND C.ValidityTo IS NULL AND CS.ValidityTo IS NULL
		AND IP.InsureeId = @InsureeId
		AND PS.ServiceID = @ServiceId
		AND (C.ClaimStatus > 2 OR C.ClaimStatus IS NULL)
		AND (CS.ClaimServiceStatus = 1 OR CS.ClaimServiceStatus IS NULL)
		AND PL.PolicyStatus = 2
		GROUP BY IP.EffectiveDate, PL.ProdID,PS.WaitingPeriodAdult,PS.WaitingPeriodChild,PS.LimitNoAdult,PS.LimitNoChild


		IF EXISTS(SELECT 1 FROM @tblService WHERE MinDate <= GETDATE())
			SET @MinDateService = (SELECT MIN(MinDate) FROM @tblService WHERE MinDate <= GETDATE())
		ELSE
			SET @MinDateService = (SELECT MIN(MinDate) FROM @tblService)
			
		IF EXISTS(SELECT 1 FROM @tblService WHERE MinDate <= GETDATE() AND ServiceLeft IS NULL)
			SET @ServiceLeft = NULL
		ELSE
			SET @ServiceLeft = (SELECT MAX(ServiceLeft) FROM @tblService WHERE ISNULL(MinDate, GETDATE()) <= GETDATE())
	END
	--

	--Item Information
	
	
	IF LEN(@ItemCode) > 0
	BEGIN
		DECLARE @ItemId INT = (SELECT ItemId FROM tblItems WHERE ItemCode = @ItemCode AND ValidityTo IS NULL)
		
		DECLARE @tblItem TABLE(EffectiveDate DATE,ProdId INT,MinDate DATE,ItemsLeft INT)

		INSERT INTO @tblItem
		SELECT IP.EffectiveDate, PL.ProdID,
		DATEADD(MONTH,CASE WHEN @Age >= 18 THEN  PItem.WaitingPeriodAdult ELSE PItem.WaitingPeriodChild END,IP.EffectiveDate) MinDate,
		(CASE WHEN @Age >= 18 THEN NULLIF(PItem.LimitNoAdult,0) ELSE NULLIF(PItem.LimitNoChild,0) END) - COUNT(CI.ItemID) ItemsLeft
		FROM tblInsureePolicy IP INNER JOIN tblPolicy PL ON IP.PolicyId = PL.PolicyID
		INNER JOIN tblProductItems PItem ON PL.ProdID = PItem.ProdID
		LEFT OUTER JOIN tblClaim C ON IP.InsureeId = C.InsureeID
		LEFT OUTER JOIN tblClaimItems CI ON C.ClaimID = CI.ClaimID
		WHERE IP.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND PItem.ValidityTo IS NULL AND C.ValidityTo IS NULL AND CI.ValidityTo IS NULL
		AND IP.InsureeId = @InsureeId
		AND PItem.ItemID = @ItemId
		AND (C.ClaimStatus > 2  OR C.ClaimStatus IS NULL)
		AND (CI.ClaimItemStatus = 1 OR CI.ClaimItemStatus IS NULL)
		AND PL.PolicyStatus = 2
		GROUP BY IP.EffectiveDate, PL.ProdID,PItem.WaitingPeriodAdult,PItem.WaitingPeriodChild,PItem.LimitNoAdult,PItem.LimitNoChild


		IF EXISTS(SELECT 1 FROM @tblItem WHERE MinDate <= GETDATE())
			SET @MinDateItem = (SELECT MIN(MinDate) FROM @tblItem WHERE MinDate <= GETDATE())
		ELSE
			SET @MinDateItem = (SELECT MIN(MinDate) FROM @tblItem)
			
		IF EXISTS(SELECT 1 FROM @tblItem WHERE MinDate <= GETDATE() AND ItemsLeft IS NULL)
			SET @ItemLeft = NULL
		ELSE
			SET @ItemLeft = (SELECT MAX(ItemsLeft) FROM @tblItem WHERE ISNULL(MinDate, GETDATE()) <= GETDATE())
	END
	
	--

	DECLARE @Result TABLE(ProdId INT, TotalAdmissionsLeft INT, TotalVisitsLeft INT, TotalConsultationsLeft INT, TotalSurgeriesLeft INT, TotalDelivieriesLeft INT, TotalAntenatalLeft INT,
					ConsultationAmountLeft DECIMAL(18,2),SurgeryAmountLeft DECIMAL(18,2),DeliveryAmountLeft DECIMAL(18,2),HospitalizationAmountLeft DECIMAL(18,2), AntenatalAmountLeft DECIMAL(18,2))

	INSERT INTO @Result
	SELECT  Prod.ProdId,
	Prod.MaxNoHospitalizaion - ISNULL(TotalAdmissions,0)TotalAdmissionsLeft,
	Prod.MaxNoVisits - ISNULL(TotalVisits,0)TotalVisitsLeft,
	Prod.MaxNoConsultation - ISNULL(TotalConsultations,0)TotalConsultationsLeft,
	Prod.MaxNoSurgery - ISNULL(TotalSurgeries,0)TotalSurgeriesLeft,
	Prod.MaxNoDelivery - ISNULL(TotalDelivieries,0)TotalDelivieriesLeft,
	Prod.MaxNoAntenatal - ISNULL(TotalAntenatal, 0)TotalAntenatalLeft,
	--Changes by Rogers Start
	Prod.MaxAmountConsultation ConsultationAmountLeft, --- SUM(ISNULL(Rem.RemConsult,0)) ConsultationAmountLeft,
	Prod.MaxAmountSurgery SurgeryAmountLeft ,--- SUM(ISNULL(Rem.RemSurgery,0)) SurgeryAmountLeft ,
	Prod.MaxAmountDelivery DeliveryAmountLeft,--- SUM(ISNULL(Rem.RemDelivery,0)) DeliveryAmountLeft,By Rogers (Amount must Remain Constant)
	Prod.MaxAmountHospitalization HospitalizationAmountLeft, -- SUM(ISNULL(Rem.RemHospitalization,0)) HospitalizationAmountLeft, By Rogers (Amount must Remain Constant)
	Prod.MaxAmountAntenatal AntenatalAmountLeft -- - SUM(ISNULL(Rem.RemAntenatal, 0)) AntenatalAmountLeft By Rogers (Amount must Remain Constant)
	--Changes by Rogers End
	FROM tblInsureePolicy IP INNER JOIN tblPolicy PL ON IP.PolicyId = PL.PolicyID
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	LEFT OUTER JOIN tblClaimDedRem Rem ON PL.PolicyID = Rem.PolicyID AND Rem.InsureeID = IP.InsureeId

	LEFT OUTER JOIN
		(SELECT COUNT(C.ClaimID)TotalAdmissions,CS.ProdID
		FROM tblClaim C INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		INNER JOIN tblInsureePolicy IP ON C.InsureeID = IP.InsureeID
		WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL AND IP.ValidityTo IS NULL
		AND C.ClaimStatus > 2
		AND CS.RejectionReason = 0
		AND C.InsureeID = @InsureeId
		AND C.ClaimCategory = 'H'
		AND (ISNULL(C.DateTo,C.DateFrom) BETWEEN IP.EffectiveDate AND IP.ExpiryDate)
		GROUP BY CS.ProdID)TotalAdmissions ON TotalAdmissions.ProdID = Prod.ProdId
		
		LEFT OUTER JOIN
		(SELECT COUNT(C.ClaimID)TotalVisits,CS.ProdID
		FROM tblClaim C INNER JOIN tblClaimServices CS ON C.ClaimID = CS.ClaimID
		WHERE C.ValidityTo IS NULL AND CS.ValidityTo IS NULL 
		AND C.ClaimStatus > 2
		AND CS.RejectionReason = 0
		AND C.InsureeID = @InsureeId
		AND C.ClaimCategory = 'V'
		GROUP BY CS.ProdID)TotalVisits ON Prod.ProdID = TotalVisits.ProdID
		LEFT OUTER JOIN
		
		(SELECT COUNT(C.ClaimID) TotalConsultations,CS.ProdID
		FROM tblClaim C 
		INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
		WHERE C.ValidityTo IS NULL 
		AND C.ClaimStatus > 2
		AND C.InsureeID = @InsureeId
		AND C.ClaimCategory = 'C'
		GROUP BY CS.ProdID) TotalConsultations ON Prod.ProdID = TotalConsultations.ProdID
		LEFT OUTER JOIN
		
		(SELECT COUNT(C.ClaimID) TotalSurgeries,CS.ProdID
		FROM tblClaim C 
		INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
		WHERE C.ValidityTo IS NULL 
		AND C.ClaimStatus > 2
		AND C.InsureeID = @InsureeId
		AND C.ClaimCategory = 'S'
		GROUP BY CS.ProdID)TotalSurgeries ON Prod.ProdID = TotalSurgeries.ProdID
		LEFT OUTER JOIN
		
		(SELECT COUNT(C.ClaimID) TotalDelivieries,CS.ProdID
		FROM tblClaim C 
		INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
		WHERE C.ValidityTo IS NULL 
		AND C.ClaimStatus > 2
		AND C.InsureeID = @InsureeId
		AND C.ClaimCategory = 'D'
		GROUP BY CS.ProdID)TotalDelivieries ON Prod.ProdID = TotalDelivieries.ProdID
		LEFT OUTER JOIN
		
		(SELECT COUNT(C.ClaimID) TotalAntenatal,CS.ProdID
		FROM tblClaim C 
		INNER JOIN (SELECT ClaimId, ProdId FROM tblClaimServices WHERE ValidityTo IS NULL AND RejectionReason = 0 GROUP BY ClaimId, ProdID) CS ON C.ClaimID = CS.ClaimID
		WHERE C.ValidityTo IS NULL 
		AND C.ClaimStatus > 2
		AND C.InsureeID = @InsureeId
		AND C.ClaimCategory = 'A'
		GROUP BY CS.ProdID)TotalAntenatal ON Prod.ProdID = TotalAntenatal.ProdID
		
	WHERE IP.ValidityTo IS NULL AND PL.ValidityTo IS NULL AND Prod.ValidityTo IS NULL AND Rem.ValidityTo IS NULL
	AND IP.InsureeId = @InsureeId

	GROUP BY Prod.ProdID,Prod.MaxNoHospitalizaion,TotalAdmissions, Prod.MaxNoVisits, TotalVisits, Prod.MaxNoConsultation, 
	TotalConsultations, Prod.MaxNoSurgery, TotalSurgeries, Prod.MaxNoDelivery, Prod.MaxNoAntenatal, TotalDelivieries, TotalAntenatal,Prod.MaxAmountConsultation,
	Prod.MaxAmountSurgery, Prod.MaxAmountDelivery, Prod.MaxAmountHospitalization, Prod.MaxAmountAntenatal
	
	Update @Result set TotalAdmissionsLeft=0 where TotalAdmissionsLeft<0;
	Update @Result set TotalVisitsLeft=0 where TotalVisitsLeft<0;
	Update @Result set TotalConsultationsLeft=0 where TotalConsultationsLeft<0;
	Update @Result set TotalSurgeriesLeft=0 where TotalSurgeriesLeft<0;
	Update @Result set TotalDelivieriesLeft=0 where TotalDelivieriesLeft<0;
	Update @Result set TotalAntenatalLeft=0 where TotalAntenatalLeft<0;

	DECLARE @MaxNoSurgery INT,
			@MaxNoConsultation INT,
			@MaxNoDeliveries INT,
			@TotalAmountSurgery DECIMAL(18,2),
			@TotalAmountConsultant DECIMAL(18,2),
			@TotalAmountDelivery DECIMAL(18,2)
			
	SELECT TOP 1 @MaxNoSurgery = TotalSurgeriesLeft, @MaxNoConsultation = TotalConsultationsLeft, @MaxNoDeliveries = TotalDelivieriesLeft,
	@TotalAmountSurgery = SurgeryAmountLeft, @TotalAmountConsultant = ConsultationAmountLeft, @TotalAmountDelivery = DeliveryAmountLeft 
	FROM @Result 


	 

	IF @ServiceCategory = N'S'
		BEGIN
			IF @MaxNoSurgery = 0 OR @ServiceLeft = 0 OR @MinDateService > GETDATE() OR @TotalAmountSurgery <= 0
				SET @isServiceOK = 0
			ELSE
				SET @isServiceOK = 1
		END
	ELSE IF @ServiceCategory = N'C'
		BEGIN
			IF @MaxNoConsultation = 0 OR @ServiceLeft = 0 OR @MinDateService > GETDATE() OR @TotalAmountConsultant <= 0
				SET @isServiceOK = 0
			ELSE
				SET @isServiceOK = 1
		END
	ELSE IF @ServiceCategory = N'D'
		BEGIN
			IF @MaxNoDeliveries = 0 OR @ServiceLeft = 0 OR @MinDateService > GETDATE() OR @TotalAmountDelivery  <= 0
				SET @isServiceOK = 0
			ELSE
				SET @isServiceOK = 1
		END
	ELSE IF @ServiceCategory = N'O'
		BEGIN
			IF  @ServiceLeft = 0 OR @MinDateService > GETDATE() 
				SET @isServiceOK = 0
			ELSE
				SET @isServiceOK = 1
		END
	ELSE 
		BEGIN
			IF  @ServiceLeft = 0 OR @MinDateService > GETDATE() 
				SET @isServiceOK = 0
			ELSE
				SET @isServiceOK = 1
		END

     

	IF @ItemLeft = 0 OR @MinDateItem > GETDATE() 
		SET @isItemOK = 0
	ELSE
		SET @isItemOK = 1


END


	ALTER TABLE #tempBase ADD DedType FLOAT NULL
	ALTER TABLE #tempBase ADD Ded1 DECIMAL(18,2) NULL
	ALTER TABLE #tempBase ADD Ded2 DECIMAL(18,2) NULL
	ALTER TABLE #tempBase ADD Ceiling1 DECIMAL(18,2) NULL
	ALTER TABLE #tempBase ADD Ceiling2 DECIMAL(18,2) NULL
			
	DECLARE @ProdID INT
	DECLARE @DedType FLOAT = NULL
	DECLARE @Ded1 DECIMAL(18,2) = NULL
	DECLARE @Ded2 DECIMAL(18,2) = NULL
	DECLARE @Ceiling1 DECIMAL(18,2) = NULL
	DECLARE @Ceiling2 DECIMAL(18,2) = NULL
	DECLARE @PolicyID INT


	DECLARE @InsuranceNumber NVARCHAR(12)
	DECLARE @OtherNames NVARCHAR(100)
	DECLARE @LastName NVARCHAR(100)
	DECLARE @BirthDate DATE
	DECLARE @Gender NVARCHAR(1)
	DECLARE @ProductCode NVARCHAR(8) = NULL
	DECLARE @ProductName NVARCHAR(50)
	DECLARE @PolicyValue DECIMAL
	DECLARE @EffectiveDate DATE=NULL
	DECLARE @ExpiryDate DATE=NULL
	DECLARE @PolicyStatus BIT =0
	DECLARE @DeductionType INT
	DECLARE @DedNonHospital DECIMAL(18,2)
	DECLARE @DedHospital DECIMAL(18,2)
	DECLARE @CeilingHospital DECIMAL(18,2)
	DECLARE @CeilingNonHospital DECIMAL(18,2)
	DECLARE @AdmissionLeft NVARCHAR
	DECLARE @PhotoPath NVARCHAR
	DECLARE @VisitLeft NVARCHAR(200)=NULL
	DECLARE @ConsultationLeft NVARCHAR(50)=NULL
	DECLARE @SurgeriesLeft NVARCHAR
	DECLARE @DeliveriesLeft NVARCHAR(50)=NULL
	DECLARE @Anc_CareLeft NVARCHAR(100)=NULL
	DECLARE @IdentificationNumber NVARCHAR(25)=NULL
	DECLARE @ConsultationAmount DECIMAL(18,2)
	DECLARE @SurgriesAmount DECIMAL(18,2)
	DECLARE @DeliveriesAmount DECIMAL(18,2)


	DECLARE Cur CURSOR FOR SELECT DISTINCT ProdId, PolicyId FROM #tempDedRem
	OPEN Cur
	FETCH NEXT FROM Cur INTO @ProdID, @PolicyId

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Ded1 = NULL
		SET @Ded2 = NULL
		SET @Ceiling1 = NULL
		SET @Ceiling2 = NULL
		
		SELECT @Ded1 =  CASE WHEN NOT DedInsuree IS NULL THEN DedInsuree WHEN NOT DedTreatment IS NULL THEN DedTreatment WHEN NOT DedPolicy IS NULL THEN DedPolicy ELSE NULL END  FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
		IF NOT @Ded1 IS NULL SET @DedType = 1
		
		IF @Ded1 IS NULL
		BEGIN
			SELECT @Ded1 = CASE WHEN NOT DedIPInsuree IS NULL THEN DedIPInsuree WHEN NOT DedIPTreatment IS NULL THEN DedIPTreatment WHEN NOT DedIPPolicy IS NULL THEN DedIPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			SELECT @Ded2 = CASE WHEN NOT DedOPInsuree IS NULL THEN DedOPInsuree WHEN NOT DedOPTreatment IS NULL THEN DedOPTreatment WHEN NOT DedOPPolicy IS NULL THEN DedOPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			IF NOT @Ded1 IS NULL OR NOT @Ded2 IS NULL SET @DedType = 1.1
		END
		
		SELECT @Ceiling1 =  CASE WHEN NOT MaxInsuree IS NULL THEN MaxInsuree WHEN NOT MaxTreatment IS NULL THEN MaxTreatment WHEN NOT MaxPolicy IS NULL THEN MaxPolicy ELSE NULL END  FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
		IF NOT @Ceiling1 IS NULL SET @DedType = 1
		
		IF @Ceiling1 IS NULL
		BEGIN
			SELECT @Ceiling1 = CASE WHEN NOT MaxIPInsuree IS NULL THEN MaxIPInsuree WHEN NOT MaxIPTreatment IS NULL THEN MaxIPTreatment WHEN NOT MaxIPPolicy IS NULL THEN MaxIPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			SELECT @Ceiling2 = CASE WHEN NOT MaxOPInsuree IS NULL THEN MaxOPInsuree WHEN NOT MaxOPTreatment IS NULL THEN MaxOPTreatment WHEN NOT MaxOPPolicy IS NULL THEN MaxOPPolicy ELSE NULL END FROM #tempDedRem WHERE ProdID = @ProdID AND PolicyId = @PolicyId
			IF NOT @Ceiling1 IS NULL OR NOT @Ceiling2 IS NULL SET @DedType = 1.1
		END
		
			UPDATE #tempBase SET DedType = @DedType, Ded1 = @Ded1, Ded2 = CASE WHEN @DedType = 1 THEN @Ded1 ELSE @Ded2 END,Ceiling1 = @Ceiling1,Ceiling2 = CASE WHEN @DedType = 1 THEN @Ceiling1 ELSE @Ceiling2 END
		WHERE ProdID = @ProdID
		 AND PolicyId = @PolicyId
		
	FETCH NEXT FROM Cur INTO @ProdID, @PolicyId
	END

	CLOSE Cur
	DEALLOCATE Cur

	--DECLARE @LASTRESULT TABLE(PolicyValue DECIMAL(18,2) NULL,EffectiveDate DATE NULL, LastName NVARCHAR(100) NULL, OtherNames NVARCHAR(100) NULL,CHFID NVARCHAR(12), PhotoPath  NVARCHAR(100) NULL,  DOB DATE NULL ,Gender NVARCHAR(1) NULL,ProductCode NVARCHAR(8) NULL,ProductName NVARCHAR(50) NULL, ExpiryDate DATE NULL, [Status] NVARCHAR(1) NULL,DedType FLOAT NULL, Ded1 DECIMAL(18,2)NULL,  Ded2 DECIMAL(18,2)NULL, Ceiling1 DECIMAL(18,2)NULL, Ceiling2 DECIMAL(18,2)NULL)
  IF (SELECT COUNT(*) FROM #tempBase WHERE [Status] = 'A') > 0
 SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft,  r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft, PolicyValue, EffectiveDate, LastName, OtherNames,CHFID, PhotoPath,  DOB,Gender,ProductCode ,ProductName, ExpiryDate, [Status],DedType, Ded1,  Ded2, CASE WHEN Ceiling1 < 0 THEN 0 ELSE  Ceiling1 END Ceiling1 , CASE WHEN Ceiling2< 0 THEN 0 ELSE Ceiling2 END Ceiling2   from #tempBase T LEFT OUTER JOIN @Result R ON R.ProdId = T.ProdID WHERE [Status] = 'A';
		
	ELSE 
		IF (SELECT COUNT(1) FROM #tempBase WHERE (YEAR(GETDATE()) - YEAR(CONVERT(DATETIME,ExpiryDate,103))) <= 2) > 1
	  SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft,  r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft,  PolicyValue,EffectiveDate, LastName, OtherNames,CHFID, PhotoPath,  DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase T LEFT OUTER JOIN @Result R ON R.ProdId = T.ProdID WHERE (YEAR(GETDATE()) - YEAR(CONVERT(DATETIME,ExpiryDate,103))) <= 2;
		ELSE
	
			 SELECT R.AntenatalAmountLeft,R.ConsultationAmountLeft,R.DeliveryAmountLeft, R.HospitalizationAmountLeft,R.SurgeryAmountLeft,R.TotalAdmissionsLeft,R.TotalAntenatalLeft, R.TotalConsultationsLeft, r.TotalDelivieriesLeft, R.TotalSurgeriesLeft ,r.TotalVisitsLeft, PolicyValue,EffectiveDate, LastName, OtherNames, CHFID, PhotoPath,  DOB,Gender,ProductCode,ProductName,ExpiryDate,[Status],DedType,Ded1,Ded2,CASE WHEN Ceiling1<0 THEN 0 ELSE Ceiling1 END Ceiling1,CASE WHEN Ceiling2<0 THEN 0 ELSE Ceiling2 END Ceiling2  from #tempBase T LEFT OUTER JOIN @Result R  ON R.ProdId = T.ProdID
END

GO

IF NOT OBJECT_ID('uspAPIEnterContribution') IS NULL
DROP PROCEDURE uspAPIEnterContribution
GO
CREATE PROCEDURE [dbo].[uspAPIEnterContribution]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12),
	@Payer NVARCHAR(100),
	@PaymentDate DATE,
	@ProductCode NVARCHAR(8),
	@ContributionAmount DECIMAL(18,2),
	@ReceiptNo NVARCHAR(50),
	@PaymentType CHAR(1),
	@ContributionCategory CHAR(1) = NULL,
	@ReactionType BIT
	
)

AS
BEGIN
	/*
	RESPONSE CODES
		1-Wrong format or missing insurance number 
		2-Insurance number of not found
		3- Wrong or missing  product code (policy of the product code not assigned to the family/group)
		4- Wrong or missing payment date
		5- Wrong contribution category
		6-Wrong or missing payment type
		7-Wrong or missing payer
		8-Missing receipt no.
		9-Duplicated receipt no.
		0 - all ok
		-1 Unknown Error

	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	DECLARE @tblPaymentType TABLE(PaymentTypeCode NVARCHAR(1))
		DECLARE @isValid BIT
		INSERT INTO @tblPaymentType(PaymentTypeCode) 
		VALUES ('B'),('C'),('F'),('M')
	--1-Wrong format or missing insurance number 
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1
	
	--2-Insurance number of not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong or missing product code (not existing or not applicable to the family/group)
	IF LEN(ISNULL(@ProductCode,'')) = 0
		RETURN 3

	IF NOT EXISTS(SELECT F.LocationId, V.LocationName, V.LocationType, D.ParentLocationId, PR.ProductCode FROM tblInsuree I
		INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
		INNER JOIN tblLocations V ON V.LocationId = F.LocationId
		INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
		INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
		INNER JOIN tblProduct PR ON (PR.LocationId = D.LocationId) OR PR.LocationId =  D.ParentLocationId OR PR.LocationId IS NULL 
		WHERE
		F.ValidityTo IS NULL
		AND V.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL AND PR.ProductCode =@ProductCode
		AND I.CHFID = @InsuranceNumber AND I.ValidityTo IS NULL AND I.IsHead = 1)
		RETURN 3

	--4- Wrong or missing payment date
	IF NULLIF(@PaymentDate,'') IS NULL
		RETURN 4

	--5- Wrong contribution category
	IF LEN(ISNULL(@ContributionCategory,'')) > 0
	IF NOT (@ContributionCategory = 'C' OR @ContributionCategory  = 'P') 
		 RETURN 5

		 --6-Wrong or missing payment type
	IF NOT EXISTS(SELECT 1 FROM @tblPaymentType WHERE PaymentTypeCode = @PaymentType) 
		 RETURN 6

	--7-Wrong or missing payer
	IF NOT EXISTS(SELECT 1 FROM tblPayer WHERE PayerName = @Payer AND ValidityTo IS NULL)
		RETURN 7
	
	--8-Missing receipt no.
	IF NULLIF(@ReceiptNo,'') IS NULL
		 RETURN 8

	--9-Duplicated receipt no.
	IF EXISTS(SELECT 1 FROM tblPolicy PL 
				INNER JOIN tblPremium PR ON PL.PolicyID = PR.PolicyID 
				INNER JOIN tblProduct Prod ON PL.ProdId = Prod.ProdId
				WHERE PL.ValidityTo IS NULL AND PR.ValidityTo IS NULL
				AND PR.Amount = @ContributionAmount AND PR.Receipt = @ReceiptNo AND Prod.ProductCode = @ProductCode)
		RETURN 9


	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION ENTERCONTRIBUTION
			
				DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
				DECLARE @FamilyId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@PaidAmount DECIMAL(18, 4),
				@PayerID INT,
				@PolicyStage CHAR(1),
				@EnrollmentDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId INT,
				@ProdId INT,
				@Active TINYINT=2,
				@Idle TINYINT=1,
				@OfficerID INT,
				@isPhotoFee BIT,
				@Installment INT, 
				@MaxInstallments INT,
				@LastDate DATE,
				@PremiumPayCount as INT 
				

				SELECT @ProdId = ProdID , @MaxInstallments = MaxInstallments  FROM tblProduct  WHERE ValidityTo IS NULL AND ProductCode = @ProductCode
				--find the right policy and family
				select @FamilyId = FamilyID  from tblInsuree where CHFID = @InsuranceNumber and ValidityTo IS NULL
				SELECT TOP 1 @PolicyId = PL.PolicyID, @PolicyStatus = PolicyStatus, @EnrollmentDate = PL.EnrollDate, @PolicyStage = PL.PolicyStage  FROM tblPolicy PL   WHERE FamilyID = @FamilyId AND PL.ValidityTo IS NULL AND PL.ProdID = @ProdId AND PolicyStatus = 1 ORDER BY PolicyStatus ASC,PolicyID DESC  
				
				DECLARE  @MaxDate TABLE (LastDate  Date) 
				INSERT @MaxDate (LastDate)
				EXECUTE  [dbo].[uspLastDateForPayment] 
				   @PolicyId
				
				SELECT @Installment = COUNT(PremiumID) from tblPremium WHERE PolicyID = @PolicyID and ValidityTo IS NULL
				SET @Installment = ISNULL(@Installment,0) + 1 

				SELECT @LastDate = LastDate FROM @MaxDate  
				
				SELECT @PayerID = PayerID FROM tblPayer WHERE ValidityTo IS NULL AND PayerName = @Payer
				
				IF ISNULL(@ContributionCategory,'') = 'P'
					SET @isPhotoFee = 1
				ELSE
					SET @isPhotoFee = 0

				INSERT INTO tblPremium(PolicyID,PayerID,Amount,Receipt,PayDate,PayType,ValidityFrom,AuditUserID,isPhotoFee)
				SELECT @PolicyId,@PayerID,ISNULL(@ContributionAmount,0),@ReceiptNo, @PaymentDate, @PaymentType,GETDATE(),@AuditUserId,@isPhotoFee

				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollmentDate, 0, @ErrorCode OUTPUT;
					
				
				SELECT @PaidAmount = ISNULL(SUM(Amount),0) FROM tblPremium WHERE PolicyId = @PolicyId and ValidityTo IS NULL AND isPhotoFee = 0 
				IF ((@PaidAmount >= @PolicyValue AND ( @Installment <= @MaxInstallments) AND (@PaymentDate <= @LastDate ) ) OR @ReactionType = 1) 
				BEGIN
					IF @PolicyStatus = 1
					BEGIN
						-- only activate if the policy was not yet activated (do not change anything on already suspended or expired policies 
						SET @PolicyStatus = @Active
						SET @EffectiveDate = @PaymentDate
						
						UPDATE tblInsureePolicy SET EffectiveDate = @EffectiveDate WHERE PolicyID = @PolicyId
						UPDATE tblPolicy SET PolicyStatus = @PolicyStatus, EffectiveDate = @EffectiveDate WHERE PolicyID = @PolicyId	
					END

				END
				--ELSE 
				--BEGIN
				--	--now check if we have problems in installments OR GracePeriod 
				--	SET @PolicyStatus = @Idle
				--	SET @EffectiveDate = NULL
				--END
			
			COMMIT TRANSACTION ENTERCONTRIBUTION
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENTERCONTRIBUTION
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

IF NOT OBJECT_ID('uspAPIEnterPolicy') IS NULL
DROP PROCEDURE uspAPIEnterPolicy
GO
CREATE PROCEDURE [dbo].[uspAPIEnterPolicy]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12),
	@EnrollmentDate DATE,
	@ProductCode NVARCHAR(8),
	@EnrollmentOfficerCode NVARCHAR(8)
)

AS
BEGIN
	/*
	RESPONSE CODES
		1-Wrong format or missing insurance number 
		2-Insurance number of not found
		3- Wrong or missing product code (not existing or not applicable to the family/group)
		4- Wrong or missing enrolment date
		5- Wrong or missing enrolment officer code (not existing or not applicable to the family/group)
		0 - all ok
		-1 Unknown Error

	*/


/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number 
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1
	
	--2-Insurance number of not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong or missing product code (not existing or not applicable to the family/group)
	IF LEN(ISNULL(@ProductCode,'')) = 0
		RETURN 3

	IF NOT EXISTS(SELECT F.LocationId, V.LocationName, V.LocationType, D.ParentLocationId, PR.ProductCode FROM tblInsuree I
		INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
		INNER JOIN tblLocations V ON V.LocationId = F.LocationId
		INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
		INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
		INNER JOIN tblProduct PR ON (PR.LocationId = D.LocationId) OR PR.LocationId =  D.ParentLocationId OR PR.LocationId IS NULL 
		WHERE
		F.ValidityTo IS NULL
		AND V.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL AND PR.ProductCode =@ProductCode AND PR.DateTo >= GETDATE()
		AND I.CHFID = @InsuranceNumber AND I.ValidityTo IS NULL AND I.IsHead = 1)
		RETURN 3

	--4- Wrong or missing enrolment date
	IF NULLIF(@EnrollmentDate,'') IS NULL
		RETURN 4

	--5- Wrong or missing enrolment officer code (not existing or not applicable to the family/group)
	IF LEN(ISNULL(@EnrollmentOfficerCode,'')) = 0
		RETURN 5
	
		IF NOT EXISTS(SELECT 1 FROM tblInsuree I 
						INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
						INNER JOIN tblLocations V ON V.LocationId = F.LocationId
						INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
						INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
						INNER JOIN tblOfficer O ON O.LocationId = D.LocationId
						WHERE 
						I.CHFID = @InsuranceNumber AND O.Code= @EnrollmentOfficerCode
						AND I.ValidityTo IS NULL
						AND F.ValidityTo IS NULL
						AND V.ValidityTo IS NULL
						AND O.ValidityTo IS NULL)
		 RETURN 5

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION ENTERPOLICY
			
				DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
				DECLARE @FamilyId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@ProdId INT,
				@PolicyStage CHAR(1) = N'N',
				@StartDate DATE,
				@ExpiryDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId INT,
				@Active TINYINT=2,
				@Idle TINYINT=1,
				@OfficerID INT,
				@HasCycle BIT

				SELECT @FamilyId = FamilyID FROM tblInsuree WHERE CHFID = @InsuranceNumber  AND ValidityTo IS NULL
				SELECT @ProdId = ProdID FROM tblProduct WHERE ProductCode = @ProductCode  AND ValidityTo IS NULL
				INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
				EXEC uspGetPolicyPeriod @ProdId, @EnrollmentDate, @HasCycle OUTPUT, @PolicyStage;
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @EnrollmentDate, 0, @ErrorCode OUTPUT;
				SELECT @StartDate = startDate FROM @tblPeriod
				SELECT @ExpiryDate = expiryDate FROM @tblPeriod
				SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @EnrollmentOfficerCode AND ValidityTo IS NULL

					INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
					SELECT	 @FamilyId,@EnrollmentDate,@StartDate,@EffectiveDate,@ExpiryDate,@Idle,@PolicyValue,@ProdId,@OfficerID,@PolicyStage,GETDATE(),@AuditUserId, 0 isOffline 
					SET @PolicyId = SCOPE_IDENTITY()

	

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

			COMMIT TRANSACTION ENTERPOLICY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENTERPOLICY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

IF NOT OBJECT_ID('uspAPIRenewPolicy') IS NULL
DROP PROCEDURE uspAPIRenewPolicy
GO
CREATE PROCEDURE [dbo].[uspAPIRenewPolicy]
(	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12),
	@RenewalDate DATE,
	@ProductCode NVARCHAR(8),
	@EnrollmentOfficerCode NVARCHAR(8)
)

AS
BEGIN
	/*
	RESPONSE CODES
		1-Wrong format or missing insurance number 
		2-Insurance number of not found
		3- Wrong or missing product code (not existing or not applicable to the family/group)
		4- Wrong or missing renewal date
		5- Wrong or missing enrolment officer code (not existing or not applicable to the family/group)
		0 - all ok
		-1 Unknown Error

	*/


/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number 
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1
	
	--2-Insurance number of not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong or missing product code (not existing or not applicable to the family/group)
	IF LEN(ISNULL(@ProductCode,'')) = 0
		RETURN 3

	IF NOT EXISTS(SELECT F.LocationId, V.LocationName, V.LocationType, D.ParentLocationId, PR.ProductCode FROM tblInsuree I
		INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
		INNER JOIN tblLocations V ON V.LocationId = F.LocationId
		INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
		INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
		INNER JOIN tblProduct PR ON (PR.LocationId = D.LocationId) OR PR.LocationId =  D.ParentLocationId OR PR.LocationId IS NULL 
		WHERE
		F.ValidityTo IS NULL
		AND V.ValidityTo IS NULL
		AND PR.ValidityTo IS NULL AND PR.ProductCode =@ProductCode
		AND I.CHFID = @InsuranceNumber AND I.ValidityTo IS NULL AND I.IsHead = 1)
		RETURN 3


	--Validating Conversional product
		DECLARE @ProdId INT,
				@ConvertionalProdId INT,
				@DateTo DATE
		
		SELECT @DateTo = DateTo, @ConvertionalProdId = ConversionProdID, @ProdId = ProdID FROM tblProduct WHERE ProductCode = @ProductCode  AND ValidityTo IS NULL
			
		IF GETDATE() > = @DateTo 
			BEGIN
				IF @ConvertionalProdId IS NOT NULL
						SET @ProdId = @ConvertionalProdId
					ELSE
						RETURN 3
			END
				
		--4- Wrong or missing renewal date
		IF NULLIF(@RenewalDate,'') IS NULL
			RETURN 4

		--5- Wrong or missing enrolment officer code (not existing or not applicable to the family/group)
		IF LEN(ISNULL(@EnrollmentOfficerCode,'')) = 0
			RETURN 5
	
		IF NOT EXISTS(SELECT 1 FROM tblInsuree I 
						INNER JOIN tblFamilies F ON F.FamilyID = I.FamilyID
						INNER JOIN tblLocations V ON V.LocationId = F.LocationId
						INNER JOIN tblLocations M ON M.LocationId = V.ParentLocationId
						INNER JOIN tblLocations D ON D.LocationId = M.ParentLocationId
						INNER JOIN tblOfficer O ON O.LocationId = D.LocationId
						WHERE 
						I.CHFID = @InsuranceNumber AND O.Code= @EnrollmentOfficerCode
						AND I.ValidityTo IS NULL
						AND F.ValidityTo IS NULL
						AND V.ValidityTo IS NULL
						AND O.ValidityTo IS NULL)
		 RETURN 5

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION RENEWPOLICY
			
				DECLARE @tblPeriod TABLE(startDate DATE, expiryDate DATE, HasCycle  BIT)
				DECLARE @FamilyId INT = 0,
				@PolicyValue DECIMAL(18, 4),
				@PolicyStage CHAR(1)='R',
				@StartDate DATE,
				@ExpiryDate DATE,
				@EffectiveDate DATE,
				@ErrorCode INT,
				@PolicyStatus INT,
				@PolicyId INT,
				@Active TINYINT=2,
				@Idle TINYINT=1,
				@OfficerID INT,
				@HasCycle BIT

				SELECT @FamilyId = FamilyID FROM tblInsuree WHERE CHFID = @InsuranceNumber  AND ValidityTo IS NULL
				INSERT INTO @tblPeriod(StartDate, ExpiryDate, HasCycle)
				EXEC uspGetPolicyPeriod @ProdId, @RenewalDate, @HasCycle OUTPUT, @PolicyStage;
				EXEC @PolicyValue = uspPolicyValue @FamilyId, @ProdId, 0, @PolicyStage, @RenewalDate, 0, @ErrorCode OUTPUT;
				SELECT @StartDate = startDate FROM @tblPeriod
				SELECT @ExpiryDate = expiryDate FROM @tblPeriod
				SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @EnrollmentOfficerCode AND ValidityTo IS NULL

					INSERT INTO tblPolicy(FamilyID,EnrollDate,StartDate,EffectiveDate,ExpiryDate,PolicyStatus,PolicyValue,ProdID,OfficerID,PolicyStage,ValidityFrom,AuditUserID, isOffline)
					SELECT	 @FamilyId,@RenewalDate,@StartDate,@EffectiveDate,@ExpiryDate,@Idle,@PolicyValue,@ProdId,@OfficerID,@PolicyStage,GETDATE(),@AuditUserId, 0 isOffline 
					SET @PolicyId = SCOPE_IDENTITY()

	

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

			COMMIT TRANSACTION RENEWPOLICY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION RENEWPOLICY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

IF NOT OBJECT_ID('uspAPIDeleteMemberFamily') IS NULL
DROP PROCEDURE uspAPIDeleteMemberFamily
GO
CREATE PROCEDURE [dbo].[uspAPIDeleteMemberFamily]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(12)
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number  of member
		2-Insurance number of member not found
		3- Member is head of family
		0 - Success (0 OK), 
		-1 -Unknown  Error 
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1

	--2-Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Member is head of family
	IF  EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL AND IsHead = 1)
		RETURN 3

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION DELETEMEMBERFAMILY
			
				DECLARE @InsureeId INT


				SELECT @InsureeID = InsureeID FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL
				
				INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,TypeOfId, HFID, CurrentAddress, CurrentVillage,GeoLocation ) 
				SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,getdate(),@insureeId ,TypeOfId, HFID, CurrentAddress, CurrentVillage, GeoLocation 
				FROM tblInsuree WHERE InsureeID = @InsureeID AND ValidityTo IS NULL
				UPDATE [tblInsuree] SET [ValidityFrom] = GetDate(),[ValidityTo] = GetDate(),[AuditUserID] = @AuditUserID 
				WHERE InsureeId = @InsureeID AND ValidityTo IS NULL

       

			COMMIT TRANSACTION DELETEMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION DELETEMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH


END

GO

IF NOT OBJECT_ID('uspAPIEnterFamily') IS NULL
DROP PROCEDURE uspAPIEnterFamily
GO
CREATE PROCEDURE [dbo].[uspAPIEnterFamily]
(
	@AuditUserID INT = -3,
	@PermanentVillageCode NVARCHAR(8),
	@InsuranceNumber NVARCHAR(12),
	@OtherNames NVARCHAR(100),
	@LastName NVARCHAR(100),
	@BirthDate DATE,
	@Gender NVARCHAR(1),
	@PovertyStatus BIT = NULL,
	@ConfirmationNo nvarchar(12) = '' ,
	@ConfirmationType NVARCHAR(1) = NULL,
	@PermanentAddress NVARCHAR(200) = '',
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = 0 ,
	@CurrentVillageCode NVARCHAR(8) = NULL ,
	@CurrentAddress NVARCHAR(200) = '',
	@Proffesion NVARCHAR(50) = NULL,
	@Education NVARCHAR(50) = NULL,
	@PhoneNumber NVARCHAR(50) = '',
	@Email NVARCHAR(100) = '',
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = '',
	@FSPCode NVARCHAR(8) = NULL,
	@GroupType NVARCHAR(2)= NULL
)
AS
BEGIN

	/*
	RESPONSE CODES
		1 - Wrong format or missing insurance number of head
		2 - Duplicated insurance number of head
		3 - Wrong or missing permanent village code
		4 - Wrong current village code
		5 - Wrong or missing  gender
		6 - Wrong format or missing birth date
		7 - Missing last name
		8 - Missing other name
		9 - Wrong confirmation type
		10 - Wrong group type
		11 - Wrong marital status
		12 - Wrong education
		13 - Wrong profession
		14 - FSP code not found
		15 - wrong identification type 
		0 - Success 
		-1 Unknown Error

	*/



	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1 - Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1
	
	--2 - Duplicated insurance number of head
	IF EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3 - Wrong or missing permanent village code
	IF LEN(ISNULL(@PermanentVillageCode,'')) = 0
		RETURN 3

	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @PermanentVillageCode AND ValidityTo IS NULL AND LocationType ='V')
		RETURN 3

	--4 - Wrong current village code
	IF LEN(ISNULL(@CurrentVillageCode,'')) <> 0
	BEGIN
		IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL AND LocationType ='V')
		RETURN 4
	END

	--5 - Wrong or missing  gender
	IF LEN(ISNULL(@Gender,'')) = 0
		RETURN 5

	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender)
		RETURN 5
	
	--6 - Wrong format or missing birth date
	IF NULLIF(@BirthDate,'') IS NULL
		RETURN 6
	
	--7 - Missing last name
	IF LEN(ISNULL(@LastName,'')) = 0 
		RETURN 7
	
	--8 - Missing other name
	IF LEN(ISNULL(@OtherNames,'')) = 0 
		RETURN 8

	--9 - Wrong confirmation type
	IF NOT EXISTS(SELECT 1 FROM tblConfirmationTypes WHERE ConfirmationTypeCode = @ConfirmationType) AND LEN(ISNULL(@ConfirmationType,'')) > 0
		RETURN 9
	
	--10 - Wrong group type
	IF NOT EXISTS(SELECT  1 FROM tblFamilyTypes WHERE FamilyTypeCode = @GroupType) AND LEN(ISNULL(@GroupType,'')) > 0
		RETURN 10

	--11 - Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 11

	--12 - Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 12

	--13 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 13

	--14 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 14

	--15 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 15


	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION ENROLFAMILY
			
				DECLARE @FamilyID INT,
						@InsureeID INT,
			
						@ProfessionId INT,
						@LocationId INT,
						@CurrentLocationId INT=0,
						@EducationId INT,
						@HfID INT

						SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
						SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
						SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
						SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
						SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
						SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
						SELECT @CurrentLocationId = LocationId FROM tblLocations WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL
						SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @PermanentVillageCode AND ValidityTo IS NULL


					INSERT INTO dbo.tblFamilies
						   (InsureeID,LocationId,Poverty,ValidityFrom,AuditUserID,FamilyType,FamilyAddress,isOffline,ConfirmationType,ConfirmationNo )
					SELECT 0 InsureeID, @LocationId LocationId, @PovertyStatus Poverty, GETDATE() ValidityFrom, @AuditUserID AuditUserID, @GroupType FamilyType, @PermanentAddress FamilyAddress, 0 isOffline, @ConfirmationType ConfirmationType, @ConfirmationNo ConfirmationNo
					SET @FamilyID = SCOPE_IDENTITY()

	

				INSERT INTO dbo.tblInsuree
					(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Phone, CardIssued, passport,TypeOfId , ValidityFrom,AuditUserID,Profession,Education,Email,isOffline,HFID,CurrentAddress,CurrentVillage)
					SELECT @FamilyID FamilyID, @InsuranceNumber CHFID, @LastName LastName, @OtherNames OtherNames, @BirthDate BirthDate, @Gender Gender, @MaritalStatus Marital, 1 IsHead, @PhoneNumber Phone, isnull(@BeneficiaryCard,0) BeneficiaryCard, @IdentificationNumber PassPort, @IdentificationType  ,GETDATE() ValidityFrom,@AuditUserID AuditUserID, @ProfessionId Profession, @EducationId Education, @Email Email, 0 IsOffline, @HfID, @CurrentAddress CurrentAddress, @CurrentLocationId CurrentVillage
					SET @InsureeID = SCOPE_IDENTITY()


					INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
					SELECT InsureeID,CHFID,'','',0,GETDATE(),ValidityFrom,AuditUserID from tblInsuree WHERE InsureeID = @InsureeID; 
					UPDATE tblInsuree SET PhotoID = (SELECT IDENT_CURRENT('tblPhotos')), PhotoDate=GETDATE() WHERE InsureeID = @InsureeID ;

					UPDATE tblFamilies SET InsureeID = @InsureeID WHERE FamilyID = @FamilyID

			COMMIT TRANSACTION ENROLFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENROLFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH


END

GO

IF NOT OBJECT_ID('udfAPIisValidMaritalStatus') IS NULL
DROP FUNCTION udfAPIisValidMaritalStatus
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

IF NOT OBJECT_ID('uspAPIEditFamily') IS NULL
DROP PROCEDURE uspAPIEditFamily
GO
CREATE PROCEDURE [dbo].[uspAPIEditFamily]
(
	@AuditUserID INT = -3,
	@InsuranceNumberOfHead NVARCHAR(12),
	@VillageCode NVARCHAR(8)= NULL,
	@OtherNames NVARCHAR(100) = NULL,
	@LastName NVARCHAR(100) = NULL,
	@BirthDate DATE = NULL,
	@Gender NVARCHAR(1) = NULL,
	@PovertyStatus BIT = NULL,
	@ConfirmationType NVARCHAR(1) = NULL,
	@GroupType NVARCHAR(2) = NULL,
	@ConfirmationNumber NVARCHAR(12) = NULL,
	@PermanentAddress NVARCHAR(200) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = NULL,
	@CurrentVillageCode NVARCHAR(8) = NULL,
	@CurrentAddress NVARCHAR(200) = NULL,
	@Proffesion NVARCHAR(50) = NULL,
	@Education NVARCHAR(50) = NULL,
	@PhoneNumber NVARCHAR(50) = NULL,
	@Email NVARCHAR(100) = NULL,
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = NULL,
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODES
		1 - Wrong format or missing insurance number of head
		2 - Insurance number of head not found
		3 - Wrong or missing permanent village code
		4 - Wrong current village code
		5 - Wrong  gender
		6 - Wrong confirmation type
		7 - Wrong group type
		8 - Wrong marital status
		9 - Wrong education
		10 - Wrong profession
		11 - FSP code not found
		12 - Wrong identification type
		0 - Success 
		-1 Unknown Error

	*/
	

	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1 - Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumberOfHead,'')) = 0
		RETURN 1
	
	--2 - Insurance number of head not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumberOfHead AND ValidityTo IS NULL AND IsHead = 1)
		RETURN 2

	--3 - Wrong missing permanent village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND  LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 3

	--4 - Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL AND LocationType ='V') AND  LEN(ISNULL(@CurrentVillageCode,'')) > 0
		RETURN 4
	
	--5 - Wrong   gender
	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender) AND LEN(ISNULL(@Gender,'')) > 0
		RETURN 5
	
	--6 - Wrong confirmation type
	IF NOT EXISTS(SELECT 1 FROM tblConfirmationTypes WHERE ConfirmationTypeCode = @ConfirmationType) AND LEN(ISNULL(@ConfirmationType,'')) > 0
		RETURN 6
	
	--7 - Wrong group type
	IF NOT EXISTS(SELECT  1 FROM tblFamilyTypes WHERE FamilyTypeCode = @GroupType) AND LEN(ISNULL(@GroupType,'')) > 0
		RETURN 7

	--8 - Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 8

	--9 - Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 9

	--10 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 10

	--11 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 11

	--12 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 12


	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

		/****************************************BEGIN TRANSACTION *************************/
		BEGIN TRY
			BEGIN TRANSACTION EDITROLFAMILY
			
				DECLARE @FamilyID INT,
						@InsureeID INT,
						@ProfessionId INT,
						@EducationId INT,
						@RelationId INT,
						@LocationId INT,
						@CurrentLocationId INT,
						@HfID INT,
						@DBLocationID INT = NULL,
						@DBOtherNames NVARCHAR(100) = NULL,
						@DBLastName NVARCHAR(100) = NULL,
						@DBBirthDate DATE = NULL,
						@DBGender NVARCHAR(1) = NULL,
						@DBMaritalStatus NVARCHAR(1) = NULL,
						@DBBeneficiaryCard BIT = NULL,
						@DBVillageID INT = NULL,
						@DBCurrentAddress NVARCHAR(200) = NULL,
						@DBProffesionID INT = NULL,
						@DBEducationID INT = NULL,
						@DBPhoneNumber NVARCHAR(50) = NULL,
						@DBEmail NVARCHAR(100) = NULL,
						@DBConfirmationType NVARCHAR(25) = NULL,
						@DBIdentificationNumber NVARCHAR(25) = NULL,
						@DBIdentificationType NVARCHAR(1) = NULL,
						@DBGroupType nvarchar(2) = NULL,
						@DBHFID INT = NULL,
						@DBCurrentLocationId INT=NULL
						

						SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
						SELECT @FamilyID = FamilyID FROM tblInsuree WHERE CHFID = @InsuranceNumberOfHead AND IsHead = 1 
						SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
						SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
						SELECT @CurrentLocationId = LocationId FROM tblLocations WHERE LocationCode = @CurrentVillageCode AND ValidityTo IS NULL
						SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL
						SELECT @InsureeId = I.InsureeID, @DBOtherNames = OtherNames, @DBLastName= LastName, @DBBirthDate = DOB, @DBGender = Gender, @DBMaritalStatus= Marital, 
						@DBBeneficiaryCard = CardIssued, @DBCurrentLocationId = CurrentVillage, @DBCurrentAddress = CurrentAddress, @DBProffesionID = Profession, @DBEducationID =Education, 
						@DBPhoneNumber = Phone, @DBEmail = Email, @DBIdentificationNumber = passport, @DBHFID = HFID, @DBLocationID = F.LocationId, @DBConfirmationType = F.ConfirmationType,
						@DBIdentificationType = [TypeOfId], @DBGroupType = FamilyType
						FROM tblInsuree I INNER JOIN tblFamilies  F ON F.FamilyID = I.FamilyID  WHERE CHFID = @InsuranceNumberOfHead AND I.ValidityTo IS NULL AND F.ValidityTo IS NULL

						SET	@LocationId = ISNULL(@LocationId, @DBLocationID)
						SET	@OtherNames = ISNULL(@OtherNames, @DBOtherNames)
						SET	@LastName = ISNULL(@LastName, @DBLastName)
						SET	@BirthDate = ISNULL(@BirthDate, @DBBirthDate)
						SET	@Gender = ISNULL(@Gender, @DBGender)
						SET	@MaritalStatus = ISNULL(@MaritalStatus, @DBMaritalStatus)
						SET	@BeneficiaryCard = ISNULL(@BeneficiaryCard, @DBBeneficiaryCard)
						SET	@CurrentAddress = ISNULL(@CurrentAddress, @DBCurrentAddress)
						SET	@ProfessionId = ISNULL(@ProfessionId, @DBProffesionID)
						SET	@EducationId = ISNULL(@EducationId, @DBEducationID)
						SET	@PhoneNumber = ISNULL(@PhoneNumber, @DBPhoneNumber)
						SET	@Email = ISNULL(@Email, @DBEmail)
						SET	@ConfirmationType = ISNULL(@ConfirmationType, @DBConfirmationType)
						SET @IdentificationType = ISNULL(@IdentificationType,@DBIdentificationType )
						SET	@IdentificationNumber = ISNULL(@IdentificationNumber, @DBIdentificationNumber)
						SET	@HfID = ISNULL(@HfID, @DBHFID )
						SET @GroupType = ISNULL(@GroupType, @DBGroupType)
						SET @CurrentLocationId = ISNULL(@CurrentLocationId,@DBCurrentLocationId)

						INSERT INTO tblFamilies ([insureeid],[Poverty],[ConfirmationType],isOffline,[ValidityFrom],[ValidityTo],[LegacyID],[AuditUserID],FamilyType, FamilyAddress,Ethnicity,ConfirmationNo, LocationId) 
						SELECT [insureeid],[Poverty],[ConfirmationType],isOffline,[ValidityFrom],getdate() ValidityTo,FamilyID, @AuditUserID,FamilyType, FamilyAddress,Ethnicity,ConfirmationNo,LocationId FROM tblFamilies
						WHERE FamilyID = @FamilyID 
								AND ValidityTo IS NULL
						

						UPDATE tblFamilies SET LocationId = @LocationId, Poverty = @PovertyStatus, ValidityFrom = GETDATE(),AuditUserID = @AuditUserID,FamilyType = @GroupType,FamilyAddress = @PermanentAddress,ConfirmationType =@ConfirmationType,
							  ConfirmationNo = @ConfirmationNumber WHERE FamilyID = @FamilyID AND ValidityTo IS NULL

						--Insert Insuree History
						INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
						SELECT	I.[FamilyID],I.[CHFID],I.[LastName],I.[OtherNames],I.[DOB],I.[Gender],I.[Marital],I.[IsHead],I.[passport],I.[Phone],I.[PhotoID],I.[PhotoDate],I.[CardIssued],I.isOffline,I.[AuditUserID],I.[ValidityFrom] ,GETDATE() ValidityTo,I.InsureeID,I.[Relationship],I.[Profession],I.[Education],I.[Email] ,I.[TypeOfId],I.[HFID], I.[CurrentAddress], I.[GeoLocation], [CurrentVillage] FROM tblInsuree I
						WHERE I.CHFID = @InsuranceNumberOfHead AND  I.ValidityTo IS NULL
					
						UPDATE tblInsuree  SET [LastName] = @LastName, [OtherNames] = @OtherNames,[DOB] = @BirthDate, [Gender] = @Gender,[Marital] = @MaritalStatus, [TypeOfId]  = @IdentificationType , [passport] = @IdentificationNumber,[Phone] = @PhoneNumber,[CardIssued] = ISNULL(@BeneficiaryCard,0),[ValidityFrom] = GetDate(),[AuditUserID] = @AuditUserID , [Profession] = @ProfessionId, [Education] = @EducationId,[Email] = @Email ,HFID = @HFID, CurrentAddress = @CurrentAddress, CurrentVillage = @CurrentLocationId
						WHERE InsureeID = @InsureeId AND  ValidityTo IS NULL 


			COMMIT TRANSACTION EDITROLFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION EDITROLFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

IF NOT OBJECT_ID('uspAPIEnterMemberFamily') IS NULL
DROP PROCEDURE uspAPIEnterMemberFamily
GO
CREATE PROCEDURE [dbo].[uspAPIEnterMemberFamily]
(
	@AuditUserID INT = -3,
	@InsureeNumberOfHead NVARCHAR(12),
	@InsureeNumber NVARCHAR(12),
	@OtherNames NVARCHAR(100),
	@LastName NVARCHAR(100),
	@BirthDate DATE,
	@Gender NVARCHAR(1),
	@Relationship NVARCHAR(50) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = 0,
	@VillageCode NVARCHAR(8)= NULL,
	@CurrentAddress NVARCHAR(200) = '',
	@Proffesion NVARCHAR(50)= NULL,
	@Education NVARCHAR(50)= NULL,
	@PhoneNumber NVARCHAR(50) = '',
	@Email NVARCHAR(100)= '',
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = '',
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of head
		2-Insurance number of head not found
		3- Wrong format or missing insurance number of member
		4-Wrong or missing  gender
		5-Wrong format or missing birth date
		6-Missing last name
		7-Missing other name
		8- Insurance number of member duplicated
		9- Wrong current village code
		10-Wrong marital status
		11-Wrong education
		12-Wrong profession
		13-Wrong RelationShip
		14-FSP code not found 
		15 - wrong identification type 
		0 - Success (0 OK), 
		-1 -Unknown  Error 
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsureeNumberOfHead,'')) = 0
		RETURN 1

	--2-Insurance number of head not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumberOfHead AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong format or missing insurance number of member
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3
	--4-Wrong or missing  gender
	IF LEN(ISNULL(@Gender,'')) = 0
		RETURN 4

	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender)
		RETURN 4

	--5-Wrong format or missing birth date
	IF NULLIF(@BirthDate,'') IS NULL
		RETURN 5

	--6-Missing last name
	IF LEN(ISNULL(@LastName,'')) = 0 
			RETURN 6
	
	--7-Missing other name
	IF LEN(ISNULL(@OtherNames,'')) = 0 
		RETURN 7

	--8- Insurance number of member duplicated
	IF EXISTS(SELECT 1 FROM tblInsuree WHERE ValidityTo IS NULL AND CHFID = @InsureeNumber)
		RETURN 8

	--9- Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 9

	--10-Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 10

	--11-Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 11

	--12 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 12

	--13 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 13

	--14 - Wrong Relation
	IF NOT EXISTS(SELECT  1 FROM tblRelations WHERE Relation = @Relationship) AND LEN(ISNULL(@Relationship,'')) > 0
		RETURN 14



	--15 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 15
	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION ENROLMEMBERFAMILY
			
				DECLARE @FamilyID INT,
						@ProfessionId INT,
						@RelationId INT,
						@EducationId INT,
						@LocationId INT,
						@HfID INT,
						@InsureeId INT



				SET @FamilyID = (SELECT TOP 1 FamilyID FROM tblInsuree WHERE CHFID = @InsureeNumberOfHead AND ValidityTo IS NULL ORDER BY FamilyID DESC)
				SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
				SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
				SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
				SELECT @RelationId = RelationId FROM tblRelations WHERE Relation = @Relationship
				SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL


				INSERT INTO dbo.tblInsuree
					(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Phone, CardIssued, passport,TypeOfId , ValidityFrom,AuditUserID,Profession,Education, Relationship, Email,isOffline,HFID,CurrentAddress,CurrentVillage)
					SELECT @FamilyID FamilyID, @InsureeNumber CHFID, @LastName LastName, @OtherNames OtherNames, @BirthDate BirthDate, @Gender Gender, @MaritalStatus Marital, 0  IsHead, @PhoneNumber Phone, @BeneficiaryCard BeneficiaryCard, @IdentificationNumber PassPort, @IdentificationType , GETDATE() ValidityFrom,@AuditUserID AuditUserID, @ProfessionId Profession, @EducationId Education, @RelationId Relation, @Email Email, 0 IsOffline, @HfID, @CurrentAddress CurrentAddress, @LocationId CurrentVillage
							SET @InsureeId = SCOPE_IDENTITY()

							INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
					SELECT InsureeID,CHFID,'','',0,GETDATE(),ValidityFrom,AuditUserID from tblInsuree WHERE InsureeID = @InsureeID; 
					UPDATE tblInsuree SET PhotoID = (SELECT IDENT_CURRENT('tblPhotos')),PhotoDate=GETDATE() WHERE InsureeID = @InsureeID;

							EXEC uspAddInsureePolicy @InsureeId;
								
				

			COMMIT TRANSACTION ENROLMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENROLMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH

END

GO

IF NOT OBJECT_ID('uspAPIEditMemberFamily') IS NULL
DROP PROCEDURE uspAPIEditMemberFamily
GO
CREATE PROCEDURE [dbo].[uspAPIEditMemberFamily]
(
	@AuditUserID INT = -3,
	@InsureeNumber NVARCHAR(12),
	@OtherNames NVARCHAR(100) = NULL,
	@LastName NVARCHAR(100) = NULL,
	@BirthDate DATE = NULL,
	@Gender NVARCHAR(1) = NULL,
	@Relationship NVARCHAR(50) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = NULL,
	@VillageCode NVARCHAR(8) = NULL,
	@CurrentAddress NVARCHAR(200) = NULL,
	@Proffesion NVARCHAR(50) = NULL,
	@Education NVARCHAR(50) = NULL,
	@PhoneNumber NVARCHAR(50) = NULL,
	@Email NVARCHAR(100) = NULL,
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = NULL,
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of a member
		2-Insurance number of head not found
		3- Wrong format or missing insurance number of member
		4-Insurance number of member not found
		5-Wrong current village code
		6-Wrong gender
		7-Wrong marital status
		8-Wrong education
		9 - Wrong profession
		10 - FSP code not found
		11 - Wrong identification type
		12 - Wrong Relation
		-1 - Unexpected error
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--3- Wrong format or missing insurance number of member
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3

	--4 - Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL)
		RETURN 4

	--5-Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 5

	--6-Wrong gender
	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender) AND LEN(ISNULL(@Gender,'')) > 0
		RETURN 6

	--7-Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 7

	--8-Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 8

	--9 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 9

	--10 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 10
	--11 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 11

	--12 - Wrong Relation
	IF NOT EXISTS(SELECT  1 FROM tblRelations WHERE Relation = @Relationship) AND LEN(ISNULL(@Relationship,'')) > 0
		RETURN 12

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION EDITMEMBERFAMILY
			
				DECLARE @FamilyID INT,
				
						@ProfessionId INT,
						@RelationId INT,
						@EducationId INT,
						@LocationId INT,
						@HfID INT,
						@InsureeId INT,
						@AssociatedPhotoFolder NVARCHAR(255),
						@DBOtherNames NVARCHAR(100) = NULL,
						@DBLastName NVARCHAR(100) = NULL,
						@DBBirthDate DATE = NULL,
						@DBGender NVARCHAR(1) = NULL,
						@DBRelationshipID NVARCHAR(50) = NULL,
						@DBMaritalStatus NVARCHAR(1) = NULL,
						@DBBeneficiaryCard BIT = NULL,
						@DBVillageID INT = NULL,
						@DBCurrentAddress NVARCHAR(200) = NULL,
						@DBProffesionID INT = NULL,
						@DBEducationID INT = NULL,
						@DBPhoneNumber NVARCHAR(50) = NULL,
						@DBEmail NVARCHAR(100) = NULL,
						@DBIdentificationNumber NVARCHAR(25) = NULL,
						@DBIdentificationType NVARCHAR(1) = NULL,
						@DBFSPCode NVARCHAR(8) = NULL


				SET @AssociatedPhotoFolder=(SELECT AssociatedPhotoFolder FROM tblIMISDefaults)
				SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
				SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
				SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
				SELECT @RelationId = RelationId FROM tblRelations WHERE Relation = @Relationship
				SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL
				SELECT @InsureeId = InsureeID, @DBOtherNames = OtherNames, @DBLastName= LastName, @DBBirthDate = DOB, @DBGender = Gender, @DBMaritalStatus= Marital, @DBBeneficiaryCard = CardIssued, 
				@DBVillageID = CurrentVillage, @DBCurrentAddress = CurrentAddress, @DBProffesionID = Profession, @DBEducationID =Education, @DBPhoneNumber = Phone, @DBEmail = Email, 
				@DBIdentificationNumber = passport, @DBFSPCode = HFID, @DBIdentificationType = TypeOfId, @DBRelationshipID=Relationship 
				FROM tblInsuree WHERE CHFID = @InsureeNumber AND ValidityTo IS NULL

					SET	@OtherNames = ISNULL(@OtherNames, @DBOtherNames)
					SET	@LastName = ISNULL(@LastName, @DBLastName)
					SET	@BirthDate = ISNULL(@BirthDate, @DBBirthDate)
					SET	@Gender = ISNULL(@Gender, @DBGender)
					SET	@RelationId = ISNULL(@RelationId, @DBRelationshipID)
					SET	@MaritalStatus = ISNULL(@MaritalStatus, @DBMaritalStatus)
					SET	@BeneficiaryCard = ISNULL(@BeneficiaryCard, @DBBeneficiaryCard)
					SET	@LocationId = ISNULL(@LocationId, @DBVillageID)
					SET	@CurrentAddress = ISNULL(@CurrentAddress, @DBCurrentAddress)
					SET	@ProfessionId = ISNULL(@ProfessionId, @DBProffesionID)
					SET	@EducationId = ISNULL(@EducationId, @DBEducationID)
					SET	@PhoneNumber = ISNULL(@PhoneNumber, @DBPhoneNumber)
					SET	@Email = ISNULL(@Email, @DBEmail)
					SET @IdentificationType = ISNULL(@IdentificationType,@DBIdentificationType )
					SET	@IdentificationNumber = ISNULL(@IdentificationNumber, @DBIdentificationNumber)

					SET	@FSPCode = ISNULL(@FSPCode, @DBFSPCode)

				--Insert Insuree History
					INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,[Relationship],[Profession],[Education],[Email],[TypeOfId],[HFID], [CurrentAddress], [GeoLocation], [CurrentVillage]) 
					SELECT	I.[FamilyID],I.[CHFID],I.[LastName],I.[OtherNames],I.[DOB],I.[Gender],I.[Marital],I.[IsHead],I.[passport],I.[Phone],I.[PhotoID],I.[PhotoDate],I.[CardIssued],I.isOffline,I.[AuditUserID],I.[ValidityFrom] ,GETDATE() ValidityTo,I.InsureeID,I.[Relationship],I.[Profession],I.[Education],I.[Email]  ,I.[TypeOfId],I.[HFID], I.[CurrentAddress], I.[GeoLocation], [CurrentVillage] FROM tblInsuree I
					WHERE I.InsureeID = @InsureeId AND  I.ValidityTo IS NULL
					
					UPDATE tblInsuree  SET [LastName] = @LastName, [OtherNames] = @OtherNames,[DOB] = @BirthDate, [Gender] = @Gender,[Marital] = @MaritalStatus, [TypeOfId]  = @IdentificationType ,[passport] = @IdentificationNumber,[Phone] = @PhoneNumber,[CardIssued] = ISNULL(@BeneficiaryCard,0),[ValidityFrom] = GetDate(),[AuditUserID] = @AuditUserID ,[Relationship] = @RelationId, [Profession] = @ProfessionId, [Education] = @EducationId,[Email] = @Email ,HFID = @HFID, CurrentAddress = @CurrentAddress, CurrentVillage = @LocationId, GeoLocation = @LocationId 
					WHERE InsureeID = @InsureeId AND  ValidityTo IS NULL 
				
					
								


			COMMIT TRANSACTION EDITMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION EDITMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END

GO

