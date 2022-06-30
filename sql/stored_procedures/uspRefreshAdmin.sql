IF OBJECT_ID('[dbo].[uspRefreshAdmin]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspRefreshAdmin]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRefreshAdmin]
AS
DECLARE @RoleName NVARCHAR(25) = 'AdminProfile',
		@LanguageId NVARCHAR(8) = 'en',
		@Phone NVARCHAR(50) = NULL,
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