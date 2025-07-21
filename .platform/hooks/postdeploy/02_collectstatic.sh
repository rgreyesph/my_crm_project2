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

echo "Copying minified Select2 files to non-minified names for dal compatibility..." | tee -a /var/log/collectstatic.log
cp /var/app/current/staticfiles/admin/css/vendor/select2/select2.min.css /var/app/current/staticfiles/admin/css/vendor/select2/select2.css 2>> /var/log/collectstatic.log
cp /var/app/current/staticfiles/admin/js/vendor/select2/select2.full.min.js /var/app/current/staticfiles/admin/js/vendor/select2/select2.full.js 2>> /var/log/collectstatic.log

# --- IN .platform/hooks/postdeploy/02_collectstatic.sh: AFTER existing cp ---
# (Existing cp for admin/select2...)
echo "Copying DAL minified to non-min for compatibility..." | tee -a /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/select2.min.css /var/app/current/staticfiles/autocomplete_light/select2.css 2>> /var/log/collectstatic.log || echo "WARN: DAL select2.min.css not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/select2.min.js /var/app/current/staticfiles/autocomplete_light/select2.js 2>> /var/log/collectstatic.log || echo "WARN: DAL select2.min.js not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/autocomplete_light.min.js /var/app/current/staticfiles/autocomplete_light/autocomplete_light.js 2>> /var/log/collectstatic.log || echo "WARN: DAL autocomplete_light.min.js not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/i18n/en.min.js /var/app/current/staticfiles/autocomplete_light/i18n/en.js 2>> /var/log/collectstatic.log || echo "WARN: DAL i18n/en.min.js not found" >> /var/log/collectstatic.log
if [ $? -eq 0 ]; then echo "SUCCESS: DAL files copied." | tee -a /var/log/collectstatic.log; fi


echo "Ensuring DAL legacy static files..." | tee -a /var/log/collectstatic.log
if [ ! -f /var/app/current/staticfiles/autocomplete_light/i18n/en.js ]; then
    cp /var/app/current/staticfiles/autocomplete_light/i18n/en.min.js /var/app/current/staticfiles/autocomplete_light/i18n/en.js 2>> /var/log/collectstatic.log || echo "WARN: en.min.js not found" >> /var/log/collectstatic.log
fi
if [ ! -f /var/app/current/staticfiles/autocomplete_light/select2.js ]; then
    cp /var/app/current/staticfiles/autocomplete_light/select2.min.js /var/app/current/staticfiles/autocomplete_light/select2.js 2>> /var/log/collectstatic.log || echo "WARN: select2.min.js not found" >> /var/log/collectstatic.log
fi
if [ ! -f /var/app/current/staticfiles/autocomplete_light/autocomplete_light.js ]; then
    cp /var/app/current/staticfiles/autocomplete_light/autocomplete_light.min.js /var/app/current/staticfiles/autocomplete_light/autocomplete_light.js 2>> /var/log/collectstatic.log || echo "WARN: autocomplete_light.min.js not found" >> /var/log/collectstatic.log
fi

if [ $? -eq 0 ]; then
  echo "SUCCESS: Minified files copied." | tee -a /var/log/collectstatic.log
else
  echo "WARNING: Failed to copy minified files." | tee -a /var/log/collectstatic.log
fi
# For autocomplete_light i18n/en.js if missing (assuming it's collected but lang-specific):
if [ ! -f /var/app/current/staticfiles/autocomplete_light/i18n/en.js ]; then
  echo "Creating placeholder for i18n/en.js if needed..." | tee -a /var/log/collectstatic.log
  mkdir -p /var/app/current/staticfiles/autocomplete_light/i18n/
  touch /var/app/current/staticfiles/autocomplete_light/i18n/en.js
  chown webapp:webapp /var/app/current/staticfiles/autocomplete_light/i18n/en.js
fi


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