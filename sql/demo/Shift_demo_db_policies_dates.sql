BEGIN
	

	DECLARE @monthShift INT

	--Get number of months to shift the policy by, using FamilyID 38 which is a renewal example described on the Wiki
	SELECT TOP(1) @monthShift = DATEDIFF(MONTH, expirydate, GETDATE()) FROM [tblPolicy] where PolicyID=38

	--Shift Enrolldate by @monthShift
	UPDATE [tblPolicy] SET EnrollDate = DATEADD(month, @monthShift, EnrollDate)

	--Shift StartDate by @monthShift
	UPDATE [tblPolicy] SET StartDate = DATEADD(month, @monthShift, StartDate)

	--Shift EffectiveDate by @monthShift
	UPDATE [tblPolicy] SET EffectiveDate = DATEADD(month, @monthShift, EffectiveDate)
	WHERE EffectiveDate is not NULL

	--Shift ExpiryDate by @monthShift
	UPDATE [tblPolicy] SET ExpiryDate = DATEADD(month, @monthShift, ExpiryDate)
	
	--Update policy status 
	UPDATE [tblPolicy] SET PolicyStatus = IIF(ExpiryDate<GETDATE(), 8, 2)
	
	--Update InsureePolicy dates
	UPDATE     IP 
	SET        IP.[EnrollmentDate] = P.[EnrollDate],
			   IP.[StartDate] = P.[StartDate],
			   IP.[EffectiveDate] = P.[EffectiveDate],
			   IP.[ExpiryDate] = P.[ExpiryDate]
	FROM       [tblInsureePolicy] IP
	INNER JOIN [tblPolicy] P
	ON         IP.PolicyID = P.PolicyID


	--Shift PayDate to EnrollDate
	UPDATE     premium
	SET        PayDate = EnrollDate
	FROM       [tblPremium] premium
	INNER JOIN [tblPolicy] policy
	ON         premium.PolicyID = policy.PolicyID

	UPDATE     [tblClaim] 
	SET        DateFrom = DATEADD(month, @monthShift, DateFrom),
			   DateTo = DATEADD(month, @monthShift, DateTo),	
			   DateClaimed = DATEADD(month, @monthShift, DateClaimed)
			   
	--Add Enquire right to Claim Administrator role
	--insert into [tblRoleRight] (RoleID, RightID, ValidityFrom) values (9, 101105, CURRENT_TIMESTAMP)

END
