import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    // Tests must never call a paid API, even if a key is in the environment.
    env: { MINGLI_AI_PROVIDER: "mock" },
  },
});
