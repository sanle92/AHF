import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // JSON transport and schema-driven form values are validated at the API/SQL
  // boundary. Their heterogeneous payloads intentionally use a dynamic type.
  {files:["app/api/**/*.ts","lib/server.ts","lib/domain.ts","components/workspace.tsx","components/record-form.tsx","components/record-detail.tsx","components/module-records.tsx","components/notification-settings.tsx","tests/auth.test.ts"],rules:{"@typescript-eslint/no-explicit-any":"off"}},
  // Browser/auth lifecycle effects synchronize external state during hydration.
  {files:["components/workspace.tsx"],rules:{"react-hooks/set-state-in-effect":"off"}},
  // Official branding uses original image files without an image optimization service.
  {files:["components/workspace.tsx","components/organization-setup.tsx","components/mfa-gate.tsx"],rules:{"@next/next/no-img-element":"off"}},
  globalIgnores([
    "dist/**",
    ".vinext/**",
    ".wrangler/**",
    ".sites-runtime/**",
    "outputs/**",
    "work/**",
  ]),
  {
    files: ["components/ui/**/*.{ts,tsx}", "hooks/use-mobile.ts"],
    rules: {
      // These files are vendored verbatim from shadcn@4.17.0. Keep the
      // registry source intact while applying the stricter rules to Site code.
      "@typescript-eslint/no-unused-vars": "off",
      "react-hooks/purity": "off",
      "react-hooks/set-state-in-effect": "off",
    },
  },
]);

export default eslintConfig;
