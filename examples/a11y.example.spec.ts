// Exemple générique (ne vient pas d'un dépôt) : tests d'accessibilité Playwright (A11Y-02, A11Y-03).
// Dépendance de développement : @axe-core/playwright.
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

// Une page = un état à contrôler ; ajouter les états qui changent le DOM (dialogue ouvert, erreur affichée).
const pages = [
  { name: "accueil", path: "/" },
  { name: "réglages", path: "/settings" },
];

for (const { name, path } of pages) {
  test(`axe : aucune violation sur ${name}`, async ({ page }) => {
    await page.goto(path);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
      .analyze();
    // toEqual([]) : le rapport s'affiche en entier à l'échec
    expect(results.violations).toEqual([]);
  });
}

test("dialogue : focus piégé, Échap ferme, focus rendu au déclencheur", async ({ page }) => {
  await page.goto("/");
  const trigger = page.getByRole("button", { name: "Ouvrir les réglages" });
  await trigger.focus();
  await page.keyboard.press("Enter");

  const dialog = page.getByRole("dialog", { name: "Réglages" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Fermer" })).toBeFocused();

  await page.keyboard.press("Escape");
  await expect(dialog).toBeHidden();
  await expect(trigger).toBeFocused();
});

test("l'erreur de formulaire est annoncée et liée au champ", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Enregistrer" }).click();
  const field = page.getByRole("textbox", { name: "Nom" });
  await expect(field).toHaveAttribute("aria-invalid", "true");
  await expect(field).toHaveAccessibleDescription(/obligatoire/i);
  await expect(page.getByRole("alert")).toBeVisible();
});
