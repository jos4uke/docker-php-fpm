FROM ubuntu:14.04.3

MAINTAINER Joseph Tran <Joseph.Tran@versailles.inra.fr>

# set locales
RUN localedef -i fr_FR -c -f UTF-8 -A /usr/share/locale/locale.alias fr_FR.UTF-8
ENV LANG fr_FR.utf8

# set timezone
RUN echo "Europe/Paris" > /etc/timezone    
RUN dpkg-reconfigure -f noninteractive tzdata

# Suppress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Add repositories
# Add source repository for php56
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list && \ 
    echo "deb http://ppa.launchpad.net/ondrej/php5/ubuntu trusty main" >> /etc/apt/sources.list.d/ondrej-php5-5.6-trusty.list && \
    echo "deb-src http://ppa.launchpad.net/ondrej/php5/ubuntu trusty main" >> /etc/apt/sources.list.d/ondrej-php5-5.6-trusty.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C && \
    apt-get update && \
    apt-get -y dist-upgrade

# bugged
#RUN apt-get update && \
#apt-get install -y software-properties-common
#RUN add-apt-repository ppa:ondrej/php5-5.6 && \
#apt-get update                                 

# Update base image
# Install software requirements
# DEFAULT_BUILD_PACKAGES="php5 php5-common libapache2-mod-php5 libapache2-mod-php5filter php5-cgi php5-cli php5-phpdbg php5-fpm libphp5-embed php5-dev php5-dbg php-pear php5-curl php5-enchant php5-gd php5-gmp php5-imap php5-interbase php5-intl php5-ldap php5-mcrypt php5-readline php5-mysql php5-mysqlnd php5-odbc php5-pgsql php5-pspell php5-recode php5-snmp php5-sqlite php5-sybase php5-tidy php5-xmlrpc php5-xsl"
## bcmath included in php5-fpm
## mhash included in php5-common
# No need
## use nginx, no need of
### libapache2-mod-php5 libapache2-mod-php5filter
## use postgres, no need of interbase, mysql, sybase
### php5-interbase php5-mysql php5-mysqlnd php5-sybase
# EXTRA_BUILD_PACKAGES
## for dev env install php5-xdebug
RUN apt-get update && \
apt-get upgrade -y && \
apt-get install -y software-properties-common && \
PHP5_BUILD_PACKAGES="php5 php5-common php5-cli php5-fpm php5-dbg php-pear php5-curl php5-gd php5-intl php5-ldap php5-mcrypt php5-readline php5-odbc php5-pgsql php5-recode php5-sqlite php5-tidy php5-xmlrpc php5-xsl" && \
apt-get install -y ${PHP5_BUILD_PACKAGES} && \
EXTRA_BUILD_PACKAGES="php5-memcache php5-memcached php5-xcache php5-xdebug" && \
apt-get -y install $EXTRA_BUILD_PACKAGES && \
apt-get remove --purge -y software-properties-common && \
apt-get autoremove -y && \
apt-get clean && \
apt-get autoclean && \
echo -n > /var/lib/apt/extended_states && \
rm -rf /var/lib/apt/lists/* && \
rm -rf /usr/share/man/?? && \
rm -rf /usr/share/man/??_*

# tweak php-fpm config
# add own conf files to php-fpm prevents it to start
## something is mis-configured or missing but no error thrown at startup
#RUN rm -rf /etc/php5/fpm/php-fpm.conf
#RUN rm -rf /etc/php5/fpm/pool.d/www.conf
#ADD ./conf/php-fpm.conf /etc/php5/fpm/php-fpm.conf
#ADD ./conf/pool.d/ /etc/php5/fpm/pool.d
#RUN rm -rf /etc/php5/cli/php.ini
#RUN ln -s /etc/php5/fpm/php.ini /etc/php5/cli/php.ini
# configure at build-time
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 25M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 25M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;*date.timezone =/date.timezone = Europe\/Paris/" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
sed -i -e "s/listen\s*=\s*\/var\/run\/php5-fpm.sock/listen = 9000/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/;*pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf

RUN mv /etc/php5/cli/php.ini /etc/php5/cli/php.ini.bkp
RUN ln -s /etc/php5/fpm/php.ini /etc/php5/cli/php.ini

RUN usermod -u 1000 www-data

EXPOSE 9000

VOLUME /etc/php5/
VOLUME /var/www

# --nodaemonize/-F : cf php-fpm.conf
ENTRYPOINT ["php5-fpm"]

