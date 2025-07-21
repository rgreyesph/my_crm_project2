#!/bin/bash
touch /var/log/collectstatic.log
chmod 664 /var/log/collectstatic.log
chown webapp:webapp /var/log/collectstatic.log
echo "Collecting static files at $(date)..." | tee -a /var/log/collectstatic.log
# source /var/app/venv/*/bin/activate #
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
echo "Running python manage.py collectstatic --noinput --clear --verbosity 2..." | tee -a /var/log/collectstatic.log
python manage.py collectstatic --noinput --clear --verbosity 2 >> /var/log/collectstatic.log 2>&1

COLLECT_STATUS=$?
if [ $COLLECT_STATUS -eq 0 ]; then
  echo "SUCCESS: Static files collected at $(date)." | tee -a /var/log/collectstatic.log
  ls -l /var/app/current/staticfiles/ >> /var/log/collectstatic.log 2>&1
  echo "Static files directory contents:" >> /var/log/collectstatic.log
  find /var/app/current/staticfiles/ -type f >> /var/log/collectstatic.log 2>&1
else
  echo "ERROR: Static file collection failed with status $COLLECT_STATUS at $(date)." | tee -a /var/log/collectstatic.log
  cat /var/log/collectstatic.log
  exit 1
fi
chmod -R 775 /var/log/collectstatic.log /var/app/current/staticfiles
chown -R webapp:webapp /var/log/collectstatic.log /var/app/current/staticfiles