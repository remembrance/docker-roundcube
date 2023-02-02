#!/command/with-contenv bash

# TODO:
# This is not atomic and not clean but "works with some ignorable errors", reasons:
# 1. There is a mix in all .sql files of CREATE TABLE foo and CREATE TABLE IF NOT EXISTS foo, so
# that some init files will always return successfully
# 2. With the behaviour from 1. we cannot really check if we have to update or not
# 3. Without writing PHP we cannot make use of the mysql URI, but this would be crazy too
# 4. Possible solution: Make all steps check for existing tables and atomic executions, produce correct
# error output to user

CONFIG=/var/www/config/config.inc.php

cd /var/www
export PATH=/var/www/bin:$PATH

echo "Linking error log."
ln -snf /dev/stderr /var/www/logs/errors.log

# stupid fix for ROUNDCUBE_ variables not supporting arrays or objects
if [ -n "${RCCONFIG}" ]; then
	echo "=== Using provisioned configuration from environment. ==="
	echo -n "${RCCONFIG}" | base64 -d >"${CONFIG}"
	chmod 600 "${CONFIG}"
else
	cp /var/www/config/config.inc.php.sample "${CONFIG}"
fi

echo "Running MySQL database initializations and migrations."
while IFS=':' read -r package_name dir; do
	echo "Init MySQL schema for plugin ${package_name} and with directory ${dir}."
	if ! initdb.sh --dir="${dir}" --create; then
		echo "Init db for ${package_name} failed, but probably not fatal because db exists."
	else
		echo "Init db for ${package_name} succeeded."
	fi
	echo "Updating MySQL schema for ${package_name} and with directory ${dir}."
	if ! updatedb.sh --package="${package_name}" --dir="${dir}"; then
		echo "Update db for ${package_name} failed, but probably not fatal because db exists."
	else
		echo "Update db for ${package_name} succeeded."
	fi
done <.db_init
