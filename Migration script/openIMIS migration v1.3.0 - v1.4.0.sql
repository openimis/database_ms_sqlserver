--- MIGRATION Script from v1.3.0 to v1.4.0

-- OS-13: Preparing the migration script for an existing database

IF COL_LENGTH('tblUsers', 'UserUUID') IS NULL
BEGIN
	ALTER TABLE tblUsers ADD UserUUID uniqueidentifier NOT NULL DEFAULT NEWID() 
END

IF COL_LENGTH('tblLocations', 'LocationUUID') IS NULL
BEGIN
	ALTER TABLE tblLocations ADD LocationUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblHF', 'HfUUID') IS NULL
BEGIN
	ALTER TABLE tblHF ADD HfUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblClaim', 'ClaimUUID') IS NULL
BEGIN
	ALTER TABLE tblClaim ADD ClaimUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblProduct', 'ProdUUID') IS NULL
BEGIN
	ALTER TABLE tblProduct ADD ProdUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblFamilies', 'FamilyUUID') IS NULL
BEGIN
	ALTER TABLE tblFamilies ADD FamilyUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblServices', 'ServiceUUID') IS NULL
BEGIN
	ALTER TABLE tblServices ADD ServiceUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblInsuree', 'InsureeUUID') IS NULL
BEGIN
	ALTER TABLE tblInsuree ADD InsureeUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPolicy', 'PolicyUUID') IS NULL
BEGIN
	ALTER TABLE tblPolicy ADD PolicyUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblItems', 'ItemUUID') IS NULL
BEGIN
	ALTER TABLE tblItems ADD ItemUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblFeedback', 'FeedbackUUID') IS NULL
BEGIN
	ALTER TABLE tblFeedback ADD FeedbackUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblOfficer', 'OfficerUUID') IS NULL
BEGIN
	ALTER TABLE tblOfficer ADD OfficerUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPayer', 'PayerUUID') IS NULL
BEGIN
	ALTER TABLE tblPayer ADD PayerUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPremium', 'PremiumUUID') IS NULL
BEGIN
	ALTER TABLE tblPremium ADD PremiumUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblClaimAdmin', 'ClaimAdminUUID') IS NULL
BEGIN
	ALTER TABLE tblClaimAdmin ADD ClaimAdminUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblExtracts', 'ExtractUUID') IS NULL
BEGIN
	ALTER TABLE tblExtracts ADD ExtractUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPhotos', 'PhotoUUID') IS NULL
BEGIN
	ALTER TABLE tblPhotos ADD PhotoUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPLItems', 'PLItemUUID') IS NULL
BEGIN
	ALTER TABLE tblPLItems ADD PLItemUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPLServices', 'PLServiceUUID') IS NULL
BEGIN
	ALTER TABLE tblPLServices ADD PLServiceUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblPolicyRenewals', 'RenewalUUID') IS NULL
BEGIN
	ALTER TABLE tblPolicyRenewals ADD RenewalUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END

IF COL_LENGTH('tblRole', 'RoleUUID') IS NULL
BEGIN
	ALTER TABLE tblRole ADD RoleUUID uniqueidentifier NOT NULL DEFAULT NEWID()
END
