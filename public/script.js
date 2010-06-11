/*global YUI, $p, _, document */

_.mixin({
    mapFn: function (map) {
        return function (key) {
            return map[key];
        };
    },
    keyFn: function (key) {
        return function (map) {
            return map[key];
        };
    }
});

YUI({filter: 'raw'}).use(
'yui2-dragdrop', 'yui2-connection', 'yui2-json', 'yui2-paginator', 
'yui2-datatable', 'yui2-button', 
'node', 'tabview', 'gallery-overlay-modal', 'overlay', 'event', 
'querystring-stringify-simple', 'io-upload-iframe', 'io', 'json', function (Y) {

    // Pure likes to work on in-dom objects, so this is a thin wrapper that
    // takes an arbitrary Y.Node-able object as its template and returns us an
    // out-of-dom Node.  The template node will not be altered.
    function pure(template, data, directives) {
        var container, rendered;

        template = Y.one(template).cloneNode(true);
        template.removeAttribute('id');

        container = Y.Node.create('<div>');
        container.append(template);

        $p(Y.Node.getDOMNode(template)).render(data, directives);

        rendered = container.get('children').item(0);
        rendered.remove();

        return rendered;
    }

    function lookup(map) {
        return function(get) {
            return function (a) {
                return map[get(a)] || '';
            };
        };
    }

    function aprop(name) {
        return function (k) {
            return function (a) {
                return a[name][k];
            }
        }
    }

    function fillSelect(select, o) {
        _.each(o, function (v, k) {
            var opt = Y.Node.create('<option>');
            opt.set('value', k);
            opt.append(v);
            select.append(opt);
        });
    }

    function ticketResponse(callback) {
        return function (id, r) {
            var ticket = Y.JSON.parse(r.responseText);
            callback(ticket);
        };
    }


    var YAHOO = Y.YUI2,
    item      = aprop('item'),
    context   = aprop('context'),
    mkButton  = function (thing) {
        var node = Y.Node.getDOMNode(Y.one(thing)),
        classes  = node.className,
        widget   = new YAHOO.widget.Button(node);
        widget.addClass(classes);
        return widget;
    },

    Ticket    = {
        editDirectives: {
            '[name=title]@value'      : 'title',
            '[name=keywords]@value'   : 'keywords',
            '[name=webgui]@value'     : 'webgui',
            '[name=wre]@value'        : 'wre',
            '[name=os]@value'         : 'os'
        },
        viewDirectives: function () {
            var h    = this.helpdesk,
            username = lookup(h.users),
            status   = lookup(h.status),
            userUrl  = function (get) {
                return function (a) {
                    return 'http://a.url/users/' + get(a);
                };
            };

            return {
                '.id'    : 'id',
                '.title' : 'title',
                '.comments' : {
                    'c<-comments' : {
                        '.timestamp'   : 'c.timestamp',
                        '.author'      : username(item('author')),
                        '.author@href' : userUrl(item('author')),
                        '@class+'      : function (a) {
                            return a.pos % 2 ? ' odd' : ' even';
                        },
                        '.body'        : 'c.body',
                        '.status'      : status(item('status')),
                        '.attachments' : {
                            'a<-c.attachments' : {
                                'li a@href' : 'a.url',
                                'li a'      : 'a.name'
                            }
                        }
                    }
                },

                '.right-side .status' : status(context('status')),

                '.visibility' : lookup(h.visibility)(context('visibility')),
                '.visibility@class+' : function (a) {
                    return ' ' + a.context.visibility;
                },

                '.severity'        : lookup(h.severity)(context('severity')),
                '.keywords'        : 'keywords',
                '.url'             : 'url',
                '.webgui'          : 'webgui',
                '.wre'             : 'wre',
                '.os'              : 'os',
                '.assignedTo'      : username(context('assignedTo')),
                '.assignedTo@href' : userUrl(context('assignedTo')),
                '.assignedOn'      : 'assignedOn',
                '.assignedBy'      : username(context('assignedBy')),
                '.assignedBy@href' : userUrl(context('assignedBy'))
            };
        },

        reply: function () {
            this.helpdesk.addComment(
                this.data.id, this.node.one('.new-comment'),
                _.bind(this.update, this)
            );
        },

        edit: function (save) {
            var self = this,
            data     = self.data,
            helpdesk = self.helpdesk,
            template = helpdesk.ticketEdit,
            form     = pure(template, data, self.editDirectives),
            vinputs  = form.all('.visibility input'),
            overlay  = new Y.Overlay({
                srcNode   : form,
                zIndex    : 2,
                centered  : true
            }).plug(Y.Plugin.OverlayModal),
            close    = _.bind(overlay.destroy, overlay);

            _.detect(Y.NodeList.getDOMNodes(vinputs), function (radio) {
                return radio.value === data.visibility;
            }).checked = true;

            form.one('[name=severity]').set('value', data.severity);
            form.one('[name=assignedTo]').set('value', data.assignedTo);

            mkButton(form.one('.close')).on('click', close);
            mkButton(form.one('.cancel')).on('click', close);

            mkButton(form.one('.save'))
                .on('click', _.bind(save, null, form, close))
            
            overlay.render();
        },

        update: function(data) {
            var stale, fresh, node = this.node;
            this.data = data;

            stale = node.one('.ticket');
            fresh = this.render().one('.ticket');
            stale.replace(fresh);

            this.node = node;
        },

        render: function () {
            var self     = this,
            template     = self.helpdesk.ticketView,
            r            = pure(template, self.data, self.viewDirectives()),
            node         = self.node = Y.Node.create('<div>')
                .addClass('yui3-tab-panel')
                .append(r);

            mkButton(node.one('.edit-button')) .on('click', function () {
                self.edit(function (form, done) {
                    helpdesk.saveTicket(self.data.id, form, function (ticket) {
                        self.update(ticket);
                        done();
                    });
                });
            });

            mkButton(node.one('.reply'))
                .on('click', _.bind(self.reply, self));

            function makeAttacher(node) {
                var handle = node.one('input').on('change', function (e) {
                    var box = this.get('parentNode'),
                    next    = box.cloneNode(true),
                    remover = Y.Node.create('<a>x</a>');
                    handle.detach();
                    box.appendChild(remover);
                    box.get('parentNode').appendChild(next);
                    makeAttacher(next);
                    mkButton(remover).on('click', _.bind(box.remove, box));
                });
            }
            makeAttacher(node.one('.attach-box'));

            fillSelect(node.one('[name=status]'), self.helpdesk.status);

            return node;
        },

        create: function (helpdesk, data) {
            var self      = Y.Object(this);
            self.helpdesk = helpdesk;
            self.data     = data;
            return self;
        }
    },

    Helpdesk = {
        status: {
            'open'         : 'Open',
            'acknowledged' : 'Acknowledged',
            'waiting'      : 'Waiting On External',
            'feedback'     : 'Feedback Requested',
            'confirmed'    : 'Confirmed',
            'resolved'     : 'Resolved'
        },

        visibility: {
            'public'  : 'Public',
            'private' : 'Private'
        },

        severity: {
            'fatal'    : 'Fatal',
            'critical' : 'Critical',
            'minor'    : 'Minor',
            'cosmetic' : 'Cosmetic'
        },

        addComment: function (id, comment, callback) {
            Y.io('tickets/' + id + '/comment', {
                method: 'POST',
                form: { 
                    id     : comment,
                    upload : true,
                },
                on: { complete: _.bind(this.getTicket, this, id, callback) }
            });
        },

        select: function (tab) {
            this.tabview.selectChild(tab.get('index'));
        },

        createTicket: function (form, callback) {
            var self = this;
            Y.io('tickets/new', {
                method: 'POST',
                form: { id: form },
                on: { 
                    complete: function (i, r) {
                        var id = r.responseText;
                        self.refresh();
                        self.openTab(id);
                        callback(id);
                    }
                }
            });
        },

        saveTicket: function (id, form, callback) {
            var self = this;
            Y.io('tickets/' + id, {
                method: 'POST',
                form: { id: form },
                on: { 
                    complete: function () {
                        self.refresh();
                        self.getTicket(id, callback);
                    }
                }
            });
        },

        buildColumns: function () {
            function setText(fn, def) {
                if (!def) {
                    def = '';
                }
                return function (cell, record, column, data) {
                    Y.one(cell).set('text', fn(data) || def);
                };
            }

            var self = this,
            fmt = {
                user   : setText(_.mapFn(self.users)),
                status : setText(_.mapFn(self.status)),
                date   : 'date',
                link   : function (cell, record, column, text) {
                    var a      = Y.Node.create('<a>'), 
                    data       = record._oData,
                    id         = data.id;

                    a.setAttribute('href', data.url);
                    a.set('text', text);

                    Y.on('click', function (e) {
                        e.halt();
                        self.openTab(id);
                    }, a);

                    Y.one(cell).append(a);
                }
            };

            return [
                {   key       : 'id',
                    label     : '#',
                    sortable  : true,
                    formatter : fmt.link
                },
                {   key       : 'title',
                    label     : 'Title',
                    sortable  : true,
                    formatter : fmt.link
                },
                {   key       : 'openedBy',
                    label     : 'Opened By',
                    sortable  : true,
                    formatter : fmt.user
                },
                {   key       : 'openedOn',
                    label     : 'Opened On',
                    sortable  : true,
                    formatter : fmt.date
                },
                {   key       : 'assignedTo',
                    label     : 'Assigned To',
                    sortable  : true,
                    formatter : setText(_.mapFn(self.users), 'unassigned'),
                },
                {   key       : 'status',
                    label     : 'Status',
                    sortable  : true,
                    formatter : fmt.status
                },
                {   key       : 'lastReply',
                    label     : 'Last Reply',
                    sortable  : true,
                    formatter : fmt.date
                }
            ];
        },
        fixupEditTemplate: function () {
            var template = Y.one(this.ticketEdit),
            visibility   = template.one('.visibility');

            _.each(this.visibility, function (v, k) {
                var label = Y.Node.create('<label>'),
                radio = Y.Node.create('<input type="radio">');
                radio.set('value', k);
                radio.set('name', 'visibility');
                label.append(radio);
                label.append(v);
                visibility.append(label);
            });
            
            fillSelect(template.one('[name=severity]'), this.severity);
            fillSelect(template.one('[name=assignedTo]'), this.users);
        },
        refresh: function () {
            var table = this.datatable,
            state     = table.getState,
            request   = table.get('generateRequest')(state, table);
            this.datasource.sendRequest(request, {
                success  : table.onDataReturnInitializeTable,
                scope    : table,
                argument : state,
            });
        },
        render: function () {
            var self = this;

            self.fixupEditTemplate();

            mkButton('#new-ticket').on('click', function () {
                Ticket.create(self, {
                    severity   : 'minor',
                    visibility : 'public'
                }).edit(_.bind(self.createTicket, self));
            });
            mkButton('#subscribe');
            mkButton('#filter');
            self.tabview.render();
            self.datatable = new YAHOO.widget.DataTable(
                'datatable',
                self.columns,
                self.datasource,
                {   initialRequest: 'sort=lastReply&dir=desc&startIndex=0&results=25',
                    dynamicData: true,
                    sortedBy: { key: "lastReply", dir:YAHOO.widget.DataTable.CLASS_DESC },
                    paginator: new YAHOO.widget.Paginator({ rowsPerPage: 25 })
                }
            );
            self.datatable.handleDataReturnPayload = function(req, res, pl) {
                pl.totalRecords = res.meta.totalRecords;
                return pl;
            };
        },
        buildDatasource: function (url) {
            function parseDate(str) {
                try { 
                    return Date.parse(str);
                }
                catch (e) { 
                    return false;
                }
            }

            var source = new YAHOO.util.DataSource(url);
            source.responseType = YAHOO.util.DataSource.TYPE_JSON;
            source.responseSchema = { 
                resultsList: 'records',
                metaFields: { totalRecords : 'total' },
                fields: [
                    { key: 'id',         parser: 'number'  },
                    { key: 'url',        parser: 'string'  },
                    { key: 'title',      parser: 'string'  },
                    { key: 'openedBy',   parser: 'string'  },
                    { key: 'openedOn',   parser: parseDate },
                    { key: 'assignedTo', parser: 'string'  },
                    { key: 'status',     parser: 'string'  },
                    { key: 'lastReply',  parser: parseDate }
                ]
            };
            return source;
        },
        create: function (args) {
            var self = Y.Object(this), node;

            _.each(['ticketView', 'ticketEdit', 'users'], function (k) {
                self[k] = args[k];
            });
            self.users      = args.users;
            self.tabs       = {};
            self.datasource = self.buildDatasource(args.datasource);
            self.columns    = self.buildColumns();

            self.tabview = new Y.TabView({
                children: [ 
                    { label: 'Tickets', panelNode: Y.one('#main-tab') } 
                ]
            });

            return self;
        },

        closeTab: function (id) {
            var tab = this.tabs[id];
            delete this.tabs[id];
            tab.remove();
        },

        getTicket: function (id, callback) {
            Y.io('tickets/' + id, { 
                on: { success: ticketResponse(callback) } 
            });
        },

        openTab: function (id) {
            var self = this,
            tab = self.tabs[id],
            template, closer, self;

            if (tab) {
                self.select(tab);
                return tab;
            }

            self.getTicket(id, function (data) {
                tab = self.tabs[id] = new Y.Tab({
                    panelNode : Ticket.create(self, data).render(),
                    label     : id.toString() 
                });

                closer = _.bind(self.closeTab, self, id);
                tab.after('render', function () {
                    var a = Y.Node.create('<a> x</a>');
                    Y.on('click', closer, a);
                    tab.get('boundingBox').one('a').append(a);
                });

                self.tabview.add(tab);
                self.select(tab);
            });
        }
    },
    helpdesk = Helpdesk.create({
        ticketView: '#ticket-view-template',
        ticketEdit: '#ticket-edit-template',
        users: {
            'pdriver'  : 'Paul Driver',
            'dbell'    : 'Doug Bell',
            'fldillon' : 'Frank Dillon',
            'xtopher'  : 'Chris Palamera',
            'vrby'     : 'Jamie Vrbsky'
        },
        datasource: 'datasource?'
    });

    Y.on('domready', _.bind(Helpdesk.render, helpdesk));
});
