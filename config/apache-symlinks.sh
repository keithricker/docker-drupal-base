#!/bin/bash

if [ -f src/config/php/php.ini ] && [ -f /etc/php5/apache2/php.ini ];
    then
    rm /etc/php5/apache2/php.ini
    ln -s /src/config/php/php.ini /etc/php5/apache2/php.ini
    sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php5/fpm/php-fpm.conf;
fi
if [ -f /src/config/apache2/sites-enabled/www.conf ] && [ -f /etc/apache2/sites-enabled/www.conf ];
    then
    rm /etc/apache2/sites-enabled/www.conf
    ln -s /src/config/apache2/sites-enabled/www.conf /etc/apache2/sites-enabled/www.conf;
fi
if [ -f /src/config/apache2/apache2.conf ] && [ -f /etc/apache2/apache2.conf ];
    then
    rm /etc/apache2/apache2.conf
    ln -s /src/config/apache2/apache2.conf /etc/apache2/apache2.conf;
fi
if [ -f /etc/apache2/sites-common/redirect ] && [ -f /src/config/apache2/redirect ];
    then
    rm /etc/apache2/sites-common/redirect
    ln -s /src/config/apache2/redirect /etc/apache2/sites-common/redirect;
fi