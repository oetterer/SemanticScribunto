#! /bin/bash

set -ex

originalDirectory=$(pwd)
cd ..
baseDir=$(pwd)
mwDir=mw

## Use sha (master@5cc1f1d) to download a particular commit to avoid breakages
## introduced by MediaWiki core
if [[ "$MW" == *@* ]]; then
    arrMw=(${MW//@/ })
    MW=${arrMw[0]}
    SOURCE=${arrMw[1]}
else
    MW=$MW
    SOURCE=$MW
fi

function installMWCoreAndDB {

    echo "Installing MW Version $MW"

    cd $baseDir
    wget https://github.com/wikimedia/mediawiki/archive/$SOURCE.tar.gz -O $MW.tar.gz

    tar -zxf $MW.tar.gz
    mv mediawiki-* $mwDir

    cd $mwDir

    composer self-update
    composer install --prefer-source

    echo "using database $DB"
    if [[ "$DB" == "postgres" ]]; then
        # See #458
        sudo /etc/init.d/postgresql stop
        sudo /etc/init.d/postgresql start

        psql -c 'create database its_a_mw;' -U postgres
        php maintenance/install.php --dbtype $DB --dbuser postgres --dbname its_a_mw --pass nyan TravisWiki admin --scriptpath /TravisWiki
    else
        mysql -e 'create database its_a_mw;'
        php maintenance/install.php --dbtype $DB --dbuser root --dbname its_a_mw --dbpath $(pwd) --pass nyan TravisWiki admin --scriptpath /TravisWiki
    fi
}

function composerStuff {

    echo "composer issues"
    cd ${baseDir}/$mwDir

    if [[ "$PHPUNIT" != "" ]]; then
		composer require 'phpunit/phpunit='$PHPUNIT --update-with-dependencies
	else
		composer require 'phpunit/phpunit=3.7.*' --update-with-dependencies
	fi
	if [[ "$MW" != "master" ]]; then
	    composer require mediawiki/scribunto "dev-$MW" --update-with-dependencies
	else
	    composer require mediawiki/scribunto "dev-REL1_30" --update-with-dependencies
	fi
    #composer require mediawiki/semantic-media-wiki  "dev-master" --update-with-dependencies
}

function readySource {

    cd ${baseDir}/$mwDir
    composer init --stability dev
    composer require mediawiki/semantic-scribunto "dev-master" --dev --update-with-dependencies

    cd extensions
    rm -rf SemanticScribunto
    cp -r $originalDirectory .
    cd ..

	# Rebuild the class map for added classes during git fetch
	composer dump-autoload
}

function readyConfig {

    cd ${baseDir}/$mwDir

	# Site language
	if [[ "$SITELANG" != "" ]]; then
		echo '$wgLanguageCode = "'$SITELANG'";' >> LocalSettings.php
	fi

	echo 'require_once "$IP/extensions/Scribunto/Scribunto.php";' >> LocalSettings.php
	echo '$wgScribuntoDefaultEngine = "luastandalone";' >> LocalSettings.php

	echo 'error_reporting(E_ALL| E_STRICT);' >> LocalSettings.php
	echo 'ini_set("display_errors", 1);' >> LocalSettings.php
	echo '$wgShowExceptionDetails = true;' >> LocalSettings.php
	echo '$wgDevelopmentWarnings = true;' >> LocalSettings.php
	echo "putenv( 'MW_INSTALL_PATH=$(pwd)' );" >> LocalSettings.php

	php maintenance/update.php --quick
}

installMWCoreAndDB
composerStuff
readySource
readyConfig
