#!/bin/sh
# Vérifie quelques règles du guide sur un ou plusieurs dépôts clonés.
# Usage : ./check-conformity.sh chemin/dépôt [chemin/dépôt ...]
# Sortie : une ligne par vérification, « ok » ou « KO », code de sortie 1 si un KO.
set -u
here=$(cd "$(dirname "$0")" && pwd)
ref=$(md5sum "$here/../templates/.github/scripts/mutation-matrix.mjs" | cut -d' ' -f1)
fail=0
check() { # dépôt règle condition(0=ok) détail
  if [ "$3" -eq 0 ]; then echo "ok  $1 $2"; else echo "KO  $1 $2 $4"; fail=1; fi
}
# Une action externe est conforme si sa référence est un SHA de 40 caractères (SEC-01)
unpinned() { grep -rhE '^[[:space:]]*-?[[:space:]]*uses: *[^./ ][^ ]*@' "$1" 2>/dev/null | grep -vE '@[0-9a-f]{40}( |$)' | wc -l; }
# Écart déclaré dans CLAUDE.md, section « Écarts au guide », qui cite la règle
declared() { sed -n '/^## Écarts au guide/,/^## [^É]/p' "$d/CLAUDE.md" 2>/dev/null | grep -q "$1"; }
# Au moins un des fichiers donnés existe
exists_any() { for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }
# Empreinte d'un fichier, après retrait éventuel de « --prerelease » (variante PHP, VER-03)
sum_of() { sed 's/ --prerelease//' "$1" | md5sum | cut -d' ' -f1; }
same_as() { [ -f "$1" ] && [ "$(sum_of "$1")" = "$(sum_of "$2")" ]; }
tpl="$here/../templates"

for d in "$@"; do
  n=$(basename "$d")
  [ -d "$d/.github/workflows" ] || { echo "KO  $n dossier .github/workflows absent"; fail=1; continue; }
  # Famille : PHP si composer.json sans package.json, sinon npm
  php=0; [ -f "$d/composer.json" ] && [ ! -f "$d/package.json" ] && php=1

  # --- Commun aux deux familles
  [ -f "$d/.github/dependabot.yml" ]; check "$n" "SEC-02 dependabot.yml" $? ""
  [ -f "$d/.github/rulesets/main.json" ]; check "$n" "GIT-01 ruleset versionné" $? ""
  bad=$(unpinned "$d/.github")
  [ "$bad" -eq 0 ]; check "$n" "SEC-01 actions épinglées par SHA" $? "($bad ligne(s))"
  { [ -d "$d/doc" ] && grep -q 'doc/' "$d/CLAUDE.md" 2>/dev/null; }; check "$n" "DOC-04 doc/ présent et cité dans CLAUDE.md" $? ""
  # --- Versionnement (VER-02…06)
  same_as "$d/.releaserc.json" "$tpl/.releaserc.json"; check "$n" "VER-02 .releaserc.json identique au modèle" $? ""
  [ -f "$d/.github/workflows/release.yml" ]; check "$n" "VER-03 release.yml présent" $? ""
  same_as "$d/.github/workflows/conventional_commits.yml" "$tpl/.github/workflows/conventional_commits.yml"; check "$n" "VER-04 conventional_commits.yml identique au modèle" $? ""
  same_as "$d/.commitlintrc.json" "$tpl/.commitlintrc.json"; check "$n" "VER-04 .commitlintrc.json identique au modèle" $? ""
  ! grep -rqE '@semantic-release/(git|changelog)' "$d/.releaserc.json" "$d/.github/workflows/release.yml" 2>/dev/null; check "$n" "VER-05 aucun commit de release sur main" $? ""
  [ "$(grep -c 'package-ecosystem' "$d/.github/dependabot.yml" 2>/dev/null)" -eq "$(grep -c 'commit-message' "$d/.github/dependabot.yml" 2>/dev/null)" ] && grep -q 'commit-message' "$d/.github/dependabot.yml" 2>/dev/null; check "$n" "VER-06 dependabot : commit-message sur chaque entrée" $? "(une entrée package-ecosystem sans commit-message)"
  tot=$(git -C "$d" log -100 --pretty=%s 2>/dev/null | wc -l)
  conv=$(git -C "$d" log -100 --pretty=%s 2>/dev/null | grep -Ec '^[a-z]+(\([^)]+\))?!?: ')
  echo "--  $n GIT-07 $conv/$tot commits conventionnels (information)"

  if [ "$php" -eq 1 ]; then
    # --- Famille PHP
    for f in ci_codequality.yml ci_tests.yml security.yml; do
      [ -f "$d/.github/workflows/$f" ]; check "$n" "PHP workflow $f présent" $? ""
    done
    make -C "$d" -s help >/dev/null 2>&1; check "$n" "PHP-01 make help" $? ""
    [ -d "$d/tools" ]; check "$n" "PHP-02 tools/ isolés" $? ""
    exists_any "$d"/phpstan.neon* && grep -Eqh 'level: *(9|max)' "$d"/phpstan.neon*; check "$n" "PHP-04 PHPStan niveau max" $? ""
    exists_any "$d"/deptrac.y*ml; check "$n" "PHP-05 Deptrac configuré" $? ""
    grep -Eq 'min-msi=100.*min-covered-msi=100|min-covered-msi=100.*min-msi=100' "$d/Makefile" "$d"/.github/workflows/*.yml 2>/dev/null; check "$n" "PHP-08 Infection MSI 100 (Makefile ou CI)" $? ""
    if [ -d "$d/tests/src/Browser" ]; then
      grep -rqi 'firefox' "$d"/.github/workflows/*.yml && grep -rqi 'chrome' "$d"/.github/workflows/*.yml; check "$n" "PHP-14 tests navigateur Chrome + Firefox" $? ""
      [ -f "$d/tools/w3c-validate/w3c_validate.sh" ]; check "$n" "PHP-15 validation W3C" $? ""
    fi
    { [ -f "$d/.commitlintrc.json" ] && [ -f "$d/.github/workflows/conventional_commits.yml" ]; }; check "$n" "GIT-07 commitlint + workflow" $? ""
    { [ -f "$d/.github/workflows/infra_updates.yml" ] || [ -f "$d/.github/workflows/infra-updates.yml" ]; }; check "$n" "UPD-01 workflow de montée de PHP" $? ""
    continue
  fi

  # --- Famille npm
  for f in ci.yml codeql.yml audit.yml; do
    [ -f "$d/.github/workflows/$f" ]; check "$n" "GIT/SEC $f présent" $? ""
  done
  if [ -f "$d/.github/scripts/mutation-matrix.mjs" ]; then
    [ "$(md5sum "$d/.github/scripts/mutation-matrix.mjs" | cut -d' ' -f1)" = "$ref" ]
    check "$n" "MUT-08 mutation-matrix.mjs identique au modèle" $? ""
  else
    echo "--  $n MUT-08 pas de matrice (un seul job ?)"
  fi
  s=$(ls "$d"/stryker.config.* 2>/dev/null | head -1)
  if [ -n "$s" ]; then grep -Eq '"?break"?: *100' "$s"; check "$n" "MUT-02 seuil break 100" $? ""
  else echo "KO  $n stryker.config absent"; fail=1; fi
  v=$(ls "$d"/vitest.config.* 2>/dev/null | head -1)
  if [ -n "$v" ]; then { [ "$(grep -Ec '(lines|branches|functions|statements): *100' "$v")" -ge 4 ] || grep -Eq 'thresholds: *\{ *100: *true' "$v"; }; check "$n" "COV-01 seuils 100" $? ""; fi
  if declared 'ARCH-01'; then echo "--  $n ARCH-01/02 écart déclaré (scripts classiques, ARCH-04)"
  else
    exists_any "$d"/.dependency-cruiser.*; check "$n" "ARCH-01 .dependency-cruiser présent" $? ""
    grep -q 'depcruise' "$d/package.json" 2>/dev/null; check "$n" "ARCH-02 depcruise dans package.json (lint)" $? ""
  fi
  if grep -q 'vite-plugin-pwa' "$d/package.json" 2>/dev/null; then
    grep -q '"vite-plugin-pwa"' <(sed -n '/"devDependencies"/,/}/p' "$d/package.json"); check "$n" "PWA-07 vite-plugin-pwa en devDependencies" $? ""
    grep -rqE "registerType: *['\"]prompt['\"]" "$d"/vite.config.* 2>/dev/null; check "$n" "PWA-04 registerType prompt" $? ""
    grep -rq 'navigateFallbackDenylist' "$d"/vite.config.* 2>/dev/null && echo "ok  $n PWA-03 navigateFallbackDenylist" || echo "--  $n PWA-03 pas de denylist (API sur une autre origine ?)"
    grep -rlq 'context\.setOffline' "$d/e2e" "$d/tests" 2>/dev/null; check "$n" "PWA-05 test e2e hors ligne" $? ""
  fi
  [ -f "$d/.github/workflows/node-updates.yml" ]; check "$n" "UPD-01 node-updates.yml" $? ""
  [ -f "$d/.github/workflows/major-updates.yml" ]; check "$n" "UPD-04 major-updates.yml" $? ""
  c=$(grep -rn "Stryker disable" "$d" --include='*.ts' --include='*.tsx' --include='*.js' --include='*.mjs' --exclude-dir=node_modules --exclude-dir=.stryker-tmp --exclude-dir=coverage 2>/dev/null | wc -l)
  echo "--  $n MUT-06 $c « Stryker disable » (information)"
done
exit $fail
