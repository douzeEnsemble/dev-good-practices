<?php

declare(strict_types=1);

namespace App\Tests\Browser;

use PHPUnit\Framework\Attributes\CoversNothing;
use PHPUnit\Framework\Attributes\Test;

/**
 * @internal
 */
#[CoversNothing]
final class HomeTest extends AbstractBrowserTestCase
{
    #[Test]
    public function homeDisplaysItsTitle(): void
    {
        $client = $this->getNewClient();
        $client->request('GET', '/');

        $this->waitUntil(
            $client,
            static fn () => 'Accueil' === $client->getTitle(),
            'le titre de la page d\'accueil',
        );

        self::assertSame('Accueil', $client->getTitle());
    }
}
