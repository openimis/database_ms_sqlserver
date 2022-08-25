IF OBJECT_ID('[dbo].[uspAPIEnterMemberFamily]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIEnterMemberFamily]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIEnterMemberFamily]
(
	@AuditUserID INT = -3,
	@InsureeNumberOfHead NVARCHAR(50),
	@InsureeNumber NVARCHAR(50),
	@OtherNames NVARCHAR(100),
	@LastName NVARCHAR(100),
	@BirthDate DATE,
	@Gender NVARCHAR(1),
	@Relationship NVARCHAR(50) = NULL,
	@MaritalStatus NVARCHAR(1) = NULL,
	@BeneficiaryCard BIT = 0,
	@VillageCode NVARCHAR(8)= NULL,
	@CurrentAddress NVARCHAR(200) = '',
	@Proffesion NVARCHAR(50)= NULL,
	@Education NVARCHAR(50)= NULL,
	@PhoneNumber NVARCHAR(50) = '',
	@Email NVARCHAR(100)= '',
	@IdentificationType NVARCHAR(1) = NULL,
	@IdentificationNumber NVARCHAR(25) = '',
	@FSPCode NVARCHAR(8) = NULL
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number of head
		2-Insurance number of head not found
		3- Wrong format or missing insurance number of member
		4-Wrong or missing  gender
		5-Wrong format or missing birth date
		6-Missing last name
		7-Missing other name
		8- Insurance number of member duplicated
		9- Wrong current village code
		10-Wrong marital status
		11-Wrong education
		12-Wrong profession
		13-Wrong RelationShip
		14-FSP code not found 
		15 - wrong identification type 
		0 - Success (0 OK), 
		-1 -Unknown  Error 
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsureeNumberOfHead,'')) = 0
		RETURN 1

	--2-Insurance number of head not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsureeNumberOfHead AND ValidityTo IS NULL)
		RETURN 2

	--3- Wrong format or missing insurance number of member
	IF LEN(ISNULL(@InsureeNumber,'')) = 0
		RETURN 3
	--4-Wrong or missing  gender
	IF LEN(ISNULL(@Gender,'')) = 0
		RETURN 4

	IF NOT EXISTS(SELECT 1 FROM tblGender WHERE Code = @Gender)
		RETURN 4

	--5-Wrong format or missing birth date
	IF NULLIF(@BirthDate,'') IS NULL
		RETURN 5

	--6-Missing last name
	IF LEN(ISNULL(@LastName,'')) = 0 
			RETURN 6
	
	--7-Missing other name
	IF LEN(ISNULL(@OtherNames,'')) = 0 
		RETURN 7

	--8- Insurance number of member duplicated
	IF EXISTS(SELECT 1 FROM tblInsuree WHERE ValidityTo IS NULL AND CHFID = @InsureeNumber)
		RETURN 8

	--9- Wrong current village code
	IF NOT EXISTS(SELECT 1 FROM tblLocations  WHERE LocationCode = @VillageCode AND ValidityTo IS NULL AND LocationType ='V') AND LEN(ISNULL(@VillageCode,'')) > 0
		RETURN 9

	--10-Wrong marital status
	IF dbo.udfAPIisValidMaritalStatus(@MaritalStatus) = 0 AND LEN(ISNULL(@MaritalStatus,'')) > 0
		RETURN 10

	--11-Wrong education
	IF NOT EXISTS(SELECT  1 FROM tblEducations WHERE Education = @Education) AND LEN(ISNULL(@Education,'')) > 0
		RETURN 11

	--12 - Wrong profession
	IF NOT EXISTS(SELECT  1 FROM tblProfessions WHERE Profession = @Proffesion) AND LEN(ISNULL(@Proffesion,'')) > 0
		RETURN 12

	--13 - FSP code not found
	IF NOT EXISTS(SELECT  1 FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL) AND LEN(ISNULL(@FSPCode,'')) > 0
		RETURN 13

	--14 - Wrong Relation
	IF NOT EXISTS(SELECT  1 FROM tblRelations WHERE Relation = @Relationship) AND LEN(ISNULL(@Relationship,'')) > 0
		RETURN 14



	--15 - Wrong identification type
	IF NOT EXISTS(SELECT 1 FROM tblIdentificationTypes WHERE  IdentificationCode  = @IdentificationType ) AND LEN(ISNULL(@IdentificationType,'')) > 0
		RETURN 15
	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION ENROLMEMBERFAMILY
			
				DECLARE @FamilyID INT,
						@ProfessionId INT,
						@RelationId INT,
						@EducationId INT,
						@LocationId INT,
						@HfID INT,
						@InsureeId INT



				SET @FamilyID = (SELECT TOP 1 FamilyID FROM tblInsuree WHERE CHFID = @InsureeNumberOfHead AND ValidityTo IS NULL ORDER BY FamilyID DESC)
				SELECT @HfID = HfID FROM tblHF WHERE HFCode = @FSPCode AND ValidityTo IS NULL
				SELECT @ProfessionId = ProfessionId FROM tblProfessions WHERE Profession = @Proffesion 
				SELECT @EducationId = EducationId FROM tblEducations WHERE Education = @Education
				SELECT @RelationId = RelationId FROM tblRelations WHERE Relation = @Relationship
				SELECT @LocationId = LocationId FROM tblLocations WHERE LocationCode = @VillageCode AND ValidityTo IS NULL


				INSERT INTO dbo.tblInsuree
					(FamilyID,CHFID,LastName,OtherNames,DOB,Gender,Marital,IsHead,Phone, CardIssued, passport,TypeOfId , ValidityFrom,AuditUserID,Profession,Education, Relationship, Email,isOffline,HFID,CurrentAddress,CurrentVillage)
					SELECT @FamilyID FamilyID, @InsureeNumber CHFID, @LastName LastName, @OtherNames OtherNames, @BirthDate BirthDate, @Gender Gender, @MaritalStatus Marital, 0  IsHead, @PhoneNumber Phone, @BeneficiaryCard BeneficiaryCard, @IdentificationNumber PassPort, @IdentificationType , GETDATE() ValidityFrom,@AuditUserID AuditUserID, @ProfessionId Profession, @EducationId Education, @RelationId Relation, @Email Email, 0 IsOffline, @HfID, @CurrentAddress CurrentAddress, @LocationId CurrentVillage
							SET @InsureeId = SCOPE_IDENTITY()

							INSERT INTO tblPhotos(InsureeID,CHFID,PhotoFolder,PhotoFileName,OfficerID,PhotoDate,ValidityFrom,AuditUserID)
					SELECT InsureeID,CHFID,'','',0,GETDATE(),ValidityFrom,AuditUserID from tblInsuree WHERE InsureeID = @InsureeID; 
					UPDATE tblInsuree SET PhotoID = (SELECT IDENT_CURRENT('tblPhotos')),PhotoDate=GETDATE() WHERE InsureeID = @InsureeID;

							EXEC uspAddInsureePolicy @InsureeId;
								
				

			COMMIT TRANSACTION ENROLMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION ENROLMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH

END
GO
