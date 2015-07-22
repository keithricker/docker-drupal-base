#!/bin/bash

# Run the parent start script if there is one.
echo "entering the start script ...."

# First, we'll define our default db connection vars
unset dbsettings;
declare -A dbsettings
dbsettings[host]=localhost && dbsettings[database]=mysite && dbsettings[username]=root && dbsettings[password]="" && dbsettings[port]=3306 && drupalprofile=spark && drupalsitename="My Drupal 7 Site"
if [ "${KB_APP_SETTINGS}" != "" ];
    then 
    apt-get install jq
    kbdbsettings=$(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.database')
    if [ "${kbdbsettings}" != "null" ];
        then
        for i in "${!dbsettings[@]}"; do
          dbsettings[$i]=$(echo $(echo "${KB_APP_SETTINGS}" | jq '.databases.default.default.'"${i}"'') | tr -d '"');
        done;
    fi;
fi

# If not using Kalabox, then we'll check for environment variables that may have been passed
# or auto-set in the docker run command.

# First check for cloud66 env variables
if [ "${MYSQL_ADDRESS_EXT}" != "" ]; then dbsettings[host]="${MYSQL_ADDRESS_EXT}"; fi
if [ "${MYSQL_DATABASE}" != "" ]; then dbsettings[database]="${MYSQL_DATABASE}"; fi

if [ "${MYSQL_PORT_3306_TCP_ADDR}" != "" ]; then dbsettings[host]="${MYSQL_PORT_3306_TCP_ADDR}"; fi

if [ "${MYSQL_USERNAME}" != "" ]; then dbsettings[username]="${MYSQL_USERNAME}"; fi
if [ "${DRUPAL_DB_USERNAME}" != "" ]; then dbsettings[username]="${DRUPAL_DB_USERNAME}"; fi

if [ "${MYSQL_PASSWORD}" != "" ]; then dbsettings[password]="${MYSQL_PASSWORD}"; fi;
if [ "${MYSQ_ROOT_PASSWORD}" != "" ]; then dbsettings[password]="${MYSQL_ROOT_PASSWORD}"; fi;
if [ "${DRUPAL_DB_PASSWORD}" != "" ]; then dbsettings[password]="${DRUPAL_DB_PASSWORD}"; fi;

# Here you can pass in the git repository as an ev variable.
if [ "${GIT_REPO}" != "" ]; then echo "environment variable GIT_REPO equals ${GIT_REPO}" && drupalprofile=minimal && gitrepo="${GIT_REPO}"; fi;

# Here you can pass in the site name as an ev variable.
if [ "${DRUPAL_SITENAME}" != "" ]; then drupalsitename="${DRUPAL_SITENAME}"; fi;

# Download Drupal if not already there
indexfile="/data/index.php"

# Check if this is a first-time install
if [ -f "/data/index.php" ]; then nocode=true; fi;

if [ -f "/data/index.php" ] && [ "$REBUILD" = "no" ];
    then
    echo "Site already installed. Yay.";
else
    if [ "$gitrepo" != "" ]; 
    then echo "Site not installed. Pulling from repository ... ";
        cd /srv/www && git clone $(echo ${gitrepo}) moveme
        rm -rfv /data/*
        mv /srv/www/moveme/* /data/
        rm -r /srv/www/moveme;
    else
        echo "Site not installed. Pulling latest drupal 7 ... ";
        cd /srv/www && drush dl spark -y && mv /srv/www/spark-7*/* /data/;
    fi
    
    mv -f /root/.htaccess /data/;
    if [ -f "/data/index.html" ]; then rm /data/index.html; fi
fi

cd /data
chown -R www-data:www-data /data; fi

if [ "$dbsettings[password]" = "" ]; then pwd=password; else pwd=$dbsettings[password]; fi;
echo "contacting mysql using credentials ... mysql -h ${dbsettings[host]} -u ${dbsettings[username]} -p ${pwd} ${dbsettings[database]} -e" && echo ""
if ! mysql -h${dbsettings[host]} -u${dbsettings[username]} -p${pwd} ${dbsettings[database]} -e 'select * from node';
then
    echo "connecting to database using these credentials ...  db-url=mysql://${dbsettings[username]}:${pwd}@${dbsettings[host]}/${dbsettings[username]} --account-pass=${pwd} --site-name=\"$(echo $drupalsitename)\""
    drush si -y $(echo "${drupalprofile}") --db-url=mysql://${dbsettings[username]}:${pwd}@${dbsettings[host]}/${dbsettings[database]} --account-pass=${pwd} --site-name="$(echo $drupalsitename)";
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

# Copy settings.php to all site directories
for path in /data/sites/*; do
    dirname="$(basename "${path}")"
    [ -d "${path}" ] || continue # if not a directory, skip
    [ "${dirname}" != "default" ] || continue
    [ "${dirname}" != "all" ] || continue
    [ ! -f /data/sites/${dirname}/settings.php ] || continue
    cp ${settingsfile} /data/sites/${dirname}/;
done

# If we're not installing the site from scratch and we're using kalabox, then replace settings.php with kalabox settings.
# Also, if app container is restarting, then we want to replace the mysql host with new ip.

if [ "${dbsettings[host]}" != "" ];
    then
    # Alter the settings.php file to point to the right IP address.
    sed "s/'host' => '.*'/'host' => '${dbsettings[host]}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php
    sed 's/"host" => ".*"/"host" => "${dbsettings[host]}"/g' "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php;
fi

if [ "$installsite" != "" ] && [ "$kbdbsettings" != "null" ];
    then
    for i in "${!dbsettings[@]}";
    do
      sed "s/'${i}' => '.*'/'${i}' => '${dbsettings[$i]}'/g" "$settingsfile" > ~/deleteme.php  &&  cp ~/deleteme.php "$settingsfile" && rm ~/deleteme.php;
    done
fi

varnishdir=/data/sites/all/modules/varnish
installmodules=false
if [ "$installsite" != "" ] && [ "$nocode" != "" ]; then installmodules=true; fi
if [ -d "$varnishdir" ]; then installmodules=false; fi

if [ "$installmodules" = true ];
    then
    cd /data
    # download and enable production-related modules
    drush dl admin_menu -y && drush dl devel -y && drush dl simpletest -y
    drush en -y simpletest
    # set up varnish and memcache
    drush dl varnish memcache && drush en varnish -y memcache -y memcache_admin -y
    # grab entity-related modules
    declare -a enablethese=(eck inline_entity_form ds entityconnect entityreference field_group backup_migrate editablefields conditional_fields ds_extra_layouts)
    for module in $enablethese; do
        drush dl ${module} -y && drush en ${module} -y;
    done
    # Set some variables
    drush vset page_cache_maximum_age 3600 && drush vset varnish_version 3
    unset REBUILD;
fi
