#!/usr/bin/env bash
# Valide le HTML des pages listées dans URLS avec le validateur W3C (vnu) — PHP-15.
# Les pages sont récupérées par le conteneur php (curl) sur le vhost de test du conteneur web,
# écrites dans var/html, puis validées. Deux URLs distinctes qui donnent le même contenu sont une
# erreur (session perdue, page d'erreur ou page de connexion servie à la place de la vraie page).
set -euo pipefail

BASE_URI="${BASE_URI:-http://web:8081/}"
OUT_DIR="var/html"
VNU_CMD="docker run --rm -v $(pwd):/app ghcr.io/validator/validator:latest vnu --format text"
CURL_CMD="docker compose exec -T php curl"

# Pages à valider, au format "rôle|chemin[|code HTTP attendu]" :
#   - rôle : anon (page publique). Pour d'autres rôles, renseigner LOGIN_PATHS et PROBE_URLS ci-dessous.
#   - code attendu : 200 par défaut. Une page avec un autre code attendu est vérifiée mais PAS validée
#     par vnu (redirection, page d'erreur…) : elle ne doit jamais être validée à la place d'une vraie page.
URLS=(
	"anon|"
	# "anon|politique"
	# "anon|ancienne-page|301"
)

# Rôles authentifiés : chemin de connexion (une requête GET qui pose le cookie de session) et page
# réservée au rôle, qui doit répondre 200 pour prouver que la session est reconnue.
declare -A LOGIN_PATHS=()   # ex. ([membre]="connexion/test?role=membre")
declare -A PROBE_URLS=()    # ex. ([membre]="mon-compte")

# Pages dont le contenu identique est explicitement attendu (chemins de fichiers séparés par un espace).
ALLOWED_DUPLICATES=""

JAR_DIR="/tmp/w3c-cookies-$$"
declare -A ROLE_COOKIES=()
FAILURES=0

fail() {
	echo "❌ $*" >&2
	FAILURES=$((FAILURES + 1))
}

cleanup() {
	docker compose exec -T php rm -rf "$JAR_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

authenticate() {
	$CURL_CMD --version >/dev/null # échoue tôt si le conteneur php est injoignable
	[ "${#LOGIN_PATHS[@]}" -gt 0 ] || return 0
	docker compose exec -T php mkdir -p "$JAR_DIR"

	local role
	for role in "${!LOGIN_PATHS[@]}"; do
		local jar="${JAR_DIR}/${role}.txt"
		echo "🔐 Connexion en tant que ${role} ..."
		if ! $CURL_CMD -fsSL -c "$jar" -o /dev/null "${BASE_URI}${LOGIN_PATHS[$role]}"; then
			echo "❌ Connexion impossible pour le rôle ${role}" >&2
			exit 1
		fi
		local cookie
		cookie="$(docker compose exec -T php sh -c "grep -E '^(#HttpOnly_)?[^#[:space:]]' '$jar' | awk '{ printf \"%s%s=%s\", sep, \$6, \$7; sep=\"; \" }'" | tr -d '\r')"
		if [ -z "$cookie" ]; then
			echo "❌ Aucun cookie de session pour le rôle ${role}" >&2
			exit 1
		fi
		ROLE_COOKIES["$role"]="$cookie"
		local code
		code="$($CURL_CMD -sS -o /dev/null -w '%{http_code}' -H "Cookie: ${cookie}" "${BASE_URI}${PROBE_URLS[$role]}")"
		if [ "$code" != "200" ]; then
			echo "❌ Session du rôle ${role} non reconnue : ${PROBE_URLS[$role]} répond HTTP ${code} au lieu de 200" >&2
			exit 1
		fi
		echo "✅ Connecté en tant que ${role}."
	done
}

fetch_and_clean() {
	local entry="$1" role website expected
	IFS='|' read -r role website expected <<<"$entry"
	expected="${expected:-200}"
	local url="${BASE_URI}${website}"
	local filename
	filename="$(echo "$website" | sed 's|^https\?://||; s|[^A-Za-z0-9._-]|_|g')"
	[ -z "$filename" ] && filename="index"
	local outfile="${OUT_DIR}/${filename}.html"

	local cookie_args=()
	[ "$role" != "anon" ] && cookie_args=(-H "Cookie: ${ROLE_COOKIES[$role]}")

	echo "🌐 ${url} (${role}) → ${outfile}"
	# Pas de -L : on veut voir les redirections. Le code HTTP est ajouté après le corps.
	local raw code body
	if ! raw="$($CURL_CMD -sS "${cookie_args[@]}" -w $'\n%{http_code}' "$url")"; then
		fail "Échec de la récupération de $url (erreur curl)"
		return
	fi
	code="${raw##*$'\n'}"
	body="${raw%$'\n'*}"

	if [ "$code" != "$expected" ]; then
		fail "$url (${role}) : HTTP $code au lieu de $expected"
		return
	fi
	if [ "$expected" != "200" ]; then
		echo "   ↪ HTTP $code attendu, non validé"
		return
	fi
	printf '%s\n' "$body" | { grep -v "Symfony Web Debug Toolbar" || true; } >"$outfile"
}

check_duplicates() {
	local prev_md5="" group=() md5 file
	while read -r md5 file; do
		if [ "$md5" = "$prev_md5" ]; then
			group+=("$file")
		else
			report_group "${group[@]+"${group[@]}"}"
			group=("$file")
			prev_md5="$md5"
		fi
	done < <(cd "$OUT_DIR" && md5sum -- *.html | sort)
	report_group "${group[@]+"${group[@]}"}"
}

report_group() {
	[ "$#" -gt 1 ] || return 0
	case " $ALLOWED_DUPLICATES " in *" $1 "*) return 0 ;; esac
	fail "Contenu identique pour des URLs distinctes : $* (mauvaise session, page d'erreur ou de connexion ?)"
}

main() {
	rm -rf "$OUT_DIR"
	mkdir -p "$OUT_DIR"
	authenticate

	local entry
	for entry in "${URLS[@]}"; do
		fetch_and_clean "$entry"
	done

	if ls "$OUT_DIR"/*.html >/dev/null 2>&1; then
		check_duplicates
		echo "🔍 Validation HTML..."
		if ! $VNU_CMD "/app/$OUT_DIR"; then
			fail "Erreurs de validation HTML"
		else
			echo "✅ Tout le HTML est valide."
		fi
	else
		fail "Aucune page à valider"
	fi

	if [ "$FAILURES" -gt 0 ]; then
		echo "🏁 Validation échouée : ${FAILURES} problème(s)." >&2
		exit 1
	fi
	echo "🏁 Validation terminée."
}

main "$@"
