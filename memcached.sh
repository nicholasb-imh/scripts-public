#!/bin/bash

SERVICE=${1?Error: missing args: Please define what parts of memcached to install (service, php, all) Usage: memcached.sh [service|php|all]}

if  [ ! $# == 1 ]
	then
	echo >&2 "Usage: memcached.sh [service|php|all]" 
	exit
fi

memcached-service() {
#libevent
cd /usr/src && wget https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz
tar -xvf libevent-2.1.8-stable.tar.gz 
cd libevent-2.1.8-stable
yes | ./configure && make && make install
#libmemcached
cd /usr/src && wget https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz
tar -xvf libmemcached-1.0.18.tar.gz
cd libmemcached-1.0.18
yes | ./configure && make && make install
#memcached
cd /usr/src && wget http://www.memcached.org/files/memcached-1.5.1.tar.gz
tar -xvf memcached-1.5.1.tar.gz
cd memcached-1.5.1
yes | ./configure --with-libevent=/usr/local/; make; make install

#Configuration files
cat > /etc/memcached.conf << "EOF"
# Max memory in footprint - be careful setting this (in MB)
-m 16
# default port
-p 11211
-u nobody
# only listen locally
-l 127.0.0.1
EOF

touch /etc/init.d/memcached
chmod +x /etc/init.d/memcached

cat << EOF >> /etc/init.d/memcached
#!/bin/bash
# the line below is needed for chkconfig, see man chkconfig
# description: This shell script takes care of starting and stopping \
#              standalone memcached.
# 
# memcached    This shell script takes care of starting and stopping
#              standalone memcached.
#
# chkconfig: - 80 12
# processname: memcached
# config: /etc/memcached.conf
# Source function library.

. /etc/rc.d/init.d/functions
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/local/bin/memcached
DAEMONBOOTSTRAP=/usr/local/bin/start-memcached
DAEMONCONF=/etc/memcached.conf
NAME=memcached
DESC=memcached
PIDFILE=/var/run/$NAME.pid
[ -x $DAEMON ] || exit 0
[ -x $DAEMONBOOTSTRAP ] || exit 0
RETVAL=0
start()
{
	echo -n $"Starting $DESC: "
	daemon $DAEMONBOOTSTRAP $DAEMONCONF
	RETVAL=$?
	[ $RETVAL -eq 0 ] && touch $PIDFILE
	echo
	return $RETVAL
}
stop()
{
	echo -n $"Shutting down $DESC: "
	killproc $NAME
	RETVAL=$?
	echo
	[ $RETVAL -eq 0 ] && rm -f $PIDFILE
	return $RETVAL
}

case "$1" in
	start)
		start
	;;
	stop)
		stop
	;;
	restart|reload)
		stop
		start
		RETVAL=$?
	;;
	status)
		status $prog
		RETVAL=$?
	;;
	*)
		echo $"Usage: $0 {start|stop|restart|status}"
		exit 1
esac
exit $RETVAL

touch /usr/local/bin/start-memcached
chmod +x /usr/local/bin/start-memcached

cat << EOF >> /usr/local/bin/start-memcached
#!/usr/bin/perl -w

use strict;

if ($> != 0 and $< != 0)
{
	print STDERR "Only root wants to run start-memcached.\n";
	exit;
}

my $etcfile = shift || "/etc/memcached.conf";
my $params = [];
my $etchandle; 

# This script assumes that memcached is located at /usr/bin/memcached, and
# that the pidfile is writable at /var/run/memcached.pid

my $memcached = "/usr/local/bin/memcached";
my $pidfile = "/var/run/memcached.pid";

# If we don't get a valid logfile parameter in the /etc/memcached.conf file,
# we'll just throw away all of our in-daemon output. We need to re-tie it so
# that non-bash shells will not hang on logout. Thanks to Michael Renner for 
# the tip

my $fd_reopened = "/dev/null";
sub handle_logfile
{
	my ($logfile) = @_;
	$fd_reopened = $logfile;
}

sub reopen_logfile
{
	my ($logfile) = @_;
	open *STDERR, ">>$logfile";
	open *STDOUT, ">>$logfile";
	open *STDIN, ">>/dev/null";
	$fd_reopened = $logfile;
}

# This is set up in place here to support other non -[a-z] directives
my $conf_directives = {
 "logfile" => \&handle_logfile};
 
if (open $etchandle, $etcfile)
{
	foreach my $line (<$etchandle>)
	{
		$line =~ s/\#.*//go;
		$line = join ' ', split ' ', $line;
		next unless $line;
		next if $line =~ /^\-[dh]/o;
		if ($line =~ /^[^\-]/o)
		{
			my ($directive, $arg) = $line =~ /^(.*?)\s+(.*)/; 
			$conf_directives->{$directive}->($arg);
			next;
		}
		push @$params, $line;
	}
}

unshift @$params, "-u root" unless (grep $_ eq '-u', @$params);
$params = join " ", @$params;
if (-e $pidfile)
{
	open PIDHANDLE, "$pidfile";
	my $localpid = <PIDHANDLE>;
	close PIDHANDLE;
	chomp $localpid;
	if (-d "/proc/$localpid")
	{
		print STDERR "memcached is already running.\n"; 
		exit;
	}
	else
	{
		`rm -f $localpid`;
	}
}

my $pid = fork();
if ($pid == 0)
{
	reopen_logfile($fd_reopened);
	exec "$memcached $params";
	exit(0);
}
elsif (open PIDHANDLE,">$pidfile")
{
	print PIDHANDLE $pid;
	close PIDHANDLE;
}
else
{
	print STDERR "Can't write pidfile to $pidfile.\n";
}
EOF

service memcached start
ps -aef | grep memcached
}


memcached-php() {

yes | /opt/cpanel/ea-php55/root/usr/bin/pecl install memcache
yes | /opt/cpanel/ea-php56/root/usr/bin/pecl install memcache
cd /usr/local/src;
wget https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.zip; unzip NON_BLOCKING_IO_php7.zip; cd pecl-memcache-NON_BLOCKING_IO_php7;
yes | /opt/cpanel/ea-php70/root/usr/bin/phpize && yes | ./configure --enable-memcache --with-php-config=/opt/cpanel/ea-php70/root/usr/bin/php-config && make
make install
make clean
make install

echo 'extension=memcache.so' >> /opt/cpanel/ea-php70/root/etc/php.ini
echo 'extension=memcache.so' >> /opt/cpanel/ea-php71/root/etc/php.ini
echo 'extension=memcache.so' >> /opt/cpanel/ea-php72/root/etc/php.ini
echo 'extension=memcache.so' >> /opt/cpanel/ea-php73/root/etc/php.ini

cd /usr/src && yes | /opt/cpanel/ea-php56/root/usr/bin/pecl download memcached-2.2.0 && tar -xvf memcached-2.2.0.tgz 
cd memcached-2.2.0
yes | /opt/cpanel/ea-php55/root/usr/bin/phpize && yes | ./configure --with-php-config=/opt/cpanel/ea-php55/root/usr/bin/php-config --disable-memcached-sasl && make && make install
make clean
yes | /opt/cpanel/ea-php56/root/usr/bin/phpize && yes | ./configure --with-php-config=/opt/cpanel/ea-php56/root/usr/bin/php-config --disable-memcached-sasl && make && make install
echo 'extension=memcached.so' >> /opt/cpanel/ea-php55/root/etc/php.ini
echo 'extension=memcached.so' >> /opt/cpanel/ea-php56/root/etc/php.ini
cd /usr/src && /opt/cpanel/ea-php70/root/usr/bin/pecl download memcached-3.0.3 && tar -xvf memcached-3.0.3.tgz
cd memcached-3.0.3 
yes | /opt/cpanel/ea-php70/root/usr/bin/phpize && yes | ./configure --with-php-config=/opt/cpanel/ea-php70/root/usr/bin/php-config --disable-memcached-sasl && make && make install
make clean
yes | /opt/cpanel/ea-php71/root/usr/bin/phpize && yes | ./configure --with-php-config=/opt/cpanel/ea-php71/root/usr/bin/php-config --disable-memcached-sasl && make && make install
make clean
yes | /opt/cpanel/ea-php72/root/usr/bin/phpize && yes | ./configure --with-php-config=/opt/cpanel/ea-php72/root/usr/bin/php-config --disable-memcached-sasl && make && make install
make clean
yes | /opt/cpanel/ea-php73/root/usr/bin/phpize && yes | ./configure --with-php-config=/opt/cpanel/ea-php73/root/usr/bin/php-config --disable-memcached-sasl && make && make install

echo 'extension=memcached.so' >> /opt/cpanel/ea-php70/root/etc/php.ini
echo 'extension=memcached.so' >> /opt/cpanel/ea-php71/root/etc/php.ini
echo 'extension=memcached.so' >> /opt/cpanel/ea-php72/root/etc/php.ini
echo 'extension=memcached.so' >> /opt/cpanel/ea-php73/root/etc/php.ini

for i in 55 56 70 71 72 73; do echo Memcache and memcached is installed for PHP $i && /opt/cpanel/ea-php$i/root/usr/bin/php -m | grep memcache; done

}


if [ $SERVICE = "service" ] 
then
	memcached-service
elif [ $SERVICE = "php" ]
then
	memcached-php
elif [ $SERVICE = "all" ]
then 
	memcached-service
	memcached-php
else
	echo >&2 "Error: malformed args: Please define what parts of memcached to install using arguments \"service\" \"php\" or \"all\"). Usage: memcached.sh [service|php|all]"; exit 1
fi



printf "\nHave a nice day :)\n\n"