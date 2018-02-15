#!/bin/bash
# Based on entrypoint of https://github.com/atmoz/sftp

# prepare rssh.conf
cat > /etc/rssh.conf << "EOT"
logfacility = LOG_USER

allowrsync
#allowrdist
#allowcvs
allowsftp
allowscp

umask = 022
#chrootpath=/home

EOT

# go through given users
for users in "$@"; do
    # split user
    IFS=':' read -ra data <<< "$users"

    # get user and password
    user="${data[0]}"
    pass="${data[1]}"

    # check if given passwords are encrypted
    if [ "${data[2]}" == "e" ]; then
        # enable encrypted option for chpasswd
        chpasswdOptions="-e"

        # get user id and group id
        uid="${data[3]}"
        gid="${data[4]}"
    else
        uid="${data[2]}"
        gid="${data[3]}"
    fi

    # prepare useradd options
    useraddOptions="--create-home --no-user-group --shell /usr/bin/rssh"

    # add user id if given
    if [ -n "$uid" ]; then
        useraddOptions+=" --non-unique --uid $uid"
    fi

    # add group id if given
    if [ -n "$gid" ]; then
        useraddOptions+=" --gid $gid"

        # add group (suppress warning if group exists)
        groupadd --gid "$gid" "$gid" 2> /dev/null
    fi

    # add user (suppress warning if user exists)
    useradd "$useraddOptions" "$user" 2> /dev/null

    # if no password given create random password
    if [ -z "$pass" ]; then
        pass="$(tr -dc "[:alnum:]" < /dev/urandom | head -c256)"
        chpasswdOptions=""
    fi

    # set password
    chpasswd $chpasswdOptions <<< "$user:$pass"    

    # add rssh entry
    echo "user=$user:011:10011:" >> /etc/rssh.conf

done

# start ssh daemon
exec /usr/sbin/sshd -D -e
