IF OBJECT_ID('[dbo].[uspPolicyInquiry2]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspPolicyInquiry2]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspPolicyInquiry2] 
	@CHFID as nvarchar(50)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @InsureeID as int
    DECLARE @FamilyID as int 
    
    DECLARE @PolicyID as int 
    
    DECLARE @LastName as nvarchar(100)
    DECLARE @OtherNames as nvarchar(100)
    DECLARE @DOB as date
    DECLARE @Gender as nvarchar(1)
    DECLARE @PhotoName as nvarchar(100)
    DECLARE @PhotoFolder as nvarchar(100)
    DECLARE @PolicyStatus as int 
    DECLARE @ExpiryDate as date
    DECLARE @ProductCode as nvarchar(8)
    DECLARE @ProductName as nvarchar(100)
        
    DECLARE @DedInsuree as decimal(18,2) 
    DECLARE @DedOPInsuree as decimal(18,2) 
    DECLARE @DedIPInsuree as decimal(18,2) 
    DECLARE @MaxInsuree as decimal(18,2) 
    DECLARE @MaxOPInsuree as decimal(18,2) 
    DECLARE @MaxIPInsuree as decimal(18,2) 
    
    DECLARE @DedTreatment as decimal(18,2) 
    DECLARE @DedOPTreatment as decimal(18,2) 
    DECLARE @DedIPTreatment as decimal(18,2) 
    DECLARE @MaxTreatment as decimal(18,2) 
    DECLARE @MaxOPTreatment as decimal(18,2) 
    DECLARE @MaxIPTreatment as decimal(18,2) 
    
    DECLARE @DedPolicy as decimal(18,2) 
    DECLARE @DedOPPolicy as decimal(18,2) 
    DECLARE @DedIPPolicy as decimal(18,2) 
    DECLARE @MaxPolicy as decimal(18,2)
    DECLARE @MaxOPPolicy as decimal(18,2) 
    DECLARE @MaxIPPolicy as decimal(18,2) 
    
    DECLARE @CalcDed as decimal(18,2)
    DECLARE @CalcIPDed as decimal(18,2)
    DECLARE @CalcOPDed as decimal(18,2)
    DECLARE @CalcMax as decimal(18,2)
    DECLARE @CalcIPMax as decimal(18,2)
    DECLARE @CalcOPMax as decimal(18,2)
    
    DECLARE @TempValue as decimal(18,2)
    DECLARE @CalcValue as decimal(18,2)
    
    DECLARE @C1 as bit 
    DECLARE @C2 as bit 
    DECLARE @C3 as bit 
    DECLARE @C4 as bit
    DECLARE @C5 as bit
    DECLARE @C6 as bit
    
    SET @C1 = 0
    SET @C2 = 0
    SET @C3 = 0
    SET @C4 = 0
    SET @C5 = 0
    SET @C6 = 0
    
    
    CREATE TABLE #Inquiry  (CHFID nvarchar(50),
							LastName nvarchar(100),
							OtherNames nvarchar(100),
							DOB  date,
							Gender  nvarchar(1),
							PolicyStatus  int ,
							ExpiryDate  date,
							ProductCode nvarchar(8),
							ProductName nvarchar(100),
							Ded decimal(18,2),
							DedIP decimal (18,2),
							DedOP decimal (18,2),
							MaxGEN decimal(18,2),
							MaxIP decimal(18,2),
							MaxOP decimal(18,2)
							)
    
    DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR 
			SELECT      tblInsuree.InsureeID, tblPolicy.PolicyID, tblInsuree.LastName, tblInsuree.OtherNames, tblInsuree.DOB, tblInsuree.Gender, tblPhotos.PhotoFolder, tblPhotos.PhotoFileName, tblPolicy.PolicyStatus, tblPolicy.ExpiryDate, 
						  tblProduct.ProductCode, tblProduct.ProductName, tblProduct.DedInsuree, tblProduct.DedOPInsuree, tblProduct.DedIPInsuree, tblProduct.MaxInsuree, 
						  tblProduct.MaxOPInsuree, tblProduct.MaxIPInsuree, tblProduct.DedTreatment, tblProduct.DedOPTreatment, tblProduct.DedIPTreatment, tblProduct.MaxTreatment, 
						  tblProduct.MaxOPTreatment, tblProduct.MaxIPTreatment, tblProduct.DedPolicy, tblProduct.DedOPPolicy, tblProduct.DedIPPolicy, tblProduct.MaxPolicy, 
						  tblProduct.MaxOPPolicy, tblProduct.MaxIPPolicy
			FROM         tblPhotos RIGHT OUTER JOIN
						  tblInsuree ON tblPhotos.PhotoID = tblInsuree.PhotoID LEFT OUTER JOIN
						  tblPolicy LEFT OUTER JOIN
						  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID RIGHT OUTER JOIN
						  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID ON tblInsuree.FamilyID = tblFamilies.FamilyID
			WHERE     (tblInsuree.ValidityTo IS NULL) AND (tblPolicy.ValidityTo IS NULL) AND (tblInsuree.CHFID = @CHFID)
		--SELECT     tblPolicy.PolicyID, tblInsuree.LastName, tblInsuree.OtherNames, tblInsuree.DOB, tblInsuree.Gender, tblPolicy.PolicyStatus, tblPolicy.ExpiryDate, 
		--					  tblProduct.ProductCode, tblProduct.ProductName, tblProduct.DedInsuree, tblProduct.DedOPInsuree, tblProduct.DedIPInsuree, tblProduct.MaxInsuree, 
		--					  tblProduct.MaxOPInsuree, tblProduct.MaxIPInsuree, tblProduct.DedTreatment, tblProduct.DedOPTreatment, tblProduct.DedIPTreatment, tblProduct.MaxTreatment, 
		--					  tblProduct.MaxOPTreatment, tblProduct.MaxIPTreatment, tblProduct.DedPolicy, tblProduct.DedOPPolicy, tblProduct.DedIPPolicy, tblProduct.MaxPolicy, 
		--					  tblProduct.MaxOPPolicy, tblProduct.MaxIPPolicy
		--FROM         tblInsuree INNER JOIN
		--					  tblFamilies ON tblInsuree.FamilyID = tblFamilies.FamilyID INNER JOIN
		--					  tblPolicy ON tblFamilies.FamilyID = tblPolicy.FamilyID INNER JOIN
		--					  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID
		--WHERE     (tblInsuree.ValidityTo IS NULL) AND (tblPolicy.ValidityTo IS NULL) AND tblInsuree.CHFID = @CHFID
	
	OPEN LOOP1
	FETCH NEXT FROM LOOP1 INTO @InsureeID, @PolicyID, @LastName,@OtherNames,@DOB,@Gender,@PhotoFolder,@PhotoName, @PolicyStatus,@ExpiryDate,@ProductCode,@ProductName,@DedInsuree,@DedOPInsuree,@DedIPInsuree,@MaxInsuree,
    @MaxOPInsuree,@MaxIPInsuree,@DedTreatment,@DedOPTreatment,@DedIPTreatment,@MaxTreatment,@MaxOPTreatment,@MaxIPTreatment,@DedPolicy,@DedOPPolicy,
    @DedIPPolicy,@MaxPolicy,@MaxOPPolicy,@MaxIPPolicy
    
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		--reset all deductables and ceilings 
		SET @CalcDed = 0 
		SET @CalcIPDed = 0 
		SET @CalcOPDed = 0 
		SET @CalcMax   = -1 
		SET @CalcIPMax  = -1 
		SET @CalcOPMax  = -1
		
		--************************DEDUCTIONS*********************************
		
		--TREATMENT level
		IF ISNULL(@DedTreatment,0) <> 0   
			SET @CalcDed = @DedTreatment 
		ELSE
		BEGIN
			IF ISNULL(@DedIPTreatment ,0) <> 0   
				SET @CalcIPDed  = @DedIPTreatment  
			IF ISNULL(@DedOPTreatment ,0) <> 0   
				SET @CalcOPDed  = @DedOPTreatment  
		END
		
		--INSUREE level
		IF ISNULL(@DedInsuree ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(DedG),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @DedInsuree > @TempValue 
				SET @CalcDed = @DedInsuree - @TempValue
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@DedIPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedIP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedIPInsuree  > @TempValue 
					SET @CalcIPDed  = @DedIPInsuree  - @TempValue
			END
			
			IF ISNULL(@DedOPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedOP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedOPInsuree  > @TempValue 
					SET @CalcOPDed  = @DedOPInsuree  - @TempValue
			END	
		END
		
		
		--POLICY level
		IF ISNULL(@DedPolicy  ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(DedG),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @DedPolicy  > @TempValue 
				SET @CalcDed = @DedPolicy - @TempValue
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@DedIPPolicy ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedIP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedIPPolicy   > @TempValue 
					SET @CalcIPDed  = @DedIPPolicy - @TempValue
			END
			
			IF ISNULL(@DedOPPolicy  ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(DedOP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @DedOPPolicy   > @TempValue 
					SET @CalcOPDed  = @DedOPPolicy - @TempValue
			END	
		END
		
		--********************CEILINGS*************************** 
		
		--TREATMENT level
		IF ISNULL(@MaxTreatment ,0) <> 0   
			SET @CalcMax = @MaxTreatment  
		IF ISNULL(@MaxIPTreatment  ,0) <> 0   
			SET @CalcIPMax   = @MaxIPTreatment   
		IF ISNULL(@MaxOPTreatment  ,0) <> 0   
			SET @CalcOPMax  = @MaxOPTreatment   
		
		--INSUREE level
		IF ISNULL(@MaxInsuree  ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(RemG),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @MaxInsuree > @TempValue 
				SET @Calcmax  = @MaxInsuree - @TempValue
			ELSE 
				SET @Calcmax  = 0   -- no value left !! 
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@MaxIPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemIP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxIPInsuree > @TempValue 
					SET @CalcIPMax   = @MaxIPInsuree  - @TempValue
				ELSE 
					SET @CalcIPMax   = 0   -- no value left !! 
			END
			IF ISNULL(@MaxOPInsuree ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemOP),0) from tblClaimDedRem WHERE InsureeID = @InsureeID AND PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxOPInsuree > @TempValue 
					SET @CalcOPMax   = @MaxOPInsuree  - @TempValue
				ELSE 
					SET @CalcOPMax   = 0   -- no value left !! 
			END
			
		END
		
		-- POLICY level
		IF ISNULL(@MaxPolicy ,0) <> 0   
		BEGIN
			SELECT @TempValue = ISNULL(SUM(RemG),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
			IF @MaxPolicy  > @TempValue 
				SET @Calcmax  = @MaxPolicy - @TempValue
			ELSE 
				SET @Calcmax  = 0   -- no value left !! 
		END
		ELSE
		BEGIN
			--check in and out patient		
			IF ISNULL(@MaxIPPolicy ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemIP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxIPPolicy  > @TempValue 
					SET @CalcIPMax   = @MaxIPPolicy - @TempValue
				ELSE 
					SET @CalcIPMax   = 0   -- no value left !! 
			END
			IF ISNULL(@MaxOPPolicy  ,0) <> 0   
			BEGIN
				SELECT @TempValue = ISNULL(SUM(RemOP),0) from tblClaimDedRem WHERE PolicyID = @PolicyID AND ValidityTo IS NULL
				IF @MaxOPPolicy  > @TempValue 
					SET @CalcOPMax   = @MaxOPPolicy  - @TempValue
				ELSE 
					SET @CalcOPMax   = 0   -- no value left !! 
			END
			
		END
		
		IF @PolicyStatus = 2
		BEGIN
			IF @CalcDed <> 0 
				SET @C1 = 1
			IF @CalcIPDed <> 0 
				SET @C2  = 1
			IF @CalcOPDed  <> 0 
				SET @C3  = 1
			IF @CalcMax  >= 0  
				SET @C4  = 1
			IF @CalcIPMax >= 0  
				SET @C5  = 1
			IF @CalcOPMax >= 0  
				SET @C6  = 1
		END
		
		IF @CalcIPMax = -1 
			SET @CalcIPMax = NULL
		IF @CalcOPMax = -1 
			SET @CalcOPMax = NULL
		IF @CalcMax = -1 
			SET @CalcMax = NULL	
		
		--INSERT Into Temp Table
		INSERT #Inquiry (CHFID,LastName,OtherNames,DOB,Gender,PolicyStatus,ExpiryDate,ProductCode,ProductName,
							Ded,
							DedIP,
							DedOP,
							MaxGEN,
							MaxIP,
							MaxOP)
						VALUES
							(@CHFID,@LastName,@OtherNames,@DOB,@Gender,@PolicyStatus,@ExpiryDate,@ProductCode,@ProductName,
							 @CalcDed,
							 @CalcIPDed,
							 @CalcOPDed,
							 @CalcMax,
							 @CalcIPMax,
							 @CalcOPMax
							)
		
		
		FETCH NEXT FROM LOOP1 INTO @InsureeID, @PolicyID, @LastName,@OtherNames,@DOB,@Gender,@PhotoFolder,@PhotoName,@PolicyStatus,@ExpiryDate,@ProductCode,@ProductName,@DedInsuree,@DedOPInsuree,@DedIPInsuree,@MaxInsuree,
    @MaxOPInsuree,@MaxIPInsuree,@DedTreatment,@DedOPTreatment,@DedIPTreatment,@MaxTreatment,@MaxOPTreatment,@MaxIPTreatment,@DedPolicy,@DedOPPolicy,
    @DedIPPolicy,@MaxPolicy,@MaxOPPolicy,@MaxIPPolicy
    
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1
    
    --Now output table 
    DECLARE @STR as nvarchar(1000)
    
    SET @STR = 'SELECT CHFID as ID,LastName as [Last Name],OtherNames as [Other Names],DOB,Gender,PolicyStatus as [Status],ExpiryDate as [Expiry],ProductCode as [Code],ProductName as [Product]' 
    IF @C1 <> 0 
		SET @STR = @STR + ',Ded as [Deductable]'
    IF @C2 <> 0 
		SET @STR = @STR + ',DedIP as [IP Deductable]'
	IF @C3  <> 0 
		SET @STR = @STR + ',DedOP as [OP Deductable]'
	IF @C4  <> 0  
		SET @STR = @STR + ',MAXGEN as [Ceiling]'
	IF @C5 <> 0  
		SET @STR = @STR + ',MAXIP as [IP Ceiling]'
	IF @C6 <> 0  
		SET @STR = @STR + ',MAXOP as [OP Ceiling]'
		
    SET @STR = @STR + ' FROM #Inquiry' 
    
    DECLARE @Active as int
    
    SELECT @Active = ISNULL(COUNT(CHFID),0) FROM #Inquiry WHERE PolicyStatus = 2
    IF @Active > 0 
	BEGIN
		SET @STR = @STR + ' WHERE PolicyStatus = 2'
	END
    ELSE
    BEGIN
		SET @STR = @STR + ' WHERE (PolicyStatus = 4 OR PolicyStatus = 8) AND ABS(DATEDIFF(y,GETDATE(),ExpiryDate)) < 2 '
	END
    
    EXEC(@STR)
    drop table #Inquiry 
    --SELECT * FROM @Inquiry 
END
GO
