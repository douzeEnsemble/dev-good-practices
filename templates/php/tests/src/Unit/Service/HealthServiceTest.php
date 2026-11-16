<?php

declare(strict_types=1);

namespace App\Tests\Unit\Service;

use App\Service\HealthService;
use Doctrine\DBAL\Connection;
use Doctrine\DBAL\ConnectionException;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\TestCase;

/**
 * @internal
 */
#[CoversClass(HealthService::class)]
final class HealthServiceTest extends TestCase
{
    public function testIsDatabaseUpWhenQuerySucceeds(): void
    {
        $connection = $this->createMock(Connection::class);
        $connection->expects(self::once())->method('executeQuery')->with('SELECT 1');

        self::assertTrue(new HealthService($connection)->isDatabaseUp());
    }

    public function testIsDatabaseDownWhenQueryFails(): void
    {
        $connection = $this->createStub(Connection::class);
        $connection->method('executeQuery')->willThrowException(new ConnectionException('lost'));

        self::assertFalse(new HealthService($connection)->isDatabaseUp());
    }
}
