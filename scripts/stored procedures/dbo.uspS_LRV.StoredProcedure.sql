USE [IMIS]
GO
/****** Object:  StoredProcedure [dbo].[uspS_LRV]    Script Date: 7/24/2018 6:47:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspS_LRV]

	(
		
		@LRV bigint OUTPUT
	)

AS
		
	set @LRV = @@DBTS 
	RETURN 




GO
