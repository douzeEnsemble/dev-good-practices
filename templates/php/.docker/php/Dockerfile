# Image PHP en trois cibles : php_base (commun), php_dev (xdebug, utilisateur du poste),
# php_prod (dépendances sans dev, cache compilé). Versions épinglées au patch : le workflow
# de montée de PHP (UPD-01) les met à jour partout. Lint : hadolint (CI « Linter Dockerfile »).
FROM php:8.5.12-fpm-alpine3.24 AS php_base

WORKDIR /app

EXPOSE 9000

ENV XDEBUG_MODE=off

## < Extensions PHP : adapter à composer.json (ext-*) et à la base choisie
# hadolint ignore=DL3018,SC2086
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
	&& pecl install apcu \
	&& docker-php-ext-enable apcu \
	&& apk del .build-deps

# PostgreSQL. Pour MySQL/MariaDB : docker-php-ext-install pdo_mysql
# hadolint ignore=DL3018
RUN apk add --no-cache libpq-dev \
	&& docker-php-ext-install pdo_pgsql pgsql

# hadolint ignore=DL3018
RUN apk add --no-cache libzip-dev zlib-dev \
	&& docker-php-ext-install zip

# hadolint ignore=DL3018
RUN apk add --no-cache icu-dev \
	&& docker-php-ext-install intl

# hadolint ignore=DL3018,DL4006,SC2015
RUN php -m | grep -qi iconv \
	&& docker-php-ext-install ctype \
	|| (apk add --no-cache libiconv-dev \
	&& docker-php-ext-configure iconv --with-iconv=/usr/local \
	&& docker-php-ext-install ctype iconv)
## > Extensions PHP

## < Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
	php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
	php -r "unlink('composer-setup.php');"

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
## > Composer

COPY --link .docker/php/conf.d/app.ini $PHP_INI_DIR/conf.d/10-app.ini

FROM php_base AS php_dev

ENV APP_ENV=dev

COPY --link .docker/php/conf.d/app.dev.ini $PHP_INI_DIR/conf.d/20-app.dev.ini

# Xdebug : couverture (XDEBUG_MODE=coverage) et débogage
# hadolint ignore=DL3018,SC2086
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS linux-headers \
	&& pecl install xdebug \
	&& docker-php-ext-enable xdebug \
	&& apk del .build-deps

# Utilisateur du poste (UID/GID passés par make et la CI) : les fichiers créés dans le
# conteneur restent à vous sur l'hôte.
ARG UID=1000
ARG GID=1000

RUN addgroup -g ${GID} app && adduser -u ${UID} -G app -s /bin/sh -D app

USER ${UID}:${GID}

FROM php_base AS php_prod

ENV APP_ENV=prod

COPY --link .docker/php/conf.d/app.prod.ini $PHP_INI_DIR/conf.d/20-app.prod.ini

## < Composer
COPY composer.* symfony.* ./

RUN set -eux; \
	composer install --no-cache --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress

COPY . ./

# Le cache prod est compilé au build avec .env.dev : il doit contenir toute clé référencée par
# %env(...)% dans config/, sinon cache:clear échoue. Aucun secret : les vraies valeurs sont
# injectées à l'exécution.
RUN mv .env.dev .env && chown www-data:www-data .env

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer run-script --no-dev post-install-cmd; \
	sync;

RUN rm .env \
	&& touch .env
## > Composer

RUN chown -R www-data:www-data var/

## < public/ partagé avec nginx
# /app/public est un volume nommé partagé avec nginx : Docker ne le remplit qu'à sa création.
# L'entrypoint le resynchronise à chaque démarrage depuis la copie figée dans l'image.
# hadolint ignore=DL3018
RUN apk add --no-cache rsync \
	&& mv public public-src
COPY --link .docker/php/docker-entrypoint-prod.sh /usr/local/bin/docker-entrypoint-prod.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-prod.sh

ENTRYPOINT ["docker-entrypoint-prod.sh"]
# ENTRYPOINT réinitialise le CMD hérité : le redéclarer pour démarrer php-fpm.
CMD ["php-fpm"]
## > public/ partagé avec nginx
