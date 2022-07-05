IF OBJECT_ID('[dbo].[uspAPIDeleteMemberFamily]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[uspAPIDeleteMemberFamily]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[uspAPIDeleteMemberFamily]
(
	@AuditUserID INT = -3,
	@InsuranceNumber NVARCHAR(50)
)

AS
BEGIN
	/*
	RESPONSE CODE
		1-Wrong format or missing insurance number  of member
		2-Insurance number of member not found
		3- Member is head of family
		0 - Success (0 OK), 
		-1 -Unknown  Error 
	*/


	/**********************************************************************************************************************
			VALIDATION STARTS
	*********************************************************************************************************************/
	--1-Wrong format or missing insurance number of head
	IF LEN(ISNULL(@InsuranceNumber,'')) = 0
		RETURN 1

	--2-Insurance number of member not found
	IF NOT EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL)
		RETURN 2

	--3- Member is head of family
	IF  EXISTS(SELECT 1 FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL AND IsHead = 1)
		RETURN 3

	/**********************************************************************************************************************
			VALIDATION ENDS
	*********************************************************************************************************************/

	BEGIN TRY
			BEGIN TRANSACTION DELETEMEMBERFAMILY
			
				DECLARE @InsureeId INT


				SELECT @InsureeID = InsureeID FROM tblInsuree WHERE CHFID = @InsuranceNumber AND ValidityTo IS NULL
				
				INSERT INTO tblInsuree ([FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,[ValidityTo],legacyId,TypeOfId, HFID, CurrentAddress, CurrentVillage,GeoLocation ) 
				SELECT	[FamilyID],[CHFID],[LastName],[OtherNames],[DOB],[Gender],[Marital],[IsHead],[passport],[Phone],[PhotoID],[PhotoDate],[CardIssued],isOffline,[AuditUserID],[ValidityFrom] ,getdate(),@insureeId ,TypeOfId, HFID, CurrentAddress, CurrentVillage, GeoLocation 
				FROM tblInsuree WHERE InsureeID = @InsureeID AND ValidityTo IS NULL
				UPDATE [tblInsuree] SET [ValidityFrom] = GetDate(),[ValidityTo] = GetDate(),[AuditUserID] = @AuditUserID 
				WHERE InsureeId = @InsureeID AND ValidityTo IS NULL

       

			COMMIT TRANSACTION DELETEMEMBERFAMILY
			RETURN 0
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION DELETEMEMBERFAMILY
			SELECT ERROR_MESSAGE()
			RETURN -1
		END CATCH
END
GO
