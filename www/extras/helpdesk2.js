/*global YUI, $p, _, document, helpdesk2, window, escape */

YUI({
    groups: {
        local: {
            base: helpdesk2.base,
            modules: {
                hd2css       : {
                    path: 'helpdesk2.css',
                    type: 'css'
                },
                underscore   : { 
                    path : 'underscore.js',
                    type : 'js'
                },
                usercomplete : { 
                    path : 'usercomplete.js',
                    type : 'js'
                },
                datejs: {
                    path : 'date.js',
                    type : 'js'
                },
                pure: {
                    path : 'pure.js',
                    type : 'js'
                }
            }
        }
    },
    filter: 'raw'
}).use(
'yui2-dragdrop', 'yui2-connection', 'yui2-json', 'yui2-paginator', 
'yui2-datatable', 'yui2-button', 'yui2-calendar', 'yui2-autocomplete',
'event', 'event-custom', 'event-key', 
'underscore', 'usercomplete', 'datejs', 'pure', 'hd2css',
'history', 'node', 'tabview', 'gallery-overlay-modal', 'overlay',
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
            };
        };
    }

    // This was taking forever for large datasets (like all the user info),
    // so it's been harshly optimized.
    function fillSelect(select, o) {
        var k, str = '';
        for (k in o) {
            if (o.hasOwnProperty(k)) {
                str += '<option value="' + k + '">' + o[k] + '</option>';
            }
        }
        Y.Node.getDOMNode(select).innerHTML = str;
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

    Filter = {
        extend: function (prop) {
            var o = Y.Object(this);
            _.extend(o, prop);
            return o;
        },
        createDom: function() {
            var self = this, remover = Y.Node.create('<a class="rem">');

            remover.on('click', function () {
                self.node.remove();
                self.remove();
            });

            this.node = Y.Node.create('<tr class="filter">')
                .append(Y.Node.create('<td>').append(remover))
                .append(Y.Node.create('<td>').append(this.label))
                .append(Y.Node.create('<td>').append(this.inputs()));

            if (this.value) {
                this.setValue();
            }
            return this.node;
        },
            
        rule: function () {
            return {
                type: this.type,
                args: this.args()
            };
        }
    },
    UserFilter = Filter.extend({
        inputs: function () {
            this.complete = new Y.UserComplete({
                multiple: true,
                datasource: this.source
            });
            this.complete.render();
            return this.complete.get('boundingBox');
        },
        setValue: function () {
            this.complete.set('selectedUsers', this.value);
        },
        args: function () {
            return this.complete.get('selectedUsers');
        }
    }),
    MultiSelectFilter = Filter.extend({
        inputs: function () {
            var s = Y.Node.create('<select multiple>');
            fillSelect(s, this.options);
            return s;
        },
        setValue: function () {
            var self = this;
            _.each(self.value, function (value) {
                self.node.all('option').each(function (n) {
                    if (n.get('value') === value) {
                        n.set('selected', true);
                    }
                });
            });
        },
        args: function (r) {
            return _(this.node.all('option')._nodes).chain()
                .filter(function (e) {
                    return e.selected;
                }).map(function (e) {
                    return e.value;
                }).value();
        }
    }),
    DateRangeFilter = Filter.extend({
        inputs: function () {
            var div = Y.Node.create('<table><tr><th>From</th><th>To</th></tr><td class="from"></td><td class="to"></td></tr></table>');

            // YUI2 really wants this in-dom when we start making calendars
            Y.one('body').append(div);

            this.from = new YAHOO.widget.Calendar(
                Y.Node.getDOMNode(div.one('.from'))
            );
            this.to = new YAHOO.widget.Calendar(
                Y.Node.getDOMNode(div.one('.to'))
            );
            this.from.render();
            this.to.render();

            div.remove();
            return div;
        },
        setValue: function () {
            // YUI2 hates not being in the dom
            Y.one('body').append(this.node);
            this.setDate('to', this.value.to);
            this.setDate('from', this.value.from);
            this.node.remove();
        },
        getDate: function (which) {
            var d = this[which].getSelectedDates()[0];
            return d && d.toString('yyyy-MM-dd');
        },
        setDate: function (which, str) {
            var cal = this[which];
            cal.select(Date.parse(str));
            cal.render();
        },
        args: function () {
            return {
                from : this.getDate('from'),
                to   :  this.getDate('to')
            };
        }
    }),

    Ticket    = {
        editDirectives: {
            '[name=title]@value'      : 'title',
            '[name=keywords]@value'   : 'keywords',
            '[name=webgui]@value'     : 'webgui',
            '[name=wre]@value'        : 'wre',
            '[name=os]@value'         : 'os'
        },
        viewDirectives: function () {
            var h     = this.helpdesk,
            status    = lookup(h.status);

            return {
                '.id'    : 'id',
                '.title' : 'title',
                '.comments' : {
                    'c<-comments' : {
                        '.timestamp'   : 'c.timestamp',
                        '.author'      : 'c.author.fullname',
                        '.author@href' : 'c.author.profile',
                        '@class+'      : function (a) {
                            return a.pos % 2 ? ' odd' : ' even';
                        },
                        '.body'        : function (a) {
                            return a.item.body
                                .replace(/\n/g, '<br>')
                                .replace(/ {2}/g, ' &nbsp;');
                        },
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
                '.url@href'        : 'url',
                '.webgui'          : 'webgui',
                '.wre'             : 'wre',
                '.os'              : 'os',
                '.assignedTo'      : 'assignedTo.fullname',
                '.assignedTo@href' : 'assignedTo.profile',
                '.assignedOn'      : 'assignedOn',
                '.assignedBy'      : 'assignedBy.fullname',
                '.assignedBy@href' : 'assignedBy.profile'
            };
        },

        reply: function () {
            this.helpdesk.addComment(
                this.data.id, this.node.one('.new-comment'),
                _.bind(this.update, this)
            );
        },

        edit: function (save) {
            var self = this, keylisten,
            data     = self.data,
            helpdesk = self.helpdesk,
            template = helpdesk.ticketEdit,
            form     = pure(template, data, self.editDirectives),
            vinputs  = form.all('.visibility input'),
            complete = form.one('[name=assignedTo]').get('parentNode'),
            overlay  = new Y.Overlay({
                srcNode   : form,
                zIndex    : 2,
                centered  : true
            }).plug(Y.Plugin.OverlayModal),
            close    = function () {
                keylisten.detach();
                try { 
                    // This sometimes breaks
                    overlay.destroy(); 
                }
                catch (e) {
                    // But we don't care when it does.
                }
                delete helpdesk.closeDialog;
            };

            _.detect(Y.NodeList.getDOMNodes(vinputs), function (radio) {
                return radio.value === data.visibility;
            }).checked = true;

            form.one('[name=severity]').set('value', data.severity);

            form.all('input').each(function () {
                this.on('change', _.bind(this.addClass, this, 'changed'));
            });

            mkButton(form.one('.close')).on('click', close);
            mkButton(form.one('.cancel')).on('click', close);

            save = _.bind(save, null, form, close);

            mkButton(form.one('.save')).on('click', save);

            keylisten = Y.on('key', function (e) {
                e.preventDefault();
                form.all('input').each(function (el) {
                    el.blur();
                });
                save();
            }, 'body', 'down:13');

            helpdesk.closeDialog = close;
            overlay.render();
            
            // We have to do this AFTER render, or the autocomplete won't be
            // in the document (and YUI2 would hate that)
            new Y.UserComplete({
                srcNode : complete,
                selectedUsers : [data.assignedTo],
                datasource: helpdesk.usersource
            }).render();
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
            helpdesk     = self.helpdesk,
            template     = helpdesk.ticketView,
            r            = pure(template, self.data, self.viewDirectives()),
            node         = self.node = Y.Node.create('<div>').append(r),
            editButton   = node.one('.edit-button'),
            status;

            if (helpdesk.staff || self.data.owner) {
                mkButton(editButton).on('click', function () {
                    self.edit(function (form, done) {
                        helpdesk.saveTicket(self.data.id, form, 
                            function (ticket) {
                                self.update(ticket);
                                done();
                            });
                    });
                });
            }
            else {
                editButton.remove();
            }

            if (helpdesk.reporter) {
                status = node.one('[name=status]');
                fillSelect(status, helpdesk.status);
                status.set('value', self.data.status);
                if (!helpdesk.staff && !self.data.owner) {
                    status.setAttribute('disabled', 'disabled');
                }

                mkButton(node.one('.reply'))
                    .on('click', _.bind(self.reply, self));

                var makeAttacher = function (node) {
                    var handle = node.one('input').on('change', function (e) {
                        var box = this.get('parentNode'),
                        remover = Y.Node.create('<a>x</a>'),
                        // file input clones behave inconsistently across browsers
                        next    = box.cloneNode(false),
                        name    = box.one('input').getAttribute('name');

                        next.append('<input type="file" name="' + name + '">');
                        handle.detach();
                        box.appendChild(remover);
                        box.get('parentNode').appendChild(next);
                        makeAttacher(next);
                        mkButton(remover).on('click', _.bind(box.remove, box));
                    });
                };
                makeAttacher(node.one('.attach-box'));
            }
            else {
                node.one('.new-comment').remove();
            }

            self.on('helpdesk:subscriptionChanged', function () {
                self.node.one('.subscribe button').
                    set('text', helpdesk.i18n(
                        self.data.subscribed ? 'Unsubscribe' : 'Subscribe'
                    ));
            });

            mkButton(node.one('.subscribe')).on('click', function () {
                helpdesk.toggleSubscription(self.data.id, function (status) {
                    self.data.subscribed = status;
                    self.fire('helpdesk:subscriptionChanged');
                });
            });

            self.fire('helpdesk:subscriptionChanged');

            return node;
        },

        create: function (helpdesk, data) {
            var self      = Y.Object(this);
            self.helpdesk = helpdesk;
            self.data     = data;
            Y.augment(self, Y.EventTarget);
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

        getState: function () {
            var selection = this.tabview.get('selection'),
            tickets      = _(this.tabs).chain().values().sortBy(function (t) {
                return t.get('index');
            }).map(function (t) {
                return t.get('label');
            }).value(),
            label = selection && 
                selection.get('index') && 
                selection.get('label');

            return Y.JSON.stringify({
                open    : label || null, 
                tickets : tickets,
                filter  : this.filter
            });
        },

        updateFromState: function (state) {
            if(this.updating) {
                return;
            }
            this.updating = 1;

            var self      = this,
            currentlyOpen = _.clone(self.tabs),
            filter;

            state = Y.JSON.parse(state);
            filter = self.filter = state.filter;
            if (filter) {
                self.clearFilters();
                _.each(self.filter.rules, _.bind(self.addRule, self));
                Y.one(self.filterDom)
                    .one('.conjunction')
                    .set('value', filter.match);
            }
            self.refresh();

            _.each(state.tickets, function (id) {
                if (id in currentlyOpen) {
                    delete currentlyOpen[id];
                }
                else {
                    self.openTab(id);
                }
            });
            _(currentlyOpen).chain().keys().each(_.bind(self.closeTab, self));
            if (state.open) {
                self.select(self.tabs[state.open]);
            }
            else {
                self.select(self.mainTab);
            }
            if (self.closeDialog) {
                self.closeDialog();
            }
            Y.one(self.share).one('a')
                .setAttribute('href', window.location);

            delete this.updating;
        },

        addComment: function (id, comment, callback) {
            var self = this;
            Y.io(self.appUrl({func: 'comment', ticketId: id}), {
                method: 'POST',
                form: { 
                    id     : comment,
                    upload : true
                },
                on: { 
                    complete: function() {
                        self.refresh();
                        self.getTicket(id, callback);
                    }
                }
            });
        },

        select: function (tab) {
            this.tabview.selectChild(tab.get('index'));
        },

        ticketUrl: function (id) {
            return this.appUrl({func: 'ticket', ticketId: id});
        },

        createTicket: function (form, callback) {
            var self = this;
            Y.io(self.ticketUrl('new'), {
                method: 'POST',
                form: { id: form },
                on: { 
                    complete: function (i, r) {
                        var id = r.responseText;
                        self.refresh();
                        self.openTab(id, true);
                        callback(id);
                    }
                }
            });
        },

        saveTicket: function (id, form, callback) {
            var self = this;
            Y.io(self.ticketUrl(id), { 
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
            var self = this, fmt, columns;

            function setText(fn, def) {
                def = (def === undefined) ? '' : self.i18n(def);
                return function (cell, record, column, data) {
                    Y.one(cell).set('text', fn(data) || def);
                };
            }

            function userLink(field, def) {
                return function (cell, record, column) {
                    var d = record._oData,
                    name  = d[field + '.fullname'],
                    url   = d[field + '.profile'];
                    cell  = Y.one(cell);

                    if (name) {
                        cell.append(Y.Node.create('<a>')
                            .setAttribute('href', url)
                            .set('text', name));
                    }
                    else {
                        cell.set('text', self.i18n(def));
                    }
                };
            }

            fmt = {
                status : setText(function (k) { 
                    return self.status[k]; 
                }),
                date   : 'date',
                link   : function (cell, record, column, text) {
                    var a      = Y.Node.create('<a>' + text + '</a>'), 
                    data       = record._oData,
                    id         = data.id;

                    a.setAttribute('href', data.url);

                    Y.on('click', function (e) {
                        e.halt();
                        self.openTab(id, true);
                    }, a);

                    Y.one(cell).append(a);
                }
            };

            columns = [
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
                    formatter : userLink('openedBy')
                },
                {   key       : 'openedOn',
                    label     : 'Opened On',
                    sortable  : true,
                    formatter : fmt.date
                },
                {   key       : 'assignedTo',
                    label     : 'Assigned To',
                    sortable  : true,
                    formatter : userLink('assignedTo', 'unassigned')
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
            _.each(columns, function (c) {
                c.label = self.i18n(c.label);
            });
            return columns;
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
        },
        centerFilters: function () {
            if (this.filterOverlay) {
                this.filterOverlay.set('centered', true);
            }
        },
        addRule: function (r) {
            var self = this, 
            id       = Y.guid(), 
            dom      = Y.one(self.filterDom), 
            row, rule, 
            p = {
                type   : r.type,
                label  : Y.one(
                _.detect(dom.all('.type option')._nodes, function (o) {
                    return o.value === r.type;
                })).get('text'),
                value  : r.args,
                remove : function () {
                    delete self.rules[id];
                    self.centerFilters();
                }
            };
            switch (r.type) {
                case 'status':
                    p.options = self.status;
                    rule = MultiSelectFilter.extend(p);
                    break;
                case 'assignedTo':
                case 'openedBy':
                    p.source = self.usersource;
                    rule = UserFilter.extend(p);
                    break;
                case 'openedOn':
                case 'lastReply':
                    rule = DateRangeFilter.extend(p);
                    break;
            }
            self.rules[id] = rule;
            row = dom.one('.addrow');
            row.insert(rule.createDom(), row);
            self.centerFilters();
        },

        buildFilter: function () {
            this.filter = {
                match: Y.one(this.filterDom)
                    .one('.conjunction').get('value'),
                rules: _(this.rules).chain().values().map(function (r) {
                    return r.rule();
                }).value()
            };
        },

        fixupFilterDialog: function () {
            var self = this, 
            close    = function () {
                self.filterOverlay.hide();
            },
            search = function () {
                self.buildFilter();
                self.refresh();
                self.mark();
                close();
            },
            dom = Y.one(self.filterDom);

            dom.all('button').each(mkButton);

            dom.one('.close').on('click', close);
            dom.one('.search').on('click', search);
            dom.one('.reset').on('click', function () {
                self.clearFilters();
                search();
            });

            dom.one('.add').on('click', function () {
                self.addRule({type: dom.one('.type').get('value')});
            });
        },
        clearFilters: function () {
            this.rules = {};
            Y.one(this.filterDom).all('.filter').remove();
            this.centerFilters();
        },
        refresh: function () {
            var table = this.datatable, state, request;
            if (!table) {
                return;
            }
            state   = table.getState();
            request = table.get('generateRequest')(state, table);
            this.ticketsource.sendRequest(request, {
                success  : table.onDataReturnInitializeTable,
                scope    : table,
                argument : state
            });
        },
        toggleSubscription: function (id, callback) {
            var data = {};
            if (id) {
                data.ticketId = id;
            }
            Y.io(this.appUrl({func: 'toggleSubscription'}), {
                method: 'POST',
                data: data,
                on: {
                    success: function (i, r) {
                        callback(r.responseText === 'subscribed');
                    }
                }
            });
        },
        render: function () {
            var self = this, dialog, dt, old;

            self.fixupEditTemplate();
            self.fixupFilterDialog();

            if (self.reporter) {
                mkButton(self.newTicket).on('click', function () {
                    Ticket.create(self, {
                        severity   : 'minor',
                        visibility : 'public'
                    }).edit(_.bind(self.createTicket, self));
                });
            } 
            else {
                Y.one(self.newTicket).remove();
            }

            self.filterOverlay = dialog = new Y.Overlay({
                zIndex    : 2,
                centered  : true,
                srcNode   : Y.one(self.filterDom).remove()
                                .setStyle('display', 'block')
            }).plug(Y.Plugin.OverlayModal);
            dialog.hide();
            dialog.render();

            mkButton(self.filterButton).on('click', function () {
                dialog.show();
            });

            self.on('helpdesk:subscriptionChanged', function () {
                Y.one(self.subscribeButton).one('button')
                    .set('text', self.i18n(
                        self.subscribed ? 'Unsubscribe' : 'Subscribe'
                     ));
            });

            mkButton(self.subscribeButton).on('click', function () {
                self.toggleSubscription(null, function (status) {
                    self.subscribed = status;
                    self.fire('helpdesk:subscriptionChanged');
                });
            });

            self.on('helpdesk:config', function () {
                self.fire('helpdesk:subscriptionChanged');
            });
            self.tabview.render(self.root);
            self.datatable = dt = new YAHOO.widget.DataTable(
                'datatable',
                self.columns,
                self.ticketsource,
                {   initialRequest: self.addFilter(
                        'sort=lastReply&dir=desc&startIndex=0&results=25'
                    ),
                    dynamicData: true,
                    sortedBy: { 
                        key: "lastReply", 
                        dir: YAHOO.widget.DataTable.CLASS_DESC 
                    },
                    paginator: new YAHOO.widget.Paginator({ rowsPerPage: 25 })
                }
            );
            dt.handleDataReturnPayload = function(req, res, pl) {
                pl.totalRecords = res.meta.totalRecords;
                return pl;
            };
            old = dt.get('generateRequest');
            dt.set('generateRequest', function (state, dt) {
                return self.addFilter(old(state, dt));
            });
        },
        addFilter: function (url) {
            return this.filter ?
                url + ';filter=' + escape(Y.JSON.stringify(this.filter)) :
                url;
        },
        buildUsersource: function (url) {
            var source            = new YAHOO.util.DataSource(url);
            source.responseType   = YAHOO.util.DataSource.TYPE_JSON;
            source.responseSchema = { 
                resultsList : 'users',
                fields      : ['fullname', 'id', 'username', 'profile']
            };
            return source;
        },
        buildTicketsource: function (url) {
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
                    { key: 'id',                  parser: 'number'  },
                    { key: 'url',                 parser: 'string'  },
                    { key: 'title',               parser: 'string'  },
                    { key: 'openedBy.profile',    parser: 'string'  },
                    { key: 'openedBy.fullname',   parser: 'string'  },
                    { key: 'openedOn',            parser: parseDate },
                    { key: 'assignedTo.profile',  parser: 'string'  },
                    { key: 'assignedTo.fullname', parser: 'string'  },
                    { key: 'status',              parser: 'string'  },
                    { key: 'lastReply',           parser: parseDate }
                ]
            };
            return source;
        },
        extend: function (args) {
            var self = Y.Object(this);
            _.extend(self, args);
            Y.augment(self, Y.EventTarget);
            self.usernames    = {};
            self.rules        = {};
            self.tabs         = {};
            self.usersource   = 
                self.buildUsersource(self.appUrl({func: 'userSource'}));
            self.ticketsource 
                = self.buildTicketsource(self.appUrl({func: 'ticketSource'}));
            self.mainTab      = new Y.Tab({
                label: 'Tickets', 
                panelNode: Y.one(args.mainTab)
            });

            self.tabview = new Y.TabView({ children: [ self.mainTab ] });
            self.tabview.after('selectionChange', _.bind(self.mark, self));

            self.publish('helpdesk:ready', { fireOnce : true });
            self.publish('helpdesk:config', { fireOnce : true });

            Y.io(self.appUrl({func: 'config'}), {
                on: {
                    complete: function (id, r) {
                        r = Y.JSON.parse(r.responseText);
                        _.extend(self, r);
                        _.each(['status', 'visibility', 'severity'], 
                            function(name) {
                                var o = self[name];
                                _.each(o, function (v, k) {
                                    o[k] = self.i18n(v);
                                });
                            });
                        self.mainTab.set('label', self.i18n(
                            self.mainTab.get('label')
                        ));
                        self.columns = self.buildColumns();
                        self.fire('helpdesk:config');
                    }
                }
            });

            Y.History.on('history:ready', function () {
                Y.on('domready', function () {
                    self.on('helpdesk:config', function () {
                        Y.all('.i18n').each(function (n) {
                            n.set('text', self.i18n(n.get('text')));
                        });
                        self.fire('helpdesk:ready');
                    });
                });
            });

            self.registerHistory();
            self.on('helpdesk:ready', _.bind(self.render, self));

            return self;
        },

        i18n: function (key) {
            // Put #s around keys we don't have a string for as a fixme
            return this.strings[key] || ('#' + key + '#');
        },

        mark: function () {
            /* We will not mark the state while we're in the process of making
             * the state consistent.  It screws up the history and can cause
             * bad oscillation between states. */
            if (!this.updating) {
                Y.History.navigate('helpdesk', this.getState());
            }
        },

        closeTab: function (id) {
            var tab = this.tabs[id];
            delete this.tabs[id];
            tab.remove();
        },

        userData: function (id, fn) {
            Y.io(this.appUrl({func: 'user', userId: id}), {
                on: {
                    complete: function (i, r) {
                        fn(Y.JSON.parse(r.responseText));
                    }
                }
            });
        },

        getTicket: function (id, callback) {
            Y.io(this.ticketUrl(id), { 
                on: { success: ticketResponse(callback) } 
            });
        },
        
        registerHistory: function() {
            var self = this,
            initial  = Y.History.getBookmarkedState(self.assetId),
            update   = function (state) {
                self.on('helpdesk:config', function () {
                    self.updateFromState(state);
                });
            };

            if (initial) {
                update(initial);
            }
            else {
                initial = '{open: null, tickets: []}';
            }
            Y.History.register('helpdesk', initial)
                .on('history:moduleStateChange', update);
        },

        appUrl: function(params) {
            var url = this.app + '?';
            _.each(params, function (v, k) {
                url += escape(k) + '=' + escape(v) + '&';
            });
            return url;
        },

        openTab: function (id, select) {
            var self = this,
            tab = self.tabs[id],
            closer;

            if (!tab) {
                tab = self.tabs[id] = new Y.Tab({
                    content   : 'Loading...',
                    label     : id.toString()
                });
                closer = _.bind(self.closeTab, self, id);
                tab.after('render', function () {
                    var a = Y.Node.create('<a>');
                    Y.on('click', closer, a);
                    tab.get('boundingBox').one('a').append(a);
                    self.getTicket(id, function (data) {
                        var content = Ticket.create(self, data).render();
                        tab.get('panelNode').setContent(content);
                    });
                });
                self.tabview.add(tab);
            }
            if (select) {
                self.select(tab);
            }
        }
    },
    helpdesk = Helpdesk.extend({
        app             : helpdesk2.app,
        assetId         : 'helpdesk',
        root            : '#helpdesk',
        ticketView      : '#ticket-view-template',
        ticketEdit      : '#ticket-edit-template',
        mainTab         : '#main-tab',
        filterDom       : '#filter-dialog',
        newTicket       : '#new-ticket',
        filterButton    : '#filter',
        subscribeButton : '#subscribe',
        share           : '#share-this'
    });

    Y.on('domready', function () {
        Y.History.initialize('#yui-history-field', '#yui-history-iframe');
    });
});
