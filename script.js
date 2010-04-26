/*global YUI */

YUI({filter: 'raw'}).use('yui2-dragdrop', 'yui2-datatable', 'node', 'tabview', 'event', function (Y) {
    var YAHOO = Y.YUI2;

    var Helpdesk = {
        status: {
            'pending'      : 'Pending',
            'acknowledged' : 'Acknowledged',
            'waiting'      : 'Waiting On External',
            'feedback'     : 'Feedback Requested',
            'confirmed'    : 'Confirmed',
            'resolved'     : 'Resolved'
        },

        columns: function () {
            function lookup(map) {
                return function(key) {
                    return map[key];
                };
            }

            function set_text(fn) {
                return function (cell, record, column, data) {
                    Y.one(cell).set('text', fn(data));
                };
            }

            var self = this;
            var fmt = {
                user   : set_text(lookup(self.users)),
                status : set_text(lookup(self.status)),
                date   : 'date',
                link   : function (cell, record, column, t) {
                    var a = Y.Node.create('<a>'), data = record._oData;
                    a.setAttribute('href', data.url);
                    a.set('text', t);
                    Y.on('click', function (e) {
                        var tab = self.open_tab(data)
                        self.tabview.selectChild(tab.get('index'));
                        e.halt();
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
                {   key       : 'opened_by',
                    label     : 'Opened By',
                    sortable  : true,
                    formatter : fmt.user
                },
                {   key       : 'opened_on',
                    label     : 'Opened On',
                    sortable  : true,
                    formatter : fmt.date
                },
                {   key       : 'assigned_to',
                    label     : 'Assigned To',
                    sortable  : true,
                    formatter : fmt.user
                },
                {   key       : 'status',
                    label     : 'Status',
                    sortable  : true,
                    formatter : fmt.status
                },
                {   key       : 'last_reply',
                    label     : 'Last Reply',
                    sortable  : true,
                    formatter : fmt.date
                }
            ];
        },
        render: function () {
            this.tabview.render();
        },
        datasource: function (tickets) {
            function parseDate(str) {
                try { 
                    return Date.parse(str);
                }
                catch(e) { 
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
                    { key: 'opened_by',   parser: 'string'  },
                    { key: 'opened_on',   parser: parseDate },
                    { key: 'assigned_to', parser: 'string'  },
                    { key: 'status',      parser: 'string'  },
                    { key: 'last_reply',  parser: parseDate }
                ]
            };
            return source;
        },
        create: function (args) {
            var self       = Y.Object(this);
            self.tabs      = {};
            self.users     = args.users;
            self.datatable = new YAHOO.widget.DataTable(
                document.createElement('div'),
                self.columns(), 
                self.datasource(args.tickets)
            );

            var node = Y.one(self.datatable.get('element'));
            node.addClass('yui3-tab-panel');

            self.tabview = new Y.TabView({
                children: [ { label: 'Tickets', panelNode: node } ]
            });

            return self;
        },

        close_tab: function(id) {
            var tab = this.tabs[id];
            delete this.tabs[id];
            tab.remove();
        },

        open_tab: function (data) {
            var id = data.id, tab = this.tabs[id];

            if (tab) {
                return tab;
            }

            tab = this.tabs[id] = new Y.Tab({
                content : "foobaz",
                label   : id.toString() 
            });

            var closer = Y.bind(this.close_tab, this, id);
            tab.after('render', function () {
                var a = Y.Node.create('<a> x</a>');
                Y.on('click', closer, a);
                tab.get('boundingBox').one('a').append(a);
            });

            this.tabview.add(tab);
            return tab;
        }
    };

    var helpdesk = Helpdesk.create({
        users: {
            'pdriver'  : 'Paul Driver',
            'dbell'    : 'Doug Bell',
            'fldillon' : 'Frank Dillon',
            'xtopher'  : 'Chris Palamera',
            'vrby'     : 'Jamie Vrbsky'
        },
        tickets: [
            {   id          : '12049',
                url         : 'http://the.real.url/no_for_real/12049',
                title       : 'My dog has no nose',
                opened_by   : 'dbell',
                opened_on   : '2010-01-02 09:53',
                assigned_to : 'pdriver',
                assigned_on : '2010-01-02 11:00',
                assigned_by : 'vrby',
                status      : 'pending',
                last_reply  : '2010-04-22 12:00',
                visibility  : 'public',
                severity    : 'critical',
                keywords    : 'squad, tell the, joke',
                webgui      : '7.7.29',
                wre         : '0.9.3',
                os          : 'Beige Pants',
                comments    : [
                    {   timestamp  : '2010-01-02 09:53',

                        author     : 'doug',
                        body       : "my dog has no nose. It's a golden labrador and now he doesn't eat or play with the kids like used to. He doesn't smile or lick his lips or drink his soup with a straw or anything.  I've attached a picture of him. Please help.",
                        attachment : {
                            url  :  '/uploads/fd/fd76868768sfsf762/BobbyTables.jpg',
                            name : 'Bobby Tables.jpg',
                            size : 280000
                        },
                        status: 'pending'
                    },
                    {   timestamp  : '2010-01-02 10:34',
                        author     : 'pdriver',
                        body       : 'how does he smell?',
                        status     : 'feedback'
                    },
                    {   timestamp  : '2010-01-02 11:01',
                        author     : 'dbell',
                        body       : 'Terrible.',
                        status     : 'pending'
                    }
                ]
            }
        ]
    });

    Y.on('available', Y.bind(Helpdesk.render, helpdesk), '#container');
});
