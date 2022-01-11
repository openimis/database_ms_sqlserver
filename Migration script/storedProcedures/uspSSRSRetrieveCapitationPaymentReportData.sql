
IF OBJECT_ID('uspSSRSRetrieveCapitationPaymentReportData', 'P') IS NOT NULL
    DROP PROCEDURE uspSSRSRetrieveCapitationPaymentReportData
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

		IF  @RegionId IS  NULL or @RegionId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.ValidityTo is NULL;
		 ELSE IF  @DistrictId is NULL or @DistrictId =0
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF JOIN tblLocations l on tblHF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId  ;
		ELSE 
			INSERT INTO @listOfHF(id) SELECT tblHF.HfID FROM tblHF WHERE tblHF.LocationId = @DistrictId and tblHF.ValidityTo is NULL;


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
	   FROM tblCapitationPayment WHERE [year] = @Year AND [month] = @Month AND HfID in (SELECT id from  @listOfHF) AND @ProdId = ProductID;
END
GO 
