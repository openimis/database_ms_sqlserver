IF OBJECT_ID('uspSSRSOverviewOfCommissions', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSOverviewOfCommissions
GO

CREATE PROCEDURE [dbo].[uspSSRSOverviewOfCommissions]
(
	@Month INT,
	@Year INT, 
	@Mode INT=NULL,
	@OfficerId INT =NULL,
	@LocationId INT, 
	@ProdId INT = NULL,
	@PayerId INT = NULL,
	@ReportingId INT = NULL,
	@Scope INT = NULL,
	@CommissionRate DECIMAL(18,2) = NULL,
	@ErrorMessage NVARCHAR(200) = N'' OUTPUT
)
AS
BEGIN
	-- check mandatory data
	if   @Month IS NULL OR @Month  = 0 
	BEGIN
		SELECT @ErrorMessage = 'Month Mandatory'
		RETURN
	END
	if   @Year IS NULL OR @Year  = 0 
	BEGIN
		SELECT @ErrorMessage = 'Year Mandatory'
		RETURN
	END			
	if   @LocationId IS NULL OR @LocationId  = 0 
	BEGIN
		SELECT @ErrorMessage = 'LocationId Mandatory'
		RETURN
	END	
	if   @CommissionRate IS NULL OR @CommissionRate  = 0 
	BEGIN
		SELECT @ErrorMessage = 'CommissionRate Mandatory'
		RETURN
	END	
	DECLARE @RecordFound INT = 0
	DECLARE @Rate DECIMAL(18,2) 

	SET @Rate = @CommissionRate / 100
	DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'; 
	DECLARE @LastDay DATE = EOMONTH(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01', 0)
		-- check that end date is before today
	if   @LastDay >  GETDATE()
	BEGIN
		SELECT @ErrorMessage = 'End report date must be before today'
		RETURN
	END

	IF @ReportingId IS NULL  -- LINK THE CONTRIBUTION TO THE REPORT
    BEGIN
		SELECT TOP(1) @ReportingId = ReportingId FROM tblReporting WHERE LocationId = @LocationId AND ISNULL(ProdId,0) = ISNULL(@ProdId,0) 
						AND StartDate = @FirstDay AND EndDate = @LastDay AND ISNULL(OfficerID,0) = ISNULL(@OfficerID,0) AND ReportMode = 0 AND ISNULL(PayerId,0) = ISNULL(@PayerId,0)
		IF @ReportingId is NULL
		BEGIN
			BEGIN TRY
				BEGIN TRAN
					-- if @Mode = 0 -- prescribed
						INSERT INTO tblReporting(ReportingDate,LocationId, ProdId, PayerId, StartDate, EndDate, RecordFound,OfficerID,ReportType,CommissionRate,ReportMode,Scope)
						SELECT GETDATE(),@LocationId,ISNULL(@ProdId,0), @PayerId, @FirstDay, @LastDay, 0,@OfficerId,2,@Rate,@Mode,@Scope; 
						--Get the last inserted reporting Id
						SELECT @ReportingId =  SCOPE_IDENTITY();
			
					UPDATE tblPremium SET ReportingCommissionID =  @ReportingId
						WHERE PremiumId IN (
						SELECT  Pr.PremiumId
						FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID -- AND (PL.PolicyStatus=1 OR PL.PolicyStatus=2)
						LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId
						LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID 
						INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
						INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
						INNER JOIN tblLocations V ON V.LocationId = F.LocationId
						INNER JOIN tblLocations W ON W.LocationId = V.ParentLocationId
						INNER JOIN tblLocations D ON D.LocationId = W.ParentLocationId
						INNER JOIN tblOfficer O ON O.LocationId = D.LocationId AND O.ValidityTo IS NULL AND O.Officerid = PL.OfficerID
						INNER JOIN tblInsuree Ins ON F.InsureeID = Ins.InsureeID  
						LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID 
						WHERE( (@Mode = 1 and PY.MatchedDate IS NOT NULL ) OR  (PY.MatchedDate IS NULL AND @Mode = 0))
						-- AND Year(Pr.PayDate) = @Year AND Month(Pr.paydate) = @Month -- To be change
						and ((Year(Py.[PaymentDate]) = @Year AND Month(Py.[PaymentDate]) = @Month and @Mode = 1 ) OR (Year(Pr.ValidityFrom) = @Year AND Month(Pr.ValidityFrom) = @Month and @Mode = 0 ) )
						AND D.LocationId = @LocationId	or D.ParentLocationId = @LocationId
						AND (ISNULL(Prod.ProdID,0) = ISNULL(@ProdId,0) OR @ProdId is null)
						AND (ISNULL(O.OfficerID,0) = ISNULL(@OfficerId,0) OR @OfficerId IS NULL)
						AND (ISNULL(Payer.PayerID,0) = ISNULL(@PayerId,0) OR @PayerId IS NULL)
						-- AND (Pr.ReportingId IS NULL OR Pr.ReportingId < 0 ) -- not matched will be with negative ID
						AND PR.PayType <> N'F'
						AND (Pr.ReportingCommissionID IS NULL)
						GROUP BY Pr.PremiumId
						HAVING SUM(ISNULL(PD.Amount,0)) = MAX(ISNULL(PY.ExpectedAmount,0))
						)	
				
					SELECT @RecordFound = @@ROWCOUNT;
					IF @RecordFound = 0 
					BEGIN
						SELECT @ErrorMessage = 'No Data'
						DELETE tblReporting WHERE ReportingId = @ReportingId;
						ROLLBACK TRAN; 
						RETURN -- To avoid a second rollback
					END
					ELSE
					BEGIN
						UPDATE tblReporting SET RecordFound = @RecordFound WHERE ReportingId = @ReportingId;
						--UPDATE tblPremium SET OverviewCommissionReport = GETDATE() WHERE ReportingCommissionID = @ReportingId AND @Scope = 0 AND OverviewCommissionReport IS NULL;
						--UPDATE tblPremium SET AllDetailsCommissionReport = GETDATE() WHERE ReportingCommissionID = @ReportingId AND @Scope = 1 AND AllDetailsCommissionReport IS NULL;
					END
				COMMIT TRAN;
			END TRY
			BEGIN CATCH
				--SELECT @ErrorMessage = ERROR_MESSAGE(); ERROR MESSAGE WAS COMMENTED BY SALUMU ON 12-11-2019
				ROLLBACK TRAN;
				--RETURN -2 RETURN WAS COMMENTED BY SALUMU ON 12-11-2019
			END CATCH
		END
	END
	      
					    
	-- FETCHT THE DATA FOR THE REPORT		
	-- OTC 70 - don-t put the familly details, insuree head, dob, pazer village and ward

	SELECT  
	Pr.PremiumId,Pr.Paydate, Pr.Receipt, ISNULL(Pr.Amount,0) PrescribedContribution, 
	CASE WHEN @Mode=1 THEN  ISNULL(PD.Amount,0) ELSE ISNULL(Pr.Amount,0) END * @Rate as Commission,
	Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName Product,
	PL.PolicyID, PL.EnrollDate,PL.PolicyStage,
	F.FamilyID,
	D.LocationName DistrictName,
	--V.LocationName VillageName,W.LocationName  WardName,
	o.OfficerID, O.Code + ' ' + O.LastName Officer, OfficerCode,O.Phone PhoneNumber,
	-- Ins.DOB, Ins.IsHead, 
	Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName,	
	REP.ReportMode,Month(REP.StartDate)  [Month], 
	--CASE WHEN Ins.IsHead = 1 THEN ISNULL(Pr.Amount,0) ELSE NULL END Amount, CASE WHEN Ins.IsHead = 1 THEN Pr.Amount ELSE NULL END  PrescribedContribution,
	-- CASE WHEN IsHead = 1 THEN SUM(ISNULL(Pr.Amount,0.00)) * ISNULL(rep.CommissionRate,0.00) ELSE NULL END  CommissionRate,CASE WHEN Ins.IsHead = 1 THEN ISNULL(PD.Amount,0) ELSE NULL END ActualPayment
	PY.PaymentDate, ISNULL(PD.Amount,0) ActualPayment , PY.ExpectedAmount PaymentAmount, TransactionNo
	-- Payer.PayerName
	FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID  AND PL.ValidityTo IS NULL
	LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId AND PD.ValidityTo IS NULl AND PR.ValidityTo IS NULL
	LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID AND PY.ValidityTo IS NULL
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID AND Prod.ValidityTo IS NULL
	INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID AND F.ValidityTo IS NULL
	INNER JOIN tblLocations V ON V.LocationId = F.LocationId
	INNER JOIN tblLocations W ON W.LocationId = V.ParentLocationId
	INNER JOIN tblLocations D ON D.LocationId = W.ParentLocationId
	INNER JOIN tblOfficer O ON O.Officerid = PL.OfficerID AND  O.LocationId = D.LocationId AND O.ValidityTo IS NULL
	--  JUST the HEAD INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL
	LEFT JOIN tblInsuree Ins ON F.InsureeID = Ins.InsureeID  
	INNER JOIN tblReporting REP ON REP.ReportingId = @ReportingId
	-- LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID
	WHERE Pr.ReportingCommissionID = @ReportingId and Pr.ValidityTo is null
	GROUP BY Pr.PremiumId,Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName , PL.PolicyID ,  F.FamilyID, D.LocationName,D.LocationID,o.OfficerID , Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames ,O.Code + ' ' + O.LastName ,
		PL.EnrollDate,REP.ReportMode,Month(REP.StartDate), Pr.Paydate, Pr.Receipt,Pr.Amount,Pr.Amount, PD.Amount , PY.PaymentDate, PY.ExpectedAmount,OfficerCode,PL.PolicyStage,TransactionNo,CommissionRate,O.Phone
	--  Ins.IsHead,Payer.PayerName,Ins.DOB,V.LocationName,W.LocationName,
	ORDER BY PremiumId, O.OfficerID,F.FamilyID DESC;

END
GO
