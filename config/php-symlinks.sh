#!/bin/bash

if [ -f src/config/php/php.ini ] && [ -f /etc/php5/fpm/php.ini ];
    then
    rm /etc/php5/fpm/php.ini
    ln -s /src/config/php/php.ini /etc/php5/fpm/php.ini
    sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php5/fpm/php-fpm.conf;
fi
# pool conf
if [ -f /src/config/php/www.conf ] && [ -f /etc/php5/fpm/pool.d/www.conf ];
    then
    rm /etc/php5/fpm/pool.d/www.conf
    ln -s /src/config/php/www.conf /etc/php5/fpm/pool.d/www.conf;
fi
if [ -f /src/config/php/20-apc.ini ] && [ -f /etc/php5/conf.d/20-apc.ini ];
    then
    rm /etc/php5/conf.d/20-apc.ini
    ln -s /src/config/php/20-apc.ini /etc/php5/conf.d/20-apc.ini;
fi	
#20-xdebug.ini
if [ -f /src/config/php/20-xdebug.ini ] && [ -f /etc/php5/conf.d/20-xdebug.ini ];
    then
    rm /etc/php5/conf.d/20-xdebug.ini
    ln -s /src/config/php/20-xdebug.ini /etc/php5/conf.d/20-xdebug.ini;
fi