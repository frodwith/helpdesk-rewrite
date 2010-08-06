CREATE TABLE AssetAspect_GetMail (
    assetId char(22),
    revisionDate bigint,
    getMailServer char(255),
    getMailAccount char(255),
    getMailPassword char(255),
    getMail boolean,
    getMailInterval bigint,
    getMailCronId char(255),

    primary key (assetId, revisionDate)
);
