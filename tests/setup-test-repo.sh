#!/usr/bin/env bash
# setup-test-repo.sh — Creates a minimal but realistic TypeScript/Node project
# for testing the full /generate-setup pipeline.
set -euo pipefail

REPO_DIR="/tmp/ccautomated-test-repo"

if [ -d "$REPO_DIR" ]; then
  echo "Cleaning existing test repo..."
  rm -rf "$REPO_DIR"
fi

echo "Creating test repo at $REPO_DIR..."
mkdir -p "$REPO_DIR/src" "$REPO_DIR/tests" "$REPO_DIR/.github/workflows"

# ── package.json ──────────────────────────────────────────────────────────────
cat > "$REPO_DIR/package.json" << 'EOF'
{
  "name": "test-api-service",
  "version": "1.0.0",
  "description": "A minimal Express API service for testing CCAutomated",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/ tests/",
    "format": "prettier --write 'src/**/*.ts' 'tests/**/*.ts'"
  },
  "dependencies": {
    "express": "^4.18.2",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.11.0",
    "typescript": "^5.3.3",
    "vitest": "^1.2.0",
    "eslint": "^8.56.0",
    "@typescript-eslint/eslint-plugin": "^6.19.0",
    "@typescript-eslint/parser": "^6.19.0",
    "prettier": "^3.2.0",
    "ts-node": "^10.9.2"
  }
}
EOF

# ── tsconfig.json ─────────────────────────────────────────────────────────────
cat > "$REPO_DIR/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
EOF

# ── Source file ───────────────────────────────────────────────────────────────
cat > "$REPO_DIR/src/index.ts" << 'EOF'
import express from "express";
import { z } from "zod";

const app = express();
app.use(express.json());

const UserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/users", (req, res) => {
  const result = UserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ errors: result.error.issues });
  }
  return res.status(201).json({ user: result.data });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

export { app };
EOF

# ── Test file ─────────────────────────────────────────────────────────────────
cat > "$REPO_DIR/tests/index.test.ts" << 'EOF'
import { describe, it, expect } from "vitest";

describe("UserSchema", () => {
  it("should validate a correct user", () => {
    const user = { name: "Alice", email: "alice@example.com" };
    expect(user.name).toBe("Alice");
  });

  it("should reject invalid email", () => {
    const user = { name: "Bob", email: "not-an-email" };
    expect(user.email).not.toContain("@example.com");
  });
});
EOF

# ── ESLint config ─────────────────────────────────────────────────────────────
cat > "$REPO_DIR/.eslintrc.json" << 'EOF'
{
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "env": {
    "node": true,
    "es2022": true
  },
  "rules": {
    "@typescript-eslint/no-unused-vars": "error"
  }
}
EOF

# ── Prettier config ───────────────────────────────────────────────────────────
cat > "$REPO_DIR/.prettierrc" << 'EOF'
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all"
}
EOF

# ── GitHub Actions CI ─────────────────────────────────────────────────────────
cat > "$REPO_DIR/.github/workflows/ci.yml" << 'EOF'
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm test
EOF

# ── README ────────────────────────────────────────────────────────────────────
cat > "$REPO_DIR/README.md" << 'EOF'
# Test API Service

A minimal Express API service with Zod validation. Used for testing CCAutomated setup generation.

## Setup
```bash
npm install
npm run dev
```

## Testing
```bash
npm test
```
EOF

# ── .gitignore ────────────────────────────────────────────────────────────────
cat > "$REPO_DIR/.gitignore" << 'EOF'
node_modules/
dist/
*.js.map
.env
EOF

# ── Initialize git ────────────────────────────────────────────────────────────
cd "$REPO_DIR"
git init -q
git add -A
git commit -q -m "Initial commit: minimal Express + TypeScript + Vitest project"

# Sentinel file — test cleanup scripts check for this before rm -rf
touch .ccautomated-test-repo

echo ""
echo "Test repo created at: $REPO_DIR"
echo "Stack: TypeScript, Node.js, Express, Zod, Vitest, ESLint, Prettier, GitHub Actions"
echo ""
echo "Next: run '/generate-setup $REPO_DIR' in Claude Code"
