#!/bin/bash
# NextcloudFull
##########################

source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

NEXTCLOUD_FULL="/var/www/nextcloudfull/"

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
	#rm -rf /usr/local/lib/owncloud

    # Extract ownCloud/Nextcloud
	unzip -q /tmp/nextcloud.zip -d $NEXTCLOUD_FULL
	rm -f /tmp/nextcloud.zip

    # The two apps we actually want are not in Nextcloud core. Download the releases from
	# their github repositories.
	mkdir -p $NEXTCLOUD_FULL/nextcloud/apps

	wget_verify https://github.com/nextcloud/contacts/releases/download/v$version_contacts/contacts.tar.gz $hash_contacts /tmp/contacts.tgz
	tar xf /tmp/contacts.tgz -C $NEXTCLOUD_FULL/nextcloud/apps/
	rm /tmp/contacts.tgz

	wget_verify https://github.com/nextcloud-releases/calendar/releases/download/v$version_calendar/calendar.tar.gz $hash_calendar /tmp/calendar.tgz
	tar xf /tmp/calendar.tgz -C $NEXTCLOUD_FULL/nextcloud/apps/
	rm /tmp/calendar.tgz

    wget_verify https://github.com/nextcloud/user_external/releases/download/v$version_user_external/user_external-$version_user_external.tar.gz $hash_user_external /tmp/user_external.tgz
	tar -xf /tmp/user_external.tgz -C $NEXTCLOUD_FULL/nextcloud/apps/
	rm /tmp/user_external.tgz

    # Fix weird permissions.
	chmod 750 $NEXTCLOUD_FULL/nextcloud/{apps,config}

	# Create a symlink to the config.php in STORAGE_ROOT (for upgrades we're restoring the symlink we previously
	# put in, and in new installs we're creating a symlink and will create the actual config later).
	ln -sf $NEXTCLOUD_FULL/nextcloud//config.php $NEXTCLOUD_FULL/nextcloud/config/config.php

    # Make sure permissions are correct or the upgrade step won't run.
	# $STORAGE_ROOT/owncloud may not yet exist, so use -f to suppress
	# that error.
	chown -f -R www-data.www-data $NEXTCLOUD_FULL/ || /bin/true

# create mysql DB
cat > /tmp/mysqlcreate << EOF;
CREATE USER 'nextcloudfull'@'localhost' IDENTIFIED BY 'BLA123';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloudfull'@'localhost';
FLUSH PRIVILEGES;
EOF

    sudo mysql -uroot -p < /tmp/mysqlcreate

    rm /tmp/mysqlcreate

    sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/occ maintenance:install --database=mysql --database-name=nextcloud --database-user=nextcloudfull --database-pass=BLA123 --admin-user=toto --admin-pass=toto --admin-email=manu@evargas.org

    

    # Add missing indices. NextCloud didn't include this in the normal upgrade because it might take some time.
	sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/occ db:add-missing-indices

	# Run conversion to BigInt identifiers, this process may take some time on large tables.
	sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/occ db:convert-filecache-bigint --no-interaction
}



# Nextcloud Version to install. Checks are done down below to step through intermediate versions.
nextcloud_ver=22.0.0
nextcloud_hash=b528c934e258e8f8de45e896ed1126f741f0b6da
contacts_ver=4.0.0
contacts_hash=f893ca57a543b260c9feeecbb5958c00b6998e18
calendar_ver=2.3.0
calendar_hash=7580f85c781b4709b22a70fdb28cec1ec04361a8
user_external_ver=1.0.0
user_external_hash=3bf2609061d7214e7f0f69dd8883e55c4ec8f50a

mkdir -p $NEXTCLOUD_FULL

# Current Nextcloud Version, #1623
# Checking /usr/local/lib/owncloud/version.php shows version of the Nextcloud application, not the DB
# $STORAGE_ROOT/owncloud is kept together even during a backup.  It is better to rely on config.php than
# version.php since the restore procedure can leave the system in a state where you have a newer Nextcloud
# application version than the database.

# If config.php exists, get version number, otherwise CURRENT_NEXTCLOUD_VER is empty.
if [ -f "$NEXTCLOUD_FULL/config.php" ]; then
	CURRENT_NEXTCLOUD_VER=$(php -r "include(\"$NEXTCLOUD_FULL/nextcloud/config.php\"); echo(\$CONFIG['version']);")
else
	CURRENT_NEXTCLOUD_VER=""
fi


InstallNextcloud $nextcloud_ver $nextcloud_hash $contacts_ver $contacts_hash $calendar_ver $calendar_hash $user_external_ver $user_external_hash

# Nextcloud 20 needs to have some optional columns added
sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/occ db:add-missing-columns


# Enable/disable apps. Note that this must be done after the Nextcloud setup.
# The firstrunwizard gave Josh all sorts of problems, so disabling that.
# user_external is what allows Nextcloud to use IMAP for login. The contacts
# and calendar apps are the extensions we really care about here.
hide_output sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/console.php app:disable firstrunwizard
# incompatible > 20.0
#hide_output sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/console.php app:enable user_external
hide_output sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/console.php app:enable contacts
hide_output sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/console.php app:enable calendar

rm /var/www/nextcloudfull/nextcloud/config/config.php

cat > /var/www/nextcloudfull/nextcloud/config/config.php << EOF;
<?php
\$CONFIG = array (
  'instanceid' => 'ocwly6b198oe',
  'forcessl' => true,
  'user_backends' => 
  array (
    0 => 
    array (
      'class' => 'OC_User_IMAP',
      'arguments' => 
      array (
        0 => '127.0.0.1',
        1 => 143,
        2 => NULL,
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
  'mail_from_address' => 'administrator',
  'passwordsalt' => 'QFGemTBcG88bXNgC85faa5jfNwAPf1',
  'secret' => 'GiGf/KCE89gy1R+50ScZ9Hg34t1kvft7lEJhzv9XZoQ401UA',
  'trusted_domains' => 
  array (
    0 => 'nextcloud.evargas.org',
  ),
  'datadirectory' => '/var/www/nextcloudfull/nextcloud/data',
  'version' => '22.0.0.11',
  'dbtype' => 'mysql',
  'dbname' => 'nextcloud',
  'dbhost' => 'localhost',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloudfull',
  'dbpassword' => 'BLA123',
  'installed' => true,
  'logtimezone' => 'Europe/Paris',
  'logdateformat' => 'Y-m-d H:i:s',
  'mail_domain' => 'mybox.evargas.org',
  'theme' => '',
  'loglevel' => 2,
  'maintenance' => false,
);
EOF

chown www-data:www-data /var/www/nextcloudfull/nextcloud/config/config.php

sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/occ upgrade
sudo -u www-data php $NEXTCLOUD_FULL/nextcloud/occ maintenance:mode --off

# Set up a cron job for Nextcloud.
cat > /etc/cron.d/mailinabox-nextcloudfull << EOF;
#!/bin/bash
# Mail-in-a-Box
*/5 * * * *	root	sudo -u www-data php -f $NEXTCLOUD_FULL/nextcloud/cron.php
EOF
chmod +x /etc/cron.d/mailinabox-nextcloudfull
