USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[UspS_ReseedTable]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UspS_ReseedTable]
	(
		@Table nvarchar(64) = '' 	)

AS
	SET NOCOUNT ON
	declare @ReseedYes as Integer
	
	IF LEN(LTRIM(RTRIM(@Table))) > 0 
	BEGIN
		set @ReseedYes = OBJECTPROPERTY ( object_id (@Table) ,'TableHasIdentity')  
		IF @ReseedYes  = 1  
			DBCC CHECKIDENT(@Table,RESEED,0)
	END
	ELSE
	BEGIN
		EXEC sp_MSforeachtable '(IF OBJECTPROPERTY(OBJECT_ID(''?''),''TableHasIdentity'') = 1 DBCC CHECKIDENT (''?'',RESEED,1))'
	END
RETURN 

GO
