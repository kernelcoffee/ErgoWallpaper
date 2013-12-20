#! /bin/bash

# ERGOWALLPAPER
# Maintainer: @kernelcoffee
# App Version: 0.1

### BEGIN INIT INFO
# Provides:          ergowallpaper
# Required-Start:    $local_fs $remote_fs $network $syslog redis-server
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ErgoWallpaper
# Description:       ErgoWallaper
### END INIT INFO


APP_ROOT="/home/deploy/apps/ergowallpaper/current"
APP_USER="deploy"
DAEMON_OPTS="-c $APP_ROOT/config/unicorn.rb -E production"
PID_PATH="$APP_ROOT/tmp/pids"
SOCKET_PATH="/tmp/"
WEB_SERVER_PID="$PID_PATH/unicorn.pid"
SIDEKIQ_PID="$PID_PATH/sidekiq.pid"
STOP_SIDEKIQ="RAILS_ENV=production bundle exec rake sidekiq:stop"
START_SIDEKIQ="RAILS_ENV=production bundle exec rake sidekiq:start"
NAME="ergowallpaper"
DESC="ErgoWallpaper service"

check_pid(){
  if [ -f $WEB_SERVER_PID ]; then
    PID=`cat $WEB_SERVER_PID`
    SPID=`cat $SIDEKIQ_PID`
    STATUS=`ps aux | grep $PID | grep -v grep | wc -l`
  else
    STATUS=0
    PID=0
  fi
}

execute() {
  sudo -u $APP_USER -H bash -l -c "$1"
}

start() {
  cd $APP_ROOT
  check_pid
  if [ "$PID" -ne 0 -a "$STATUS" -ne 0 ]; then
    # Program is running, exit with error code 1.
    echo "Error! $DESC $NAME is currently running!"
    exit 1
  else
    if [ `whoami` = root ]; then
      execute "rm -f $SOCKET_PATH/unicorn.ergowallpaper.socket"
      execute "RAILS_ENV=production bundle exec unicorn_rails $DAEMON_OPTS  > /dev/null  2>&1 &"
      execute "mkdir -p $PID_PATH && $START_SIDEKIQ > /dev/null  2>&1 &"
      echo "$DESC started"
    fi
  fi
}

stop() {
  cd $APP_ROOT
  check_pid
  if [ "$PID" -ne 0 -a "$STATUS" -ne 0 ]; then
    ## Program is running, stop it.
    kill -QUIT `cat $WEB_SERVER_PID`
    execute "mkdir -p $PID_PATH && $STOP_SIDEKIQ  > /dev/null  2>&1 &"
    rm -f "$WEB_SERVER_PID" >> /dev/null
    echo "$DESC stopped"
  else
    ## Program is not running, exit with error.
    echo "Error! $DESC not started!"
    exit 1
  fi
}

restart() {
  cd $APP_ROOT
  check_pid
  if [ "$PID" -ne 0 -a "$STATUS" -ne 0 ]; then
    echo "Restarting $DESC..."
    kill -USR2 `cat $WEB_SERVER_PID`
    execute "mkdir -p $PID_PATH && $STOP_SIDEKIQ  > /dev/null  2>&1 &"
    if [ `whoami` = root ]; then
      execute "mkdir -p $PID_PATH && $START_SIDEKIQ  > /dev/null  2>&1 &"
    fi
    echo "$DESC restarted."
  else
    echo "Error, $NAME not running!"
    exit 1
  fi
}

status() {
  cd $APP_ROOT
  check_pid
  if [ "$PID" -ne 0 -a "$STATUS" -ne 0 ]; then
    echo "$DESC / Unicorn with PID $PID is running."
    echo "$DESC / Sidekiq with PID $SPID is running."
  else
    echo "$DESC is not running."
    exit 1
  fi
}

## Check to see if we are running as root first.
## Found at http://www.cyberciti.biz/tips/shell-root-user-check-script.html
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  restart)
        restart
        ;;
  reload|force-reload)
        echo -n "Reloading $NAME configuration: "
        kill -HUP `cat $PID`
        echo "done."
        ;;
  status)
        status
        ;;
  *)
        echo "Usage: sudo service ergowallpaper {start|stop|restart|reload}" >&2
        exit 1
        ;;
esac

exit 0
