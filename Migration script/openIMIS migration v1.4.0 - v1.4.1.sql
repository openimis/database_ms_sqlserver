ALTER TABLE tblUsers DROP CONSTRAINT FK_tblLanguages_tblUsers
ALTER TABLE tblLanguages DROP CONSTRAINT PK_Language

ALTER TABLE tblLanguages
ALTER COLUMN LanguageCode [nvarchar](5) NOT NULL

ALTER TABLE tblUsers
ALTER COLUMN LanguageID [nvarchar](5) NOT NULL

ALTER TABLE tblLanguages ADD CONSTRAINT PK_Language PRIMARY KEY NONCLUSTERED (LanguageCode ASC) ON [PRIMARY];
ALTER TABLE tblUsers WITH CHECK ADD CONSTRAINT FK_tblLanguages_tblUsers FOREIGN KEY(LanguageID)
REFERENCES tblLanguages (LanguageCode)
