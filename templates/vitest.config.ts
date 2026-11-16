import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node", // jsdom par fichier : // @vitest-environment jsdom
    globals: true,
    include: ["shared/**/*.test.ts", "worker/**/*.test.ts", "src/**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      // Tout le code applicatif, en glob : un nouveau fichier est couvert
      // d'office (ou fait échouer le seuil).
      include: ["shared/**/*.ts", "worker/**/*.ts", "src/**/*.ts"],
      exclude: [
        "**/*.test.ts",
        "worker/test/**",
        "shared/types.ts", // types seuls
        "worker/listRoom.ts", // coque Durable Object, prouvée par l'e2e
      ],
      thresholds: { lines: 100, branches: 100, functions: 100, statements: 100 },
    },
  },
});
