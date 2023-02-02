FROM gutmensch/php74:1.0.0 AS builder

LABEL maintainer="Robert Schumann <rs@n-os.org>"

ARG ROUNDCUBE_VERSION=1.6.1
ARG DEBUG
ARG COMMIT

WORKDIR /var/www

USER root

# build dependencies
RUN apk add -U unzip file npm patch git \
  && npm install -g less uglify-js less-plugin-clean-css csso-cli

COPY --from=composer/composer:latest-bin /composer /usr/bin/composer
COPY patches /var/tmp

USER phpapp

# checkout roundcube source
RUN bash -c "export VERSION=release-${ROUNDCUBE_VERSION%.*} \
  && echo Checking out \$VERSION \
  && rm -rf * \
  && git clone --branch \${VERSION} $(test -z \"${COMMIT}\" && echo -n \"--depth 1\") https://github.com/roundcube/roundcubemail.git . \
  && ( test -n \"${COMMIT}\" && git reset --hard ${COMMIT} || true ) \
  && rm -rf .git installer skins/{classic,larry}"

ENV PATH=/usr/local/bin:/bin:/usr/bin:/var/www/bin \
  STYLES=skins/elastic/styles \
  SKIP_DB_INIT=1

# install dependencies via composer
RUN mv composer.json-dist composer.json \
  && composer config secure-http false \
  # skip db initialization in plugin installer but create log for container start \
  # as done in patch for plugin-installer \
  # start with package roundcube to initialize this too \
  && echo "roundcube:/var/www/SQL" > .db_init \
  && composer require --working-dir=/var/www --update-no-dev roundcube/plugin-installer:* \
  && patch -p1 < /var/tmp/rc_plugin_installer_skip_db_init.patch \
  \
  # install plugins \
  && composer require --working-dir=/var/www --update-no-dev \
  roundcube/carddav:* \
  johndoh/contextmenu \
  johndoh/sauserprefs \
  dondominio/ddnotes \
  johndoh/swipe \
  kolab/calendar \
  && find . -type d -name vendor \
  && ln -svf ../../vendor plugins/carddav/vendor \
  && composer clear-cache \
  \
  # fix buggy mysql init command for calendar plugin - table not quoted and package name wrong \
  && patch -p1 < /var/tmp/kolab_calendar_plugin_db.patch \
  \
  # fix swipe plugin issue raised with rc changes \
  # https://github.com/roundcube/roundcubemail/issues/8433 \
  # https://github.com/johndoh/roundcube-swipe/issues/21 \
  # && patch -p1 < /var/tmp/rc_1_5_swipe_plugin_fix.patch \
  \
  # shrink static assets if no debug image \
  && if [ -z "${DEBUG}" ]; then \
  jsshrink.sh \
  && updatecss.sh \
  && cssshrink.sh \
  && lessc --clean-css="--s1 --advanced" $STYLES/styles.less > $STYLES/styles.min.css \
  && lessc --clean-css="--s1 --advanced" $STYLES/print.less > $STYLES/print.min.css \
  && lessc --clean-css="--s1 --advanced" $STYLES/embed.less > $STYLES/embed.min.css \
  && install-jsdeps.sh \
  && jsshrink.sh program/js/publickey.js \
  && jsshrink.sh plugins/managesieve/codemirror/lib/codemirror.js; else \
  \
  # do not shrink otherwise \
  updatecss.sh \
  && lessc $STYLES/styles.less > $STYLES/styles.min.css \
  && lessc $STYLES/print.less > $STYLES/print.min.css \
  && lessc $STYLES/embed.less > $STYLES/embed.min.css \
  && install-jsdeps.sh ; fi \
  \
  # configure default plugins \
  && echo "\$config['plugins'] = ['carddav','managesieve','contextmenu','sauserprefs','enigma','ddnotes', 'calendar', 'swipe'];" >> config/defaults.inc.php \
  && echo "\$config['swipe_actions'] = array( \
  'messagelist' => array('left' => 'delete', 'right' => 'reply', 'down' => 'checkmail'), \
  'contactlist' => array('left' => 'delete', 'right' => 'compose', 'down' => 'none'));" >> config/defaults.inc.php \
  && echo "\$config['enigma_pgp_homedir'] = '/var/gpg';" >> config/defaults.inc.php \
  && echo "\$config['managesieve_conn_options'] = [ 'ssl' => [ \
  'verify_peer' => false, 'verify_peer_name' => false, 'allow_self_signed' => true ]];" >> config/defaults.inc.php \
  && echo "\$config['imap_conn_options'] = [ 'ssl' => [ \
  'verify_peer' => false, 'verify_peer_name' => false, 'allow_self_signed' => true ]];" >> config/defaults.inc.php \
  && echo "\$config['smtp_conn_options'] = [ 'ssl' => [ \
  'verify_peer' => false, 'verify_peer_name' => false, 'allow_self_signed' => true ]];" >> config/defaults.inc.php \
  \
  # cleanup \
  && rm -rvf jsdeps.json bin/install-jsdeps.sh *.orig vendor/masterminds/html5/test vendor/pear/*/tests \
  vendor/*/*/.git* vendor/pear/crypt_gpg/tools vendor/pear/console_commandline/docs \
  vendor/pear/mail_mime/scripts vendor/pear/net_ldap2/doc vendor/pear/net_smtp/docs \
  vendor/pear/net_smtp/examples vendor/pear/net_smtp/README.rst vendor/bacon/bacon-qr-code/test temp/js_cache \
  tests plugins/*/tests .git* .tx* .ci* .editorconfig* index-test.php Dockerfile Makefile

# branding
COPY berlin_logo.svg skins/elastic/images/logo.svg

#
# ===== RUN STAGE =====
#

FROM gutmensch/php74:1.0.0

ENV DOCUMENT_ROOT=/var/www/public_html TZ="Europe/Berlin" ROUNDCUBE_LOG_DRIVER="stdout" ROUNDCUBE_LOG_LOGINS="true" ROUNDCUBE_SMTP_LOG="true"

WORKDIR ${DOCUMENT_ROOT}/..

USER root

COPY --from=builder /var/www /var/www

# for enigma support
RUN apk -U add gnupg

# Init scripts (volume preparation)
COPY manifest /

# change phpapp user id to wanted one and adjust ownership
RUN mkdir /var/gpg \
  && chown -R phpapp: /etc/s6-overlay /var/gpg /var/www

# run unprivileged
USER phpapp

# set cookie respone from roundcube expected
HEALTHCHECK --interval=30s --timeout=5s --retries=3  CMD sh /usr/local/bin/probe.sh

# Keep the db in a volume for persistence
VOLUME /var/gpg
