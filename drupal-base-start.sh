#!/bin/bash

# Run the parent start script if there is one.
echo "entering the start script ...."

# First, we'll define our default db connection vars
mysqlip=localhost && drupaldbname=drupal && drupaluname=root && drupalpwd=password && drupaldbport=3306
if [ "${KB_APP_SETTINGS}" != "" ];
    then 
    apt-get install jq
    kbdbsettings=$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.database')
if [ "${kbdbsettings}" != "null" ];
    then
    mysqlip=$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.host');
    drupaluname=$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.username');
    drupalpwd =$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.password');
    drupaldbname =$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.database');
    drupaldbport =$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.port');
fi;
fi

# If not using Kalabox, then we'll check for environment variables that may have been passed
# or auto-set in the docker run command.
if [ "${MYSQL_PORT_3306_TCP_ADDR}" != "" ]; then mysqlip="${MYSQL_PORT_3306_TCP_ADDR}"; fi
if [ "${DRUPAL_DB_USERNAME}" != "" ]; then drupaluname="${DRUPAL_DB_USERNAME}"; fi
if [ "${DRUPAL_DB_PASSWORD}" != "" ]; 
    then drupalpwd="${DRUPAL_DB_PASSWORD}"; 
else 
if [ "${MYSQ_ROOT_PASSWORD}" != "" ]; then drupalpwd="${MYSQL_ROOT_PASSWORD}"; fi 
fi

# Download Drupal if not already there
indexfile=/srv/www/siterooot/index.php
if [ -f "$indexfile" ];
    then
    echo "Site already installed. Yay.";
else
    echo "Site not installed. Pulling latest drupal 7 ... "
    cd /srv/www && drush dl drupal -y && mv /srv/www/drupal-7*/* /srv/www/siteroot
    cd /srv/www/siteroot
    rm index.html && chown -R www-data:www-data /srv/www/siteroot;
    # Use drush to install a default generic drupal site and database installation
    drush si -y minimal --db-url=mysql://${drupaluname}:${drupalpwd}@${mysqlip}/${drupaldbname} --account-pass=admin
    chown -R www-data:www-data /srv/www/siteroot/sites;
    installsite=true;
fi

# Create files directory if it doesn't yet exist.
cd /srv/www/siteroot && filesdirectory=/srv/www/siteroot/sites/default/files

if [ ! -d "$filesdirectory" ]; then
  mkdir -p /srv/www/siteroot/sites/default/files;
fi
chmod a+w /srv/www/siteroot/sites/default -R

# Configure settings.php 
settingsfile=/srv/www/siterooot/sites/default/settings.php

# If we're not installing the site from scratch and we're using kalabox, then replace settings.php with kalabox settings.
if [ ! -v installsite ] && [ "$kbdbsettings" != "null" ];
    then
    # Alter the settings.php file to point to the right IP address.
    sed -i "s/'host' => '.*'/'host' => '${mysqlip}'/g" /srv/www/siteroot/sites/default/settings.php
    sed -i 's/"host" => ".*"/"host" => "${mysqlip}"/g' /srv/www/siteroot/sites/default/settings.php;

    # Alter the settings.php file to configure the database name
    sed -i "s/'username' => '.*'/'username' => '${drupaluname}'/g" /srv/www/siteroot/sites/default/settings.php
    sed -i 's/"username" => ".*"/"username" => "${drupaluname}"/g' /srv/www/siteroot/sites/default/settings.php;

    sed -i "s/'password' => '.*'/'password' => '${drupalpwd}'/g" /srv/www/siteroot/sites/default/settings.php
    sed -i 's/"password" => ".*"/"password" => "${drupalpwd}"/g' /srv/www/siteroot/sites/default/settings.php;

    sed -i "s/'database' => '.*'/'database' => '${drupaluname}'/g" /srv/www/siteroot/sites/default/settings.php
    sed -i 's/"database" => ".*"/"database" => "${drupaluname}"/g' /srv/www/siteroot/sites/default/settings.php;

    sed -i "s/'port' => '.*'/'port' => '${drupaldbport}'/g" /srv/www/siteroot/sites/default/settings.php
    sed -i 's/"port" => ".*"/"port" => "${drupaldbport}"/g' /srv/www/siteroot/sites/default/settings.php;
fi

varnishdir=/srv/www/siteroot/sites/all/modules/varnish
installmodules=false
if [ -v installsite ] || [ -v REBUILD ]; then installmodules=true; fi
if [ -d "$varnishdir" ]; then installmodules=false; fi

if [ "$installmodules" = true ];
    then
    cd /srv/www/siteroot
    drush dl admin_menu -y && drush_dl devel -y && drush dl simpletest -y
    drush en -y admin_menu simpletest
    drush vset "admin_menu_tweak_modules" 1	
    # set up varnish and memcached
    drush dl varnish memcache && drush en varnish memcache memcache_admin -y
    drush vset cache 1 && drush vset page_cache_maximum_age 3600 && drush vset varnish_version 3
    unset REBUILD;
fi
