#!/bin/bash

# Create log file if missing
touch /var/log/collectstatic.log
chmod 664 /var/log/collectstatic.log
chown webapp:webapp /var/log/collectstatic.log

echo "Collecting static files at $(date '+%c %Z')..." | tee -a /var/log/collectstatic.log

source "$PYTHONPATH/activate"
cd /var/app/current
export DATABASE_URL=$(/opt/elasticbeanstalk/bin/get-config environment -k DATABASE_URL)
export SECRET_KEY=$(/opt/elasticbeanstalk/bin/get-config environment -k SECRET_KEY)
export DEBUG="False"
export DATABASE_SSL="True"

echo "Waiting for migrations at $(date)..." >> /var/log/collectstatic.log
until python manage.py migrate --check >> /var/log/collectstatic.log 2>&1; do
    echo "Migrations not complete, waiting..." >> /var/log/collectstatic.log
    sleep 2
done

# Delete manifest to prevent hashed substitution in templates
rm -f /var/app/current/staticfiles/staticfiles.json 2>> /var/log/collectstatic.log || echo "WARN: staticfiles.json not found, skipped deletion" >> /var/log/collectstatic.log

# Ensure staticfiles dir exists
mkdir -p /var/app/current/staticfiles
chown webapp:webapp /var/app/current/staticfiles

# Run collectstatic (rely on CompressedStaticFilesStorage for no hashing)
echo "Running python manage.py collectstatic --noinput --clear --verbosity 2..." | tee -a /var/log/collectstatic.log
python manage.py collectstatic --noinput --clear --verbosity 2 >> /var/log/collectstatic.log 2>&1

COLLECT_STATUS=$?
if [ $COLLECT_STATUS -eq 0 ]; then
    echo "SUCCESS: Static files collected at $(date '+%c %Z')." | tee -a /var/log/collectstatic.log
    find /var/app/current/staticfiles/ -type f >> /var/log/collectstatic.log 2>&1
else
    echo "ERROR: Static file collection failed with status $COLLECT_STATUS at $(date '+%c %Z')." | tee -a /var/log/collectstatic.log
    cat /var/log/collectstatic.log
    exit 1
fi

# Set permissions recursively
chmod -R 775 /var/log/collectstatic.log /var/app/current/staticfiles
chown -R webapp:webapp /var/log/collectstatic.log /var/app/current/staticfiles