<?php

declare(strict_types=1);

namespace App\Tests\Browser;

use Facebook\WebDriver\Exception\TimeoutException;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\WebDriverBy;
use Symfony\Component\Panther\Client;
use Symfony\Component\Panther\PantherTestCase;

/**
 * Base des tests navigateur : un client Selenium (Chrome ou Firefox, selon PANTHER_BROWSER_NAME).
 *
 * @SuppressWarnings("PHPMD.NumberOfChildren")
 */
abstract class AbstractBrowserTestCase extends PantherTestCase
{
    protected static function getNewClient(): Client
    {
        $rawHost = getenv('PANTHER_SELENIUM_HOST');
        $host = false !== $rawHost ? $rawHost : 'http://chrome:4444/wd/hub';
        $rawBrowserName = getenv('PANTHER_BROWSER_NAME');
        $browserName = false !== $rawBrowserName ? $rawBrowserName : 'chrome';

        $capabilities = 'firefox' === $browserName
            ? DesiredCapabilities::firefox()
            : DesiredCapabilities::chrome();
        $capabilities->setCapability('acceptInsecureCerts', true);

        return static::createPantherClient(
            ['browser' => static::SELENIUM],
            [],
            [
                'host' => $host,
                'capabilities' => $capabilities,
            ],
        );
    }

    /**
     * Attend la condition comme `$client->wait()->until()`, mais un dépassement de délai dit où en
     * était le navigateur (URL, titre, début du texte), ce que le message brut n'indique pas.
     *
     * @param callable(): mixed $condition
     */
    protected function waitUntil(Client $client, callable $condition, string $description): void
    {
        try {
            $client->wait()->until($condition);
        } catch (TimeoutException $e) {
            throw new \RuntimeException(
                sprintf(
                    "Timeout en attendant %s.\nURL : %s\nTitre : %s\nTexte : %s",
                    $description,
                    $client->getCurrentURL(),
                    $client->getTitle(),
                    mb_substr(trim($client->findElement(WebDriverBy::cssSelector('body'))->getText()), 0, 1500),
                ),
                0,
                $e,
            );
        }
    }
}
