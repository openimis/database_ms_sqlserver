USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspPolicyStatusUpdate]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspPolicyStatusUpdate]
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PolicyID as int 
	
	UPDATE tblPolicy SET PolicyStatus = 8 WHERE ValidityTo IS NULL AND ExpiryDate < CAST (GETDATE() as DATE)
    
END
GO
