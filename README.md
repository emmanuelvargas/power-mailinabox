(Power) Mail-in-a-Box
=====================

## Installation

- **PRE-REQUISITES:** Debian 10 (Buster) or Ubuntu 20.04 LTS fresh installation

Update packages:
```sh
sudo apt update
sudo apt full-upgrade
```

Make sure that the `en_US.UTF-8` locale exists and is set as primary (this depends on the image you use)
```sh
sudo apt install locales
sudo dpkg-reconfigure locales
```

**Installing Power-Mail-in-a-Box**
```sh
curl https://raw.githubusercontent.com/ddavness/power-mailinabox/master/setup/bootstrap.sh | sudo bash
```

**Restoring Power-Mail-in-a-Box**
```
export PASSPHRASE=$(cat your_backup_secret_key_file.txt)
sudo -E duplicity restore --force file:///path/to/copied/files /home/user-data/
sudo su -
cd mailinabox
RESTORE=1 EMAIL_ADDR="me@yourdomain.lt" ./setup/start.sh
```

## Current Version: v0.54.POWER.3 (Tracking v0.54)

This is a fork of MiaB (duh), hacked and tuned to my needs:

✅ - **Done**

👨‍💻 - **Not there yet, but soon!**

💤 - **I did not begin this part yet!**

- ✅ Support for Debian AND Ubuntu 20.04 LTS;

- ✅ Native support for SMTP relays (For example: SendGrid);

- ✅ Bumped the bootstrap and jQuery dependencies' versions - and we've got a brand new admin panel now!

- ✅ Per-domain `nginx` configuration: Custom pages will no longer have their pages defaulting to the MiaB services (`/admin`, `/mail`, etc.);

- ✅ Updated NextCloud to the latest version available;

- ✅ Performing backups immediately from the admin panel (independently from the daily schedule);

- 👨‍💻 Encrypting backups using user-provided PGP keys;

- ✅ Integrate a WKD server (Web Key Directory) for PGP keys;

- 💤 Restricting access to the admin panel to certain IP's?

- 💤 Customizing MTA names? (because privacy)

### Ideas section:

- 💤 Ability to download the backups from the admin panel;

- 💤 Possibility of making some services optional (if they require more software to be installed) on setup?

- - For example, one might simply not use NextCloud/Munin at all, and they're there... just wasting resources.

- 💤 AXFR Transfers (for secondary DNS) using TSIG?

- 💤 Expand DNS record options?

- 💤 More complete webmail configuration via the admin panel/plugin management?

- 💤 Expand the TOTP Two-Factor-Authentication for the webmail?

- - Maybe U2F one day, too, but I don't have a capable device for this just yet...

- 💤 Anything else I might need to use;

All in all, I think I should rename this to something like "Central [Clown Computing](https://www.urbandictionary.com/define.php?term=clown%20computing)", since I'm trying to cram as many services as possible into that poor machine (Spending 5$ is better than spending 10$)

Original Documentation
======================

By [@JoshData](https://github.com/JoshData) and [contributors](https://github.com/mail-in-a-box/mailinabox/graphs/contributors).

Mail-in-a-Box helps individuals take back control of their email by defining a one-click, easy-to-deploy SMTP+everything else server: a mail server in a box.

**Please see [https://mailinabox.email](https://mailinabox.email) for the project's website and setup guide!**

* * *

Our goals are to:

* Make deploying a good mail server easy.
* Promote [decentralization](http://redecentralize.org/), innovation, and privacy on the web.
* Have automated, auditable, and [idempotent](https://web.archive.org/web/20190518072631/https://sharknet.us/2014/02/01/automated-configuration-management-challenges-with-idempotency/) configuration.
* **Not** make a totally unhackable, NSA-proof server.
* ~~**Not** make something customizable by power users.~~

Additionally, this project has a [Code of Conduct](CODE_OF_CONDUCT.md), which supersedes the goals above. Please review it when joining our community.


In The Box
----------

Mail-in-a-Box turns a fresh ~~Ubuntu 18.04 LTS~~ Debian 10 (Buster) 64-bit machine into a working mail server by installing and configuring various components.

It is a one-click email appliance. There are no user-configurable setup options. It "just works."

The components installed are:

* SMTP ([postfix](http://www.postfix.org/)), IMAP ([Dovecot](http://dovecot.org/)), CardDAV/CalDAV ([Nextcloud](https://nextcloud.com/)), and Exchange ActiveSync ([z-push](http://z-push.org/)) servers
* Webmail ([Roundcube](http://roundcube.net/)), mail filter rules (thanks to Roundcube and Dovecot), and email client autoconfig settings (served by [nginx](http://nginx.org/))
* Spam filtering ([spamassassin](https://spamassassin.apache.org/)) and greylisting ([postgrey](http://postgrey.schweikert.ch/))
* DNS ([nsd4](https://www.nlnetlabs.nl/projects/nsd/)) with [SPF](https://en.wikipedia.org/wiki/Sender_Policy_Framework), DKIM ([OpenDKIM](http://www.opendkim.org/)), [DMARC](https://en.wikipedia.org/wiki/DMARC), [DNSSEC](https://en.wikipedia.org/wiki/DNSSEC), [DANE TLSA](https://en.wikipedia.org/wiki/DNS-based_Authentication_of_Named_Entities), [MTA-STS](https://tools.ietf.org/html/rfc8461), and [SSHFP](https://tools.ietf.org/html/rfc4255) policy records automatically set
* TLS certificates are automatically provisioned using [Let's Encrypt](https://letsencrypt.org/) for protecting https and all of the other services on the box
* Backups ([duplicity](http://duplicity.nongnu.org/)), firewall ([ufw](https://launchpad.net/ufw)), intrusion protection ([fail2ban](http://www.fail2ban.org/wiki/index.php/Main_Page)), and basic system monitoring ([munin](http://munin-monitoring.org/))

It also includes system management tools:

* Comprehensive health monitoring that checks each day that services are running, ports are open, TLS certificates are valid, and DNS records are correct
* A control panel for adding/removing mail users, aliases, custom DNS records, configuring backups, etc.
* An API for all of the actions on the control panel

It also supports static website hosting since the box is serving HTTPS anyway. (To serve a website for your domains elsewhere, just add a custom DNS "A" record in you Mail-in-a-Box's control panel to point domains to another server.)

For more information on how Mail-in-a-Box handles your privacy, see the [security details page](security.md).


Installation
------------

See the [setup guide](https://mailinabox.email/guide.html) for detailed, user-friendly instructions.

For experts, start with a completely fresh (really, I mean it) Ubuntu 18.04 LTS 64-bit machine. On the machine...

Clone this repository and checkout the tag corresponding to the most recent release:

	$ git clone https://github.com/mail-in-a-box/mailinabox
	$ cd mailinabox
	$ git checkout v0.54

Begin the installation.

	$ sudo setup/start.sh

The installation will install, uninstall, and configure packages to turn the machine into a working, good mail server.

For help, DO NOT contact Josh directly --- I don't do tech support by email or tweet (no exceptions).

Post your question on the [discussion forum](https://discourse.mailinabox.email/) instead, where maintainers and Mail-in-a-Box users may be able to help you.

Note that while we want everything to "just work," we can't control the rest of the Internet. Other mail services might block or spam-filter email sent from your Mail-in-a-Box.
This is a challenge faced by everyone who runs their own mail server, with or without Mail-in-a-Box. See our discussion forum for tips about that.


Contributing and Development
----------------------------

Mail-in-a-Box is an open source project. Your contributions and pull requests are welcome. See [CONTRIBUTING](CONTRIBUTING.md) to get started.


The Acknowledgements
--------------------

This project was inspired in part by the ["NSA-proof your email in 2 hours"](http://sealedabstract.com/code/nsa-proof-your-e-mail-in-2-hours/) blog post by Drew Crawford, [Sovereign](https://github.com/sovereign/sovereign) by Alex Payne, and conversations with <a href="https://twitter.com/shevski" target="_blank">@shevski</a>, <a href="https://github.com/konklone" target="_blank">@konklone</a>, and <a href="https://github.com/gregelin" target="_blank">@GregElin</a>.

Mail-in-a-Box is similar to [iRedMail](http://www.iredmail.org/) and [Modoboa](https://github.com/tonioo/modoboa).


The History
-----------

* In 2007 I wrote a relatively popular Mozilla Thunderbird extension that added client-side SPF and DKIM checks to mail to warn users about possible phishing: [add-on page](https://addons.mozilla.org/en-us/thunderbird/addon/sender-verification-anti-phish/), [source](https://github.com/JoshData/thunderbird-spf).
* In August 2013 I began Mail-in-a-Box by combining my own mail server configuration with the setup in ["NSA-proof your email in 2 hours"](http://sealedabstract.com/code/nsa-proof-your-e-mail-in-2-hours/) and making the setup steps reproducible with bash scripts.
* Mail-in-a-Box was a semifinalist in the 2014 [Knight News Challenge](https://www.newschallenge.org/challenge/2014/submissions/mail-in-a-box), but it was not selected as a winner.
* Mail-in-a-Box hit the front page of Hacker News in [April](https://news.ycombinator.com/item?id=7634514) 2014, [September](https://news.ycombinator.com/item?id=8276171) 2014, [May](https://news.ycombinator.com/item?id=9624267) 2015, and [November](https://news.ycombinator.com/item?id=13050500) 2016.
* FastCompany mentioned Mail-in-a-Box a [roundup of privacy projects](http://www.fastcompany.com/3047645/your-own-private-cloud) on June 26, 2015.
