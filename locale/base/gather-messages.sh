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

# gettext package test
if ! which xgettext &>/dev/null ; then
    echo "xgettext not found. Do you need to install gettext?"
    exit 1;
fi

[[ $OLANG ]] || OLANG=$(echo $LANG | sed 's/\..*//;')
potfile='messages.pot'
twtxt='translation-words.txt'
ampconf='../../config/ampache.cfg.php'

usage() {
    echo ""
    echo -e "usage: $0 [--help|--get|--getutw|--init|--merge|--format|--all]"
    echo ""
    echo -e "[-g|--get]\t Creates the messages.pot file from translation strings within the source code."
    echo -e "[-gu|--getutw]\t Generates the Pot file from translation strings within the source code\n\t\t and creates or updates the 'translation-words.txt' from the database-preference-table strings.\n\t\t Ampache needs to be fully setup for this to work."
    echo -e "[-i|--init]\t Creates a new language catalog and its directory structure."
    echo -e "[-m|--merge]\t Merges the messages.pot into the language catalogs and shows obsolet translations."
    echo -e "[-f|--format]\t Compiles the .mo file for its related .po file."
    echo -e "[-a|--all]\t Does all exept --init and --utw."
    echo -e "[-h|--help]\t Shows this help screen."
    echo ""
    echo "See also: https://github.com/ampache/ampache/blob/master/locale/base/TRANSLATIONS"
    echo ""
    exit 1
}

generate_pot() {
    echo "Generating/updating pot-file"
    xgettext    --from-code=UTF-8 \
                --add-comment=HINT: \
                --msgid-bugs-address="translations@ampache.org" \
                -L php \
                --keyword=gettext_noop --keyword=T_ --keyword=T_gettext --keyword=T_ngettext --keyword=ngettext \
                -o $potfile \
                $(find ../../ -type f -name \*.php -o -name \*.inc | sort)
    if [[ $? -eq 0 ]]; then
        echo "Pot file creation succeeded. Adding 'translation-words.txt"
        cat $twtxt >> $potfile
    else
        echo "pot file creation failed"
    fi
}

generate_pot_utw() {
    echo ""
    echo "Generating/updating pot-file"
    echo ""
    xgettext    --from-code=UTF-8 \
                --add-comment=HINT: \
                --msgid-bugs-address="translations@ampache.org" \
                -L php \
                --keyword=gettext_noop --keyword=T_ --keyword=T_gettext --keyword=T_ngettext --keyword=ngettext \
                -o $potfile \
                $(find ../../ -type f -name \*.php -o -name \*.inc | sort)
    if [[ $? -eq 0 ]]; then
    
        ampconf='../../config/ampache.cfg.php'
        
        echo -e "Pot creation/update successful\n"
        echo -e "Reading database login information from Amapche config file\n"
        
        dbhost=$(grep -oP "(?<=database_hostname = \")[^\"\n]+" $ampconf)
        if [ ! $dbhost ]; then
            echo ""
            echo "Error: No or false database host setting detected!"
            read -r -p "Type in a host or simply press enter to use localhost instead: " dbhost
                if [ ! $dbhost ]; then
                    dbhost=localhost
                else
                    continue
                fi
        fi
        echo "Saved '$dbhost' as your database host"
        
        dbport=$(grep -oP "(?<=database_port*=*\")[^\"\n]+" $ampconf)
        if [ ! $dbport ]; then
            echo ""
            echo "Error: No or false database_port setting detected!"
            read -r -p "Type in a port or simply press enter to use default port 3306 instead: " dbport
                if [ ! $dbport ]; then
                    dbport=3306
                fi
        fi
        echo "Saved '$dbport' as your database port"
        
        dbname=$(grep -oP "(?<=database_name = \")[^\"\n]+" $ampconf)
        if [ ! $dbname ]; then
            echo ""
            echo "No datatabase name detected, please check your 'database_name' setting"
            read -r -p "or type in the right database name here for temporary use: " dbname
                if [ ! $dbname ]; then
                    echo ""
                    echo "Error: You didn't type in a database name, Sorry but I have to exit :("
                    exit
                fi
        fi
        echo "Saved '$dbname' as you database name"
        
        dbuser=$(grep -oP "(?<=database_username = \")[^\"\n]+" $ampconf)
        if [ ! $dbuser ]; then
            echo "You need to set a valid database user in you Ampache config file"
            read -r -p "Or type it in here for temporary use: " dbuser
                if [ ! $dbuser ]; then
                    echo "Error: You didn't type in a database user! Sorry but I have to exit :("
                    exit
                fi
        fi
        echo "Saved '$dbuser' as your database user"

            dbpass=$(grep -oP "(?<=database_password = \")[^\"\n]+" $ampconf)
        if [ ! $dbpass ]; then
            echo "You haven't set a database password in your Amapche config."
            read -r -p "If this is OK, press Y to continue. Otherwise we will break here: " answer
            if [[ $answer =~ ^([yY][eE][sS]|[yY])$ ]]; then
                echo "Great, lets go on"
            else
                exit
            fi
        fi
        echo "Saved 'password123' as your database password... Hehe, just kidding, but I won't show it here"
        
        echo ""
        echo "Deleting old translation-words.txt"
        echo ""
        rm $twtxt

        echo -e "Creating new 'translation-words.txt' from database\n"
        mysql -N --database=$dbname --host=$dbhost --user=$dbuser --password=$dbpass -se "SELECT id FROM preference" | 
        while read dbprefid; do
            dbprefdesc=$(mysql -N --database=$dbname --host=$dbhost --user=$dbuser --password=$dbpass -se "SELECT description FROM preference where id=$dbprefid")
            dbprefdescchk=$(grep "\"$dbprefdesc\"" $potfile)
            if [ ! "$dbprefdescchk" ]; then
                echo -e "\n#: Database preference table id $dbprefid" >> $twtxt
                echo -e "msgid \"$dbprefdesc\"" >> $twtxt
                echo -e "msgstr \"\"" >> $twtxt
            else
                echo -e "\n#: Database preference table id $dbprefid" >> $twtxt
                echo -e "# is already in the source code\n# but to avoid confusion, it's added and commented" >> $twtxt
                echo -e "# msgid \"$dbprefdesc\"" >> $twtxt
                echo -e "# msgstr \"\"" >> $twtxt
            fi
        done
        echo -e "Adding preference-table strings to pot file...\n"
        cat $twtxt >> $potfile
    else
        echo "pot file creation failed"
    fi
}
        
do_msgmerge() {
    source=$potfile
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
    '-a'|'--all')
        generate_pot
	for i in $(ls ../ | grep -v base); do
	    do_msgmerge $i
	    do_msgfmt $i
	done
    ;;
    '-af'|'--allformat')
	for i in $(ls ../ | grep -v base); do
	    do_msgfmt $i
	done
    ;;
    '-am'|'--allmerge')
	for i in $(ls ../ | grep -v base); do
	    do_msgmerge $i
	done
    ;;
    '-g'|'--get')
        generate_pot
    ;;
    '-gu'|'--getutw')
        generate_pot_utw
    ;;
    '-i'|'--init'|'init')
        outdir="../$OLANG/LC_MESSAGES"
        [[ -d $outdir ]] || mkdir -p $outdir
	msginit -l $LANG -i $potfile -o $outdir/messages.po
    ;;
    '-f'|'--format'|'format')
        do_msgfmt $OLANG
    ;;
    '-m'|'--merge'|'merge')
        do_msgmerge $OLANG
    ;;
    '-h'|'--help'|'help'|'*')
        usage
    ;;
esac
