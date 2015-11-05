#!/bin/bash

# If there is a private key defined in the env vars, then add it.
echo "entering the start script ...."
if [ "${PRIVATE_KEY_CONTENTS}" != "" ]; then
    echo "Copying over the private key."
    echo "${PRIVATE_KEY_CONTENTS}" > ~/.ssh/${PRIVATE_KEY_FILE}
    sed -i 's/\\n/\
/g' ~/.ssh/${PRIVATE_KEY_FILE}
    chmod 600  ~/.ssh/${PRIVATE_KEY_FILE}
    sed -i \
        -e 's/^#*\(PermitRootLogin\) .*/\1 yes/' \
        -e 's/^#*\(PasswordAuthentication\) .*/\1 yes/' \
        -e 's/^#*\(PermitEmptyPasswords\) .*/\1 yes/' \
        -e 's/^#*\(UsePAM\) .*/\1 no/' \
        /etc/ssh/sshd_config
    service ssh restart;
fi

# First, we'll define our default db connection vars
unset dbsettings;
declare -A dbsettings
dbsettings[host]=localhost && dbsettings[database]=mysite && dbsettings[username]=root && dbsettings[password]="" && dbsettings[port]=3306 && drupalprofile=minimal && drupalsitename="My Drupal 7 Site" && drupalusername=admin && drupalpassword=password
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
if [ "${MYSQL_PORT_3306_TCP_ADDR}" != "" ]; then dbsettings[host]="${MYSQL_PORT_3306_TCP_ADDR}"; fi
if [ "${MYSQL_ADDRESS_EXT}" != "" ]; then dbsettings[host]="${MYSQL_ADDRESS_EXT}"; fi
if [ "${MYSQL_ENV_TUTUM_CONTAINER_FQDN}" != "" ]; then dbsettings[host]="${MYSQL_ENV_TUTUM_CONTAINER_FQDN}"; fi

if [ "${MYSQL_PORT_3306_TCP_PORT}" != "" ]; then dbsettings[port]="${MYSQL_PORT_3306_TCP_PORT}"; fi
if [ "${MYSQL_DATABASE}" != "" ]; then dbsettings[database]="${MYSQL_DATABASE}"; fi

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
    cd /data && rm -rf * && cd /srv/www
    if [ "$gitrepo" != "" ]; 
    then 
        echo "Site not installed. Pulling from repository ... "
        git config --global --unset https.proxy && git config --global --unset http.proxy
        git clone $(echo ${gitrepo}) moveme
        # Allow for creating a new branch if specified in the configuration or docker run command.
        if [ "$MAKE_GIT_BRANCH" != "" ]; 
        then
            gitbranchname=$MAKE_GIT_BRANCH
            if [ "$TUTUM_SERVICE_FQDN" != "" ]; then gitbranchname=$(echo ${TUTUM_SERVICE_FQDN} |cut -d"." -f2); fi
            if [ "$MAKE_GIT_BRANCH_NAME" != "" ]; then gitbranchname="$MAKE_GIT_BRANCH_NAME"; fi
            git checkout -b ${gitbranchname} || true
            git push origin ${gitbranchname} || true;
        fi
        mv /srv/www/moveme/.* /data/
        mv /srv/www/moveme/* /data/
        rm -r /srv/www/moveme;
    else
        echo "Site not installed. Pulling latest drupal 7 ... ";
        cd /srv/www && drush dl spark -y && mv /srv/www/spark-7*/* /data/
        drupalprofile=spark;
    fi
    
    mv -f /root/.htaccess /data/ || true;
    if [ -f "/data/index.html" ]; then rm /data/index.html; fi
fi;

cd /data
chown -R www-data:www-data /data;

# Install the site(s)

# If no settings file is present, and we pulled a fresh distro, then install and skip the other stuff below
settingsfile=$(readlink -f /data/sites/default/settings.php) && if [ ! -f "$settingsfile" ]; then settingsfile=""; fi
if [ "$settingsfile" != "" ]; then cd /data/sites/default && if drush sql-connect ; then dsqcdf=$(drush sql-connect); fi && cd /data || cd /data && true; fi
[ "$settingsfile" != "" ] || drush si -y $(echo "${drupalprofile}") --db-url=mysql://${dbsettings[username]}:${dbsettings[password]}@${dbsettings[host]}/${dbsettings[database]} --account-name=${drupalusername} --account-pass=${drupalpassword} --site-name="$(echo $drupalsitename)";
[ "$settingsfile" = "" ] || for path in /data/sites/*; do
    dirname="$(basename "${path}")"
    [ -d "${path}" ] || continue
    [ "${dirname}" != "all" ] || continue
    [ -f /data/sites/${dirname}/settings.php ] || cp ${settingsfile} /data/sites/${dirname}/
    [ -f /data/sites/${dirname}/settings.php ] || continue
    
    # if we're not in sites/default, but sites/default has configured settings and it's the same as this one, then skip
    echo "moving to directory sites/default/${dirname}"
    cd /data/sites/${dirname}
    dsqct=$(drush sql-connect) || dsqct="" && true
    if [ "${dirname}" != "default" ] && [ "${dsqcdf}" != "" ] && [ "${dsqct}" = "${dsqcdf}" ]; then continue; fi;
    
    # Finally install the site if it isn't already
    drush pm-info node --fields=status || nonodetable=correct && true;
    if [ "$nonodetable" = "correct" ]; 
    then
        echo "Site not installed. Checking db connection."
        drush sql-connect || drushsqlconnection=nada && true;
        if [ "$drushsqlconnection" != "nada" ]; 
        then
            echo "Settings file is configured. Installing site."
            dburl=$(php -r 'include "settings.php"; if (!empty($databases)) { $tdb=$databases["default"]["default"]; echo "--db-url=mysql://".$tdb["username"].":".$tdb["password"]."@".$tdb["host"].":".$tdb["port"]."/".$tdb["database"]; };')
            syncalias=$(php -r 'include "settings.php"; if (!empty($syncalias)) { echo $syncalias; }')
            echo "running sql-create using db url: ${dburl}"
            drush sql-create -y $(echo "${dburl}") || true
            if [ "$syncalias" != "" ]; 
            then 
                drush cc -y drush || true
                echo "attempting to sync database with ${syncalias}"
                drush sql-sync -y ${syncalias} @self || drush si -y $(echo "${drupalprofile}") $(echo "${dburl}") --account-name=${drupalusername} --account-pass=${drupalpassword} --site-name="$(echo $drupalsitename)";
                echo "attempting to sync files."
                drush rsync -y ${syncalias}:%files @self:%files || true
            else
                echo "No sync alias found. Performing normal drush site-install."
                drush si -y $(echo "${drupalprofile}") $(echo "${dburl}") --account-name=${drupalusername} --account-pass=${drupalpassword} --site-name="$(echo $drupalsitename)";
            fi;
        else
            echo "Settings file not configured. Doing site-install using default settings ..."
            drush si -y $(echo "${drupalprofile}") --db-url=mysql://${dbsettings[username]}:${dbsettings[password]}@${dbsettings[host]}/${dbsettings[database]} --account-name=${drupalusername} --account-pass=${drupalpassword} --site-name="$(echo $drupalsitename)";
        fi;
        installsite=true;
    fi; 
done

# Create files directory if it doesn't yet exist.
cd /data && filesdirectory=/data/sites/default/files
if [ ! -d "$filesdirectory" ]; then
  mkdir -p /data/sites/default/files;
fi
chmod a+w /data/sites/default -R

# If we're not installing the site from scratch and we're using kalabox, then replace settings.php with kalabox settings.
# Also, if app container is restarting, then we want to replace the mysql host with new ip.

[ "$settingsfile" != "" ] || settingsfile=/data/sites/default/settings.php
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
    declare -a enablethese=(backup_migrate eck inline_entity_form ds entityconnect entityreference field_group backup_migrate editablefields conditional_fields ds_extra_layouts)
    for module in $enablethese; do
        drush dl ${module} -y && drush en ${module} -y;
    done
    # Set some variables
    drush vset page_cache_maximum_age 3600 && drush vset varnish_version 3
    unset REBUILD;
fi
