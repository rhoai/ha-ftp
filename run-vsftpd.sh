#!/bin/bash

# Custom die function
#
die() { echo >&2 -e "\nRUN ERROR $@\n"; usage; exit 1; }

# If no env var for FTP_USER has been specified, use 'admin':
if [ "$FTP_USER" = "**String**" ]; then
    export FTP_USER='admin'
fi

# If no env var has been specified, generate a random password for FTP_USER:
if [ "$FTP_PASS" = "**Random**" ]; then
    export FTP_PASS=`cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c${1:-16}`
fi

# Do not log to STDOUT by default:
if [ "$LOG_STDOUT" = "**Boolean**" ]; then
        export LOG_STDOUT=''
else
        export LOG_STDOUT='Yes.'
fi

# Create home dir and update vsftpd user db:
echo -e "${FTP_USER}\n${FTP_PASS}" > /etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db

export ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo $ZONE
if [ "$ZONE" = ${NLB_AZ_1} ]; then
    export PASV_ADDRESS=${NLB_AZ_1_PASV_ADDRESS}
elif [ "$ZONE" = ${NLB_AZ_2} ]; then
    export PASV_ADDRESS=${NLB_AZ_2_PASV_ADDRESS}
else
    die "Cannot determine ip address"
fi

echo "pasv_address=${PASV_ADDRESS}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_max_port=${PASV_MAX_PORT}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_min_port=${PASV_MIN_PORT}" >> /etc/vsftpd/vsftpd.conf
# Get log file path
export LOG_FILE=`grep vsftpd_log_file /etc/vsftpd/vsftpd.conf|cut -d= -f2`

# stdout server info:
if [ ! $LOG_STDOUT ]; then
cat << EOB
    *************************************************
    *                                               *
    *    Docker image: fauria/vsftd                 *
    *    https://github.com/fauria/docker-vsftpd    *
    *                                               *
    *************************************************
    SERVER SETTINGS
    ---------------
    · FTP User: $FTP_USER
    · FTP Password: $FTP_PASS
    · Log file: $LOG_FILE
    · Redirect vsftpd log to STDOUT: No.
EOB
else
    /usr/bin/ln -sf /proc/$$/fd/1 $LOG_FILE
fi

# ssl conf
echo "rsa_private_key_file=${SSL_KEY_FILE}" >> /etc/vsftpd/vsftpd.conf
echo "rsa_cert_file=${SSL_CERT_FILE}" >> /etc/vsftpd/vsftpd.conf

# s3 ftp backend
echo ${S3_USER}:${S3_CREDENTIAL} > /s3fs/cred/credential
chmod 600 /s3fs/cred/credential

echo "starting s3fs"

s3fs ${S3_BUCKET} /s3fs/vsftpd -o passwd_file=/s3fs/cred/credential -o url=https://s3.amazonaws.com -o allow_other -d -d -f -o f2 &

echo "started s3fs"

# Run vsftpd:
&>/dev/null /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
