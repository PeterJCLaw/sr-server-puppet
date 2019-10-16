# Setting up a new production host

1. Spin up the VM. It needs to be a supported OS & version; see the
   `Vagrantfile` for the current target.

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

6. Configure key based SSH access for that user.

7. Bootstrap puppet:

    ```bash
    dnf install --assumeyes puppet git
    rm -rf /etc/puppet
    git clone --recurse-submodules https://github.com/srobo/server-puppet /etc/puppet
    ```

8. Create the "secrets" for the machine. These are a mixture of "backup" data
   and new private data. If restoring from a backup, this step would be skipped
   and the backup would be dropped in instead. This is placed in `/srv/secrets`,
   which must be readable only by `root`: `mkdir --mode=0700 /srv/secrets`.

   There also exists a dummy version of these "secrets" at
   <https://github.com/srobo/server-dummy-secrets>.

   The files you'll need to create in `/srv/secrets` are:
     - `mysql/phpbb_sr$YYYY.db`, with `$YYYY` so that the file name matches
       `$forum_db_name` in `modules/www/manifests/phpbb.pp`. This should be
       copied from `dummy-secrets`.

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

     - `ide/notifications`, `ide/repos` and `ide/settings`; these should be
       non-empty directories:

       ```bash
       cd /srv/secrets
       mkdir --parents --mode=700 ide/notifications ide/repos ide/settings
       touch ide/notifications/sr ide/repos/sr ide/settings/sr
       ```

     - various `login/ssh_host*` files. Copy these from `/etc/ssh/ssh_host*`.
       Yes this shouldn't be needed; it's an artefact of this puppet config
       being more about to restoring from backup than new machine setup.

       ```bash
       mkdir --mode=700 /srv/secrets/login
       cp /etc/ssh/ssh_host* /srv/secrets/login
       ```

     - `login/backups_ssh_keys`; this can be empty as a first pass.
     - `login/monitoring_ssh_keys`; this can be empty as a first pass.

9. Create the production configuration for the new machine. This is a manual
   process of generating random secrets for the machine and building them into a
   hiera config at `/srv/secrets/$(hostname).yaml`.

   That file should then be symlinked into puppet's `hieradata` directory:

    ```bash
    mkdir --mode=0700 /etc/puppet/hieradata/secrets
    ln -s /srv/secrets/$(hostname).yaml /etc/puppet/hieradata/secrets/
    ```

   See `hieradata/common.yaml` for the settings to override and how to generate
   them.

   **Warning**: if you fail to create this file puppet will still apply, however
   you will have provisioned a server with insecure details.

10. Run puppet:

    ```bash
    /etc/puppet/scripts/apply
    ```

    If you get the following firewall error the first time you run this, that's
    unfortunately normal (though undesirable) -- just run puppet again.

    ```
    Error: /Stage[main]/Sr_site::Firewall/Resources[firewall]: Failed to generate additional resources using 'generate': Command iptables_save is missing
    ```
