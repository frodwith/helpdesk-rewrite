create table Helpdesk2_Ticket (
    helpdesk   char(22),
    groupId    char(22),
    id         int,
    openedBy   char(22) not null,
    openedOn   bigint   not null,
    assignedOn bigint,
    assignedTo char(22),
    assignedBy char(22),
    status     char(50) not null,
    lastReply  bigint,
    public     boolean  not null,
    severity   char(50) not null,
    title      char(80) not null default '',
    keywords   char(80) not null default '',
    webgui     char(80) not null default '',
    wre        char(80) not null default '',
    os         char(80) not null default '',

    primary key(helpdesk, id)
);

CREATE TABLE Helpdesk2_Comment (
    id         char(22),
    helpdesk   char(22),
    ticket     int,
    timestamp  bigint,
    author     char(22),
    body       text,
    status     char(80),

    primary key(id)
);

CREATE TABLE Helpdesk2_Attachment (
    comment    char(22),
    storage    char(22),
    filename   char(80)
);
