#!/bin/bash

# Run the parent start script if there is one.
echo "entering the start script ...."

# First, we'll define our default db connection vars
mysqlip=localhost && drupaldbname=mysite && drupaluname=root && drupalpwd="" && drupaldbport=3306
if [ "${KB_APP_SETTINGS}" != "" ];
    then 
    apt-get install jq
    kbdbsettings=$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.database')
if [ "${kbdbsettings}" != "null" ];
    then
    mysqlip=$(echo $(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.host') | tr -d '"');
    drupaldbname=$(echo $(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.database') | tr -d '"');
    drupaluname=$(echo $(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.username') | tr -d '"');
    drupalpwd=$(echo $(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.password') | tr -d '"');
    drupaldbport=$(echo $(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.port') | tr -d '"');
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
indexfile="/data/index.php"
if [ -f "/data/index.php" ];
    then
    echo "Site already installed. Yay.";
else
    echo "Site not installed. Pulling latest drupal 7 ... ";
    mv /data/.htaccess /srv/www/
    cd /srv/www && drush dl spark -y && mv /srv/www/spark-7*/* /data && mv -f .htaccess /data/.htaccess
    if [ -f "/data/index.html" ]; then rm /data/index.html
    if [ "$drupalpwd" = "" ]; then pwd=password; else pwd=$drupalpwd; fi;
fi

cd /data
chown -R www-data:www-data /data; fi

if ! mysql -h${mysqlip} -u${drupaluname} -p${pwd} ${drupaldbname} -e 'select * from node';
    then
    drush si -y spark --db-url=mysql://${drupaluname}:${drupalpwd}@${mysqlip}/${drupaldbname} --account-pass=password --site-name="Your Drupal7 Site"
    installsite=true;
fi;

# Create files directory if it doesn't yet exist.
cd /data && filesdirectory=/data/sites/default/files

if [ ! -d "$filesdirectory" ]; then
  mkdir -p /data/sites/default/files;
fi
chmod a+w /data/sites/default -R

# Configure settings.php, with contingency in case it is a symlink
settingsfile=$(readlink -f /data/sites/default/settings.php);

# If we're not installing the site from scratch and we're using kalabox, then replace settings.php with kalabox settings.
# Also, if app container is restarting, then we want to replace the mysql host with new ip.

if [ "${MYSQL_PORT_3306_TCP_ADDR}" != "" ];
    then
    # Alter the settings.php file to point to the right IP address.
    sed "s/'host' => '.*'/'host' => '${mysqlip}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"host" => ".*"/"host" => "${mysqlip}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php;
fi

if [ "$installsite" != "" ] && [ "$kbdbsettings" != "null" ];
    then
    sed "s/'host' => '.*'/'host' => '${mysqlip}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"host" => ".*"/"host" => "${mysqlip}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php

    sed "s/'username' => '.*'/'username' => '${drupaluname}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"username" => ".*"/"username" => "${drupaluname}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php

    sed "s/'password' => '.*'/'password' => '${drupalpwd}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"password" => ".*"/"password" => "${drupalpwd}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php

    sed "s/'database' => '.*'/'database' => '${drupaldbname}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"database" => ".*"/"database" => "${drupaldbname}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php

    sed "s/'port' => '.*'/'port' => '${drupaldbport}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"port" => ".*"/"port" => "${drupaldbport}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php;
fi

varnishdir=/data/sites/all/modules/varnish
installmodules=false
if [ "$installsite" != "" ] || [ "$REBUILD" != "" ]; then installmodules=true; fi
if [ -d "$varnishdir" ]; then installmodules=false; fi

if [ "$installmodules" = true ];
    then
    cd /data
    drush dl admin_menu -y && drush dl devel -y && drush dl simpletest -y
    drush en -y simpletest
    # set up varnish and memcache
    drush dl varnish memcache && drush en varnish -y memcache -y memcache_admin -y
    # grab entity-related modules
    drush dl eck -y inline_entity_form -y  ds -y entityconnect -y entityreference -y field_group -y
    drush en eck -y && drush en inline_entity_form -y && drush en ds -y && drush en entityconnect -y && \
    drush en entityreference -y && drush en field_group -y
    drush dl backup_migrate -y && drush en backup_migrate -y; drush dl editablefields -7 && drush en editablefields -y &&\
    drush dl conditional_fields -y && drush en conditional_fields -y && \
    drush dl ds_extra_layouts -y && drush en ds_extra_layouts -y
    drush vset cache 1 && drush vset page_cache_maximum_age 3600 && drush vset varnish_version 3
    unset REBUILD;
fi