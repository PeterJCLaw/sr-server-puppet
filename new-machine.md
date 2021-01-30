# Setting up a new production host

1. Spin up the VM. It needs to be a supported OS & version; see the
   `Vagrantfile` for the current target.

  **Note**: for TLS configuration to work correctly the hostname of the machine
  must match the public DNS name of the machine. If spinning up a Digtial Ocean
  box, this means the name of the machine you put into DO's UI must be the fully
  qualified name for the machine.

2. Login as root

3. Create a non-root user with `sudo` access:

    ```bash
    useradd --create-home --user-group --groups wheel $USERNAME
    ```

4. Set the password for that account (so it can `sudo`):

    ```bash
    passwd $USERNAME  # and then follow the prompts
    ```

5. Logout and log back in as that user. This is important because our puppet
   configuration removes `ssh` access for the root user.

   **Note**: the remainder of thes instructions require root access, so you
   probably want to `sudo su` at this point.

6. Configure key based SSH access for that user.

7. Repeat for another user, so that more than one person has access to
   administer the machine.

8. Bootstrap puppet:

    ```bash
    dnf install --assumeyes puppet git
    rm -rf /etc/puppet
    git clone --recurse-submodules https://github.com/srobo/server-puppet /etc/puppet
    ```

9. Create the "secrets" for the machine. These are a mixture of "backup" data
   and new private data. If restoring from a backup, this step would be skipped
   and the backup would be dropped in instead. This is placed in `/srv/secrets`,
   which must be readable only by `root`: `mkdir --mode=0700 /srv/secrets`.

   There also exists a dummy version of these "secrets" at
   <https://github.com/srobo/server-dummy-secrets>.

   The files you'll need to create in `/srv/secrets` are:
     - `mysql/phpbb_sr.db` which should be copied from `dummy-secrets` and
         modified as follows:
       - `cookie_domain`, `server_name`: change `sr-vm` for `studentrobotics.org`
       - `ldap_password`: change to the actual LDAP password for the anon user
         (see the following step, related to the production configuration for
         choosing that password)

     - `mcfs/ticket.key`; see <https://github.com/srobo/tickets#ticket-generation>
       for how to generate this. (Note: this _may_ need to be the same file as
       `tickets/ticket.key`, however this is not clear).
     - `tickets/ticket.key`; see <https://github.com/srobo/tickets#ticket-generation>
       for how to generate this.

     - `wifi-keys.yaml`; this should be a YAML file will the TLAs of the
       competing teams as keys and a unique random password as the value of
       each. This can be done by pasting a newline separated list of TLAs into:

       ```bash
       /etc/puppet/scripts/generate-wifi-keys.py > /srv/secrets/wifi-keys.yaml
       ```
     - `code-submitter-credentials.yaml`; this should be a YAML file in the same format
       as `wifi-keys.yaml` (and thus generated using the same script). In addition to
       competing teams, the TLA "SRX" should be provided for volunteer login.

     - `ide/notifications`, `ide/repos` and `ide/settings`; these should be
       non-empty directories:

       ```bash
       cd /srv/secrets
       mkdir --parents --mode=700 ide/notifications ide/repos ide/settings
       touch ide/notifications/sr ide/repos/sr ide/settings/sr
       ```

     - `ldap/ldap_backup`; this should be an empty file on a new machine.

       ```bash
       mkdir --mode=700 /srv/secrets/ldap
       touch /srv/secrets/ldap/ldap_backup
       ```

     - various `login/ssh_host*` files. Copy these from `/etc/ssh/ssh_host*`.
       Yes this shouldn't be needed; it's an artefact of this puppet config
       being more about to restoring from backup than new machine setup.

       ```bash
       mkdir --mode=700 /srv/secrets/login
       cp /etc/ssh/ssh_host* /srv/secrets/login
       ```

     - `login/backups_ssh_keys`; this can be an empty file as a first pass.
     - `login/monitoring_ssh_keys`; this can be an empty file as a first pass.

10. Create the production configuration for the new machine. This is a manual
    process of generating random secrets for the machine and building them into a
    hiera config at `/srv/secrets/$(hostname).yaml`.

    That file should then be symlinked into puppet's `hieradata` directory:

     ```bash
     mkdir --mode=0700 /etc/puppet/hieradata/secrets
     ln -s /srv/secrets/$(hostname).yaml /etc/puppet/hieradata/secrets/
     ```

    See `hieradata/common.yaml` for the settings to override and how to generate
    them. Note that that file contains all the base settings yet the secret
    machine config should contain only the keys which are actually secret.
    Configuration which is not secret should be in
    `hieradata/nodes/$(hostname).yaml`, committed to this repo.

    **Warning**: if you fail to create this file puppet will still apply, however
    you will have provisioned a server with insecure details.

11. Run puppet:

    ```bash
    /etc/puppet/scripts/apply
    ```

    If you get the following firewall error the first time you run this, that's
    unfortunately normal (though undesirable) -- just run puppet again.

    ```
    Error: /Stage[main]/Sr_site::Firewall/Resources[firewall]: Failed to generate additional resources using 'generate': Command iptables_save is missing
    ```

12. Configure the forums' Slack integration. This is manual as it involves
    getting a secret from Slack and inputting it into the forums configuration
    pages.

    1. Login to the forums as the `anon` user (which is configured as the forms
       Admin) and go to the Admin Control Panel then to the Customise tab.
    2. Disable and then re-enable the "Entropy" extension (this forces it to
       re-register with PHPBB and thus add itself to the Admin Control Panel UI)
    3. Sign in to the SR slack and then visit https://api.slack.com/apps
    4. Create an app to use (or click through to an existing one) and then to
       "Add features and functionality" and then "Incoming Webhooks".
    5. Copy the Webhook URL for the app.
    6. Go to the Extension page in the Admin Control Panel of the forums
    7. Paste the Webhook URL into the "Incoming webhook url" field & Submit
