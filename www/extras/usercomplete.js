/*global YUI, _ */

/**
 * usercomplete provides a wrapper around a YUI2 autocomplete used for
 * selecting one or more WebGUI users.
 * @module usercomplete
 */

YUI.add('usercomplete', function (Y) {
    Y.UserComplete = function () {
        Y.UserComplete.superclass.constructor.apply(this, arguments);
    };
    Y.extend(Y.UserComplete, Y.Widget, {
        renderUI: function () {
            var ac, content = this.get('contentBox'),
            input           = Y.Node.create('<input>');
            container       = Y.Node.create('<div>');

            content.all('input').remove();

            input.addClass(this.getClassName('label'));
            input.removeAttribute('name');
            content.append(container);
            content.append(input);

            this._userData = {};
            ac = this._autocomplete = new Y.YUI2.widget.AutoComplete(
                Y.Node.getDOMNode(input),
                Y.Node.getDOMNode(container),
                this.get('datasource')
            );
            if (this.get('multiple')) {
                ac.delimChar = ',';
            }
            ac.resultTypeList    = false;
            ac.forceSelection    = true;
            ac.queryQuestionMark = false;
            ac.formatResult = _.bind(this._formatResult, this);
        },
        _formatResult: function (data, query, match) {
            /* We want any name that comes up in the box to have its data
             * accessible -- they may type names in without actually selecting
             * them, etc. */
            this._userData[data.fullname] = data;
            return data.fullname + ' (' + data.username + ')';
        },
        _addValueNodes: function () {
            var box, valueClass, formName = this.get('formName');
            if (!formName) {
                return;
            }

            box        = this.get('contentBox');
            valueClass = this.getClassName('value');
            box.all('.' + valueClass).remove();
            
            _.each(this.get('selectedUsers'), function (u) {
                var input = Y.Node.create('<input type="hidden">');
                input.addClass(valueClass);
                input.set('value', u.id);
                input.setAttribute('name', formName);
                box.append(input);
            }, this);
        },
        bindUI: function () {
            var ac = this._autocomplete;
            ac.textboxChangeEvent.subscribe(function (type, args, self) {
                var names = ac.getInputEl().value.split(/\s*,\s*/);
                self.set('selectedUsers', _(names).chain().map(function (n) {
                    return self._userData[n];
                }).compact().value());
            }, this);
            this.after('selectedUsersChange', 
                _.bind(this._selectionChanged, this));
        },
        _selectionChanged: function () {
            this._addValueNodes();
            this._formatTextBox();
        },
        _formatTextBox: function () {
            var users = this.get('selectedUsers'), str = '';
            if (users.length > 0) {
                if (this.get('multiple')) {
                    _.each(users, function (u) {
                        str += u.fullname + ', ';
                    });
                }
                else {
                    str = users[0].fullname;
                }
                this._autocomplete.getInputEl().value = str;
            }
        },
        syncUI: function () {
            this._selectionChanged();
        }
    }, {
        NAME  : 'usercomplete',
        HTML_PARSER: {
            formName: function (node) {
                var input = node.one('input');
                return input && input.getAttribute('name');
            }
        },
        ATTRS : {
            /**
             * The form name the hidden inputs used for ID form submission
             * will have.  If this is not set, no hidden inputs will be
             * generated.  Its value is taken from srcNode if possible.
             * @attribute formName
             */
            formName: {
            },
            /**
             * A YUI2 DataSource that provides user data.  It should at least
             * provide fullname, id, and username.
             */
            datasource: {
            },
            /**
             * A boolean indicating whether multiple users can be selected.
             * @attribute selectedUsers
             */
            multiple: {
                value: false
            },
            /**
             * An array of user objects.
             * @attribute selectedUsers
             */
            selectedUsers: {
                value: []
            }
        }
    });
}, '0.1', { requires: ['widget', 'underscore', 'yui2-autocomplete'] });
