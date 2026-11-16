<?php

declare(strict_types=1);

namespace App\Tests\Integration\Controller;

use App\Controller\HealthController;
use PHPUnit\Framework\Attributes\CoversClass;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

/**
 * @internal
 */
#[CoversClass(HealthController::class)]
final class HealthControllerTest extends WebTestCase
{
    public function testHealthReportsDatabaseUp(): void
    {
        $client = self::createClient();
        $client->request('GET', '/health');

        self::assertResponseStatusCodeSame(200);
        self::assertSame('{"database":"up"}', $client->getResponse()->getContent());
    }
}
