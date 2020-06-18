--- MIGRATION Script from v1.4.2 - tbd

-- OTC-111: Changing the logic of user Roles

IF COL_LENGTH('tblUserRole', 'Assign') IS NULL
BEGIN
	ALTER TABLE tblUserRole ADD Assign int NULL DEFAULT(3)
END

IF TYPE_ID(N'xtblUserRole') IS NULL
BEGIN
	CREATE TYPE [dbo].[xtblUserRole] AS TABLE(
		[UserRoleID] [int] NOT NULL,
		[UserID] [int] NOT NULL,
		[RoleID] [int] NOT NULL,
		[ValidityFrom] [datetime] NULL,
		[ValidityTo] [datetime] NULL,
		[AudituserID] [int] NULL,
		[LegacyID] [int] NULL,
		[Assign] [int] NULL
)
END 