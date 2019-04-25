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