# Architecture

> `doc/` = vérité stable, lue par un humain **et** par un agent (DOC-04). Court, factuel, à jour.

## Vue d'ensemble
<!-- Ce que fait l'application, ses entrées (HTTP, CLI, file de messages) et ses sorties (base, API externes). -->

## Carte des répertoires
<!-- Un dossier = une ligne : rôle, ce qu'il peut importer (reflet de deptrac.yaml). -->

## Rôle de chaque couche
Controller → Service → Calculator → Repository (contrôlé par Deptrac, PHP-05)

| Couche | Rôle | Interdit |
|---|---|---|
| Controller | Valide l'entrée (DTO), appelle un service, formate la réponse | Logique métier, accès direct au repository d'une autre couche |
| Service | Orchestration | |
| Calculator | Calcul métier pur | |
| Repository | Accès aux données (SQL complexe dans `resources/sql/*.sql`) | |

## Flux typiques
<!-- Un flux par entrée : de la requête à la réponse, avec les fichiers (fichier:ligne). -->

## Environnements et services Docker
<!-- dev / test / int / ci / prod, ce que lance docker-compose.yaml. -->
