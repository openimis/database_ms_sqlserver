

ALTER TABLE [dbo].[tblBatchRun] ADD  CONSTRAINT [DF_tblBatchRun_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblClaim] ADD  DEFAULT (newid()) FOR [ClaimUUID]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_ClaimStatus]  DEFAULT ((2)) FOR [ClaimStatus]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_DateClaimed]  DEFAULT (getdate()) FOR [DateClaimed]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_Feedback]  DEFAULT ((0)) FOR [Feedback]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_FeedbackID]  DEFAULT ((0)) FOR [FeedbackID]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_FeedbackStatus]  DEFAULT ((1)) FOR [FeedbackStatus]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_ReviewStatus]  DEFAULT ((1)) FOR [ReviewStatus]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_ApprovalStatus]  DEFAULT ((1)) FOR [ApprovalStatus]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_RejectionReason]  DEFAULT ((0)) FOR [RejectionReason]
GO
ALTER TABLE [dbo].[tblClaim] ADD  CONSTRAINT [DF_tblClaim_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblClaimAdmin] ADD  DEFAULT (newid()) FOR [ClaimAdminUUID]
GO
ALTER TABLE [dbo].[tblClaimDedRem] ADD  CONSTRAINT [DF_tblClaimDedRem_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblClaimItems] ADD  CONSTRAINT [DF_tblClaimItems_ClaimItemStatus]  DEFAULT ((1)) FOR [ClaimItemStatus]
GO
ALTER TABLE [dbo].[tblClaimItems] ADD  CONSTRAINT [DF_tblClaimItems_Availability]  DEFAULT ((1)) FOR [Availability]
GO
ALTER TABLE [dbo].[tblClaimItems] ADD  CONSTRAINT [DF_tblClaimItems_RejectionReason]  DEFAULT ((0)) FOR [RejectionReason]
GO
ALTER TABLE [dbo].[tblClaimItems] ADD  CONSTRAINT [DF_tblClaimItems_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblClaimServices] ADD  CONSTRAINT [DF_tblClaimServices_ClaimServiceStatus]  DEFAULT ((1)) FOR [ClaimServiceStatus]
GO
ALTER TABLE [dbo].[tblClaimServices] ADD  CONSTRAINT [DF_tblClaimServices_RejectionReason]  DEFAULT ((0)) FOR [RejectionReason]
GO
ALTER TABLE [dbo].[tblClaimServices] ADD  CONSTRAINT [DF_tblClaimServices_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblExtracts] ADD  DEFAULT (newid()) FOR [ExtractUUID]
GO
ALTER TABLE [dbo].[tblExtracts] ADD  CONSTRAINT [DF_tblExtracts_ExtractDirection]  DEFAULT ((0)) FOR [ExtractDirection]
GO
ALTER TABLE [dbo].[tblExtracts] ADD  CONSTRAINT [DF_tblExtracts_ExtractType]  DEFAULT ((0)) FOR [ExtractType]
GO
ALTER TABLE [dbo].[tblExtracts] ADD  CONSTRAINT [DF_tblExtracts_ExtractDate]  DEFAULT (getdate()) FOR [ExtractDate]
GO
ALTER TABLE [dbo].[tblExtracts] ADD  CONSTRAINT [DF_tblExtracts_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblFamilies] ADD  DEFAULT (newid()) FOR [FamilyUUID]
GO
ALTER TABLE [dbo].[tblFamilies] ADD  CONSTRAINT [DF_tblFamilies_InsureeID]  DEFAULT ((0)) FOR [InsureeID]
GO
ALTER TABLE [dbo].[tblFamilies] ADD  CONSTRAINT [DF_tblFamilies_Poverty]  DEFAULT ((0)) FOR [Poverty]
GO
ALTER TABLE [dbo].[tblFamilies] ADD  CONSTRAINT [DF_tblFamilies_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblFamilies] ADD  CONSTRAINT [DF__tblFamili__isOff__0D6FE0E5]  DEFAULT ((0)) FOR [isOffline]
GO
ALTER TABLE [dbo].[tblFamilySMS] ADD  CONSTRAINT [DF_tblFamilies_ApprovalOfSMS]  DEFAULT ((0)) FOR [ApprovalOfSMS]
GO
ALTER TABLE [dbo].[tblFamilySMS] ADD  CONSTRAINT [DF_tblFamilies_LanguageOfSMS]  DEFAULT([dbo].[udfDefaultLanguageCode]()) FOR [LanguageOfSMS]
GO
ALTER TABLE [dbo].[tblFeedback] ADD  DEFAULT (newid()) FOR [FeedbackUUID]
GO
ALTER TABLE [dbo].[tblFeedback] ADD  CONSTRAINT [DF_tblFeedback_CareRendered]  DEFAULT ((0)) FOR [CareRendered]
GO
ALTER TABLE [dbo].[tblFeedback] ADD  CONSTRAINT [DF_tblFeedback_PaymentAsked]  DEFAULT ((0)) FOR [PaymentAsked]
GO
ALTER TABLE [dbo].[tblFeedback] ADD  CONSTRAINT [DF_tblFeedback_DrugPrescribed]  DEFAULT ((0)) FOR [DrugPrescribed]
GO
ALTER TABLE [dbo].[tblFeedback] ADD  CONSTRAINT [DF_tblFeedback_DrugReceived]  DEFAULT ((0)) FOR [DrugReceived]
GO
ALTER TABLE [dbo].[tblFeedback] ADD  CONSTRAINT [DF_tblFeedback_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblFeedbackPrompt] ADD  CONSTRAINT [DF_tblFeedbackPrompt_SMSStatus]  DEFAULT ((0)) FOR [SMSStatus]
GO
ALTER TABLE [dbo].[tblFromPhone] ADD  CONSTRAINT [DF_tblFromPhone_LandedDate]  DEFAULT (getdate()) FOR [LandedDate]
GO
ALTER TABLE [dbo].[tblHealthStatus] ADD  CONSTRAINT [DF_tblHealthStatus_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblHF] ADD  DEFAULT (newid()) FOR [HfUUID]
GO
ALTER TABLE [dbo].[tblHF] ADD  CONSTRAINT [DF_tblHF_OffLine]  DEFAULT ((0)) FOR [OffLine]
GO
ALTER TABLE [dbo].[tblHF] ADD  CONSTRAINT [DF_tblHF_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblHFCatchment] ADD  CONSTRAINT [DF_tblHFCatchment_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblICDCodes] ADD  CONSTRAINT [DF_tblICDCodes_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_PolicyRenewalInterval]  DEFAULT ((14)) FOR [PolicyRenewalInterval]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_FTPPort]  DEFAULT ((21)) FOR [FTPPort]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_AppVersionEnquire]  DEFAULT ((1.0)) FOR [AppVersionEnquire]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_AppVersionEnroll]  DEFAULT ((1.0)) FOR [AppVersionEnroll]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_AppVersionRenewal]  DEFAULT ((1.0)) FOR [AppVersionRenewal]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_AppVersionFeedback]  DEFAULT ((1.0)) FOR [AppVersionFeedback]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_AppVersionClaim]  DEFAULT ((1.0)) FOR [AppVersionClaim]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  CONSTRAINT [DF_tblIMISDefaults_OffLineHF]  DEFAULT ((0)) FOR [OffLineHF]
GO
ALTER TABLE [dbo].[tblIMISDefaults] ADD  DEFAULT ((0)) FOR [OfflineCHF]
GO
ALTER TABLE [dbo].[tblInsuree] ADD  DEFAULT (newid()) FOR [InsureeUUID]
GO
ALTER TABLE [dbo].[tblInsuree] ADD  CONSTRAINT [DF_tblInsuree_IsHead]  DEFAULT ((0)) FOR [IsHead]
GO
ALTER TABLE [dbo].[tblInsuree] ADD  CONSTRAINT [DF_tblInsuree_CardIssued]  DEFAULT ((0)) FOR [CardIssued]
GO
ALTER TABLE [dbo].[tblInsuree] ADD  CONSTRAINT [DF_tblInsuree_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblInsuree] ADD  CONSTRAINT [DF__tblInsure__isOff__0E64051E]  DEFAULT ((0)) FOR [isOffline]
GO
ALTER TABLE [dbo].[tblInsureePolicy] ADD  CONSTRAINT [DF_tblInsureePolicy_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblInsureePolicy] ADD  CONSTRAINT [DF_tblInsureePolicy_isOffline]  DEFAULT ((0)) FOR [isOffline]
GO
ALTER TABLE [dbo].[tblItems] ADD  DEFAULT (newid()) FOR [ItemUUID]
GO
ALTER TABLE [dbo].[tblItems] ADD  CONSTRAINT [DF_tblItems_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblLocations] ADD  DEFAULT (newid()) FOR [LocationUUID]
GO
ALTER TABLE [dbo].[tblLocations] ADD  CONSTRAINT [DF_tblLocations_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblOfficer] ADD  DEFAULT (newid()) FOR [OfficerUUID]
GO
ALTER TABLE [dbo].[tblOfficer] ADD  CONSTRAINT [DF_tblOfficer_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblOfficer] ADD  DEFAULT ((0)) FOR [PhoneCommunication]
GO
ALTER TABLE [dbo].[tblOfficerVillages] ADD  CONSTRAINT [DF_tblOfficerVillages]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPayer] ADD  DEFAULT (newid()) FOR [PayerUUID]
GO
ALTER TABLE [dbo].[tblPayer] ADD  CONSTRAINT [DF_tblPayer_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPayment] ADD  DEFAULT (newid()) FOR PaymentUUID
GO
ALTER TABLE [dbo].[tblPhotos] ADD  DEFAULT (newid()) FOR [PhotoUUID]
GO
ALTER TABLE [dbo].[tblPhotos] ADD  CONSTRAINT [DF_tblPhotos_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPhotos] ADD  CONSTRAINT [DF_tblPhotos_AudiitUser]  DEFAULT ((0)) FOR [AuditUserID]
GO
ALTER TABLE [dbo].[tblPLItems] ADD  DEFAULT (newid()) FOR [PLItemUUID]
GO
ALTER TABLE [dbo].[tblPLItems] ADD  CONSTRAINT [DF_tblPLItems_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPLItemsDetail] ADD  CONSTRAINT [DF_tblPLItemsDetail_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPLServices] ADD  DEFAULT (newid()) FOR [PLServiceUUID]
GO
ALTER TABLE [dbo].[tblPLServices] ADD  CONSTRAINT [DF_tblPLServices_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPLServicesDetail] ADD  CONSTRAINT [DF_tblPLServicesDetail_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPolicy] ADD  DEFAULT (newid()) FOR [PolicyUUID]
GO
ALTER TABLE [dbo].[tblPolicy] ADD  CONSTRAINT [DF_tblPolicy_PolicyStatus]  DEFAULT ((1)) FOR [PolicyStatus]
GO
ALTER TABLE [dbo].[tblPolicy] ADD  CONSTRAINT [DF_tblPolicy_PolicyStage]  DEFAULT ('N') FOR [PolicyStage]
GO
ALTER TABLE [dbo].[tblPolicy] ADD  CONSTRAINT [DF_tblPolicy_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPolicy] ADD  CONSTRAINT [DF__tblPolicy__isOff__0F582957]  DEFAULT ((0)) FOR [isOffline]
GO
ALTER TABLE [dbo].[tblPolicyRenewalDetails] ADD  CONSTRAINT [DF_tblPolicyRenewalDetails_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPolicyRenewals] ADD  DEFAULT (newid()) FOR [RenewalUUID]
GO
ALTER TABLE [dbo].[tblPolicyRenewals] ADD  CONSTRAINT [DF_tblPolicyRenewals_IsSMSSent]  DEFAULT ((0)) FOR [SMSStatus]
GO
ALTER TABLE [dbo].[tblPolicyRenewals] ADD  CONSTRAINT [DF_tblPolicyRenewals_RenewalWarnings]  DEFAULT ((0)) FOR [RenewalWarnings]
GO
ALTER TABLE [dbo].[tblPolicyRenewals] ADD  CONSTRAINT [DF_tblPolicyRenewals_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPremium] ADD  DEFAULT (newid()) FOR [PremiumUUID]
GO
ALTER TABLE [dbo].[tblPremium] ADD  CONSTRAINT [DF_tblPremium_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblPremium] ADD  CONSTRAINT [DF_tblPremium_PayCategory]  DEFAULT ((0)) FOR [isPhotoFee]
GO
ALTER TABLE [dbo].[tblPremium] ADD  CONSTRAINT [DF__tblPremiu__isOff__104C4D90]  DEFAULT ((0)) FOR [isOffline]
GO
ALTER TABLE [dbo].[tblProduct] ADD  DEFAULT (newid()) FOR [ProdUUID]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_tblProduct_InsurancePeriod]  DEFAULT ((12)) FOR [InsurancePeriod]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_tblProduct_GracePeriod]  DEFAULT ((0)) FOR [GracePeriod]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_tblProduct_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblProduct] ADD  DEFAULT ((0)) FOR [RenewalDiscountPerc]
GO
ALTER TABLE [dbo].[tblProduct] ADD  DEFAULT ((0)) FOR [RenewalDiscountPeriod]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_ShareContribution]  DEFAULT ((100.00)) FOR [ShareContribution]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_WeightPopulation]  DEFAULT ((0.00)) FOR [WeightPopulation]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_WeightNumberFamilies]  DEFAULT ((0.00)) FOR [WeightNumberFamilies]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_WeightInsuredPopulation]  DEFAULT ((100.00)) FOR [WeightInsuredPopulation]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_WeightNumberInsuredFamilies]  DEFAULT ((0.00)) FOR [WeightNumberInsuredFamilies]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_WeightNumberVisits]  DEFAULT ((0.00)) FOR [WeightNumberVisits]
GO
ALTER TABLE [dbo].[tblProduct] ADD  CONSTRAINT [DF_WeightAdjustedAmount]  DEFAULT ((0.00)) FOR [WeightAdjustedAmount]
GO
ALTER TABLE [dbo].[tblProductItems] ADD  CONSTRAINT [DF_tblProductItems_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblProductServices] ADD  CONSTRAINT [DF_tblProductServices_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblRelDistr] ADD  CONSTRAINT [DF_tblRelDistr_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblRelIndex] ADD  CONSTRAINT [DF_tblRelIndex_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblRole] ADD  DEFAULT (newid()) FOR [RoleUUID]
GO
ALTER TABLE [dbo].[tblServices] ADD  DEFAULT (newid()) FOR [ServiceUUID]
GO
ALTER TABLE [dbo].[tblServices] ADD  CONSTRAINT [DF_tblServices_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblSubmittedPhotos] ADD  DEFAULT (getdate()) FOR [RegisterDate]
GO
ALTER TABLE [dbo].[tblUsers] ADD  DEFAULT (newid()) FOR [UserUUID]
GO
ALTER TABLE [dbo].[tblUsers] ADD  CONSTRAINT [DF_tblUsers_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblUsersDistricts] ADD  CONSTRAINT [DF_tblUsersDistricts_ValidityFrom]  DEFAULT (getdate()) FOR [ValidityFrom]
GO
ALTER TABLE [dbo].[tblBatchRun]  WITH CHECK ADD  CONSTRAINT [FK_tblBatchRun_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblBatchRun] CHECK CONSTRAINT [FK_tblBatchRun_tblLocations]
GO
ALTER TABLE [dbo].[tblClaim]  WITH CHECK ADD  CONSTRAINT [FK_tblClaim_tblBatchRun] FOREIGN KEY([RunID])
REFERENCES [dbo].[tblBatchRun] ([RunID])
GO
ALTER TABLE [dbo].[tblClaim] CHECK CONSTRAINT [FK_tblClaim_tblBatchRun]
GO
ALTER TABLE [dbo].[tblClaim]  WITH CHECK ADD  CONSTRAINT [FK_tblClaim_tblClaimAdmin] FOREIGN KEY([ClaimAdminId])
REFERENCES [dbo].[tblClaimAdmin] ([ClaimAdminId])
GO
ALTER TABLE [dbo].[tblClaim] CHECK CONSTRAINT [FK_tblClaim_tblClaimAdmin]
GO
ALTER TABLE [dbo].[tblClaim]  WITH NOCHECK ADD  CONSTRAINT [FK_tblClaim_tblFeedback-FeedbackID] FOREIGN KEY([FeedbackID])
REFERENCES [dbo].[tblFeedback] ([FeedbackID])
NOT FOR REPLICATION 
GO
ALTER TABLE [dbo].[tblClaim] NOCHECK CONSTRAINT [FK_tblClaim_tblFeedback-FeedbackID]
GO
ALTER TABLE [dbo].[tblClaim]  WITH CHECK ADD  CONSTRAINT [FK_tblClaim_tblHF] FOREIGN KEY([HFID])
REFERENCES [dbo].[tblHF] ([HfID])
GO
ALTER TABLE [dbo].[tblClaim] CHECK CONSTRAINT [FK_tblClaim_tblHF]
GO
ALTER TABLE [dbo].[tblClaim]  WITH CHECK ADD  CONSTRAINT [FK_tblClaim_tblICDCodes-ICDID] FOREIGN KEY([ICDID])
REFERENCES [dbo].[tblICDCodes] ([ICDID])
GO
ALTER TABLE [dbo].[tblClaim] CHECK CONSTRAINT [FK_tblClaim_tblICDCodes-ICDID]
GO
ALTER TABLE [dbo].[tblClaim]  WITH CHECK ADD  CONSTRAINT [FK_tblClaim_tblInsuree-InsureeID] FOREIGN KEY([InsureeID])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
GO
ALTER TABLE [dbo].[tblClaim] CHECK CONSTRAINT [FK_tblClaim_tblInsuree-InsureeID]
GO
ALTER TABLE [dbo].[tblClaim]  WITH CHECK ADD  CONSTRAINT [FK_tblClaim_tblUsers] FOREIGN KEY([Adjuster])
REFERENCES [dbo].[tblUsers] ([UserID])
GO
ALTER TABLE [dbo].[tblClaim] CHECK CONSTRAINT [FK_tblClaim_tblUsers]
GO
ALTER TABLE [dbo].[tblClaimAdmin]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimAdmin_tblHF] FOREIGN KEY([HFId])
REFERENCES [dbo].[tblHF] ([HfID])
GO
ALTER TABLE [dbo].[tblClaimAdmin] CHECK CONSTRAINT [FK_tblClaimAdmin_tblHF]
GO
ALTER TABLE [dbo].[tblClaimDedRem]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimDedRem_tblInsuree] FOREIGN KEY([InsureeID])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
GO
ALTER TABLE [dbo].[tblClaimDedRem] CHECK CONSTRAINT [FK_tblClaimDedRem_tblInsuree]
GO
ALTER TABLE [dbo].[tblClaimDedRem]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimDedRem_tblPolicy] FOREIGN KEY([PolicyID])
REFERENCES [dbo].[tblPolicy] ([PolicyID])
GO
ALTER TABLE [dbo].[tblClaimDedRem] CHECK CONSTRAINT [FK_tblClaimDedRem_tblPolicy]
GO
ALTER TABLE [dbo].[tblClaimItems]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimItems_tblClaim-ClaimID] FOREIGN KEY([ClaimID])
REFERENCES [dbo].[tblClaim] ([ClaimID])
GO
ALTER TABLE [dbo].[tblClaimItems] CHECK CONSTRAINT [FK_tblClaimItems_tblClaim-ClaimID]
GO
ALTER TABLE [dbo].[tblClaimItems]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimItems_tblItems-ItemID] FOREIGN KEY([ItemID])
REFERENCES [dbo].[tblItems] ([ItemID])
GO
ALTER TABLE [dbo].[tblClaimItems] CHECK CONSTRAINT [FK_tblClaimItems_tblItems-ItemID]
GO
ALTER TABLE [dbo].[tblClaimItems]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimItems_tblProduct-ProdID] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblClaimItems] CHECK CONSTRAINT [FK_tblClaimItems_tblProduct-ProdID]
GO
ALTER TABLE [dbo].[tblClaimServices]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimServices_tblClaim-ClaimID] FOREIGN KEY([ClaimID])
REFERENCES [dbo].[tblClaim] ([ClaimID])
GO
ALTER TABLE [dbo].[tblClaimServices] CHECK CONSTRAINT [FK_tblClaimServices_tblClaim-ClaimID]
GO
ALTER TABLE [dbo].[tblClaimServices]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimServices_tblProduct-ProdID] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblClaimServices] CHECK CONSTRAINT [FK_tblClaimServices_tblProduct-ProdID]
GO
ALTER TABLE [dbo].[tblClaimServices]  WITH CHECK ADD  CONSTRAINT [FK_tblClaimServices_tblServices-ServiceID] FOREIGN KEY([ServiceID])
REFERENCES [dbo].[tblServices] ([ServiceID])
GO
ALTER TABLE [dbo].[tblClaimServices] CHECK CONSTRAINT [FK_tblClaimServices_tblServices-ServiceID]
GO
ALTER TABLE [dbo].[tblFamilies]  WITH CHECK ADD  CONSTRAINT [FK_tblConfirmationType_tblFamilies] FOREIGN KEY([ConfirmationType])
REFERENCES [dbo].[tblConfirmationTypes] ([ConfirmationTypeCode])
GO
ALTER TABLE [dbo].[tblFamilies] CHECK CONSTRAINT [FK_tblConfirmationType_tblFamilies]
GO
ALTER TABLE [dbo].[tblFamilies]  WITH NOCHECK ADD  CONSTRAINT [FK_tblFamilies_tblInsuree] FOREIGN KEY([InsureeID])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
NOT FOR REPLICATION 
GO
ALTER TABLE [dbo].[tblFamilies] NOCHECK CONSTRAINT [FK_tblFamilies_tblInsuree]
GO
ALTER TABLE [dbo].[tblFamilies]  WITH CHECK ADD  CONSTRAINT [FK_tblFamilies_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblFamilies] CHECK CONSTRAINT [FK_tblFamilies_tblLocations]
GO
ALTER TABLE [dbo].[tblFamilies]  WITH CHECK ADD  CONSTRAINT [FK_tblFamilyTypes_tblFamilies] FOREIGN KEY([FamilyType])
REFERENCES [dbo].[tblFamilyTypes] ([FamilyTypeCode])
GO
ALTER TABLE [dbo].[tblFamilies] CHECK CONSTRAINT [FK_tblFamilyTypes_tblFamilies]
GO
ALTER TABLE [dbo].[tblFamilySMS] WITH CHECK ADD CONSTRAINT [FK_tblFamilySMS_tblFamily-FamilyID] FOREIGN KEY([FamilyID])
REFERENCES [dbo].[tblFamilies]
GO
ALTER TABLE [dbo].[tblFeedback]  WITH CHECK ADD  CONSTRAINT [FK_tblFeedback_tblClaim-ClaimID] FOREIGN KEY([ClaimID])
REFERENCES [dbo].[tblClaim] ([ClaimID])
GO
ALTER TABLE [dbo].[tblFeedback] CHECK CONSTRAINT [FK_tblFeedback_tblClaim-ClaimID]
GO
ALTER TABLE [dbo].[tblHealthStatus]  WITH CHECK ADD  CONSTRAINT [FK_tblHealthStatus_tblInsuree] FOREIGN KEY([InsureeID])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
GO
ALTER TABLE [dbo].[tblHealthStatus] CHECK CONSTRAINT [FK_tblHealthStatus_tblInsuree]
GO
ALTER TABLE [dbo].[tblHF]  WITH CHECK ADD  CONSTRAINT [FK_tblHF_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblHF] CHECK CONSTRAINT [FK_tblHF_tblLocations]
GO
ALTER TABLE [dbo].[tblHF]  WITH CHECK ADD  CONSTRAINT [FK_tblHF_tblPLItems-PLItemID] FOREIGN KEY([PLItemID])
REFERENCES [dbo].[tblPLItems] ([PLItemID])
GO
ALTER TABLE [dbo].[tblHF] CHECK CONSTRAINT [FK_tblHF_tblPLItems-PLItemID]
GO
ALTER TABLE [dbo].[tblHF]  WITH CHECK ADD  CONSTRAINT [FK_tblHF_tblPLServices-PLService-ID] FOREIGN KEY([PLServiceID])
REFERENCES [dbo].[tblPLServices] ([PLServiceID])
GO
ALTER TABLE [dbo].[tblHF] CHECK CONSTRAINT [FK_tblHF_tblPLServices-PLService-ID]
GO
ALTER TABLE [dbo].[tblHF]  WITH CHECK ADD  CONSTRAINT [FK_tblHFSublevel_tblHF] FOREIGN KEY([HFSublevel])
REFERENCES [dbo].[tblHFSublevel] ([HFSublevel])
GO
ALTER TABLE [dbo].[tblHF] CHECK CONSTRAINT [FK_tblHFSublevel_tblHF]
GO
ALTER TABLE [dbo].[tblHF]  WITH CHECK ADD  CONSTRAINT [FK_tblLegalForms_tblHF] FOREIGN KEY([LegalForm])
REFERENCES [dbo].[tblLegalForms] ([LegalFormCode])
GO
ALTER TABLE [dbo].[tblHF] CHECK CONSTRAINT [FK_tblLegalForms_tblHF]
GO
ALTER TABLE [dbo].[tblHFCatchment]  WITH CHECK ADD  CONSTRAINT [FK_tblHFCatchment_tbLHF] FOREIGN KEY([HFID])
REFERENCES [dbo].[tblHF] ([HfID])
GO
ALTER TABLE [dbo].[tblHFCatchment] CHECK CONSTRAINT [FK_tblHFCatchment_tbLHF]
GO
ALTER TABLE [dbo].[tblHFCatchment]  WITH CHECK ADD  CONSTRAINT [FK_tblHFCatchment_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblHFCatchment] CHECK CONSTRAINT [FK_tblHFCatchment_tblLocations]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblEducations_tblInsuree] FOREIGN KEY([Education])
REFERENCES [dbo].[tblEducations] ([EducationId])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblEducations_tblInsuree]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblIdentificationTypes_tblInsuree] FOREIGN KEY([TypeOfId])
REFERENCES [dbo].[tblIdentificationTypes] ([IdentificationCode])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblIdentificationTypes_tblInsuree]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblInsuree_tblFamilies1-FamilyID] FOREIGN KEY([FamilyID])
REFERENCES [dbo].[tblFamilies] ([FamilyID])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblInsuree_tblFamilies1-FamilyID]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblInsuree_tblGender] FOREIGN KEY([Gender])
REFERENCES [dbo].[tblGender] ([Code])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblInsuree_tblGender]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblInsuree_tblHF] FOREIGN KEY([HFID])
REFERENCES [dbo].[tblHF] ([HfID])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblInsuree_tblHF]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblInsuree_tblPhotos] FOREIGN KEY([PhotoID])
REFERENCES [dbo].[tblPhotos] ([PhotoID])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblInsuree_tblPhotos]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblProfessions_tblInsuree] FOREIGN KEY([Profession])
REFERENCES [dbo].[tblProfessions] ([ProfessionId])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblProfessions_tblInsuree]
GO
ALTER TABLE [dbo].[tblInsuree]  WITH CHECK ADD  CONSTRAINT [FK_tblRelations_tblInsuree] FOREIGN KEY([Relationship])
REFERENCES [dbo].[tblRelations] ([RelationId])
GO
ALTER TABLE [dbo].[tblInsuree] CHECK CONSTRAINT [FK_tblRelations_tblInsuree]
GO
ALTER TABLE [dbo].[tblInsureePolicy]  WITH CHECK ADD  CONSTRAINT [FK_tblInsureePolicy_tblInsuree] FOREIGN KEY([InsureeId])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
GO
ALTER TABLE [dbo].[tblInsureePolicy] CHECK CONSTRAINT [FK_tblInsureePolicy_tblInsuree]
GO
ALTER TABLE [dbo].[tblInsureePolicy]  WITH CHECK ADD  CONSTRAINT [FK_tblInsureePolicy_tblPolicy] FOREIGN KEY([PolicyId])
REFERENCES [dbo].[tblPolicy] ([PolicyID])
GO
ALTER TABLE [dbo].[tblInsureePolicy] CHECK CONSTRAINT [FK_tblInsureePolicy_tblPolicy]
GO
ALTER TABLE [dbo].[tblLogins]  WITH CHECK ADD  CONSTRAINT [FK_tblLogins_tblUsers] FOREIGN KEY([UserId])
REFERENCES [dbo].[tblUsers] ([UserID])
GO
ALTER TABLE [dbo].[tblLogins] CHECK CONSTRAINT [FK_tblLogins_tblUsers]
GO
ALTER TABLE [dbo].[tblOfficer]  WITH CHECK ADD  CONSTRAINT [FK_tblOfficer_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblOfficer] CHECK CONSTRAINT [FK_tblOfficer_tblLocations]
GO
ALTER TABLE [dbo].[tblOfficer]  WITH NOCHECK ADD  CONSTRAINT [FK_tblOfficer_tblOfficer] FOREIGN KEY([OfficerIDSubst])
REFERENCES [dbo].[tblOfficer] ([OfficerID])
GO
ALTER TABLE [dbo].[tblOfficer] CHECK CONSTRAINT [FK_tblOfficer_tblOfficer]
GO
ALTER TABLE [dbo].[tblOfficerVillages]  WITH CHECK ADD  CONSTRAINT [FK_tblOfficerVillages_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblOfficerVillages] CHECK CONSTRAINT [FK_tblOfficerVillages_tblLocations]
GO
ALTER TABLE [dbo].[tblOfficerVillages]  WITH CHECK ADD  CONSTRAINT [FK_tblOfficerVillages_tblOfficer] FOREIGN KEY([OfficerId])
REFERENCES [dbo].[tblOfficer] ([OfficerID])
GO
ALTER TABLE [dbo].[tblOfficerVillages] CHECK CONSTRAINT [FK_tblOfficerVillages_tblOfficer]
GO
ALTER TABLE [dbo].[tblPayer]  WITH CHECK ADD  CONSTRAINT [FK_tblPayer_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblPayer] CHECK CONSTRAINT [FK_tblPayer_tblLocations]
GO
ALTER TABLE [dbo].[tblPayer]  WITH CHECK ADD  CONSTRAINT [FK_tblPayer_tblPayerType] FOREIGN KEY([PayerType])
REFERENCES [dbo].[tblPayerType] ([Code])
GO
ALTER TABLE [dbo].[tblPayer] CHECK CONSTRAINT [FK_tblPayer_tblPayerType]
GO
ALTER TABLE [dbo].[tblPLItems]  WITH CHECK ADD  CONSTRAINT [FK_tblPLItems_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblPLItems] CHECK CONSTRAINT [FK_tblPLItems_tblLocations]
GO
ALTER TABLE [dbo].[tblPLItemsDetail]  WITH CHECK ADD  CONSTRAINT [FK_tblPLItemsDetail_tblItems-ItemID] FOREIGN KEY([ItemID])
REFERENCES [dbo].[tblItems] ([ItemID])
GO
ALTER TABLE [dbo].[tblPLItemsDetail] CHECK CONSTRAINT [FK_tblPLItemsDetail_tblItems-ItemID]
GO
ALTER TABLE [dbo].[tblPLItemsDetail]  WITH CHECK ADD  CONSTRAINT [FK_tblPLItemsDetail_tblPLItems-PLItemID] FOREIGN KEY([PLItemID])
REFERENCES [dbo].[tblPLItems] ([PLItemID])
GO
ALTER TABLE [dbo].[tblPLItemsDetail] CHECK CONSTRAINT [FK_tblPLItemsDetail_tblPLItems-PLItemID]
GO
ALTER TABLE [dbo].[tblPLServices]  WITH CHECK ADD  CONSTRAINT [FK_tblPLServices_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblPLServices] CHECK CONSTRAINT [FK_tblPLServices_tblLocations]
GO
ALTER TABLE [dbo].[tblPLServicesDetail]  WITH CHECK ADD  CONSTRAINT [FK_tblPLServicesDetail_tblPLServices-PLServiceID] FOREIGN KEY([PLServiceID])
REFERENCES [dbo].[tblPLServices] ([PLServiceID])
GO
ALTER TABLE [dbo].[tblPLServicesDetail] CHECK CONSTRAINT [FK_tblPLServicesDetail_tblPLServices-PLServiceID]
GO
ALTER TABLE [dbo].[tblPLServicesDetail]  WITH CHECK ADD  CONSTRAINT [FK_tblPLServicesDetail_tblServices-ServiceID] FOREIGN KEY([ServiceID])
REFERENCES [dbo].[tblServices] ([ServiceID])
GO
ALTER TABLE [dbo].[tblPLServicesDetail] CHECK CONSTRAINT [FK_tblPLServicesDetail_tblServices-ServiceID]
GO
ALTER TABLE [dbo].[tblPolicy]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicy_tblFamilies-FamilyID] FOREIGN KEY([FamilyID])
REFERENCES [dbo].[tblFamilies] ([FamilyID])
GO
ALTER TABLE [dbo].[tblPolicy] CHECK CONSTRAINT [FK_tblPolicy_tblFamilies-FamilyID]
GO
ALTER TABLE [dbo].[tblPolicy]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicy_tblOfficer-OfficerID] FOREIGN KEY([OfficerID])
REFERENCES [dbo].[tblOfficer] ([OfficerID])
GO
ALTER TABLE [dbo].[tblPolicy] CHECK CONSTRAINT [FK_tblPolicy_tblOfficer-OfficerID]
GO
ALTER TABLE [dbo].[tblPolicy]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicy_tblProduct-ProductID] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblPolicy] CHECK CONSTRAINT [FK_tblPolicy_tblProduct-ProductID]
GO
ALTER TABLE [dbo].[tblPolicyRenewalDetails]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicyRenewalDetails_tblInsuree] FOREIGN KEY([InsureeID])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
GO
ALTER TABLE [dbo].[tblPolicyRenewalDetails] CHECK CONSTRAINT [FK_tblPolicyRenewalDetails_tblInsuree]
GO
ALTER TABLE [dbo].[tblPolicyRenewalDetails]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicyRenewalDetails_tblPolicyRenewals] FOREIGN KEY([RenewalID])
REFERENCES [dbo].[tblPolicyRenewals] ([RenewalID])
GO
ALTER TABLE [dbo].[tblPolicyRenewalDetails] CHECK CONSTRAINT [FK_tblPolicyRenewalDetails_tblPolicyRenewals]
GO
ALTER TABLE [dbo].[tblPolicyRenewals]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicyRenewals_tblInsuree] FOREIGN KEY([InsureeID])
REFERENCES [dbo].[tblInsuree] ([InsureeID])
GO
ALTER TABLE [dbo].[tblPolicyRenewals] CHECK CONSTRAINT [FK_tblPolicyRenewals_tblInsuree]
GO
ALTER TABLE [dbo].[tblPolicyRenewals]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicyRenewals_tblOfficer] FOREIGN KEY([NewOfficerID])
REFERENCES [dbo].[tblOfficer] ([OfficerID])
GO
ALTER TABLE [dbo].[tblPolicyRenewals] CHECK CONSTRAINT [FK_tblPolicyRenewals_tblOfficer]
GO
ALTER TABLE [dbo].[tblPolicyRenewals]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicyRenewals_tblPolicy] FOREIGN KEY([PolicyID])
REFERENCES [dbo].[tblPolicy] ([PolicyID])
GO
ALTER TABLE [dbo].[tblPolicyRenewals] CHECK CONSTRAINT [FK_tblPolicyRenewals_tblPolicy]
GO
ALTER TABLE [dbo].[tblPolicyRenewals]  WITH CHECK ADD  CONSTRAINT [FK_tblPolicyRenewals_tblProduct] FOREIGN KEY([NewProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblPolicyRenewals] CHECK CONSTRAINT [FK_tblPolicyRenewals_tblProduct]
GO
ALTER TABLE [dbo].[tblPremium]  WITH CHECK ADD  CONSTRAINT [FK_tblPremium_tblPayer] FOREIGN KEY([PayerID])
REFERENCES [dbo].[tblPayer] ([PayerID])
GO
ALTER TABLE [dbo].[tblPremium] CHECK CONSTRAINT [FK_tblPremium_tblPayer]
GO
ALTER TABLE [dbo].[tblPremium]  WITH CHECK ADD  CONSTRAINT [FK_tblPremium_tblPolicy] FOREIGN KEY([PolicyID])
REFERENCES [dbo].[tblPolicy] ([PolicyID])
GO
ALTER TABLE [dbo].[tblPremium] CHECK CONSTRAINT [FK_tblPremium_tblPolicy]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblHFSublevel_tblProduct_1] FOREIGN KEY([Sublevel1])
REFERENCES [dbo].[tblHFSublevel] ([HFSublevel])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblHFSublevel_tblProduct_1]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblHFSublevel_tblProduct_2] FOREIGN KEY([Sublevel2])
REFERENCES [dbo].[tblHFSublevel] ([HFSublevel])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblHFSublevel_tblProduct_2]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblHFSublevel_tblProduct_3] FOREIGN KEY([Sublevel3])
REFERENCES [dbo].[tblHFSublevel] ([HFSublevel])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblHFSublevel_tblProduct_3]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblHFSublevel_tblProduct_4] FOREIGN KEY([Sublevel4])
REFERENCES [dbo].[tblHFSublevel] ([HFSublevel])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblHFSublevel_tblProduct_4]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblProduct_tblCeilingInterpretation] FOREIGN KEY([CeilingInterpretation])
REFERENCES [dbo].[tblCeilingInterpretation] ([CeilingIntCode])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblProduct_tblCeilingInterpretation]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblProduct_tblLocation] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblProduct_tblLocation]
GO
ALTER TABLE [dbo].[tblProduct]  WITH CHECK ADD  CONSTRAINT [FK_tblProduct_tblProduct] FOREIGN KEY([ConversionProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [FK_tblProduct_tblProduct]
GO
ALTER TABLE [dbo].[tblProductItems]  WITH CHECK ADD  CONSTRAINT [FK_tblProductItems_tblItems-ItemID] FOREIGN KEY([ItemID])
REFERENCES [dbo].[tblItems] ([ItemID])
GO
ALTER TABLE [dbo].[tblProductItems] CHECK CONSTRAINT [FK_tblProductItems_tblItems-ItemID]
GO
ALTER TABLE [dbo].[tblProductItems]  WITH CHECK ADD  CONSTRAINT [FK_tblProductItems_tblProduct-ProductID] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblProductItems] CHECK CONSTRAINT [FK_tblProductItems_tblProduct-ProductID]
GO
ALTER TABLE [dbo].[tblProductServices]  WITH CHECK ADD  CONSTRAINT [FK_tblProductServices_tblProduct-ProductID] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblProductServices] CHECK CONSTRAINT [FK_tblProductServices_tblProduct-ProductID]
GO
ALTER TABLE [dbo].[tblProductServices]  WITH CHECK ADD  CONSTRAINT [FK_tblProductServices_tblServices-ServiceID] FOREIGN KEY([ServiceID])
REFERENCES [dbo].[tblServices] ([ServiceID])
GO
ALTER TABLE [dbo].[tblProductServices] CHECK CONSTRAINT [FK_tblProductServices_tblServices-ServiceID]
GO
ALTER TABLE [dbo].[tblRelDistr]  WITH CHECK ADD  CONSTRAINT [FK_tblRelDistr_tblProduct] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblRelDistr] CHECK CONSTRAINT [FK_tblRelDistr_tblProduct]
GO
ALTER TABLE [dbo].[tblRelIndex]  WITH CHECK ADD  CONSTRAINT [FK_tblRelIndex_tblProduct] FOREIGN KEY([ProdID])
REFERENCES [dbo].[tblProduct] ([ProdID])
GO
ALTER TABLE [dbo].[tblRelIndex] CHECK CONSTRAINT [FK_tblRelIndex_tblProduct]
GO
ALTER TABLE [dbo].[tblRoleRight]  WITH CHECK ADD  CONSTRAINT [FK_tblRoleRight_tblRole] FOREIGN KEY([RoleID])
REFERENCES [dbo].[tblRole] ([RoleID])
GO
ALTER TABLE [dbo].[tblRoleRight] CHECK CONSTRAINT [FK_tblRoleRight_tblRole]
GO
ALTER TABLE [dbo].[tblUserRole]  WITH CHECK ADD  CONSTRAINT [FK_tblUserRole_tblRole] FOREIGN KEY([RoleID])
REFERENCES [dbo].[tblRole] ([RoleID])
ON UPDATE CASCADE
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[tblUserRole] CHECK CONSTRAINT [FK_tblUserRole_tblRole]
GO
ALTER TABLE [dbo].[tblUserRole]  WITH CHECK ADD  CONSTRAINT [FK_tblUserRole_tblUsers] FOREIGN KEY([UserID])
REFERENCES [dbo].[tblUsers] ([UserID])
ON UPDATE CASCADE
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[tblUserRole] CHECK CONSTRAINT [FK_tblUserRole_tblUsers]
GO
ALTER TABLE [dbo].[tblUsers]  WITH CHECK ADD  CONSTRAINT [FK_tblLanguages_tblUsers] FOREIGN KEY([LanguageID])
REFERENCES [dbo].[tblLanguages] ([LanguageCode])
GO
ALTER TABLE [dbo].[tblUsers] CHECK CONSTRAINT [FK_tblLanguages_tblUsers]
GO
ALTER TABLE [dbo].[tblUsersDistricts]  WITH CHECK ADD  CONSTRAINT [FK_tblUsersDistricts_tblLocations] FOREIGN KEY([LocationId])
REFERENCES [dbo].[tblLocations] ([LocationId])
GO
ALTER TABLE [dbo].[tblUsersDistricts] CHECK CONSTRAINT [FK_tblUsersDistricts_tblLocations]
GO
ALTER TABLE [dbo].[tblUsersDistricts] WITH CHECK ADD CONSTRAINT [FK_tblUsersDistricts_tblUsers] FOREIGN KEY([UserID])
REFERENCES [dbo].[tblUsers] ([UserID])
GO
ALTER TABLE [dbo].[tblControlNumber] WITH CHECK ADD CONSTRAINT [FK_tblControlNumber_tblPayment] FOREIGN KEY([PaymentID])
REFERENCES [dbo].[tblPayment] ([PaymentId])
GO
ALTER TABLE [dbo].[tblPaymentDetails] WITH CHECK ADD CONSTRAINT [FK_tblPaymentDetails_tblPayment] FOREIGN KEY([PaymentID])
REFERENCES [dbo].[tblPayment] ([PaymentId])
GO
ALTER TABLE [dbo].[tblUsersDistricts] CHECK CONSTRAINT [FK_tblUsersDistricts_tblUsers]
GO
ALTER TABLE [dbo].[tblFromPhone]  WITH CHECK ADD  CONSTRAINT [chk_DocType] CHECK  (([DocType]=N'C' OR [DocType]=N'F' OR [DocType]=N'R' OR [DocType]=N'E'))
GO
ALTER TABLE [dbo].[tblFromPhone] CHECK CONSTRAINT [chk_DocType]
GO
ALTER TABLE [dbo].[tblProduct]  WITH NOCHECK ADD  CONSTRAINT [CHK_Weight] CHECK  (([ValidityTo] IS NOT NULL OR [ValidityTo] IS NULL AND isnull(nullif(((((isnull([WeightPopulation],(0))+isnull([WeightNumberFamilies],(0)))+isnull([WeightInsuredPopulation],(0)))+isnull([WeightNumberInsuredFamilies],(0)))+isnull([WeightNumberVisits],(0)))+isnull([WeightAdjustedAmount],(0)),(0)),(100))=(100)))
GO
ALTER TABLE [dbo].[tblProduct] CHECK CONSTRAINT [CHK_Weight]
GO
