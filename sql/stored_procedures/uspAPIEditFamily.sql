IF OBJECT_ID('[dbo].[uspAPIEditFamily]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIEditFamily]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIEditFamily]
(
	@AuditUserID INT = -3,
	@InsuranceNumberOfHead NVARCHAR(50),
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
						SELECT [insureeid], [Poverty], [ConfirmationType], isOffline, [ValidityFrom], getdate() ValidityTo, FamilyID, @AuditUserID, FamilyType, FamilyAddress, Ethnicity, ConfirmationNo, LocationId FROM tblFamilies
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
