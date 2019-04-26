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
GO
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
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Enrolement Officer' AND ValidityTo IS NULL) IS NULL
	INSERT INTO tblRole
	(RoleName,IsSystem,ValidityFrom,IsBlocked)
	VALUES('Enrolement Officer',1,GETDATE(),0)
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
IF (SELECT 1 FROM tblRole WHERE RoleName = 'Administrator' AND ValidityTo IS NULL) IS NULL
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
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Enrolement Officer'
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
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Administrator'
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
	SELECT @NewRoleID = RoleID from tblRole WHERE Rolename ='Claim Contributer'
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