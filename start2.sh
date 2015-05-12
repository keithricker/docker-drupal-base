#!/bin/bash

# Run the parent start script if there is one.
echo "entering the start script ...."
startsh=/root.start.sh
if [ -f "$startsh" ]; then sh /root/start.sh; fi

# Download Drupal if not already there
indexfile=/srv/www/siterooot/index.php
if [ -f "$indexfile" ];
	then
		echo "Site already installed. Yay."
	else
		echo "Site not installed. Pulling latest drupal 7 ... "
		cd /srv/www && drush dl drupal && mv /srv/www/drupal-7* /srv/www/siteroot
		cd /srv/www/siteroot;
fi

if [ -v MYSQL_PORT_3306_TCP_ADDR ]; then mysqlip=$MYSQL_PORT_3306_TCP_ADDR else mysqlip=localhost; fi
if [ -v DRUPAL_DB_USERNAME ]; then drupaluname=$DRUPAL_DB_USERNAME else drupaluname=root; fi
if [ -v DRUPAL_DB_PASSWORD ]; 
	then drupalpwd=$DRUPAL_DB_PASSWORD 
else 
	if [ -v MYSQ_ROOT_PASSWORD ]; 
		then drupalpwd=$MYSQL_ROOT_PASSWORD
	else drupalpwd=password;
	fi 
fi

settingsfile=/srv/www/siterooot/sites/default/settings.php
if [ ! -f "$settingsfile" ] && [ -v MYSQL_PORT_3306_TCP_ADDR ];
	then
	    drush si -y minimal --db-url=mysql://${drupaluname}:${drupalpwd}@${mysqlip}/drupal --account-pass=admin
	    installsite=true;
fi

# If the mysql environment variable exists, then alter the settings.php file to point to the right IP address.
if [ -v MYSQL_PORT_3306_TCP_ADDR ]; 
then 
	sed -i "s/'host' => '.*'/'host' => '${MYSQL_PORT_3306_TCP_ADDR}'/g" /srv/www/siteroot/sites/default/settings.php
	sed -i 's/"host" => ".*"/"host" => "${MYSQL_PORT_3306_TCP_ADDR}"/g' /srv/www/siteroot/sites/default/settings.php;
fi

# If the mysql environment variable exists, then alter the settings.php file to point to the right IP address.
if [ -v DRUPAL_DB_USERNAME ]; 
then 
	sed -i "s/'username' => '.*'/'username' => '${DRUPAL_DB_USERNAME}'/g" /srv/www/siteroot/sites/default/settings.php
	sed -i 's/"username" => ".*"/"username" => "${DRUPAL_DB_USERNAME}"/g' /srv/www/siteroot/sites/default/settings.php;
fi

if [ "$drupalpwd" != "password" ]; 
then 
	sed -i "s/'password' => '.*'/'password' => '${drupalpwd}'/g" /srv/www/siteroot/sites/default/settings.php
	sed -i 's/"password" => ".*"/"password" => "${drupalpwd}"/g' /srv/www/siteroot/sites/default/settings.php;
fi

if [ -v DRUPAL_DB_NAME ]; 
then 
	sed -i "s/'database' => '.*'/'database' => '${DRUPAL_DB_NAME}'/g" /srv/www/siteroot/sites/default/settings.php
	sed -i 's/"database" => ".*"/"database" => "${DRUPAL_DB_NAME}"/g' /srv/www/siteroot/sites/default/settings.php;
fi

if [ -v DRUPAL_DB_PORT ]; 
then 
	sed -i "s/'port' => '.*'/'port' => '${DRUPAL_DB_PORT}'/g" /srv/www/siteroot/sites/default/settings.php
	sed -i 's/"port" => ".*"/"port" => "${DRUPAL_DB_PORT}"/g' /srv/www/siteroot/sites/default/settings.php;
fi

varnishdir=/srv/www/siteroot/sites/all/modules/varnish
installmodules=false
if [ -v installsite ] || [ -v REBUILD ]; then installmodules=true; fi
if [ ! -v MYSQL_PORT_3306_TCP_ADDR ] || [ -d "$varnishdir" ]; then installmodules=false; fi

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
