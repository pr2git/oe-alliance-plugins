#!/bin/bash
# Script to generate po files outside of the normal build process
#  
# Pre-requisite:
# The following tools must be installed on your system and accessible from path
# gawk, find, xgettext, gsed, python, msguniq, msgmerge, msgattrib, msgfmt, msginit
#
# Run this script from the top folder of enigma2-plugins
#
#
# Author: Pr2 for OE-Alliance
# Version: 1.1

localgsed="sed"
findoptions=""

#
# Script only run with sed but on some distro normal sed is already sed so checking it.
#
sed --version 2> /dev/null | grep -q "GNU"
if [ $? -eq 0 ]; then
	localgsed="sed"
else
	"$localgsed" --version | grep -q "GNU"
	if [ $? -eq 0 ]; then
		printf "GNU sed found: [%s]\n" $localgsed
	fi
fi

which python
if [ $? -eq 1 ]; then
	which python3
	if [ $? -eq 1 ]; then
		printf "python not found on this system, please install it first or ensure that it is in the PATH variable.\n"
		exit 1
	fi
fi

#
# On Mac OSX find option are specific
#
if [[ "$OSTYPE" == "darwin"* ]]
	then
		# Mac OSX
		printf "Script running on Mac OSX [%s]\n" "$OSTYPE"
    	findoptions=" -s -X "
        localgsed="gsed"
fi

rootpath=$PWD
#
# Parsing the folders tree
#
printf "Po files update/creation from script starting.\n"
for directory in */po/ ; do
	cd $rootpath/$directory
	languages=($(ls *.po | tr "\n" " " | gsed 's/.po//g'))
	plugin=$(gawk ' BEGIN { FS=" " } /^PLUGIN/ { print $3 }' Makefile.am)
	printf "Processing plugin %s\n" $plugin
	#
	printf "Creating temporary file $plugin-py.pot\n"
	find $findoptions .. -name "*.py" -exec xgettext --no-wrap -L Python --from-code=UTF-8 -kpgettext:1c,2 --add-comments="TRANSLATORS:" -d $plugin -s -o $plugin-py.pot {} \+
	$localgsed --in-place $plugin-py.pot --expression=s/CHARSET/UTF-8/
	printf "Creating temporary file $plugin-xml.pot\n"
	which python
	if [ $? -eq 0 ]; then
		find $findoptions .. -name "*.xml" -exec python $rootpath/xml2po.py {} \+ > $plugin-xml.pot
	else
		find $findoptions .. -name "*.xml" -exec python3 $rootpath/xml2po.py {} \+ > $plugin-xml.pot
	fi
	printf "Merging pot files to create: %s.pot\n" $plugin
	cat $plugin-py.pot $plugin-xml.pot | msguniq --no-wrap --no-location -o $plugin.pot -
	rm $plugin-py.pot $plugin-xml.pot
	# git add $plugin.pot
	OLDIFS=$IFS
	IFS=" "
	for lang in "${languages[@]}" ; do
		if [ -f $lang.po ]; then 
			printf "Updating existing translation file $lang.po\n"
			msgmerge --backup=none --no-wrap --no-location -s -U $lang.po $plugin.pot && touch $lang.po
			msgattrib --no-wrap --no-obsolete $lang.po -o $lang.po
			msgfmt -o $lang.mo $lang.po
			# git add -f $lang.po; \
		else \
			printf "New file created: $lang.po, please add it to # github before commit\n"
			msginit -l $lang.po -o $lang.po -i $plugin.pot --no-translator
			msgfmt -o $lang.mo $lang.po
			# git add -f $lang.po; \
		fi
	done
	IFS=$OLDIFS 
	# git commit -m "Plugin $plugin po files updated at $(date +"%Y-%m-%d %H:%M")"
done
# git push
cd $rootpath/
printf "Po files update/creation from script finished!\n"
