#!/bin/bash
# Nextcloud
##########################

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# ### Installing Nextcloud

echo "Installing Nextcloud FULL..."

InstallNextcloud() {

	version=$1
	hash=$2
	version_contacts=$3
	hash_contacts=$4
	version_calendar=$5
	hash_calendar=$6
	version_user_external=${7:-}
	hash_user_external=${8:-}

	echo
	echo "Upgrading to Nextcloud version $version"
	echo

	# Download and verify
	wget_verify https://download.nextcloud.com/server/releases/nextcloud-$version.zip $hash /tmp/nextcloud.zip

	# Remove the current owncloud/Nextcloud
	rm -rf /usr/local/lib/nextcloud

	# Extract ownCloud/Nextcloud
	unzip -q /tmp/nextcloud.zip -d /usr/local/lib
	rm -f /tmp/nextcloud.zip

	# The two apps we actually want are not in Nextcloud core. Download the releases from
	# their github repositories.
	mkdir -p /usr/local/lib/nextcloud/apps

	wget_verify https://github.com/nextcloud/contacts/releases/download/v$version_contacts/contacts.tar.gz $hash_contacts /tmp/contacts.tgz
	tar xf /tmp/contacts.tgz -C /usr/local/lib/nextcloud/apps/
	rm /tmp/contacts.tgz

	wget_verify https://github.com/nextcloud-releases/calendar/releases/download/v$version_calendar/calendar.tar.gz $hash_calendar /tmp/calendar.tgz
	tar xf /tmp/calendar.tgz -C /usr/local/lib/nextcloud/apps/
	rm /tmp/calendar.tgz

	# Starting with Nextcloud 15, the app user_external is no longer included in Nextcloud core,
	# we will install from their github repository.
	if [ -n "$version_user_external" ]; then
		wget_verify https://github.com/nextcloud/user_external/releases/download/v$version_user_external/user_external-$version_user_external.tar.gz $hash_user_external /tmp/user_external.tgz
		tar -xf /tmp/user_external.tgz -C /usr/local/lib/nextcloud/apps/
		rm /tmp/user_external.tgz
	fi

	# Fix weird permissions.
	chmod 750 /usr/local/lib/nextcloud/{apps,config}

	# Create a symlink to the config.php in STORAGE_ROOT (for upgrades we're restoring the symlink we previously
	# put in, and in new installs we're creating a symlink and will create the actual config later).
	ln -sf $STORAGE_ROOT/nextcloud/config.php /usr/local/lib/nextcloud/config/config.php

	# Make sure permissions are correct or the upgrade step won't run.
	# $STORAGE_ROOT/owncloud may not yet exist, so use -f to suppress
	# that error.
	chown -f -R www-data.www-data $STORAGE_ROOT/nextcloud /usr/local/lib/nextcloud || /bin/true

    if [ -z ${SECRET_KEY_SQLNC} ]; then
        sudo -u www-data php /usr/local/lib/nextcloud/occ upgrade

        if [ \( $? -ne 0 \) -a \( $? -ne 3 \) ]; then
			echo "Trying nextcloud upgrade again to work around ownCloud upgrade bug..."
			sudo -u www-data php /usr/local/lib/nextcloud/occ upgrade
			if [ \( $? -ne 0 \) -a \( $? -ne 3 \) ]; then exit 1; fi
			sudo -u www-data php /usr/local/lib/nextcloud/occ maintenance:mode --off
			echo "...which seemed to work."
        fi

        # Add missing indices. NextCloud didn't include this in the normal upgrade because it might take some time.
		sudo -u www-data php /usr/local/lib/nextcloud/occ db:add-missing-indices

		# Run conversion to BigInt identifiers, this process may take some time on large tables.
		sudo -u www-data php /usr/local/lib/nextcloud/occ db:convert-filecache-bigint --no-interaction

    fi

}

# Nextcloud Version to install. Checks are done down below to step through intermediate versions.
nextcloud_ver=22.0.0
nextcloud_hash=b528c934e258e8f8de45e896ed1126f741f0b6da
contacts_ver=4.0.0
contacts_hash=f893ca57a543b260c9feeecbb5958c00b6998e18
calendar_ver=2.3.0
calendar_hash=7580f85c781b4709b22a70fdb28cec1ec04361a8
user_external_ver=2.0.0
user_external_hash=e3c96426128fb3a134840a1f9024d26836cb80c2

if [ ! -d /usr/local/lib/nextcloud/ ] || [ ! -z "${RESTORE+x}" ]; then
    echo "--- First installation OR Restoration from backup: database creation"
    # random password
    echo -e "SECRET_KEY_SQLNC : $SECRET_KEY_SQLNC"
    # create mysql DB
    cat > /tmp/mysqlcreate << EOF;
DROP USER IF EXISTS 'nextcloudfull'@'localhost';
FLUSH PRIVILEGES;
CREATE USER 'nextcloudfull'@'localhost' IDENTIFIED BY '${SECRET_KEY_SQLNC}';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloudfull'@'localhost';
FLUSH PRIVILEGES;
EOF

    mysql -uroot < /tmp/mysqlcreate

    rm /tmp/mysqlcreate

else
    echo "a nextcloud instance is already present"
fi

# Current Nextcloud Version, #1623
# Checking /usr/local/lib/owncloud/version.php shows version of the Nextcloud application, not the DB
# $STORAGE_ROOT/owncloud is kept together even during a backup.  It is better to rely on config.php than
# version.php since the restore procedure can leave the system in a state where you have a newer Nextcloud
# application version than the database.

# If config.php exists, get version number, otherwise CURRENT_NEXTCLOUD_VER is empty.
if [ -f "$STORAGE_ROOT/nextcloud/config.php" ]; then
	CURRENT_NEXTCLOUD_VER=$(php -r "include(\"$STORAGE_ROOT/nextcloud/config.php\"); echo(\$CONFIG['version']);")
else
	CURRENT_NEXTCLOUD_VER=""
fi

# If the Nextcloud directory is missing (never been installed before, or the nextcloud version to be installed is different
# from the version currently installed, do the install/upgrade
if [ ! -d /usr/local/lib/nextcloud/ ] || [[ ! ${CURRENT_NEXTCLOUD_VER} =~ ^$nextcloud_ver ]]; then

    echo "Nextcloud directory is missing or nextcloud version to be installed is different : backup and upgrade"

	# Stop php-fpm if running. If theyre not running (which happens on a previously failed install), dont bail.
	service php$(php_version)-fpm stop &> /dev/null || /bin/true

	# Backup the existing ownCloud/Nextcloud.
	# Create a backup directory to store the current installation and database to
	BACKUP_DIRECTORY=$STORAGE_ROOT/nextcloud-backup/$(date +"%Y-%m-%d-%T")
	mkdir -p "$BACKUP_DIRECTORY"
	if [ -d /usr/local/lib/nextcloud/ ]; then
		echo "Upgrading Nextcloud --- backing up existing installation, configuration, and database to directory to $BACKUP_DIRECTORY..."
		cp -r /usr/local/lib/nextcloud "$BACKUP_DIRECTORY/nextcloud-install"
	fi
	if [ -e $STORAGE_ROOT/nextcloud/nextcloud.db ]; then
		cp $STORAGE_ROOT/nextcloud/nextcloud.db $BACKUP_DIRECTORY
	fi
	if [ -e $STORAGE_ROOT/nextcloud/config.php ]; then
		cp $STORAGE_ROOT/nextcloud/config.php $BACKUP_DIRECTORY
	fi

	# If ownCloud or Nextcloud was previously installed....
	if [ ! -z ${CURRENT_NEXTCLOUD_VER} ]; then
        if [[ ${CURRENT_NEXTCLOUD_VER} =~ ^18 ]]; then
                    InstallNextcloud 19.0.4 01e98791ba12f4860d3d4047b9803f97a1b55c60 3.4.1 aee680a75e95f26d9285efd3c1e25cf7f3bfd27e 2.0.3 9d9717b29337613b72c74e9914c69b74b346c466 1.0.0 3bf2609061d7214e7f0f69dd8883e55c4ec8f50a
                    CURRENT_NEXTCLOUD_VER="19.0.4"
        fi
	fi

    mkdir -p $STORAGE_ROOT/nextcloud/SQL/

	InstallNextcloud $nextcloud_ver $nextcloud_hash $contacts_ver $contacts_hash $calendar_ver $calendar_hash $user_external_ver $user_external_hash

	# Nextcloud 20 needs to have some optional columns added
	#sudo -u www-data php /usr/local/lib/nextcloud/occ db:add-missing-columns
fi

# ### Configuring Nextcloud

if [ -f $STORAGE_ROOT/nextcloud/config.php ] ; then
    secrettorestore=$(awk -F"'" '/secret/{print $4}' /home/user-data/nextcloud/config.php)
    echo "secret to restore : $secrettorestore"
fi


# Setup Nextcloud if the Nextcloud database does not yet exist. Running setup when
# the database does exist wipes the database and user data.
if [ ! -f $STORAGE_ROOT/nextcloud/config.php ] || [ ! -z "${RESTORE+x}" ]; then

    echo "config.php is not present : generating config file"
	# Create user data directory
	mkdir -p $STORAGE_ROOT/nextcloud

	# Create an initial configuration file.
	#instanceid=oc$(echo $PRIMARY_HOSTNAME | sha1sum | fold -w 10 | head -n 1)
    instanceid=ocNCFULL
	cat > $STORAGE_ROOT/nextcloud/config.php <<EOF;
<?php
\$CONFIG = array (
  'datadirectory' => '$STORAGE_ROOT/nextcloud',

  'instanceid' => '$instanceid',

  'forcessl' => true, # if unset/false, Nextcloud sends a HSTS=0 header, which conflicts with nginx config

  'user_backends' => array(
    array(
      'class' => 'OC_User_IMAP',
        'arguments' => array(
          '127.0.0.1', 143, null
         ),
    ),
  ),
  'mail_smtpmode' => 'sendmail',
  'mail_smtpsecure' => '',
  'mail_smtpauthtype' => 'LOGIN',
  'mail_smtpauth' => false,
  'mail_smtphost' => '',
  'mail_smtpport' => '',
  'mail_smtpname' => '',
  'mail_smtppassword' => '',
  'mail_from_address' => 'nextcloud',
  'dbtype' => 'mysql',
  'dbname' => 'nextcloud',
  'dbhost' => 'localhost',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloudfull',
  'dbpassword' => '${SECRET_KEY_SQLNC}',
);
?>
EOF

	# Create an auto-configuration file to fill in database settings
	# when the install script is run. Make an administrator account
	# here or else the install can't finish.
	adminpassword=$(dd if=/dev/urandom bs=1 count=40 2>/dev/null | sha1sum | fold -w 30 | head -n 1)
	cat > /usr/local/lib/nextcloud/config/autoconfig.php <<EOF;
<?php
\$AUTOCONFIG = array (
  # storage/database
  'dbtype' => 'mysql',
  'dbname' => 'nextcloud',
  'dbhost' => 'localhost',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloudfull',
  'dbpassword' => '${SECRET_KEY_SQLNC}',

  # create an administrator account with a random password so that
  # the user does not have to enter anything on first load of Nextcloud
  'adminlogin'    => 'root',
  'adminpass'     => '$adminpassword',
);
?>
EOF

	# Set permissions
	chown -R www-data.www-data $STORAGE_ROOT/nextcloud /usr/local/lib/nextcloud

	# Execute Nextcloud's setup step, which creates the Nextcloud sqlite database.
	# It also wipes it if it exists. And it updates config.php with database
	# settings and deletes the autoconfig.php file.
    if [ ! -z "${RESTORE+x}" ]; then
        ADMINNC=$(dd if=/dev/urandom bs=1 count=5 2>/dev/null | sha1sum | fold -w 30 | head -n 1)
    else
        ADMINNC=adminnc
    fi

    
    sudo -u www-data php /usr/local/lib/nextcloud/occ -vvv maintenance:install --database=mysql \
        --database-name=nextcloud --database-user=nextcloudfull \
        --data-dir=${STORAGE_ROOT}/nextcloud \
        --database-pass=${SECRET_KEY_SQLNC} --admin-user=${ADMINNC} \
        --admin-pass=${SECRET_KEY_SQLNC} --admin-email=${EMAIL_ADDR}

    if [ ! -z "${RESTORE+x}" ]; then
        echo "restoring config.php from restore"
        gunzip --force /home/user-data/nextcloud/SQL/nextcloud_backup.sql.gz
        mysql nextcloud < /home/user-data/nextcloud/SQL/nextcloud_backup.sql
        secrettoremove=$(awk -F"'" '/secret/{print $4}' /home/user-data/nextcloud/config.php)
        echo "secret to remove : $secrettoremove / secret to restore : $secrettorestore"
        sed -i 's,'"$secrettoremove"','"$secrettorestore"',' $STORAGE_ROOT/nextcloud/config.php
    fi

fi

echo "update config.php"
# Update config.php.
# * trusted_domains is reset to localhost by autoconfig starting with ownCloud 8.1.1,
#   so set it here. It also can change if the box's PRIMARY_HOSTNAME changes, so
#   this will make sure it has the right value.
# * Some settings weren't included in previous versions of Mail-in-a-Box.
# * We need to set the timezone to the system timezone to allow fail2ban to ban
#   users within the proper timeframe
# * We need to set the logdateformat to something that will work correctly with fail2ban
# * mail_domain' needs to be set every time we run the setup. Making sure we are setting
#   the correct domain name if the domain is being change from the previous setup.
# Use PHP to read the settings file, modify it, and write out the new settings array.

TIMEZONE=$(cat /etc/timezone)
CONFIG_TEMP=$(/bin/mktemp)
php <<EOF > $CONFIG_TEMP && mv $CONFIG_TEMP $STORAGE_ROOT/nextcloud/config.php;
<?php
include("$STORAGE_ROOT/nextcloud/config.php");

\$CONFIG['trusted_domains'] = array('nextcloud.$DEFAULT_DOMAIN_GUESS');

\$CONFIG['mail_from_address'] = 'administrator'; # just the local part, matches our master administrator address

\$CONFIG['logtimezone'] = '$TIMEZONE';
\$CONFIG['logdateformat'] = 'Y-m-d H:i:s';

\$CONFIG['mail_domain'] = '$PRIMARY_HOSTNAME';

\$CONFIG['user_backends'] = array(array('class' => 'OC_User_IMAP','arguments' => array('127.0.0.1', 143, null),),);

echo "<?php\n\\\$CONFIG = ";
var_export(\$CONFIG);
echo ";";
?>
EOF

chown www-data.www-data $STORAGE_ROOT/nextcloud/config.php

# Enable/disable apps. Note that this must be done after the Nextcloud setup.
# The firstrunwizard gave Josh all sorts of problems, so disabling that.
# user_external is what allows Nextcloud to use IMAP for login. The contacts
# and calendar apps are the extensions we really care about here.

hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:disable firstrunwizard
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f user_external
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable contacts
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable calendar
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f maps
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f mail
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f news
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f notes
#hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f social
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f socialsharing_email
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f socialsharing_facebook
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f socialsharing_twitter
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f spreed
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f tasks
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f files_frommail
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f keeweb
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f audioplayer
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f audioplayer_editor
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f gpxpod
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f music
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f phonetrack
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f podcast
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f radio
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f talk_simple_poll
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f souvenirs
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f event_update_notification
#hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f files_editors
#hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f quicknotes
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f passwords
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f activitylog
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f external
hide_output sudo -u www-data php /usr/local/lib/nextcloud/console.php app:enable -f flowupload


# When upgrading, run the upgrade script again now that apps are enabled. It seems like
# the first upgrade at the top won't work because apps may be disabled during upgrade?
# Check for success (0=ok, 3=no upgrade needed).
sudo -u www-data php /usr/local/lib/nextcloud/occ upgrade
if [ \( $? -ne 0 \) -a \( $? -ne 3 \) ]; then exit 1; fi


# TODO : make a backup script for the DB with a ln to the latest one
# Set up a cron job for Nextcloud.
cat > /etc/cron.d/mailinabox-nextcloud_full << EOF;
#!/bin/bash
# Mail-in-a-Box
*/5 * * * *	root	sudo -u www-data php -f /usr/local/lib/nextcloud/cron.php
15 03 * * *	root	/usr/bin/mysqldump --single-transaction --routines --events --triggers --add-drop-table --extended-insert -u root nextcloud | gzip -9 > /home/user-data/nextcloud/SQL/nextcloud_backup.sql.gz
EOF
chmod +x /etc/cron.d/mailinabox-nextcloud_full


# There's nothing much of interest that a user could do as an admin for Nextcloud,
# and there's a lot they could mess up, so we don't make any users admins of Nextcloud.
# But if we wanted to, we would do this:
# ```
# for user in $(management/cli.py user admins); do
#	 sqlite3 $STORAGE_ROOT/owncloud/owncloud.db "INSERT OR IGNORE INTO oc_group_user VALUES ('admin', '$user')"
# done
# ```

# Enable PHP modules and restart PHP.
restart_service php$(php_version)-fpm
