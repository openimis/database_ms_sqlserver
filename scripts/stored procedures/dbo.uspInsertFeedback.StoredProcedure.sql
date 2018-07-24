USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspInsertFeedback]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[uspInsertFeedback]
(
	@FileName VARCHAR(100)
)
/*
	-1: Fatal Error
	0: All OK
	1: Invalid Officer code
	2: Claim does not exist
	3: Invalid CHFID
	
*/
AS
BEGIN
	
	BEGIN TRY
		DECLARE @FilePath NVARCHAR(250)
		DECLARE @XML XML
		DECLARE @Query NVARCHAR(3000)
		
		DECLARE @OfficerCode NVARCHAR(8)
		DECLARE @OfficerID INT
		DECLARE @ClaimID INT
		DECLARE @CHFID VARCHAR(12)
		DECLARE @Answers VARCHAR(5)
		DECLARE @FeedbackDate DATE
		
		--SELECT @FilePath = 'C:/inetpub/wwwroot' + FTPFeedbackFolder + '/' + @FileName FROM tblIMISDefaults
				
		SET @Query = (N'SELECT  @XML = (SELECT CAST(X AS XML) FROM OPENROWSET(BULK ''' + @FileName +''',SINGLE_BLOB) AS T(X))')
		
		EXECUTE sp_executesql  @Query,N'@XML XML OUTPUT',@XML OUTPUT
		
		SELECT
		@OfficerCode = feedback.value('(Officer)[1]','NVARCHAR(8)'),
		@ClaimID = feedback.value('(ClaimID)[1]','NVARCHAR(8)'),
		@CHFID  = feedback.value('(CHFID)[1]','VARCHAR(12)'),
		@Answers = feedback.value('(Answers)[1]','VARCHAR(5)'),
		@FeedbackDate = CONVERT(DATE,feedback.value('(Date)[1]','VARCHAR(10)'),103)
		FROM @XML.nodes('feedback') AS T(feedback)


		IF NOT EXISTS(SELECT * FROM tblOfficer WHERE Code = @OfficerCode AND ValidityTo IS NULL)
			RETURN 1
		ELSE
			SELECT @OfficerID = OfficerID FROM tblOfficer WHERE Code = @OfficerCode AND ValidityTo IS NULL

		IF NOT EXISTS(SELECT * FROM tblClaim WHERE ClaimID = @ClaimID)
			RETURN 2
		
		IF NOT EXISTS(SELECT C.ClaimID FROM tblClaim C INNER JOIN tblInsuree I ON C.InsureeID = I.InsureeID WHERE C.ClaimID = @ClaimID AND I.CHFID = @CHFID)
			RETURN 3
		
		DECLARE @CareRendered BIT = SUBSTRING(@Answers,1,1)
		DECLARE @PaymentAsked BIT = SUBSTRING(@Answers,2,1) 
		DECLARE @DrugPrescribed BIT  = SUBSTRING(@Answers,3,1)
		DECLARE @DrugReceived BIT = SUBSTRING(@Answers,4,1)
		DECLARE @Asessment TINYINT = SUBSTRING(@Answers,5,1)
		
		INSERT INTO tblFeedback(ClaimID,CareRendered,PaymentAsked,DrugPrescribed,DrugReceived,Asessment,CHFOfficerCode,FeedbackDate,ValidityFrom,AuditUserID)
						VALUES(@ClaimID,@CareRendered,@PaymentAsked,@DrugPrescribed,@DrugReceived,@Asessment,@OfficerID,@FeedbackDate,GETDATE(),-1);
		
		UPDATE tblClaim SET FeedbackStatus = 8 WHERE ClaimID = @ClaimID;
		
	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN -1
	END CATCH
	
	RETURN 0
END
GO
