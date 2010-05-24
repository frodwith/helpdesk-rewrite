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

YUI({filter: 'raw'}).use('gallery-overlay-modal', 'yui2-dragdrop', 'yui2-datatable', 'yui2-button', 'node', 'tabview', 'overlay', 'event', function (Y) {

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
                return map[get(a)];
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
            '.keywords@value'   : 'keywords',
            '.webgui@value'     : 'webgui',
            '.wre@value'        : 'wre',
            '.os@value'         : 'os'
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
                        '.status'      : status(item('status'))
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

        edit: function () {
            var data = this.data,
            template = this.helpdesk.ticketEdit,
            rendered = pure(template, data, this.editDirectives),
            vinputs  = rendered.all('.visibility input'),
            overlay, background, close;

            close = function () {
                overlay.destroy();
            };

            _.detect(Y.NodeList.getDOMNodes(vinputs), function (radio) {
                return radio.value === data.visibility;
            }).checked = true;

            rendered.one('.severity').set('value', data.severity);
            rendered.one('.assignedTo').set('value', data.assignedTo);
            rendered.one('.cancel').on('click', close);

            mkButton(rendered.one('.close')).on('click', close);
            mkButton(rendered.one('.cancel')).on('click', close);

            mkButton(rendered.one('.save')).on('click', 
                _.bind(this.editSave, this, rendered, close));
            
            overlay = new Y.Overlay({
                srcNode   : rendered,
                zIndex    : 2,
                centered  : true,
            });
            overlay.plug(Y.Plugin.OverlayModal).render();
        },

        editSave: function (editor, cb) {
            var self = this,
            data     = _.clone(this.data),
            radios   = editor.one('.visibility').all('input');

            data.visibility =
            _.detect(Y.NodeList.getDOMNodes(radios), function (r) {
                return r.checked;
            }).value;

            _.each(['severity', 'keywords', 'assignedTo', 
            'webgui', 'wre', 'os'], function(k) {
                data[k] = editor.one('.' + k).get('value');
            });

            this.helpdesk.saveTicket(data, function (data) {
                self.update(data);
                cb();
            });
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
            var template = this.helpdesk.ticketView,
            r            = pure(template, this.data, this.viewDirectives()),
            node         = this.node = Y.Node.create('<div>')
                .addClass('yui3-tab-panel')
                .append(r);

            mkButton(node.one('.edit-button'))
                .on('click', _.bind(this.edit, this));

            mkButton(node.one('.reply'))
                .on('click', _.bind(this.reply, this));

            fillSelect(node.one('[name=status]'), this.helpdesk.status);

            return this.node;
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

        addComment: function (id, comment, cb) {
            var fake = _.clone(this.tickets[id].data),
            c  = {   
                timestamp  : Date.now().toString('yyyy-MM-dd HH:mm'),
                author     : 'dbell',
                body       : comment.get('comment').get('value'),
                status     : comment.get('status').get('value')
            };
            fake.comments.push(c);
            cb(fake);
        },

        saveTicket: function (t, cb) {
            cb(t);
        },

        columns: function () {
            function setText(fn) {
                return function (cell, record, column, data) {
                    Y.one(cell).set('text', fn(data));
                };
            }

            var self = this,
            fmt = {
                user   : setText(_.mapFn(self.users)),
                status : setText(_.mapFn(self.status)),
                date   : 'date',
                link   : function (cell, record, column, text) {
                    var a      = Y.Node.create('<a>'), 
                    id         = record._oData.id;

                    a.setAttribute('href', self.tickets[id].data.url);
                    a.set('text', text);

                    Y.on('click', function (e) {
                        var tab;
                        e.halt();
                        tab = self.openTab(id);
                        self.tabview.selectChild(tab.get('index'));
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
                    formatter : fmt.user
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
            
            fillSelect(template.one('.severity'), this.severity);
            fillSelect(template.one('.assignedTo'), this.users);
        },
        render: function () {
            this.fixupEditTemplate();
            this.tabview.render();
        },
        datasource: function (tickets) {
            function parseDate(str) {
                try { 
                    return Date.parse(str);
                }
                catch (e) { 
                    return false;
                }
            }

            var source = new YAHOO.util.DataSource(tickets);
            source.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
            source.responseSchema = { 
                fields: [
                    { key: 'id',          parser: 'number'  },
                    { key: 'url',         parser: 'string'  },
                    { key: 'title',       parser: 'string'  },
                    { key: 'openedBy',   parser: 'string'  },
                    { key: 'openedOn',   parser: parseDate },
                    { key: 'assignedTo', parser: 'string'  },
                    { key: 'status',      parser: 'string'  },
                    { key: 'lastReply',  parser: parseDate }
                ]
            };
            return source;
        },
        create: function (args) {
            var self = Y.Object(this),
            tickets  = args.tickets,
            node;

            _.each(['ticketView', 'ticketEdit', 'users'], function (k) {
                self[k] = args[k];
            });
            self.users   = args.users;
            self.tabs    = {};
            self.tickets = {};

            _(tickets).chain()
                .map(_.bind(Ticket.create, Ticket, self))
                .each(function (t) {
                    self.tickets[t.data.id] = t;
                });

            self.datatable = new YAHOO.widget.DataTable(
                document.createElement('div'),
                self.columns(), 
                self.datasource(tickets)
            );

            node = Y.one(self.datatable.get('element'));
            node.addClass('yui3-tab-panel');

            self.tabview = new Y.TabView({
                children: [ { label: 'Tickets', panelNode: node } ]
            });

            return self;
        },

        closeTab: function (id) {
            var tab = this.tabs[id];
            delete this.tabs[id];
            tab.remove();
        },

        openTab: function (id) {
            var tab = this.tabs[id],
            template, closer;

            if (tab) {
                return tab;
            }

            tab = this.tabs[id] = new Y.Tab({
                panelNode : this.tickets[id].render(),
                label     : id.toString() 
            });

            closer = _.bind(this.closeTab, this, id);
            tab.after('render', function () {
                var a = Y.Node.create('<a> x</a>');
                Y.on('click', closer, a);
                tab.get('boundingBox').one('a').append(a);
            });

            this.tabview.add(tab);
            return tab;
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
        tickets: [
            {   
                id         : '12049',
                url        : 'http://the.real.url/no_for_real/12049',
                title      : 'My dog has no nose',
                openedBy   : 'dbell',
                openedOn   : '2010-01-02 09:53',
                assignedTo : 'pdriver',
                assignedOn : '2010-01-02 11:00',
                assignedBy : 'vrby',
                status     : 'open',
                lastReply  : '2010-04-22 12:00',
                visibility : 'public',
                severity   : 'critical',
                keywords   : 'squad, tell the, joke',
                webgui     : '7.7.29',
                wre        : '0.9.3',
                os         : 'Beige Pants',
                comments   : [
                    {   
                        timestamp  : '2010-01-02 09:53',
                        author     : 'dbell',
                        body       : "my dog has no nose. It's a golden labrador and now he doesn't eat or play with the kids like he used to. He doesn't smile or lick his lips or drink his soup with a straw or anything.  I've attached a picture of him. Please help.",
                        attachments : [
                            {
                                url  :  '/uploads/fd/fd76868768sfsf762/BobbyTables.jpg',
                                name : 'Bobby Tables.jpg',
                                size : 280000
                            }
                        ],
                        status: 'open'
                    },
                    {   
                        timestamp  : '2010-01-02 10:34',
                        author     : 'pdriver',
                        body       : 'how does he smell?',
                        status     : 'feedback'
                    },
                    {   
                        timestamp  : '2010-01-02 11:01',
                        author     : 'dbell',
                        body       : 'Terrible.',
                        status     : 'open'
                    }
                ]
            }
        ]
    });

    Y.on('domready', _.bind(Helpdesk.render, helpdesk));
});
