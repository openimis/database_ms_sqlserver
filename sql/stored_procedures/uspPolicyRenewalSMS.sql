IF OBJECT_ID('[dbo].[uspPolicyRenewalSMS]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspPolicyRenewalSMS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspPolicyRenewalSMS]
	--@RenewalWarning --> 1 = no valid product for renewal  2= No enrollment officer found (no photo)  4= INVALID Enrollment officer
	@RangeFrom as date = '',
	@RangeTo as date = '',
	@FamilyMessage NVARCHAR(500) = '' 
	
AS
BEGIN
	SET NOCOUNT ON;
	
	/*
	DECLARE @RangeFrom as date
	DECLARE @RangeTo as date 
	SET @RangeFrom = '2012-07-13'
	SET @RangeTo = '2012-07-13'
	*/
	DECLARE @RenewalID int
	
	DECLARE @SMSMessage as nvarchar(4000)
	DECLARE @SMSHeader nvarchar(1000)
	DECLARE @SMSPhotos nvarchar(3000)
	DECLARE @RenewalDate as date
	DECLARE @InsureeID as int
	DECLARE @ProductCode as nvarchar(8)
	DECLARE @ProductName as nvarchar(100)
	DECLARE @DistrictName as nvarchar(50)
	DECLARE @VillageName as nvarchar(50) 
	DECLARE @WardName as nvarchar(50)  
	DECLARE @CHFID as nvarchar(50)
	DECLARE @HeadPhotoRenewal bit 
	DECLARE @InsLastName as nvarchar(100)
	DECLARE @InsOtherNames as nvarchar(100)
	DECLARE @ConvProdID as int    
    DECLARE @OfficerID as int               
	DECLARE @OffPhone as nvarchar(50)
	DECLARE @RenewalWarning as tinyint 

	DECLARE @SMSStatus as tinyint 
	DECLARE @iCount as int 
	
	DECLARE @CHFIDPhoto as nvarchar(50)	
	DECLARE @InsLastNamePhoto as nvarchar(100)
	DECLARE @InsOtherNamesPhoto as nvarchar(100)	
	DECLARE @InsPhoneNumber NVARCHAR(20)

	DECLARE @PhoneCommunication BIT

	IF @RangeFrom = '' SET @RangeFrom = GETDATE()
	IF @RangeTo = '' SET @RangeTo = GETDATE()
	DECLARE @SMSQueue TABLE (SMSID int, PhoneNumber nvarchar(50)  , SMSMessage nvarchar(4000) , SMSLength int)
	
	SET @iCount = 1 
	DECLARE LOOP1 CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT     tblPolicyRenewals.RenewalID, tblPolicyRenewals.RenewalDate, tblPolicyRenewals.PhoneNumber, tblDistricts.DistrictName, tblVillages.VillageName, tblWards.WardName, 
								tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames, tblProduct.ProductCode, tblProduct.ProductName, tblPolicyRenewals.RenewalWarnings, tblInsuree.Phone, tblOfficer.PhoneCommunication
										  
					FROM         tblPolicyRenewals INNER JOIN
										  tblInsuree ON tblPolicyRenewals.InsureeID = tblInsuree.InsureeID INNER JOIN
										  tblPolicy ON tblPolicyRenewals.PolicyID = tblPolicy.PolicyID INNER JOIN
										  tblFamilies ON tblPolicy.FamilyID = tblFamilies.FamilyID INNER JOIN
										  tblVillages ON tblFamilies.LocationId = tblVillages.VillageID INNER JOIN
										  tblWards ON tblVillages.WardID = tblWards.WardID INNER JOIN
										  tblDistricts ON tblWards.DistrictID = tblDistricts.DistrictID INNER JOIN
										  tblProduct ON tblPolicy.ProdID = tblProduct.ProdID
										  INNER JOIN tblOfficer ON tblPolicyRenewals.NewOfficerID = tblOfficer.OfficerID
										  WHERE NOT (tblPolicyRenewals.PhoneNumber IS NULL) AND tblPolicyRenewals.RenewalPromptDate Between @RangeFrom AND @RangeTo
										  
	OPEN LOOP1
	FETCH NEXT FROM LOOP1 INTO @RenewalID, @RenewalDate,@OffPhone,@DistrictName,@VillageName,@WardName, @CHFID,@InsLastName,@InsOtherNames,@ProductCode,@ProductName,@RenewalWarning, @InsPhoneNumber, @PhoneCommunication
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
			SET @HeadPhotoRenewal = 0
			SET @SMSHeader = ''
			SET @SMSPhotos = ''
			
			--first get the photo renewal string 
			
			DECLARE LOOPPHOTOS CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT     tblInsuree.CHFID, tblInsuree.LastName, tblInsuree.OtherNames
					FROM         tblPolicyRenewalDetails INNER JOIN
										  tblInsuree ON tblPolicyRenewalDetails.InsureeID = tblInsuree.InsureeID
					WHERE  tblPolicyRenewalDetails.RenewalID = @RenewalID
										  
			OPEN LOOPPHOTOS
			FETCH NEXT FROM LOOPPHOTOS INTO @CHFIDPhoto,@InsLastNamePhoto,@InsOtherNamesPhoto
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				IF @CHFIDPhoto = @CHFID 
				BEGIN
					--remember that the head needs renewal as well 
					SET @HeadPhotoRenewal = 1
				END
				ELSE
				BEGIN
					--add to string of dependant that need photo renewal
					SET @SMSPhotos = @SMSPhotos + char(10) + @CHFIDPhoto + char(10) + @InsLastNamePhoto + ' ' + @InsOtherNamesPhoto 
				END
				FETCH NEXT FROM LOOPPHOTOS INTO @CHFIDPhoto,@InsLastNamePhoto,@InsOtherNamesPhoto
		    END       
			CLOSE LOOPPHOTOS
			DEALLOCATE LOOPPHOTOS
			
			IF LEN(@SMSPhotos) <> 0 OR @HeadPhotoRenewal = 1
			BEGIN
				IF @HeadPhotoRenewal = 1 
					SET @SMSPhotos = '--Photos--' + char(10) + 'HOF' + @SMSPhotos
				ELSE
					SET @SMSPhotos = '--Photos--' + @SMSPhotos
			END
			
			--now construct the header record
			SET @SMSHeader = '--Renewal--' +  char(10) + CONVERT(nvarchar(20),@RenewalDate,103) + char(10) + @CHFIDPhoto + char(10) + @InsLastNamePhoto + ' ' + @InsOtherNamesPhoto + char(10) + @DistrictName + char(10) + @WardName + char(10) + @VillageName + char(10) + @ProductCode  + '-' + @ProductName + char(10)
			SET @SMSMessage = @SMSHeader + char(10) + @SMSPhotos
			--SET @SMSMessage = REPLACE(@SMSMessage,char(10),'%0A')

			IF @PhoneCommunication = 1
			BEGIN
				INSERT INTO @SMSQueue VALUES (@iCount,@OffPhone, @SMSMessage , LEN(@SMSMessage))
				SET @iCount = @iCount + 1
			END
			
			--Create SMS for the family 
			IF LEN(ISNULL(@FamilyMessage,'')) > 0 AND LEN(@InsPhoneNumber) > 0
			BEGIN
				
				--Create dynamic parameters
				DECLARE @ExpiryDate DATE = DATEADD(DAY, -1, @RenewalDate)
				DECLARE @NewFamilyMessage NVARCHAR(500) = ''
				SET @NewFamilyMessage = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@FamilyMessage, '@@InsuranceID', @CHFID), '@@LastName', @InsLastName), '@@OtherNames', @InsOtherNames), '@@ProductCode', @ProductCode), '@@ProductName', @ProductName), '@@ExpiryDate', FORMAT(@ExpiryDate,'dd MMM yyyy'))

				IF LEN(@NewFamilyMessage) > 0 
				BEGIN
					INSERT INTO @SMSQueue VALUES(@iCount, @InsPhoneNumber, @NewFamilyMessage, LEN(@NewFamilyMessage))
					SET @iCount += 1;
				END
			END

		FETCH NEXT FROM LOOP1 INTO @RenewalID, @RenewalDate,@OffPhone,@DistrictName,@VillageName,@WardName, @CHFID,@InsLastName,@InsOtherNames,@ProductCode,@ProductName,@RenewalWarning, @InsPhoneNumber, @PhoneCommunication
	END
	CLOSE LOOP1
	DEALLOCATE LOOP1
	
	--SELECT * FROM @SMSQueue
	
	SELECT N'IMIS-RENEWAL' sender,
		(
			SELECT REPLACE(PhoneNumber,' ','')  [to] 
			FROM @SMSQueue PNo
			WHERE Pno.SMSId = SMS.SMSID
			FOR XML  PATH('recipients'), TYPE
		) PhoneNumber,
	SMS.SMSMessage [text]
	FROM @SMSQueue SMS
	WHERE LEN(SMS.PhoneNumber) > 0 AND LEN(ISNULL(SMS.SMSMessage,'')) > 0
	FOR XML PATH('message'), ROOT('request'), TYPE; 
	
END
GO
