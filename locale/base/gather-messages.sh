#!/bin/bash
#
# vim:set softtabstop=4 shiftwidth=4 expandtab:
#
# Copyright 2001 - 2015 Ampache.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License v2
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

PATH=$PATH:/bin:/usr/bin:/usr/local/bin
dbhost=$(grep -oP "(?<=database_hostname = \")[^\"\n]+" ../../config/ampache.cfg.php)
dbname=$(grep -oP "(?<=database_name = \")[^\"\n]+" ../../config/ampache.cfg.php)
dbuser=$(grep -oP "(?<=database_username = \")[^\"\n]+" ../../config/ampache.cfg.php)
dbpass=$(grep -oP "(?<=database_password = \")[^\"\n]+" ../../config/ampache.cfg.php)

# gettext package test
if ! which xgettext &>/dev/null ; then
    echo "xgettext not found. Do you need to install gettext?"
    exit 1;
fi

[[ $OLANG ]] || OLANG=$(echo $LANG | sed 's/\..*//;')
POTNAME='messages.pot'

usage() {
    echo "usage: $0 [--help|--get|--init|--merge|--format|--all]"
    echo
    echo 'See also: http://ampache.org/wiki/dev:translation'
    exit 1
}

generate_pot() {
    echo "Deleting old messages.pot"
    rm messages.pot
    xgettext    --from-code=UTF-8 \
                --add-comment=HINT: \
                --msgid-bugs-address="translations@ampache.org" \
                -L php \
                --keyword=gettext_noop --keyword=T_ --keyword=T_gettext --keyword=T_ngettext --keyword=ngettext \
                -o $POTNAME \
                $(find ../../ -type f -name \*.php -o -name \*.inc | sort)
    if [[ $? -eq 0 ]]; then
        echo "pot file creation succeeded"
        echo "delete old translation-words.txt"
        rm translation-words.txt
        echo "Adding database words to pot file..."
        mysql -N --database=$dbname --host=$dbhost --user=$dbuser --password=$dbpass -se "SELECT id FROM preference" | 
        while read dbprefid; do
            dbprefdesc=$(mysql -N --database=$dbname --host=$dbhost --user=$dbuser --password=$dbpass -se "SELECT description FROM preference where id=$dbprefid")
            dbprefdescchk=$(grep "\"$dbprefdesc\"" messages.pot)
            if [ ! "$dbprefdescchk" ]; then
            echo    "#: Database preference table id $dbprefid" >> translation-words.txt
            echo -e "msgid \"$dbprefdesc\"" >> translation-words.txt
            echo -e "msgstr \"\"\n" >> translation-words.txt
            else
            echo    "#: Database preference table id $dbprefid" >> translation-words.txt
            echo -e "# is already in the source code\n# but to avoid confusion, it's added and commented" >> translation-words.txt
            echo -e "# msgid \"$dbprefdesc\"" >> translation-words.txt
            echo -e "# msgstr \"\"\n" >> translation-words.txt
            fi
        done
        cat translation-words.txt >> messages.pot
    else
        echo "pot file creation failed"
    fi
}

do_msgmerge() {
    source=$POTNAME
    target="../$1/LC_MESSAGES/messages.po"
    echo "Merging $source into $target"
    msgmerge --update --backup=off $target $source
    echo "Obsolete messages in $target: " $(grep '^#~' $target | wc -l)
}

do_msgfmt() {
    source="../$1/LC_MESSAGES/messages.po"
    target="../$1/LC_MESSAGES/messages.mo"
    echo "Creating $target from $source"
    msgfmt --verbose --check $source -o $target
}

if [[ $# -eq 0 ]]; then
    usage
fi

case $1 in
    '--all'|'-a'|'all')
        generate_pot
	for i in $(ls ../ | grep -v base); do
	    do_msgmerge $i
	    do_msgfmt $i
	done
    ;;
    '--allformat')
	for i in $(ls ../ | grep -v base); do
	    do_msgfmt $i
	done
    ;;
    '--allmerge')
	for i in $(ls ../ | grep -v base); do
	    do_msgmerge $i
	done
    ;;
    '--get'|'-g'|'get')
        generate_pot
    ;;
    '--init'|'-i'|'init')
        outdir="../$OLANG/LC_MESSAGES"
        [[ -d $outdir ]] || mkdir -p $outdir
	msginit -l $LANG -i $POTNAME -o $outdir/messages.po
    ;;
    '--format'|'-f'|'format')
        do_msgfmt $OLANG
    ;;
    '--merge'|'-m'|'merge')
        do_msgmerge $OLANG
    ;;
    '--help'|'-h'|'help'|'*')
        usage
    ;;
esac
