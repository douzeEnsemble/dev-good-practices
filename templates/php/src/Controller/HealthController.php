<?php

declare(strict_types=1);

namespace App\Controller;

use App\Service\HealthService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

/**
 * Exemple de couche Controller : aucune logique métier, un service, une réponse.
 */
final readonly class HealthController
{
    public function __construct(private HealthService $healthService) {}

    #[Route('/health', name: 'health', methods: ['GET'])]
    public function __invoke(): JsonResponse
    {
        $isUp = $this->healthService->isDatabaseUp();

        return new JsonResponse(
            ['database' => $isUp ? 'up' : 'down'],
            $isUp ? Response::HTTP_OK : Response::HTTP_SERVICE_UNAVAILABLE,
        );
    }
}
