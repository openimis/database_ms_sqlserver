IF OBJECT_ID('[dbo].[uspAPIEditMemberFamily]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIEditMemberFamily]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIEditMemberFamily]
(
	@AuditUserID INT = -3,
	@InsureeNumber NVARCHAR(50),
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
