<?php

declare(strict_types=1);

namespace App\Tests\Integration\Controller;

use App\Controller\HomeController;
use PHPUnit\Framework\Attributes\CoversClass;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

/**
 * @internal
 */
#[CoversClass(HomeController::class)]
final class HomeControllerTest extends WebTestCase
{
    public function testHomeIsAValidHtmlPage(): void
    {
        $client = self::createClient();
        $client->request('GET', '/');

        self::assertResponseStatusCodeSame(200);
        self::assertSame(
            '<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Accueil</title></head>'
            .'<body><h1>Accueil</h1></body></html>',
            $client->getResponse()->getContent(),
        );
    }
}
