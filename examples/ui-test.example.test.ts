// Exemple générique (ne vient pas d'un dépôt) : test d'interface à structure exacte.
// @vitest-environment jsdom
import { describe, expect, it, vi } from "vitest";
import { renderCard, wireDelete } from "./card";

describe("renderCard", () => {
  it("produit exactement la structure attendue", () => {
    const el = renderCard({ id: "a", label: "Pain" });
    // toBe sur le HTML complet : tue « classe vidée », « type supprimé »…
    expect(el.outerHTML).toBe(
      '<li class="card" data-id="a"><span class="label">Pain</span></li>',
    );
    // et aucun attribut en trop
    expect(el.getAttributeNames()).toEqual(["class", "data-id"]);
  });
});

describe("wireDelete", () => {
  it("bloque l'action par défaut du clic", () => {
    const button = document.createElement("button");
    wireDelete(button, vi.fn());
    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    button.dispatchEvent(click);
    // pas seulement « le handler est appelé »
    expect(click.defaultPrevented).toBe(true);
  });
});
