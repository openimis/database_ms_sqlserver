--- MIGRATION Script from v1.2.0 to v1.3.0

-- OP-50: User's password storage in the DB (RFC 105)

IF  COL_LENGTH('tblUsers','StoredPassword') IS NULL
ALTER TABLE tblUsers ADD StoredPassword nvarchar(256) NULL
GO
IF  COL_LENGTH('tblUsers','PrivateKey') IS NULL
ALTER TABLE tblUsers ADD PrivateKey nvarchar(256) NULL
GO
IF  COL_LENGTH('tblUsers','PrivateKey') < 256
ALTER TABLE tblUsers ALTER COLUMN PrivateKey nvarchar(256) NULL
GO
IF  COL_LENGTH('tblUsers','PasswordValidity') IS NULL
ALTER TABLE tblUsers ADD PasswordValidity DateTime NULL
OPEN SYMMETRIC KEY EncryptionKey DECRYPTION BY Certificate EncryptData;
UPDATE tblUsers 
SET Privatekey =
CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(LoginName AS VARCHAR(MAX))),2),
StoredPassword =
CONVERT(varchar(max),HASHBYTES('SHA2_256',
	CONCAT
		(
		CAST(CONVERT(NVARCHAR(25), DECRYPTBYKEY(Password)) COLLATE LATIN1_GENERAL_CS_AS AS VARCHAR(MAX))
		,CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(LoginName AS VARCHAR(MAX))),2)
		)
	),2)
FROM tblusers  
WHERE ValidityTo is null

CLOSE SYMMETRIC KEY EncryptionKey
GO													   

-- OP-63: Generation of user records for enrolment officer and claim administrators	(RFC 91)
IF  COL_LENGTH('tblOfficer','HasLogin') IS NULL
	ALTER TABLE tblOfficer Add HasLogin BIT NULL

IF  COL_LENGTH('tblClaimAdmin','HasLogin') IS NULL
	ALTER TABLE tblClaimAdmin Add HasLogin BIT NULL

IF COL_LENGTH('tblUsers','IsAssociated') IS NULL
	ALTER TABLE tblUsers Add IsAssociated BIT NULL

-- OP-64: Creation of user profiles (RFC 92)
IF OBJECT_ID('tblRole') IS NULL
	BEGIN
		CREATE TABLE [dbo].[tblRole](
			[RoleID] [int] IDENTITY(1,1) NOT NULL,
			[RoleName] [nvarchar](50) NOT NULL,
			[AltLanguage] [nvarchar](50),
			[IsSystem] [int] NOT NULL,
			[IsBlocked] [bit] NOT NULL,
			[ValidityFrom] [datetime] NOT NULL,
			[ValidityTo] [datetime] NULL,
			[AuditUserID] [int] NULL,
			[LegacyID] [int] NULL
		 CONSTRAINT [PK_tblRole] PRIMARY KEY CLUSTERED
		(
			[RoleID] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
	END
GO

IF OBJECT_ID('tblRoleRight') IS NULL
	BEGIN
		CREATE TABLE [dbo].[tblRoleRight](
			[RoleRightID] [int] IDENTITY(1,1) NOT NULL,
			[RoleID] [int] NOT NULL,
			[RightID] [int] NOT NULL,
			[ValidityFrom] [datetime] NOT NULL,
			[ValidityTo] [datetime] NULL,
			[AuditUserId] [int] NULL,
			[LegacyID] [int] NULL,
		 CONSTRAINT [PK_tblRoleRight] PRIMARY KEY CLUSTERED
		(
			[RoleRightID] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
	END
GO
IF  Object_id('FK_tblRoleRight_tblRole') is null
	ALTER TABLE [dbo].[tblRoleRight]  WITH CHECK ADD  CONSTRAINT [FK_tblRoleRight_tblRole] FOREIGN KEY([RoleID])
	REFERENCES [dbo].[tblRole] ([RoleID])
GO


ALTER TABLE [dbo].[tblRoleRight] CHECK CONSTRAINT [FK_tblRoleRight_tblRole]
GO

IF OBJECT_ID('tblUserRole') IS NULL
	CREATE TABLE tblUserRole
	(	UserRoleID INT not null IDENTITY(1,1),
		UserID INT NOT NULL,
		RoleID int NOT null,
		ValidityFrom datetime NOT NULL,
		ValidityTo datetime NULL,
		AudituserID INT NULL,
		LegacyID INT NULL
		CONSTRAINT PK_tblUserRole PRIMARY KEY (UserRoleID),
		CONSTRAINT FK_tblUserRole_tblUsers FOREIGN KEY (UserID) REFERENCES tblUsers(UserID) ON DELETE CASCADE ON UPDATE CASCADE,
		CONSTRAINT FK_tblUserRole_tblRole FOREIGN KEY (RoleID) REFERENCES tblRole (RoleID) ON DELETE CASCADE ON UPDATE CASCADE
	)
	GO
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Enrolment Officer' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Enrolment Officer',1,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Manager' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Manager',2,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Accountant' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Accountant',4,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Clerk' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Clerk',8,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Medical Officer' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Medical Officer',16,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Scheme Administrator' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Scheme Administrator',32,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'IMIS Administrator' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('IMIS Administrator',64,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Receptionist' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Receptionist',128,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Claim Administrator' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Claim Administrator',256,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Claim Contributor' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Claim Contributor',512,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'HF Administrator' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('HF Administrator',524288,GETDATE(),0)
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Offline Administrator') IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Offline Administrator',1048576,GETDATE(),0)
GO

--EnrolementOfficer = 1
 --       CHFManager = 2
 --       CHFAccountant = 4
 --       CHFClerk = 8
 --       CHFMedicalOfficer = 16
 --       CHFAdministrator = 32
 --       IMISAdministrator = 64
 --       Receptionist = 128
 --       ClaimAdministrator = 256
 --       ClaimContributor = 512

 --       HFAdministrator = 524288
 --       OfflineCHFAdministrator = 1048576
 DECLARE @AuditUserID INT = 0
 DECLARE @LegacyRoleID INT
 DECLARE @UserID INT
 DECLARE @NewRoleID INT

 SELECT @AuditUserID = UserID FROM tblUsers WHERE loginName = 'Admin'

 DECLARE User_Cursor CURSOR FOR
 SELECT UserID,RoleID FROM tblUsers where validityto is null

OPEN User_Cursor
FETCH NEXT FROM User_Cursor INTO @UserID,@LegacyRoleID

WHILE @@FETCH_STATUS = 0
BEGIN
IF @LegacyRoleID & 1 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Enrolment Officer'
	IF @NewRoleID > 0
		BEGIN
			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL
				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)
		END
END
IF @LegacyRoleID & 2 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Manager'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)
		END
END
IF @LegacyRoleID & 4 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Accountant'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 8 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Clerk'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 16 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Medical Officer'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 32 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Scheme Administrator'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 64 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='IMIS Administrator'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 128 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Receptionist'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 256 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Claim Administrator'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 512 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Claim Contributor'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END

IF @LegacyRoleID & 524288 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='HF Administrator'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
IF @LegacyRoleID & 1048576 > 0
BEGIN
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Offline Administrator'
	IF @NewRoleID > 0
		BEGIN

			IF (SELECT userID FROM tblUserRole WHERE Userid = @UserID AND RoleID = @NewRoleID AND ValidityTo IS NULL) IS NULL

				INSERT INTO tblUserRole (USERID,RoleID,ValidityFrom,AudituserID)
				VALUES(@UserID,@NewRoleID,GETDATE(),@AuditUserID)

		END
END
FETCH NEXT FROM User_Cursor INTO @UserID,@LegacyRoleID
END
CLOSE User_Cursor
DEALLOCATE User_Cursor
GO

IF NOT OBJECT_ID('uspRefreshAdmin') IS NULL
DROP PROCEDURE uspRefreshAdmin
GO
CREATE PROCEDURE uspRefreshAdmin

AS
DECLARE @RoleName NVARCHAR(25) = 'AdminProfile',
		@LanguageId NVARCHAR(8) = 'en',
		@Phone NVARCHAR(8) = NULL,
		@RoleID INT = NULL,
		@IsSystem INT = -1,
		@IsBlocked INT = 0,
		@LastName NVARCHAR(50) = 'Admin',
		@OtherName NVARCHAR(50) ='Admin',
		@LoginName NVARCHAR(50) ='Admin',
		@HFID INT = 0, 
		@AuditUserID INT = -1,
		@password VARBINARY(256) = 123, 
		@EmailId NVARCHAR(200) = NULL,
		@PrivateKey NVARCHAR(256) = NULL,
		@StoredPassword NVARCHAR(256) = NULL,
		@LegacyID INT = NULL,
		@UserID INT = NULL

	--Assignment		

	SELECT @UserID = UserID FROM tblUsers WHERE LoginName = @LoginName AND ValidityTo IS NULL
	SELECT @RoleID = RoleID FROM tblRole WHERE RoleName = @RoleName AND ValidityTo IS NULL	

	/* tblUsers */
	IF @UserID IS NOT NULL  
		BEGIN
			SET	@UserID = (SELECT UserID FROM tblUsers WHERE LoginName = @LoginName AND ValidityTo IS NULL)		 
			INSERT INTO tblUsers (LanguageID, LastName, OtherNames, Phone, LoginName, RoleID, HFID, ValidityTo, LegacyID, AuditUserID, PrivateKey, StoredPassword)
			SELECT LanguageID, LastName, OtherNames, Phone, LoginName, RoleID, HFID, GETDATE(), UserID, AuditUserID, PrivateKey, StoredPassword
			
			
			 
			 FROM tblUsers 
				    WHERE LoginName = @LoginName AND ValidityTo IS NULL;
			UPDATE tblUsers SET ValidityFrom = GETDATE(), AuditUserID = @AuditUserID,  
			PrivateKey=
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2),
				StoredPassword=
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST(@LoginName AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2))),2)
			 WHERE LoginName = @LoginName			
		END
	ELSE
		BEGIN
			INSERT INTO tblUsers (LanguageID, LastName, OtherNames, Phone, LoginName, RoleID, HFID, ValidityFrom, LegacyID, AuditUserID, PrivateKey, StoredPassword) 
			VALUES(@LanguageId, @LastName, @OtherName, @Phone, @LoginName, @RoleID, @HFID, GETDATE(), @LegacyID, @AuditUserID, /*, @password, NULL, NULL, */
				--PrivateKey
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2),
				--StoredPassword
				CONVERT(varchar(max),HASHBYTES('SHA2_256',CONCAT(CAST(@LoginName AS VARCHAR(MAX)),CONVERT(varchar(max),HASHBYTES('SHA2_256',CAST(@LoginName AS VARCHAR(MAX))),2))),2))
			SELECT @UserID = SCOPE_IDENTITY()		
		END   
	
		/* tblUsersDistricts */

	UPDATE tblUsersDistricts SET ValidityTo = GETDATE() WHERE UserId = @UserID AND ValidityTo IS NULL	
			
	DECLARE @LocationID AS TABLE(LocD INT)
	INSERT INTO @LocationID SELECT DISTINCT LocationID FROM tblLocations  WHERE LocationType ='D' AND  ValidityTo IS NULL
	INSERT INTO tblUsersDistricts ([UserId],[LocationId],[AuditUserID])	SELECT @UserId, LocD, @AuditUserID FROM @LocationID  
		
	/* tblrole */
	IF @RoleID IS NULL		
		BEGIN
			INSERT INTO tblRole (RoleName,IsSystem,isBlocked,ValidityFrom,LegacyID,AuditUserID)
			VALUES (@RoleName, @IsSystem, @IsBlocked, GETDATE(), @LegacyID, @AuditUserID)
			SELECT @RoleID = SCOPE_IDENTITY()
		END

	/* tblUserRole */
	UPDATE tblUserRole SET ValidityTo = GETDATE() WHERE UserId = @UserID AND ValidityTo IS NULL			
	INSERT INTO tblUserRole (UserID, RoleID,ValidityFrom) 
	VALUES (@UserID, @RoleID, GETDATE())
	
 	--Table variable
	DECLARE @Rights as TABLE(RightID INT NULL)

	-- User rights

	INSERT INTO @Rights VALUES('121702')
	
	-- Full access to Location
	INSERT INTO @Rights VALUES('121901')
	INSERT INTO @Rights VALUES('121902')
	INSERT INTO @Rights VALUES('121903')
	INSERT INTO @Rights VALUES('121904')

	-- User Profile rights
	INSERT INTO @Rights VALUES('122000')
	INSERT INTO @Rights VALUES('122001')
	INSERT INTO @Rights VALUES('122002')
	INSERT INTO @Rights VALUES('122003')
	INSERT INTO @Rights VALUES('122004')
	INSERT INTO @Rights VALUES('122005')

	-- Tool/Registers/Location 
	INSERT INTO @Rights VALUES('131005')
	INSERT INTO @Rights VALUES('131006') 

	--Delete exists Rights
	DELETE FROM tblRoleRight WHERE RightID NOT IN 
	(SELECT RightID FROM @Rights ) AND RoleID = @RoleID AND ValidityTo IS NULL

	INSERT INTO tblRoleRight (RoleID, RightID, ValidityFrom) 
			SELECT @RoleID, RightID, GETDATE() 
			FROM @Rights 
			WHERE RightID 
			NOT IN(SELECT ISNULL(RightID,0) RightID FROM tblRoleRight WHERE RoleID = @RoleID)
GO

--'Enrolment Officer'
DECLARE @RoleID as INT
DECLARE @Rights AS TABLE(RightID INT) 
INSERT INTO @Rights VALUES(101001)--FamilySearch
INSERT INTO @Rights VALUES(101002)--FamilyAdd
INSERT INTO @Rights VALUES(101003)--FamilyEdit
INSERT INTO @Rights VALUES(101004)--FamilyDelete 
INSERT INTO @Rights VALUES(101101)--InsureeSearch
INSERT INTO @Rights VALUES(101102)--InsureeAdd
INSERT INTO @Rights VALUES(101103)--InsureeEdit
INSERT INTO @Rights VALUES(101104)--InsureeDelete
INSERT INTO @Rights VALUES(101105)--InsureeEnquire
INSERT INTO @Rights VALUES(101201)--PolicySearch 
INSERT INTO @Rights VALUES(101202)--PolicyAdd
INSERT INTO @Rights VALUES(101203)--PolicyEdit
INSERT INTO @Rights VALUES(101204)--PolicyDelete
INSERT INTO @Rights VALUES(101205)--PolicyRenew
INSERT INTO @Rights VALUES(101301)--ContributionSearch   
INSERT INTO @Rights VALUES(101302)--ContributionAdd
INSERT INTO @Rights VALUES(101303)--ContributionEdit
INSERT INTO @Rights VALUES(101304)--ContributionDelete
INSERT INTO @Rights VALUES(111001)--ClaimSearch  
INSERT INTO @Rights VALUES(111009)--ClaimFeedback 
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Enrolment Officer' AND ValidityTo IS NULL	
--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

--Setting value	

INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL 
GO
-- Scheme Administrator
							
--Declare variable
DECLARE @RoleID as INT		
DECLARE @Rights AS TABLE(RightID INT) 

INSERT INTO @Rights VALUES(101105)--InsureeEnquire 
INSERT INTO @Rights VALUES(121001)--ProductSearch  
INSERT INTO @Rights VALUES(121002)--ProductAdd     
INSERT INTO @Rights VALUES(121003)--ProductEdit    
INSERT INTO @Rights VALUES(121004)--ProductDelete  
INSERT INTO @Rights VALUES(121005)--ProductDuplicate  
INSERT INTO @Rights VALUES(121101)--HealthFacilitiesSearch  
INSERT INTO @Rights VALUES(121102)--HealthFacilitiesAdd   
INSERT INTO @Rights VALUES(121103)--HealthFacilitiesEdit    
INSERT INTO @Rights VALUES(121104)--HealthFacilitiesDelete   
INSERT INTO @Rights VALUES(121201)--PriceListMedicalServicesSearch   
INSERT INTO @Rights VALUES(121202)--PriceListMedicalServicesAdd      
INSERT INTO @Rights VALUES(121203)--PriceListMedicalServicesEdit     
INSERT INTO @Rights VALUES(121204)--PriceListMedicalServicesDelete   
INSERT INTO @Rights VALUES(121205)--PriceListMedicalServicesDuplicate   
INSERT INTO @Rights VALUES(121301)--PriceListMedicalItemsSearch   
INSERT INTO @Rights VALUES(121302)--PriceListMedicalItemsAdd      
INSERT INTO @Rights VALUES(121303)--PriceListMedicalItemsEdit     
INSERT INTO @Rights VALUES(121304)--PriceListMedicalItemsDelete   
INSERT INTO @Rights VALUES(121305)--PriceListMedicalItemsDuplicate   
INSERT INTO @Rights VALUES(121401)--MedicalServicesSearch  
INSERT INTO @Rights VALUES(121402)--MedicalServicesAdd     
INSERT INTO @Rights VALUES(121403)--MedicalServicesEdit    
INSERT INTO @Rights VALUES(121404)--MedicalServicesDelete   
INSERT INTO @Rights VALUES(122101)--MedicalItemsSearch   
INSERT INTO @Rights VALUES(122102)--MedicalItemsAdd     
INSERT INTO @Rights VALUES(122103)--MedicalItemsEdit     
INSERT INTO @Rights VALUES(122104)--MedicalItemsDelete   
INSERT INTO @Rights VALUES(121501)--OfficerSearch        
INSERT INTO @Rights VALUES(121502)--OfficerAdd           
INSERT INTO @Rights VALUES(121503)--OfficerEdit          
INSERT INTO @Rights VALUES(121504)--OfficerDelete   
INSERT INTO @Rights VALUES(121601)--ClaimAdministratorSearch    
INSERT INTO @Rights VALUES(121602)--ClaimAdministratorAdd       
INSERT INTO @Rights VALUES(121603)--ClaimAdministratorEdit      
INSERT INTO @Rights VALUES(121604)--ClaimAdministratorDelete   
INSERT INTO @Rights VALUES(121801)--PayersSearch      
INSERT INTO @Rights VALUES(121802)--PayersAdd         
INSERT INTO @Rights VALUES(121803)--PayersEdit        
INSERT INTO @Rights VALUES(121804)--PayersDelete 
 
 -- Scheme administrator loses all rights to the register of locations  
 
INSERT INTO @Rights VALUES(131001)--DiagnosesUpload          
INSERT INTO @Rights VALUES(131002)--DiagnosesDownload        
INSERT INTO @Rights VALUES(131003)--HealthFacilitiesUpload   
INSERT INTO @Rights VALUES(131004)--HealthFacilitiesDownload

 -- Scheme administrator loses all rights to the register of locations upload and download

INSERT INTO @Rights VALUES(131101)--ExtractsMasterDataDownload      
INSERT INTO @Rights VALUES(131102)--ExtractsPhoneExtractsCreate     
INSERT INTO @Rights VALUES(131103)--ExtractsOfflineExtractCreate    
INSERT INTO @Rights VALUES(131104)--ExtractsClaimsUpload            
INSERT INTO @Rights VALUES(131105)--ExtractsEnrolmentsUpload        
INSERT INTO @Rights VALUES(131106)--ExtractsFeedbackUpload  
INSERT INTO @Rights VALUES(131209)--ReportsStatusOfRegister  

 --Setting value
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Scheme Administrator'	 AND ValidityTo IS NULL	 
--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL

GO
--IMIS Administrator
							
--Declare variable
DECLARE @RoleID as INT
	
DECLARE @Rights AS TABLE(RightID INT) 
INSERT INTO @Rights VALUES(101105)--InsureeEnquire
INSERT INTO @Rights VALUES(121701)--UsersSearch
INSERT INTO @Rights VALUES(121702)--UsersAdd
INSERT INTO @Rights VALUES(121703)--UsersEdit
INSERT INTO @Rights VALUES(121704)--UsersDelete 

-- 22-03-2019 IMIS Administrator gets rights to the register of locations  
INSERT INTO @Rights VALUES(121901)--LocationsSearch   
INSERT INTO @Rights VALUES(121902)--LocationsAdd      
INSERT INTO @Rights VALUES(121903)--LocationsEdit     
INSERT INTO @Rights VALUES(121904)--LocationsDelete  
INSERT INTO @Rights VALUES(121905)--LocationsMove  
 
 -- (IMIS Administrator loses all rights to the register of user profile previous has rights

-- 22-03-2019 IMIS Administrator gets rights to the register of locations  upload / download
INSERT INTO @Rights VALUES(131005)--LocationsUpload          
INSERT INTO @Rights VALUES(131006)--LocationsDownload   


INSERT INTO @Rights VALUES(131207)--ReportsUserActivity
INSERT INTO @Rights VALUES(131301)--Backup
INSERT INTO @Rights VALUES(131302)--Restore
INSERT INTO @Rights VALUES(131303)--ExecuteScript
INSERT INTO @Rights VALUES(131304)--EmailSetting

-- User Profile rights
INSERT INTO @Rights VALUES('122000') -- userProfiles
INSERT INTO @Rights VALUES('122001') -- FindUserProfile
INSERT INTO @Rights VALUES('122002') -- AddUserProfile
INSERT INTO @Rights VALUES('122003') -- DeleteUserProfile
INSERT INTO @Rights VALUES('122004') -- EditUserProfile
INSERT INTO @Rights VALUES('122005') -- DuplicateUserProfile

--Setting value
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='IMIS Administrator' AND ValidityTo IS NULL	
--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)
 
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL 

GO
							
-- Accountant--
DECLARE @Rights AS TABLE(RightID INT)
INSERT INTO @Rights VALUES(101001)--FamilySearch
INSERT INTO @Rights VALUES(101101)--InsureeSearch
INSERT INTO @Rights VALUES(101105)--InsureeEnquire
INSERT INTO @Rights VALUES(101201)--PolicySearch
INSERT INTO @Rights VALUES(101301)--ContributionSearch
INSERT INTO @Rights VALUES(101401)--PaymentSearch
INSERT INTO @Rights VALUES(101402)--PaymentAdd
INSERT INTO @Rights VALUES(101403)--PaymentEdit
INSERT INTO @Rights VALUES(101404)--PaymentDelete
INSERT INTO @Rights VALUES(111101)--BatchProcess
INSERT INTO @Rights VALUES(111102)--BatchFilter
INSERT INTO @Rights VALUES(111103)--BatchPreview
INSERT INTO @Rights VALUES(131204)--ReportsContributionCollection
INSERT INTO @Rights VALUES(131205)--ReportsProductSales
INSERT INTO @Rights VALUES(131206)--ReportsContributionDistribution
INSERT INTO @Rights VALUES(131210)--ReportsInsureeWithoutPhotos
INSERT INTO @Rights VALUES(131211)--ReportsPaymentCategoryOverview
INSERT INTO @Rights VALUES(131212)--ReportsMatchingFunds
INSERT INTO @Rights VALUES(131213)--ReportsClaimOverviewReport 
INSERT INTO @Rights VALUES(131214)--ReportsPercentageReferrals
INSERT INTO @Rights VALUES(131215)--ReportsFamiliesInsureesOverview
INSERT INTO @Rights VALUES(131216)--ReportsPendingInsurees
INSERT INTO @Rights VALUES(131217)--ReportsRenewals
INSERT INTO @Rights VALUES(131218)--ReportsCapitationPayment
INSERT INTO @Rights VALUES(131219)--ReportRejectedPhoto
INSERT INTO @Rights VALUES(131220)--ReportsContributionPayment
INSERT INTO @Rights VALUES(131221)--ReportsControlNumberAssignment
INSERT INTO @Rights VALUES(131222)--ReportsOverviewOfCommissions
INSERT INTO @Rights VALUES(131401)--AddFund

DECLARE @RoleID INT
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Accountant'
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,R.RightID,GETDATE() FROM @Rights R 
LEFT JOIN tblRoleRight RR ON RR.RoleID =@RoleID AND RR.RightID = R.RightID AND RR.ValidityTo IS NULL 
WHERE RR.RoleRightID IS NULL
						--END Accountant--

--END Accountant--
GO
--Claim Administrator

DECLARE @RoleID as INT	
DECLARE @Rights AS TABLE(RightID INT)  

INSERT INTO @Rights VALUES(111001)--ClaimSearch
INSERT INTO @Rights VALUES(111002)--ClaimAdd
INSERT INTO @Rights VALUES(111004)--ClaimDelete
INSERT INTO @Rights VALUES(111005)--ClaimLoad
INSERT INTO @Rights VALUES(111006)--ClaimPrint  
INSERT INTO @Rights VALUES(111007)--ClaimSubmit
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Claim Administrator'	
--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

 --Setting value

INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL
GO
--Clerk
DECLARE @RoleID as INT	
DECLARE @Rights AS TABLE(RightID INT) 
INSERT INTO @Rights VALUES(101001)--FamilySearch
INSERT INTO @Rights VALUES(101002)--FamilyAdd
INSERT INTO @Rights VALUES(101003)--FamilyEdit
INSERT INTO @Rights VALUES(101004)--FamilyDelete 
INSERT INTO @Rights VALUES(101101)--InsureeSearch
INSERT INTO @Rights VALUES(101102)--InsureeAdd
INSERT INTO @Rights VALUES(101103)--InsureeEdit
INSERT INTO @Rights VALUES(101104)--InsureeDelete
INSERT INTO @Rights VALUES(101105)--InsureeEnquire 
INSERT INTO @Rights VALUES(101201)--PolicySearch
INSERT INTO @Rights VALUES(101202)--PolicyAdd
INSERT INTO @Rights VALUES(101203)--PolicyEdit
INSERT INTO @Rights VALUES(101204)--PolicyDelete
INSERT INTO @Rights VALUES(101205)--PolicyRenew 
INSERT INTO @Rights VALUES(101301)--ContributionSearch
INSERT INTO @Rights VALUES(101302)--ContributionAdd
INSERT INTO @Rights VALUES(101303)--ContributionEdit
INSERT INTO @Rights VALUES(101304)--ContributionDelete 
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Clerk'	
--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

 --Setting value

INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL
GO
--Manager							

DECLARE @RoleID as INT
DECLARE @Rights AS TABLE(RightID INT)  
INSERT INTO @Rights VALUES(131201)--ReportsPrimaryOperationalIndicators-policies
INSERT INTO @Rights VALUES(131202)--ReportsPrimaryOperationalIndicatorsClaims
INSERT INTO @Rights VALUES(131203)--ReportsDerivedOperationalIndicators
INSERT INTO @Rights VALUES(131208)--ReportsEnrolmentPerformanceIndicators
INSERT INTO @Rights VALUES(101105)--InsureeEnquire
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Manager'	
	--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

 --Setting value
	
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL

GO
--Medical Officer--
DECLARE @RoleID as INT
DECLARE @Rights AS TABLE(RightID INT)
INSERT INTO @Rights VALUES(111001)--ClaimSearch
INSERT INTO @Rights VALUES(111008)--ClaimReview
INSERT INTO @Rights VALUES(111009)--ClaimFeedback
INSERT INTO @Rights VALUES(111010)--ClaimUpdate
INSERT INTO @Rights VALUES(111011)--ClaimProcess
INSERT INTO @Rights VALUES(131223)--ReportsClaimHistoryReport

SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Medical Officer'
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)


	
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL
--END Medical Officer
GO
							
--Declare variable
--Receptionist
DECLARE @RoleID as INT		
DECLARE @Rights AS TABLE(RightID INT)  
INSERT INTO @Rights VALUES(101001)--FamilySearch  
INSERT INTO @Rights VALUES(101101)--InsureeSearch 
INSERT INTO @Rights VALUES(101105)--InsureeEnquire 
INSERT INTO @Rights VALUES(101201)--PolicySearch
SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Receptionist'
--Uncheck
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

 --Setting value

INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL
GO
					--START Claim Contributor--
					DECLARE @RoleID as INT		
DECLARE @Rights AS TABLE(RightID INT)  
INSERT INTO @Rights VALUES(111001)--FindClaim  
INSERT INTO @Rights VALUES(111002)--EnterClaim 
INSERT INTO @Rights VALUES(111005)--LoadClaim 

SELECT @RoleID = RoleID from tblRole WHERE Rolename ='Claim Contributor'
DELETE FROM tblRoleRight WHERE RoleID = @RoleID AND RightID NOT IN (SELECT RightID FROM @Rights)

 --Setting value

INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom) 
SELECT @RoleID,Ro.RightID,GETDATE() FROM @Rights Ro 
		LEFT OUTER JOIN tblRoleRight Rr ON Rr.RoleID =@RoleID 
		AND Rr.RightID = Ro.RightID 
		AND Rr.ValidityTo IS NULL 
		WHERE Rr.RoleRightID IS NULL
GO

--START Offline Administrator--
DECLARE @ID as INT
SELECT @ID = RoleID from tblRole WHERE Rolename ='Offline Administrator'
--User
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121701 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121701,GETDATE()) --FindUser
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121702 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121702,GETDATE()) --AddUser
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121703 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121703,GETDATE()) --EditUser

--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121704 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121704,GETDATE()) --DeleteUser

--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131101 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131101,GETDATE()) --Extract 

--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131103 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131103,GETDATE()) --OfflineExtractCreate

--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131301 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131301,GETDATE()) --Backup

--Restore
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131302 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131302,GETDATE()) --Restore
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131303 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131303,GETDATE()) --ExecuteScript
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131304 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131304,GETDATE()) --EmailSettings
GO
--END Offline Administrator--

--START HF Administrator--
DECLARE @ID as INT
SELECT @ID = RoleID from tblRole WHERE Rolename ='HF Administrator'
--User
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121701 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121701,GETDATE()) --FindUser
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121702 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121702,GETDATE()) --AddUser
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121703 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121703,GETDATE()) --EditUser
--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 121704 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,121704,GETDATE()) --DeleteUser

IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131101 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131101,GETDATE()) --Extract 

--
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131103 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131103,GETDATE()) --OfflineExtractCreate
 
--Backup
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131301 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131301,GETDATE()) --Backup 

--Restore
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131302 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131302,GETDATE()) --Restore

--Execute Script
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131303 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131303,GETDATE()) --ExecuteScript

--Email Settings
IF (SELECT 1 FROM tblRoleRight WHERE RightID = 131304 AND ROLEID = @ID) IS NULL
INSERT INTO tblRoleRight (RoleID,RightID,ValidityFrom)
VALUES (@ID,131304,GETDATE()) --EmailSettings
GO
--END HF Administrator--

-- fixes the table name misspell
IF (EXISTS (SELECT *
		FROM INFORMATION_SCHEMA.TABLES
		WHERE  TABLE_NAME = 'tblIMISDetaulsPhone'))
BEGIN
    EXEC sp_rename 'tblIMISDetaulsPhone', 'tblIMISDefaultsPhone'
END