IF OBJECT_ID('[dbo].[uspAPIEnterFamily]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIEnterFamily]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIEnterFamily]
(
	@AuditUserID INT = -3,
	@PermanentVillageCode NVARCHAR(8),
	@InsuranceNumber NVARCHAR(50),
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
	@CurrentVillageCode NVARCHAR(8) = NULL,
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
