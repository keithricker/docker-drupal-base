FROM kricker/server-base:latest

ENV REBUILD yes

# Create files directory if it doesn't yet exist.
RUN cd /srv/www/siteroot && filesdirectory=/srv/www/siteroot/sites/default/files
RUN if [ ! -d "$filesdirectory" ]; then \
  mkdir -p /srv/www/siteroot/sites/default/files; \
fi
RUN chmod a+w /srv/www/siteroot/sites/default -R

# Install Composer.
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Install Drush 6.
RUN composer global require drush/drush:6.*
RUN composer global update
RUN ln -s /root/.composer/vendor/bin/drush /usr/bin

# download drush recipes
RUN drush dl drush_recipes-7.x-1.x-dev -y

# For compatibility with Kalabox 2
# The data container will manage these config files if using kalabox.
# Because we are awesome, we will not force these settings should some wish not to use kalabox.

# php.ini
RUN if [ -f src/config/php/php.ini ] && [ -f /etc/php5/fpm/php.ini ]; \
	then \
	rm /etc/php5/fpm/php.ini \
    ln -s /src/config/php/php.ini /etc/php5/fpm/php.ini \
    sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php5/fpm/php-fpm.conf; \
    fi
# pool conf
RUN if [ -f /src/config/php/www.conf ] && [ -f /etc/php5/fpm/pool.d/www.conf ]; \
	then \
	rm /etc/php5/fpm/pool.d/www.conf \
	ln -s /src/config/php/www.conf /etc/php5/fpm/pool.d/www.conf; \
	fi
RUN if [ -f /src/config/php/20-apc.ini ] && [ -f /etc/php5/conf.d/20-apc.ini ]; \
	then \
	rm /etc/php5/conf.d/20-apc.ini \
	ln -s /src/config/php/20-apc.ini /etc/php5/conf.d/20-apc.ini; \
	fi	
#20-xdebug.ini
RUN if [ -f /src/config/php/20-xdebug.ini ] && [ -f /etc/php5/conf.d/20-xdebug.ini ]; \
	then \
	rm /etc/php5/conf.d/20-xdebug.ini \
	ln -s /src/config/php/20-xdebug.ini /etc/php5/conf.d/20-xdebug.ini; \
	fi

# For compatibility with Apache. 
# Again, we don't force these settings on those wishing to use other systems.
# Create some sym-links
RUN if [ -f /src/config/apache2/sites-enabled/www.conf ] && [ -f /etc/apache2/sites-enabled/www.conf ]; \
	then \
    rm /etc/apache2/sites-enabled/www.conf \
    ln -s /src/config/apache2/sites-enabled/www.conf /etc/apache2/sites-enabled/www.conf; \
	fi
RUN if [ -f /src/config/apache2/apache2.conf ] && [ -f /etc/apache2/apache2.conf ]; \
	then \
    rm /etc/apache2/apache2.conf \
    ln -s /src/config/apache2/apache2.conf /etc/apache2/apache2.conf; \
	fi
RUN if [ -f /etc/apache2/sites-common/redirect ] && [ -f /src/config/apache2/redirect ]; \
	then \
    rm /etc/apache2/sites-common/redirect \
    ln -s /src/config/apache2/redirect /etc/apache2/sites-common/redirect;\
	fi

# And finally we configure settings in the event we're using nginx with Kalabox.
RUN if [ -f /etc/nginx/nginx.conf ] && [ -f /src/config/nginx/nginx.conf ]; \
	then \
    rm /etc/nginx/nginx.conf \
    ln -s /src/config/nginx/nginx.conf /etc/nginx/nginx.conf; \
	fi
RUN if [ -f /etc/nginx/nginx.conf ] && [ -f /src/config/nginx/nginx.conf ]; \
	then \
    rm /etc/nginx/sites-enabled/default \
    ln -s /src/config/nginx/site.conf /etc/nginx/sites-enabled/default; \
	fi

# Add start script.
COPY start2.sh /root/start2.sh
RUN chmod 777 /root/start2.sh

# Define default command.
CMD ["/root/start2.sh"]