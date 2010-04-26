/*global YUI */

YUI({filter: 'raw'}).use(
    'yui2-dragdrop', 
    'yui2-datatable', 
    'node',
    'tabview',
    'event', function (Y) {
        var YAHOO = Y.YUI2, tickets, dt, fmt, status, users, i, open_tab, tabs;

        function parse_date(str) {
            try { 
                return Date.parse(str);
            }
            catch(e) { 
                return false;
            }
        }

        function lookup(map) {
            return function(key) {
                return map[key];
            }
        }

        function set_text(fn) {
            return function (cell, record, column, data) {
                cell.appendChild(document.createTextNode(fn(data)));
            };
        }

        function digits(n, digits) {
            var str = n.toString();
            var diff = digits - str.length;
            for (var i = 0; i < diff; i += 1) {
                str = '0' + str;
            }
            return str;
        }

        var tabs = {};
        open_tab = function (data) {
            var id = data.id, tab = tabs[id];
            if (tab) {
                return tab;
            }
            tab = tabs[id] = new Y.Tab(
                {   content : "foobaz",
                    label   : id.toString() 
                }
            );
            tab.after('render', function () {
                var a = document.createElement('a');
                a.appendChild(document.createTextNode(' x'));
                Y.on('click', function () {
                    tab.remove();
                }, a);
                tab.get('boundingBox').one('a').append(a);
            });
            tabs.add(tab);
            return tab;
        };

        tickets = [
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
        ];

        status = {
            'pending'      : 'Pending',
            'acknowledged' : 'Acknowledged',
            'waiting'      : 'Waiting On External',
            'feedback'     : 'Feedback Requested',
            'confirmed'    : 'Confirmed',
            'resolved'     : 'Resolved'
        };

        users = {
            'pdriver'  : 'Paul Driver',
            'dbell'    : 'Doug Bell',
            'fldillon' : 'Frank Dillon',
            'xtopher'  : 'Chris Palamera',
            'vrby'     : 'Jamie Vrbsky'
        };


        fmt = {
            user   : set_text(lookup(users)),
            status : set_text(lookup(status)),
            date   : 'date',
            link   : function (cell, record, column, data) {
                var a = document.createElement('a');
                a.href = record._oData.url;
                a.appendChild(document.createTextNode(data));
                Y.on('click', function (e) {
                    var tab = open_tab(record._oData);
                    tab.get('parent').selectChild(tab);
                    e.halt();
                }, a);
                cell.appendChild(a);
            },
        };

        dt = {
            columns: [
                {   key       : 'id',
                    label     : '#',
                    formatter : fmt.link
                },
                {   key       : 'title',
                    label     : 'Title',
                    formatter : fmt.link
                },
                {   key       : 'opened_by',
                    label     : 'Opened By',
                    formatter : fmt.user
                },
                {   key       : 'opened_on',
                    label     : 'Opened On',
                    formatter : fmt.date
                },
                {   key       : 'assigned_to',
                    label     : 'Assigned To',
                    formatter : fmt.user
                },
                {   key       : 'status',
                    label     : 'Status',
                    formatter : fmt.status
                },
                {   key       : 'last_reply',
                    label     : 'Last Reply',
                    formatter : fmt.date
                }
            ],
            source: new YAHOO.util.DataSource(tickets),
            widget: null
        };

        for (i = 0; i < dt.columns.length; i += 1) {
            dt.columns[i].sortable = true;
        }

        dt.source.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
        dt.source.responseSchema = { 
            fields: [
                { key: 'id',          parser: 'number'   },
                { key: 'url',         parser: 'string'   },
                { key: 'title',       parser: 'string'   },
                { key: 'opened_by',   parser: 'string'   },
                { key: 'opened_on',   parser: parse_date },
                { key: 'assigned_to', parser: 'string'   },
                { key: 'status',      parser: 'string'   },
                { key: 'last_reply',  parser: parse_date }
            ]
        };

        Y.on('available', function () {
            dt.node   = document.createElement('div');
            dt.widget = new YAHOO.widget.DataTable(
                dt.node, dt.columns, dt.source
            );
            dt.node   = Y.one(dt.node);
            dt.node.addClass('yui3-tab-panel');
            tabs      = new Y.TabView({
                children: [ { label: 'Tickets', panelNode: dt.node } ]
            });
            tabs.render();
        }, '#container');
});
