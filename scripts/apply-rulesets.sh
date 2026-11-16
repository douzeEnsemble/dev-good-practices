#!/bin/sh
# Applique .github/rulesets/main.json de chaque dépôt au ruleset « main » de GitHub.
# Usage : ./apply-rulesets.sh propriétaire/dépôt [propriétaire/dépôt ...]
# Prérequis : gh authentifié (droits d'administration) ; chaque dépôt cloné
# dans le dossier courant sous son nom (dépôt/.github/rulesets/main.json).
set -eu
for slug in "$@"; do
  repo=${slug#*/}
  file="$repo/.github/rulesets/main.json"
  [ -f "$file" ] || { echo "$slug : $file introuvable, ignoré"; continue; }
  id=$(gh api "repos/$slug/rulesets" -q '.[] | select(.name=="main") | .id')
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$slug/rulesets/$id" --input "$file" >/dev/null
    echo "$slug : ruleset $id mis à jour"
  else
    gh api -X POST "repos/$slug/rulesets" --input "$file" >/dev/null
    echo "$slug : ruleset créé"
  fi
done
