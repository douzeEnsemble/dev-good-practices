#!/bin/sh
set -e

# /app/public est un volume nommé partagé en lecture seule avec nginx. Docker ne le remplit
# depuis l'image qu'à sa création : aux déploiements suivants, il garderait un contenu périmé.
# On le resynchronise donc depuis la copie de l'image à chaque démarrage.
rsync -a --delete /app/public-src/ /app/public/

# RUN_MIGRATIONS=true sur le seul service `php` (pas sur les workers) : les migrations
# Doctrine tournent une seule fois par déploiement, sans verrou entre services.
if [ "${RUN_MIGRATIONS:-}" = "true" ]; then
	php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
fi

exec docker-php-entrypoint "$@"
