# Point d'entrée unique (SCR-03, PHP-01) : tout se lance par `make`, dans Docker.
# La CI appelle les mêmes commandes. `make help` liste les cibles (commentaires « ## »).
# Adapter : noms de services (php), dossiers de tests, outils présents dans tools/.

# Image de production (PHP-13) et dossier des mocks Moco (PHP-09, PHP-10) : adapter
IMAGE ?= ghcr.io/proprietaire/projet
MOCKS_DIR ?= tests/resources/moco

DOCKER = docker
DOCKER_COMP = docker compose

# Conteneurs
PHP_CONT = $(DOCKER_COMP) exec php

# Exécutables
PHP      = $(PHP_CONT) php
COMPOSER = $(PHP_CONT) composer
SYMFONY  = $(PHP) bin/console
PHPUNIT  = $(PHP) vendor/bin/phpunit --display-all

# Linters d'infrastructure : images épinglées (mises à jour par workflow, UPD-01)
DOCKERCOMPOSE_LINTER_CMD = docker run -t --rm -v ${PWD}:/app zavoloklom/dclint:3.1.0-alpine
DOTENV_LINTER_CMD = docker run -t --rm -v ${PWD}:/app -w /app dotenvlinter/dotenv-linter:4.0.0
HADOLINT_CMD = docker run -i --rm hadolint/hadolint:v2.15.1-alpine hadolint -
EDITORCONFIG_LINTER_CMD = docker run --rm --volume=${PWD}:/check mstruebing/editorconfig-checker:4.0.2

# Outils de tools/ (une ligne par outil : audit et mises à jour les parcourent)
TOOLS = php-cs-fixer phpmd phpstan psalm deptrac infection jsonlint

SHELL := /bin/bash
.DEFAULT_GOAL = help

# Lance plusieurs cibles avec spinner, affiche ✔/✘ et ne déverse le log QUE des cibles en échec.
define sequential_runner
@TOOLS="$(1)"; \
LABEL="$(2)"; \
N=0; for t in $$TOOLS; do N=$$((N+1)); done; \
TMPDIR=$$(mktemp -d); \
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'); \
printf "Running $$N $$LABEL sequentially…\n\n"; \
for tool in $$TOOLS; do \
	printf "  \033[2m○\033[0m  %s\n" "$$tool"; \
done; \
for tool in $$TOOLS; do \
	idx=0; \
	for t in $$TOOLS; do \
		[ "$$t" = "$$tool" ] && break; \
		idx=$$((idx + 1)); \
	done; \
	lines_up=$$((N - idx)); \
	( $(MAKE) --no-print-directory $$tool > "$$TMPDIR/$$tool.log" 2>&1; echo $$? > "$$TMPDIR/$$tool.exit" ) & \
	spin_idx=0; \
	while [ ! -f "$$TMPDIR/$$tool.exit" ]; do \
		spin_char=$${SPINNER[$$((spin_idx % 10))]}; \
		printf "\033[%dA\r\033[2K  \033[33m%s\033[0m  %s\033[%dB\r" "$$lines_up" "$$spin_char" "$$tool" "$$lines_up"; \
		spin_idx=$$((spin_idx + 1)); \
		sleep 0.1; \
	done; \
	exit_code=$$(cat "$$TMPDIR/$$tool.exit"); \
	if [ "$$exit_code" -eq 0 ]; then \
		printf "\033[%dA\r\033[2K  \033[32m✔\033[0m  %s\033[%dB\r" "$$lines_up" "$$tool" "$$lines_up"; \
	else \
		printf "\033[%dA\r\033[2K  \033[31m✘\033[0m  %s\033[%dB\r" "$$lines_up" "$$tool" "$$lines_up"; \
		printf "\n"; \
		cat "$$TMPDIR/$$tool.log"; \
		rm -rf "$$TMPDIR"; \
		exit 1; \
	fi; \
done; \
printf "\n"; \
rm -rf "$$TMPDIR"
endef

define parallel_runner
@TOOLS="$(1)"; \
LABEL="$(2)"; \
N=0; for t in $$TOOLS; do N=$$((N+1)); done; \
TMPDIR=$$(mktemp -d); \
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'); \
printf "Launching $$N $$LABEL in parallel…\n\n"; \
for tool in $$TOOLS; do \
	printf "  \033[33m⏳\033[0m  %s\n" "$$tool"; \
done; \
for tool in $$TOOLS; do \
	( $(MAKE) --no-print-directory $$tool > "$$TMPDIR/$$tool.log" 2>&1; echo $$? > "$$TMPDIR/$$tool.exit" ) & \
done; \
PENDING="$$TOOLS"; \
FAILED=0; \
spin_idx=0; \
while [ -n "$$PENDING" ]; do \
	spin_char=$${SPINNER[$$((spin_idx % 10))]}; \
	NEW_PENDING=""; \
	for tool in $$PENDING; do \
		idx=0; \
		for t in $$TOOLS; do \
			[ "$$t" = "$$tool" ] && break; \
			idx=$$((idx + 1)); \
		done; \
		lines_up=$$((N - idx)); \
		if [ -f "$$TMPDIR/$$tool.exit" ]; then \
			exit_code=$$(cat "$$TMPDIR/$$tool.exit"); \
			if [ "$$exit_code" -eq 0 ]; then \
				printf "\033[%dA\r\033[2K  \033[32m✔\033[0m  %s\033[%dB\r" "$$lines_up" "$$tool" "$$lines_up"; \
			else \
				printf "\033[%dA\r\033[2K  \033[31m✘\033[0m  %s\033[%dB\r" "$$lines_up" "$$tool" "$$lines_up"; \
				FAILED=1; \
			fi; \
		else \
			printf "\033[%dA\r\033[2K  \033[33m%s\033[0m  %s\033[%dB\r" "$$lines_up" "$$spin_char" "$$tool" "$$lines_up"; \
			NEW_PENDING="$$NEW_PENDING $$tool"; \
		fi; \
	done; \
	PENDING="$$NEW_PENDING"; \
	spin_idx=$$((spin_idx + 1)); \
	[ -n "$$PENDING" ] && sleep 0.1; \
done; \
printf "\n"; \
if [ $$FAILED -eq 0 ]; then \
	printf "\033[32mAll $$LABEL passed.\033[0m\n"; \
else \
	for tool in $$TOOLS; do \
		exit_code=$$(cat "$$TMPDIR/$$tool.exit"); \
		if [ "$$exit_code" -ne 0 ]; then \
			printf "\n\033[31m── %s ──────────────────────────────────────────────────\033[0m\n" "$$tool"; \
			cat "$$TMPDIR/$$tool.log"; \
		fi; \
	done; \
fi; \
rm -rf "$$TMPDIR"; \
[ $$FAILED -eq 0 ]
endef

.PHONY: help
help: ## Affiche cette aide
	@grep -E '(^[a-zA-Z0-9_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

## —— Docker 🐳 ——————————————————————————————————————————
.env:
	touch .env
.env.dev.local:
	cp .env.dev .env.dev.local

.PHONY: build
build: ## Construit les images
	$(DOCKER_COMP) build

.PHONY: install
install: ## Prépare un poste neuf
install: .env .env.dev.local build

.PHONY: start
start: ## Démarre le projet (poste neuf compris)
start: install up vendor cc

.PHONY: up
up: ## Démarre les conteneurs
	$(DOCKER_COMP) up --wait

.PHONY: stop
stop: ## Arrête le projet
	$(DOCKER_COMP) down --remove-orphans

.PHONY: destruct
destruct: ## Repart de zéro (volumes et images)
destruct: stop
	$(DOCKER_COMP) down --remove-orphans --volumes --rmi all

.PHONY: sh
sh: ## Shell dans le conteneur PHP
	@$(PHP_CONT) sh

.PHONY: composer
composer: ## Lance composer : make composer c='req paquet'
	@$(COMPOSER) $(c)

.PHONY: vendor
vendor: ## Installe les dépendances du composer.lock
	@$(COMPOSER) install --prefer-dist --no-progress --no-interaction

.PHONY: cc
cc: ## Vide le cache
	@$(SYMFONY) cache:clear
	@$(SYMFONY) cache:clear --env=test

## —— Agrégats 🚀 ——————————————————————————————————————————
.PHONY: all a
all: ## Tout : infra-quality, code-quality, tests + mesures, security
	$(call parallel_runner,infra-quality code-quality tests-measures security,test suites)
a: all

.PHONY: tests-measures
tests-measures:
	$(call sequential_runner,tests measures,tests-measures)

.PHONY: quality
quality: ## infra-quality + code-quality
	$(call parallel_runner,infra-quality code-quality,quality checks)

## —— Tests 🧪 ——————————————————————————————————————————
.PHONY: tests t
tests: ## Tests unitaires + intégration
	$(call parallel_runner,tests-unit tests-integration,test suites)
t: tests

.PHONY: tests-unit tu
tests-unit: ## Tests unitaires
	$(PHPUNIT) tests/src/Unit
tu: tests-unit

.PHONY: tests-integration ti
tests-integration: ## Tests d'intégration
	$(PHPUNIT) tests/src/Integration
ti: tests-integration

## —— Infra Quality 🏗️ ——————————————————————————————————————
.PHONY: infra-quality iq
infra-quality: ## Tous les linters d'infrastructure
	$(call parallel_runner,docker-compose-linter dockerfile-linter dotenv-linter check-moco-refs,infra-quality checks)
iq: infra-quality

.PHONY: docker-compose-linter
docker-compose-linter: ## Linter Docker Compose
	$(DOCKERCOMPOSE_LINTER_CMD) -r .

.PHONY: dockerfile-linter
dockerfile-linter: ## Linter Dockerfile
	@for f in $$(find .docker -name Dockerfile); do $(HADOLINT_CMD) < $$f || exit 1; done

.PHONY: dotenv-linter
dotenv-linter: ## Linter .env
	$(DOTENV_LINTER_CMD) check --recursive .

## —— Code Quality 🔍 ——————————————————————————————————————
.PHONY: code-quality cq
code-quality: ## Toutes les analyses de code
	$(call parallel_runner,editorconfig-linter jsonlint validate-autoloader phpcsfixer phpmd psalm phpstan deptrac,code-quality checks)
cq: code-quality

.PHONY: editorconfig-linter
editorconfig-linter: ## EditorConfig
	$(EDITORCONFIG_LINTER_CMD) editorconfig-checker --exclude=".phar"

.PHONY: validate-autoloader
validate-autoloader: ## Fichiers/classes mal nommés (PSR strict)
	@$(COMPOSER) dump-autoload -o --strict-psr --strict-ambiguous --dry-run

# Les outils s'installent à la demande : `make phpstan` marche sur un clone neuf.
tools/%/vendor: tools/%/composer.json
	$(COMPOSER) install --working-dir=tools/$* --prefer-dist --no-progress --no-interaction
tools/php-cs-fixer/vendor/bin/php-cs-fixer: tools/php-cs-fixer/vendor
tools/phpmd/vendor/bin/phpmd: tools/phpmd/vendor
tools/psalm/vendor/bin/psalm: tools/psalm/vendor
tools/phpstan/vendor/bin/phpstan: tools/phpstan/vendor
tools/deptrac/vendor/bin/deptrac: tools/deptrac/vendor
tools/infection/vendor/bin/infection: tools/infection/vendor
tools/jsonlint/vendor/bin/jsonlint: tools/jsonlint/vendor

.PHONY: phpcsfixer
phpcsfixer: ## PHP-CS-Fixer (check)
phpcsfixer: tools/php-cs-fixer/vendor/bin/php-cs-fixer
	@$(PHP) tools/php-cs-fixer/vendor/bin/php-cs-fixer check --diff

.PHONY: phpcsfixer-fix
phpcsfixer-fix: ## PHP-CS-Fixer (fix)
phpcsfixer-fix: tools/php-cs-fixer/vendor/bin/php-cs-fixer
	@$(PHP) tools/php-cs-fixer/vendor/bin/php-cs-fixer fix

.PHONY: phpmd
phpmd: ## PHPMD
phpmd: tools/phpmd/vendor/bin/phpmd
	@$(PHP) tools/phpmd/vendor/bin/phpmd analyze src tests --format text --ruleset phpmd.ruleset.xml

.PHONY: psalm
psalm: ## Psalm (deux passes)
psalm: tools/psalm/vendor/bin/psalm
	@$(PHP_CONT) rm -Rf var/cache/psalm
	$(call parallel_runner,psalm-xml psalm-src-xml,psalm analyses)

.PHONY: psalm-xml
psalm-xml: tools/psalm/vendor/bin/psalm
	@$(PHP) tools/psalm/vendor/bin/psalm -c psalm.xml --no-diff --show-info=false --no-cache --find-unused-psalm-suppress --no-suggestions

.PHONY: psalm-src-xml
psalm-src-xml: tools/psalm/vendor/bin/psalm
	@$(PHP) tools/psalm/vendor/bin/psalm -c psalm-src-only.xml --no-diff --show-info=false --no-cache --find-unused-psalm-suppress --no-suggestions

.PHONY: phpstan
phpstan: ## PHPStan
phpstan: tools/phpstan/vendor/bin/phpstan
	@$(PHP) tools/phpstan/vendor/bin/phpstan clear-result-cache
	@$(PHP) tools/phpstan/vendor/bin/phpstan analyse --memory-limit=-1

.PHONY: deptrac
deptrac: ## Deptrac (architecture)
deptrac: tools/deptrac/vendor/bin/deptrac
	@$(PHP) tools/deptrac/vendor/bin/deptrac analyse --report-uncovered --fail-on-uncovered

## —— Mesures 📏 ——————————————————————————————————————————
.PHONY: measures m
measures: ## Couverture (100 %) puis mutation (MSI 100 %)
measures: clear-build
	$(call sequential_runner,coverage-generate coverage-check infection,measures)
m: measures

.PHONY: clear-build
clear-build:
	@rm -Rf build/coverage*

.PHONY: coverage-generate
coverage-generate: build/coverage/coverage-xml

build/coverage/coverage-xml:
	$(DOCKER_COMP) exec -e XDEBUG_MODE=coverage -T php \
		php vendor/bin/phpunit --no-progress --exclude-testsuite="Browser Test Suite" \
			--coverage-clover=build/coverage/coverage.xml \
			--coverage-xml=build/coverage/coverage-xml \
			--log-junit=build/coverage/junit.xml

.PHONY: coverage-check
coverage-check: ## Seuil de couverture 100 % ; génère le HTML en cas d'échec
coverage-check: build/coverage/coverage-xml
	@$(PHP_CONT) php tools/coverage/coverage.php build/coverage/coverage.xml 100 true \
	|| (echo "❌ Couverture sous le seuil, génération du HTML…" && $(MAKE) coverage-html && exit 1)

.PHONY: coverage
coverage: ## Couverture + seuil
coverage: clear-build build/coverage/coverage-xml coverage-check

.PHONY: coverage-html
coverage-html: ## Rapport de couverture HTML
	$(DOCKER_COMP) exec -e XDEBUG_MODE=coverage -T php \
		php vendor/bin/phpunit --no-progress --exclude-testsuite="Browser Test Suite" --coverage-html=build/coverage/coverage-html

.PHONY: infection
infection: ## Mutation (MSI et covered MSI à 100)
infection: build/coverage/coverage-xml tools/infection/vendor/bin/infection
	@$(PHP_CONT) rm -Rf var/cache/infection
	@$(PHP) tools/infection/vendor/bin/infection --threads=4 --no-progress \
		--skip-initial-tests --coverage=build/coverage \
		--min-msi=100 --min-covered-msi=100 --filter=src

## —— Sécurité 🛡️ ——————————————————————————————————————————
.PHONY: security s
security: ## composer audit : application et chaque outil
	$(call parallel_runner,composer-audit composer-audit-tools,security checks)
s: security

.PHONY: composer-audit
composer-audit: ## composer audit (application)
	@$(COMPOSER) audit --locked

.PHONY: composer-audit-tools
composer-audit-tools: ## composer audit (chaque outil)
	@for tool in $(TOOLS); do echo "Audit de tools/$$tool"; $(COMPOSER) audit --locked --working-dir=tools/$$tool || exit 1; done

.PHONY: jsonlint
jsonlint: ## Valide la syntaxe JSON des fixtures et des mocks
jsonlint: tools/jsonlint/vendor/bin/jsonlint
	@find tests/resources -type f -name "*.json" -exec $(PHP) tools/jsonlint/vendor/bin/jsonlint {} \; > /dev/null

## —— Mocks 🎭 ——————————————————————————————————————————
.PHONY: check-moco-refs
check-moco-refs: ## Références des mocks Moco : aucune cassée, aucun fichier orphelin (sans Docker)
	@# Convention : $(MOCKS_DIR)/<jeu>.moco.json + dossier de réponses $(MOCKS_DIR)/<jeu>/
	@for f in $(MOCKS_DIR)/*.moco.json; do \
		[ -e "$$f" ] || continue; \
		tools/check-moco-refs/check_moco_refs.sh "$${f%.moco.json}" $(MOCKS_DIR) "$$f" || exit 1; \
	done

.PHONY: clean-unused-files
clean-unused-files: ## Supprime les fichiers de mock inutiles d'un jeu : make clean-unused-files mock=<jeu>
	tools/clean-unused-files/clean_unused_files.sh $(MOCKS_DIR)/$(mock)

.PHONY: clean-moco-routes
clean-moco-routes: ## Supprime les routes de mock inutiles d'un jeu : make clean-moco-routes mock=<jeu>
	tools/clean-moco-routes/clean_moco_routes.sh $(MOCKS_DIR)/$(mock).moco.json

## —— Image 🐳 ——————————————————————————————————————————
.PHONY: img-build
img-build: ## Construit l'image de production
	$(DOCKER) build --target php_prod -f ./.docker/php/Dockerfile -t $(IMAGE):latest .

## —— Git 🌿 ——————————————————————————————————————————
.PHONY: hooks
hooks: ## Active le hook Conventional Commits (GIT-07)
	git config core.hooksPath .githooks
