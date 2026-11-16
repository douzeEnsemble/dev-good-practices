<?php

declare(strict_types=1);

namespace App\Controller;

use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

/**
 * Page d'exemple pour les tests navigateur et la validation W3C : à remplacer par vos vraies pages.
 */
final readonly class HomeController
{
    #[Route('/', name: 'home', methods: ['GET'])]
    public function __invoke(): Response
    {
        return new Response(
            '<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Accueil</title></head>'
            .'<body><h1>Accueil</h1></body></html>',
        );
    }
}
