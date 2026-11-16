<?php

declare(strict_types=1);

namespace App\Service;

use Doctrine\DBAL\Connection;
use Doctrine\DBAL\Exception;

/**
 * Exemple de couche Service : orchestre, sans accès HTTP. Non finale pour pouvoir être mockée (PHP-06).
 */
class HealthService
{
    public function __construct(private readonly Connection $connection) {}

    public function isDatabaseUp(): bool
    {
        try {
            $this->connection->executeQuery('SELECT 1');
        } catch (Exception) {
            return false;
        }

        return true;
    }
}
