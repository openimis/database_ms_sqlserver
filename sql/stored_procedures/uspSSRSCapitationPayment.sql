IF NOT OBJECT_ID('uspSSRSCapitationPayment') IS NULL
DROP PROCEDURE uspSSRSCapitationPayment
GO

CREATE PROCEDURE [dbo].[uspSSRSCapitationPayment]
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

		DECLARE @Level1 CHAR(1) = NULL,
			    @Sublevel1 CHAR(1) = NULL,
			    @Level2 CHAR(1) = NULL,
			    @Sublevel2 CHAR(1) = NULL,
			    @Level3 CHAR(1) = NULL,
			    @Sublevel3 CHAR(1) = NULL,
			    @Level4 CHAR(1) = NULL,
			    @Sublevel4 CHAR(1) = NULL,
			    @ShareContribution DECIMAL(5, 2),
			    @WeightPopulation DECIMAL(5, 2),
			    @WeightNumberFamilies DECIMAL(5, 2),
			    @WeightInsuredPopulation DECIMAL(5, 2),
			    @WeightNumberInsuredFamilies DECIMAL(5, 2),
			    @WeightNumberVisits DECIMAL(5, 2),
			    @WeightAdjustedAmount DECIMAL(5, 2)


	    DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'
	    DECLARE @LastDay DATE = EOMONTH(@FirstDay, 0)
	    DECLARE @DaysInMonth INT = DATEDIFF(DAY,@FirstDay,DATEADD(MONTH,1,@FirstDay))

		 set @DistrictId = CASE @DistrictId WHEN 0 THEN NULL ELSE @DistrictId END

		DECLARE @Locations TABLE (
			LocationId INT,
			LocationName VARCHAR(50),
			LocationCode VARCHAR(8),
			ParentLocationId INT
			)
		-- fetch all the region and districts
		INSERT INTO @Locations 
		    SELECT 0 LocationId, N'National' LocationName, NULL ParentLocationId,  0 LocationCode

			UNION ALL

			SELECT LocationId,LocationName, LocationCode, ISNULL(ParentLocationId, 0) 
			FROM tblLocations 
			WHERE ValidityTo IS NULL 
				AND LocationType IN ('R', 'D') 

		DECLARE @LocationTemp table (LocationId int, RegionId int, RegionCode [nvarchar](8) , RegionName [nvarchar](50), DistrictId int, DistrictCode [nvarchar](8), 
			DistrictName [nvarchar](50), ParentLocationId int)

		-- create table with locaiton hiearchy
		INSERT INTO  @LocationTemp(LocationId , RegionId , RegionCode , RegionName , DistrictId , DistrictCode , 
		DistrictName , ParentLocationId)
			( SELECT ISNULL(d.LocationId,r.LocationId) LocationId , 
				r.LocationId as RegionId , 
				r.LocationCode as RegionCode  , 
				r.LocationName as RegionName , 
				d.LocationId as DistrictId , 
				d.LocationCode as DistrictCode , 
				d.LocationName as DistrictName , 
				ISNULL(d.ParentLocationId,r.ParentLocationId) ParentLocationId 
			FROM @Locations  d  
			INNER JOIN @Locations r on d.ParentLocationId = r.LocationId
		UNION ALL 
			SELECT r.LocationId, r.LocationId as RegionId , 
			r.LocationCode as RegionCode  , 
			r.LocationName as RegionName , 
			NULL DistrictId , 
			NULL DistrictCode , 
		    NULL DistrictName ,  ParentLocationId 
			FROM @Locations  r WHERE ParentLocationId = 0)
		
		declare @listOfHF table (id int)

		-- get the product data
	    SELECT @Level1 = Level1, 
			@Sublevel1 = Sublevel1, 
			@Level2 = Level2, 
			@Sublevel2 = Sublevel2, 
			@Level3 = Level3, 
			@Sublevel3 = Sublevel3, 
			@Level4 = Level4, 
			@Sublevel4 = Sublevel4, 
			@ShareContribution = ISNULL(ShareContribution, 0), 
			@WeightPopulation = ISNULL(WeightPopulation, 0), 
			@WeightNumberFamilies = ISNULL(WeightNumberFamilies, 0), 
			@WeightInsuredPopulation = ISNULL(WeightInsuredPopulation, 0), 
			@WeightNumberInsuredFamilies = ISNULL(WeightNumberInsuredFamilies, 0), 
			@WeightNumberVisits = ISNULL(WeightNumberVisits, 0), 
			@WeightAdjustedAmount = ISNULL(WeightAdjustedAmount, 0)
	    FROM tblProduct Prod 
	    WHERE ProdId = @ProdId

				-- get the list of Hf part of the covered regions and config
		IF  (@RegionId IS  NULL or @RegionId =0) AND (@DistrictId is NULL or @DistrictId =0)
		BEGIN
			INSERT INTO @listOfHF(id) SELECT HF.HfID FROM tblHF HF WHERE HF.ValidityTo is NULL
			AND(
			    ((HF.HFLevel = @Level1) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      )
		 END
		 ELSE IF  @DistrictId is NULL or @DistrictId =0
		 begin
			INSERT INTO @listOfHF(id) SELECT HF.HfID FROM tblHF HF JOIN tblLocations l on HF.LocationId = l.LocationId   WHERE l.ParentLocationId =  @RegionId 
			AND(
			    ((HF.HFLevel = @Level1) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      )
		END
		ELSE
		BEGIN
			INSERT INTO @listOfHF(id) SELECT HF.HfID FROM tblHF HF WHERE HF.LocationId = @DistrictId and HF.ValidityTo is NULL
			AND(
			    ((HF.HFLevel = @Level1) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      )
		END
		-- get pop
	    DECLARE @TotalPopFam TABLE (
			HFID INT,
			TotalPopulation DECIMAL(18, 6), 
			TotalFamilies DECIMAL(18, 6)
			)

		INSERT INTO @TotalPopFam 

		    SELECT C.HFID HFID ,
		    SUM((ISNULL(L.MalePopulation, 0) + ISNULL(L.FemalePopulation, 0) + ISNULL(L.OtherPopulation, 0)) *(0.01* Catchment)) TotalPopulation, 
		    SUM(ISNULL(((L.Families)*(0.01* Catchment)), 0))TotalFamilies
		    FROM tblHFCatchment C
		    LEFT JOIN tblLocations L ON L.LocationId = C.LocationId OR  L.LegacyId = C.LocationId
		    INNER JOIN tblHF HF ON C.HFID = HF.HfID
		    INNER JOIN @LocationTemp D ON HF.LocationId = D.DistrictId
			INNER JOIN @listOfHF HFF ON C.HFID = HFF.ID
		    WHERE (C.ValidityTo IS NULL OR C.ValidityTo >= @FirstDay) AND C.ValidityFrom< @FirstDay
		    AND(L.ValidityTo IS NULL OR L.ValidityTo >= @FirstDay) AND L.ValidityFrom< @FirstDay
		    AND (HF.ValidityTo IS NULL )
		    GROUP BY C.HFID, D.DistrictId, D.RegionId


		-- get insuree
		DECLARE @InsuredInsuree TABLE (
			HFID INT,
			ProdId INT, 
			TotalInsuredInsuree DECIMAL(18, 6)
			)

		INSERT INTO @InsuredInsuree

		    SELECT HC.HFID, @ProdId ProdId, COUNT(DISTINCT IP.InsureeId)*(0.01 * Catchment) TotalInsuredInsuree
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.FamilyId = I.FamilyId
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
			INNER JOIN @listOfHF HFF ON HC.HFID = HFF.ID
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
		    GROUP BY HC.HFID, Catchment--, L.LocationId



		-- get insured family
		DECLARE @InsuredFamilies TABLE (
			HFID INT,
			TotalInsuredFamilies DECIMAL(18, 6)
			)

		INSERT INTO @InsuredFamilies
		    SELECT HC.HFID, COUNT(DISTINCT F.FamilyID)*(0.01 * Catchment) TotalInsuredFamilies
		    FROM tblInsureePolicy IP
		    INNER JOIN tblInsuree I ON I.InsureeId = IP.InsureeId
		    INNER JOIN tblFamilies F ON F.InsureeID = I.InsureeID
		    INNER JOIN tblHFCatchment HC ON HC.LocationId = F.LocationId
		    INNER JOIN tblPolicy PL ON PL.PolicyID = IP.PolicyId
			INNER JOIN @listOfHF HFF ON HC.HFID = HFF.ID
		    WHERE (HC.ValidityTo IS NULL OR HC.ValidityTo >= @FirstDay) AND HC.ValidityFrom< @FirstDay
		    AND I.ValidityTo IS NULL
		    AND IP.ValidityTo IS NULL
		    AND F.ValidityTo IS NULL
		    AND PL.ValidityTo IS NULL
		    AND IP.EffectiveDate <= @LastDay 
		    AND IP.ExpiryDate > @LastDay
		    AND PL.ProdID = @ProdId
		    GROUP BY HC.HFID, Catchment--, L.LocationId

		-- get allocated contribution
		DECLARE @Allocation TABLE (
			ProdId INT,
			Allocated DECIMAL(18, 6)
			)

		INSERT INTO @Allocation
			SELECT Prod.ProdId, SUM(ISNULL( CAST(1+DATEDIFF(DAY,
			CASE WHEN @FirstDay >  PR.PayDate and  @FirstDay >  PL.EffectiveDate  THEN  @FirstDay  WHEN PR.PayDate > PL.EffectiveDate THEN PR.PayDate ELSE  PL.EffectiveDate  END
				,CASE WHEN PL.ExpiryDate < @LastDay THEN PL.ExpiryDate ELSE @LastDay END)
				as decimal(18,4)) / ISNULL(NULLIF(DATEDIFF (DAY,(CASE WHEN PR.PayDate > PL.EffectiveDate THEN PR.PayDate ELSE  PL.EffectiveDate  END), PL.ExpiryDate ) * PR.Amount, 0), 1)
			 ,0)) Allocated
			FROM tblPremium PR 
			INNER JOIN tblPolicy PL ON PR.PolicyID = PL.PolicyID
			INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID 
			INNER JOIN  @Locations L ON ISNULL(Prod.LocationId, 0) = L.LocationId and (L.LocationId = ISNULL(@DistrictId, @RegionId) OR   ( L.ParentLocationId = ISNULL(@DistrictId, @RegionId)))
			WHERE PR.ValidityTo IS NULL
			AND PL.ValidityTo IS NULL
			AND Prod.ValidityTo IS  NULL
			AND Prod.ProdID = @ProdId
			AND PL.PolicyStatus <> 1
			AND PR.PayDate <= PL.ExpiryDate
			AND PL.ExpiryDate >= @FirstDay
			AND (PR.PayDate <=  @LastDay AND PL.EffectiveDate <= @LastDay) 
			GROUP BY Prod.ProdId


		DECLARE @ReportData TABLE (
			RegionCode VARCHAR(MAX),
			RegionName VARCHAR(MAX),
			DistrictCode VARCHAR(MAX),
			DistrictName VARCHAR(MAX),
			HFCode VARCHAR(MAX),
			HFID INT,
			HFName VARCHAR(MAX),
			AccCode VARCHAR(MAX),
			HFLevel VARCHAR(MAX),
			HFSublevel VARCHAR(MAX),
			TotalPopulation DECIMAL(18, 6),
			TotalFamilies DECIMAL(18, 6),
			TotalInsuredInsuree DECIMAL(18, 6),
			TotalInsuredFamilies DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6),
			TotalAdjusted DECIMAL(18, 6),

			PaymentCathment DECIMAL(18, 6),
			AlcContriPopulation DECIMAL(18, 6),
			AlcContriNumFamilies DECIMAL(18, 6),
			AlcContriInsPopulation DECIMAL(18, 6),
			AlcContriInsFamilies DECIMAL(18, 6),
			AlcContriVisits DECIMAL(18, 6),
			AlcContriAdjustedAmount DECIMAL(18, 6),
			UPPopulation DECIMAL(18, 6),
			UPNumFamilies DECIMAL(18, 6),
			UPInsPopulation DECIMAL(18, 6),
			UPInsFamilies DECIMAL(18, 6),
			UPVisits DECIMAL(18, 6),
			UPAdjustedAmount DECIMAL(18, 6)


			)

		DECLARE @ClaimValues TABLE (
			HFID INT,
			ProdId INT,
			TotalAdjusted DECIMAL(18, 6),
			TotalClaims DECIMAL(18, 6)
			)

		INSERT INTO @ClaimValues
		SELECT HFID, @ProdId ProdId, SUM(TotalAdjusted)TotalAdjusted, COUNT(DISTINCT ClaimId)TotalClaims FROM
		(
			SELECT HFID, SUM(PriceAdjusted)TotalAdjusted, ClaimId
			FROM 
			(SELECT C.HFID,c.ClaimId, PriceAdjusted 
			FROM  tblClaim C WITH (NOLOCK)
			INNER JOIN tblClaimItems ci ON c.ClaimID = ci.ClaimID
			INNER JOIN tblHF HF ON HF.HFID = C.HFID 
			WHERE CI.ValidityTo IS NULL  AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month
				AND ci.ProdId = @ProdId 
				AND (@WeightAdjustedAmount > 0.0 or @WeightNumberVisits > 0.0)
				AND (
			    ((HF.HFLevel = @Level1) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      )
			UNION ALL
			SELECT C.HFID, c.ClaimId, PriceAdjusted 
			FROM tblClaim C WITH (NOLOCK) 
			INNER JOIN tblClaimServices cs ON c.ClaimID = cs.ClaimID 
			INNER JOIN tblHF HF ON HF.HFID = C.HFID 
			WHERE cs.ValidityTo IS NULL  	AND C.ValidityTo IS NULL
				AND C.ClaimStatus > 4
				AND YEAR(C.DateProcessed) = @Year
				AND MONTH(C.DateProcessed) = @Month	
				AND cs.ProdId = @ProdId 
				AND (@WeightAdjustedAmount > 0.0 or @WeightNumberVisits > 0.0)
				AND (
			    ((HF.HFLevel = @Level1) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      )
			) claimdetails GROUP BY HFID,ClaimId
		)claims GROUP by HFID

	    INSERT INTO @ReportData 
		    SELECT L.RegionCode, L.RegionName, L.DistrictCode, L.DistrictName, HF.HFCode, HF.HfID, HF.HFName, Hf.AccCode, 
			HL.Name HFLevel, 
			SL.HFSublevelDesc HFSublevel,
		    PF.[TotalPopulation] TotalPopulation, PF.TotalFamilies TotalFamilies, II.TotalInsuredInsuree, IFam.TotalInsuredFamilies, CV.TotalClaims, CV.TotalAdjusted
		    ,(
			      ISNULL(ISNULL(PF.[TotalPopulation], 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightPopulation)) /  NULLIF(SUM(PF.[TotalPopulation])OVER(),0),0)  
			    + ISNULL(ISNULL(PF.TotalFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberFamilies)) /NULLIF(SUM(PF.[TotalFamilies])OVER(),0),0) 
			    + ISNULL(ISNULL(II.TotalInsuredInsuree, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightInsuredPopulation)) /NULLIF(SUM(II.TotalInsuredInsuree)OVER(),0),0) 
			    + ISNULL(ISNULL(IFam.TotalInsuredFamilies, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberInsuredFamilies)) /NULLIF(SUM(IFam.TotalInsuredFamilies)OVER(),0),0) 
			    + ISNULL(ISNULL(CV.TotalClaims, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightNumberVisits)) /NULLIF(SUM(CV.TotalClaims)OVER() ,0),0) 
			    + ISNULL(ISNULL(CV.TotalAdjusted, 0) * (A.Allocated * (0.01 * @ShareContribution) * (0.01 * @WeightAdjustedAmount)) /NULLIF(SUM(CV.TotalAdjusted)OVER(),0),0)

		    ) PaymentCathment

		    , A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution) AlcContriPopulation
		    , A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution) AlcContriNumFamilies
		    , A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution) AlcContriInsPopulation
		    , A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution) AlcContriInsFamilies
		    , A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution) AlcContriVisits
		    , A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution) AlcContriAdjustedAmount

		    ,  ISNULL((A.Allocated * (0.01 * @WeightPopulation) * (0.01 * @ShareContribution))/ NULLIF(SUM(PF.[TotalPopulation]) OVER(),0),0) UPPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberFamilies) * (0.01 * @ShareContribution))/NULLIF(SUM(PF.TotalFamilies) OVER(),0),0) UPNumFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightInsuredPopulation) * (0.01 * @ShareContribution))/NULLIF(SUM(II.TotalInsuredInsuree) OVER(),0),0) UPInsPopulation
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberInsuredFamilies) * (0.01 * @ShareContribution))/ NULLIF(SUM(IFam.TotalInsuredFamilies) OVER(),0),0) UPInsFamilies
		    ,  ISNULL((A.Allocated * (0.01 * @WeightNumberVisits) * (0.01 * @ShareContribution)) / NULLIF(SUM(CV.TotalClaims) OVER(),0),0) UPVisits
		    ,  ISNULL((A.Allocated * (0.01 * @WeightAdjustedAmount) * (0.01 * @ShareContribution))/ NULLIF(SUM(CV.TotalAdjusted) OVER(),0),0) UPAdjustedAmount

		    FROM tblHF HF
		    INNER JOIN @HFLevel HL ON HL.Code = HF.HFLevel
		    LEFT OUTER JOIN tblHFSublevel SL ON SL.HFSublevel = HF.HFSublevel
		    LEFT JOIN @LocationTemp L ON L.LocationId = HF.LocationId
		    LEFT OUTER JOIN @TotalPopFam PF ON PF.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredInsuree II ON II.HFID = HF.HfID
		    LEFT OUTER JOIN @InsuredFamilies IFam ON IFam.HFID = HF.HfID
		    --LEFT OUTER JOIN @Claims C ON C.HFID = HF.HfID
		    LEFT OUTER JOIN @ClaimValues CV ON CV.HFID = HF.HfID
		    LEFT OUTER JOIN @Allocation A ON A.ProdID = @ProdId

		    WHERE HF.ValidityTo IS NULL
		    AND (((L.RegionId = @RegionId OR @RegionId IS NULL) AND (L.DistrictId = @DistrictId OR @DistrictId IS NULL)) OR CV.ProdID IS NOT NULL OR II.ProdId IS NOT NULL)
		    AND(
			    ((HF.HFLevel = @Level1) AND (HF.HFSublevel = @Sublevel1 OR @Sublevel1 IS NULL))
			    OR ((HF.HFLevel = @Level2 ) AND (HF.HFSublevel = @Sublevel2 OR @Sublevel2 IS NULL))
			    OR ((HF.HFLevel = @Level3) AND (HF.HFSublevel = @Sublevel3 OR @Sublevel3 IS NULL))
			    OR ((HF.HFLevel = @Level4) AND (HF.HFSublevel = @Sublevel4 OR @Sublevel4 IS NULL))
		      )

	    SELECT  MAX (RegionCode)RegionCode, 
			MAX(RegionName)RegionName,
			MAX(DistrictCode)DistrictCode,
			MAX(DistrictName)DistrictName,
			HFCode, 
			MAX(HFName)HFName,
			MAX(AccCode)AccCode, 
			MAX(HFLevel)HFLevel, 
			MAX(HFSublevel)HFSublevel,
			ISNULL(SUM([TotalPopulation]),0)[Population],
			ISNULL(SUM(TotalFamilies),0)TotalFamilies,
			ISNULL(SUM(TotalInsuredInsuree),0)TotalInsuredInsuree,
			ISNULL(SUM(TotalInsuredFamilies),0)TotalInsuredFamilies,
			ISNULL(MAX(TotalClaims), 0)TotalClaims,
			ISNULL(SUM(AlcContriPopulation),0)AlcContriPopulation,
			ISNULL(SUM(AlcContriNumFamilies),0)AlcContriNumFamilies,
			ISNULL(SUM(AlcContriInsPopulation),0)AlcContriInsPopulation,
			ISNULL(SUM(AlcContriInsFamilies),0)AlcContriInsFamilies,
			ISNULL(SUM(AlcContriVisits),0)AlcContriVisits,
			ISNULL(SUM(AlcContriAdjustedAmount),0)AlcContriAdjustedAmount,
			ISNULL(SUM(UPPopulation),0)UPPopulation,
			ISNULL(SUM(UPNumFamilies),0)UPNumFamilies,
			ISNULL(SUM(UPInsPopulation),0)UPInsPopulation,
			ISNULL(SUM(UPInsFamilies),0)UPInsFamilies,
			ISNULL(SUM(UPVisits),0)UPVisits,
			ISNULL(SUM(UPAdjustedAmount),0)UPAdjustedAmount,
			ISNULL(SUM(PaymentCathment),0)PaymentCathment,
			ISNULL(SUM(TotalAdjusted),0)TotalAdjusted
	
	 FROM @ReportData

	 GROUP BY HFCode
END 
