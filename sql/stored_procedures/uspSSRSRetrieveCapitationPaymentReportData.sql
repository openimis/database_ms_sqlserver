IF OBJECT_ID('[dbo].[uspSSRSRetrieveCapitationPaymentReportData]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspSSRSRetrieveCapitationPaymentReportData]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspSSRSRetrieveCapitationPaymentReportData]
(
	@RegionId INT = NULL,
	@DistrictId INT = NULL,
	@ProdId INT,
	@Year INT,
	@Month INT,	
	@HFLevel xAttributeV READONLY
)
AS
BEGIN		
	declare @listOfHF table (id int);

	IF @ProdId is NULL or @ProdId <=0
	begin
		IF  @RegionId IS  NULL or @RegionId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.ValidityTo is NULL;
		ELSE IF  @DistrictId is NULL or @DistrictId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF JOIN tblLocations l on tblHF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId  ;
		ELSE 
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.LocationId = @DistrictId and tblHF.ValidityTo is NULL;
	ENd

	SELECT  RegionCode, 
			RegionName,
			DistrictCode,
			DistrictName,
			HFCode, 
			HFName,
			AccCode, 
			HFLevel, 
			HFSublevel,
			TotalPopulation[Population],
			TotalFamilies,
			TotalInsuredInsuree,
			TotalInsuredFamilies,
			TotalClaims,
			AlcContriPopulation,
			AlcContriNumFamilies,
			AlcContriInsPopulation,
			AlcContriInsFamilies,
			AlcContriVisits,
			AlcContriAdjustedAmount,
			UPPopulation,
			UPNumFamilies,
			UPInsPopulation,
			UPInsFamilies,
			UPVisits,
			UPAdjustedAmount,
			PaymentCathment,
			TotalAdjusted
	FROM tblCapitationPayment WHERE [year] = @Year AND [month] = @Month AND ( (SELECT count(id) from  @listOfHF)=0 OR HfID in (SELECT id from  @listOfHF)) AND ISNULL(@ProdId,-1) in  (ProductID,-1);
END
GO
 