#!/bin/bash
# /etc/init.d/minecraft
# Author by Nav Vasky
# Modified by KJie

### BEGIN INIT INFO
# Provides:   MineCraft
# Required-Start: $local_fs $remote_fs screen-cleanup
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    MineCraft server
# Description:    Starts the MineCraft server
### END INIT INFO

#Settings
SERVICE='spigot.jar'	#The name of the jar file used to boot the server, also the name of the process
SCREENNAME='minecraft'	#The name screen will use
OPTIONS='nogui'			#Optional arguments for MineCraft
USERNAME='minecraft'			#The user name of the Linux account to be used
WORLD='world'			#The selected world to load when the server boots
MCPATH="/home/$USERNAME/server"	#The file path for the directory where the server jar is held
BACKUPPATH="/home/$USERNAME/mcserver_backup/"	#The file path for the directory for the back ups of the server
MAXHEAP=1536			#The maximum amount of ram allocated to the server
MINHEAP=1024			#The minimum amount of ram allocated to the server
HISTORY=1024			
INVOCATION="java -Xms${MINHEAP}M -Xmx${MAXHEAP}M -XX:+UseConcMarkSweepGC -jar $SERVICE $OPTIONS"


ME=`whoami`
				#Checks if the correct user is executing the service, if not, try to switch user
as_user() {
  if [ $ME == $USERNAME ] ; then
    bash -c "$1"
  else
    su - $USERNAME -c "$1"
  fi
}
#Starts the MineCraft Server
mc_start() {
  if  pgrep -u $USERNAME -f $SERVICE > /dev/null	#Checks if the server is already running
  then
    echo "$SERVICE is already running!"
  else
    echo "Starting $SERVICE..."
    cd $MCPATH
    as_user "cd $MCPATH && screen -h $HISTORY -dmS $SCREENNAME $INVOCATION"	#Starts the server
    sleep 7
    if pgrep -u $USERNAME -f $SERVICE > /dev/null	#Checks if the service started or not
    then
      echo "$SERVICE is now running."
    else
      echo "Error! Could not start $SERVICE!"
    fi
  fi
}
#Turns off saving of the server
mc_saveoff() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null
  then				#Checks if the server is running, then it alerts the users
    echo "$SERVICE is running... suspending saves"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"say SERVER BACKUP STARTING. Server going readonly...\"\015'"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"save-off\"\015'"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"save-all\"\015'"
    sync
    sleep 10
  else
    echo "$SERVICE is not running. Not suspending saves."
  fi
}
#Turns on the saving of the server
mc_saveon() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null
  then				#Checks if the server is running, then it alerts the users
    echo "$SERVICE is running... re-enabling saves"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"save-on\"\015'"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"say SERVER BACKUP ENDED. Server going read-write...\"\015'"
  else
    echo "$SERVICE is not running. Not resuming saves."
  fi
}
#Stops the server
mc_stop() {
  if pgrep -u $USERNAME -f $SERVICE > /dev/null
  then				#Alerts the users on the server of incoming server shut down
    echo "Stopping $SERVICE"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map...\"\015'"	
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"save-all\"\015'"
    sleep 10
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"stop\"\015'"
    sleep 7
  else
    echo "$SERVICE was not running."
  fi
  if pgrep -u $USERNAME -f $SERVICE > /dev/null	#Checks if the server is still running
  then
    echo "Error! $SERVICE could not be stopped."
  else
    echo "$SERVICE is stopped."
  fi
} 
#Backs up the server into a compressed file according to the settings
mc_backup() {
   mc_saveoff				#Disables saves
   
   NOW=`date "+%Y-%m-%d_%Hh%M"`
   BACKUP_FILE="$BACKUPPATH/${WORLD}_${NOW}.tar"
   echo "Backing up minecraft world..."
   #as_user "cd $MCPATH && cp -r $WORLD $BACKUPPATH/${WORLD}_`date "+%Y.%m.%d_%H.%M"`"
   as_user "tar -C \"$MCPATH\" -cf \"$BACKUP_FILE\" $WORLD"
   as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" ${WORLD}_nether"
   as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" ${WORLD}_the_end"
   as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" server.properties"
   #as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" plugins"

   echo "Backing up $SERVICE"
   as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" $SERVICE"
   #as_user "cp \"$MCPATH/$SERVICE\" \"$BACKUPPATH/minecraft_server_${NOW}.jar\""

   mc_saveon

   echo "Compressing backup..."
   as_user "gzip -f \"$BACKUP_FILE\""
   echo "Done."
}
#Allows the execution of commands outside of the screen
mc_command() {
  command="$1";	#Takes the first argument as the command
  if pgrep -u $USERNAME -f $SERVICE > /dev/null
  then					#Writes to the latest log
    pre_log_len=`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`	
    echo "$SERVICE is running... executing command"
    as_user "screen -p 0 -S $SCREENNAME -X eval 'stuff \"$command\"\015'"
    sleep .1 # assumes that the command will run and print to the log file in less than .1 seconds
    # print output
    tail -n $[`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`-$pre_log_len] "$MCPATH/logs/latest.log"
  fi
}

#Start-Stop here
case "$1" in
  start)
    mc_start
    ;;
  stop)
    mc_stop
    ;;
  restart)
    mc_stop
    mc_start
    ;;
  backup)
    mc_backup
    ;;
  status)
    if pgrep -u $USERNAME -f $SERVICE > /dev/null
    then
      echo "$SERVICE is running."
    else
      echo "$SERVICE is not running."
    fi
    ;;
  command)
    if [ $# -gt 1 ]; then
      shift
      mc_command "$*"
    else
      echo "Must specify server command (try 'help'?)"
    fi
    ;;

  *)
  echo "Usage: $0 {start|stop|backup|status|restart|command \"server command\"}"
  exit 1
  ;;
esac

exit 0
