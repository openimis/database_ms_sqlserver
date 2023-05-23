/****** Object:  StoredProcedure [dbo].[uspSSRSOverviewOfCommissions]    Script Date: 02/09/2022 17:03:08 ******/
IF OBJECT_ID('[dbo].[uspSSRSOverviewOfCommissions]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspSSRSOverviewOfCommissions]
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
	
	DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'; 
	DECLARE @LastDay DATE = EOMONTH(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01', 0)
		-- check that end date is before today
	if   @LastDay >  GETDATE()
	BEGIN
		SELECT @ErrorMessage = 'End report date must be before today'
		RETURN
	END
	
	SELECT 
	Pr.PremiumId,Pr.Paydate, Pr.Receipt, ISNULL(Pr.Amount,0) PrescribedContribution, 
	CASE WHEN @Mode=1 THEN  ISNULL(PD.Amount,0) ELSE ISNULL(Pr.Amount,0) END * @CommissionRate * 0.01 as Commission,
	Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName Product,
	PL.PolicyID, PL.EnrollDate,PL.PolicyStage,
	F.FamilyID,
	D.LocationName DistrictName,
	o.OfficerID, O.Code + ' ' + O.LastName Officer, O.Code OfficerCode,O.Phone PhoneNumber,
	Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName,	
	@Mode ReportMode, @Month [Month], 
	PY.PaymentDate, ISNULL(PD.Amount,0) ActualPayment , PY.ExpectedAmount PaymentAmount, TransactionNo

	FROM tblPremium Pr INNER JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID 
	INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID
	INNER JOIN tblInsuree Ins ON F.InsureeID = Ins.InsureeID
	LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId
	LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID 
	INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID
	INNER JOIN tblOfficer O ON O.Officerid = PL.OfficerID
	INNER JOIN tblLocations D ON D.LocationId = O.LocationId
	LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID 
	WHERE((@Mode = 1 and PY.MatchedDate IS NOT NULL ) OR  (PY.MatchedDate IS NULL AND @Mode = 0))
	and ((Year(Py.[PaymentDate]) = @Year AND Month(Py.[PaymentDate]) = @Month and @Mode = 1 ) 
		OR (Year(Pr.PayDate) = @Year AND Month(Pr.PayDate) = @Month and @Mode = 0 ))
	AND (D.LocationId = @LocationId	OR D.ParentLocationId = @LocationId)
	AND (ISNULL(Prod.ProdID,0) = ISNULL(@ProdId,0) OR @ProdId is null)
	AND (ISNULL(O.OfficerID,0) = ISNULL(@OfficerId,0) OR @OfficerId IS NULL)
	AND (ISNULL(Payer.PayerID,0) = ISNULL(@PayerId,0) OR @PayerId IS NULL)
	AND PR.PayType <> N'F'
	AND PR.ValidityTo IS NULL
	AND F.ValidityTo IS NULL
	AND Ins.ValidityTo IS NULL
							
ORDER BY PremiumId, O.OfficerID,F.FamilyID DESC;

END
