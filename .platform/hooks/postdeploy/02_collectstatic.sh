#!/bin/bash

touch /var/log/collectstatic.log
chmod 664 /var/log/collectstatic.log
chown webapp:webapp /var/log/collectstatic.log
echo "Collecting static files at $(date)..." | tee -a /var/log/collectstatic.log
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

mkdir -p /var/app/current/staticfiles
chown webapp:webapp /var/app/current/staticfiles

python manage.py collectstatic --noinput --clear --verbosity 2 >> /var/log/collectstatic.log 2>&1

echo "Copying minified Select2 files to non-minified names for dal compatibility..." | tee -a /var/log/collectstatic.log
cp /var/app/current/staticfiles/admin/css/vendor/select2/select2.min.css /var/app/current/staticfiles/admin/css/vendor/select2/select2.css 2>> /var/log/collectstatic.log || echo "WARN: select2.min.css not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/admin/js/vendor/select2/select2.full.min.js /var/app/current/staticfiles/admin/js/vendor/select2/select2.full.js 2>> /var/log/collectstatic.log || echo "WARN: select2.full.min.js not found" >> /var/log/collectstatic.log

echo "Copying DAL minified to non-min for compatibility..." | tee -a /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/select2.min.css /var/app/current/staticfiles/autocomplete_light/select2.css 2>> /var/log/collectstatic.log || echo "WARN: DAL select2.min.css not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/select2.min.js /var/app/current/staticfiles/autocomplete_light/select2.js 2>> /var/log/collectstatic.log || echo "WARN: DAL select2.min.js not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/autocomplete_light.min.js /var/app/current/staticfiles/autocomplete_light/autocomplete_light.js 2>> /var/log/collectstatic.log || echo "WARN: DAL autocomplete_light.min.js not found" >> /var/log/collectstatic.log
cp /var/app/current/staticfiles/autocomplete_light/i18n/en.min.js /var/app/current/staticfiles/autocomplete_light/i18n/en.js 2>> /var/log/collectstatic.log || echo "WARN: DAL i18n/en.min.js not found" >> /var/log/collectstatic.log

echo "Mapping WhiteNoise hashed files for DAL..." | tee -a /var/log/collectstatic.log
for file in select2.css select2.js autocomplete_light.js i18n/en.js; do
    hashed_file=$(find /var/app/current/staticfiles/autocomplete_light/ -name "*${file}*" | grep -E "\.[a-f0-9]+\.${file}$|\.min\.[a-f0-9]+\.${file}$|\.[a-f0-9]+\.${file}\.(gz|br)$|\.min\.[a-f0-9]+\.${file}\.(gz|br)$" | head -n 1)
    if [ -n "$hashed_file" ]; then
        cp -f "$hashed_file" "/var/app/current/staticfiles/autocomplete_light/${file}" 2>> /var/log/collectstatic.log || echo "WARN: Failed to copy $hashed_file to ${file}" >> /var/log/collectstatic.log
        echo "SUCCESS: Mapped $hashed_file to ${file}" | tee -a /var/log/collectstatic.log
    else
        echo "ERROR: No hashed version found for ${file}" | tee -a /var/log/collectstatic.log
    fi
done
# Add for main.js with dir check to avoid find error
if [ -d "/var/app/current/staticfiles/js/" ]; then
    main_hashed=$(find /var/app/current/staticfiles/js/ -name "main.[a-f0-9]*.js*" | head -n 1)
    if [ -n "$main_hashed" ]; then
        cp -f "$main_hashed" "/var/app/current/staticfiles/js/main.js" 2>> /var/log/collectstatic.log || echo "WARN: Failed to copy $main_hashed to main.js" >> /var/log/collectstatic.log
        echo "SUCCESS: Mapped $main_hashed to main.js" | tee -a /var/log/collectstatic.log
    fi
else
    echo "WARN: /var/app/current/staticfiles/js/ dir missing" | tee -a /var/log/collectstatic.log
fi

COLLECT_STATUS=$?
if [ $COLLECT_STATUS -eq 0 ]; then
    echo "SUCCESS: Static files collected at $(date)." | tee -a /var/log/collectstatic.log
    find /var/app/current/staticfiles/autocomplete_light/ -type f >> /var/log/collectstatic.log 2>&1
else
    echo "ERROR: Static file collection failed with status $COLLECT_STATUS at $(date)." | tee -a /var/log/collectstatic.log
    cat /var/log/collectstatic.log
    exit 1
fi
chmod -R 775 /var/log/collectstatic.log /var/app/current/staticfiles
chown -R webapp:webapp /var/log/collectstatic.log /var/app/current/staticfiles