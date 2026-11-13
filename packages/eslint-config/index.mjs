import antfu from '@antfu/eslint-config';
import checkFile from 'eslint-plugin-check-file';
import globalsLib from 'globals';

/**
 * @param {object} config - Configuration options
 * @param {'app'|'lib'} [config.type] - Project type, either 'app' or 'lib'
 * @param {boolean} [config.typescript] - Whether to enable TypeScript support
 * @param {boolean} [config.vue] - Whether to enable Vue support
 * @param {boolean} [config.react] - Whether to enable React support
 * @param {boolean} [config.markdown] - Whether to enable Markdown support
 * @param {Parameters<typeof antfu>[1][]} userConfigs
 */
export function defineConfig(
  { type = 'app', typescript = true, vue = false, react = false, markdown = false } = {},
  ...userConfigs
) {
  return antfu(
    {
      type,
      typescript: typescript && {
        overrides: {
          // Allow both `type` and `interface` instead of enforcing one style.
          'ts/consistent-type-definitions': ['off'],
          // Disallow using symbols before they’re defined; named exports are allowed, but function declarations still can’t be used before definition.
          'ts/no-use-before-define': ['error', { allowNamedExports: true, functions: false }],
          // Permit re-declaring identifiers (useful with TS declaration merging).
          'ts/no-redeclare': ['off'],
        },
      },

      stylistic: {
        // Enforce semicolons.
        semi: true,
      },
      vue: vue && {
        overrides: {
          // Warn if Vue event names don’t follow the expected casing.
          'vue/custom-event-name-casing': ['warn'],
          // Enforce SFC (Single File Component) block order.
          'vue/block-order': ['error', { order: ['template', 'script', 'style'] }],
          // Disallow use of undefined variables in Vue SFCs.
          'no-undef': ['error'],
        },
      },

      react,

      markdown,

      rules: {
        /* Code style */
        // Require braces for all control statements, even single‑line.
        'curly': ['error', 'all'],
        // Enforce 1TBS (One True Brace Style - opening brace goes on the same line as the statement) braces and disallow single-line blocks.
        'style/brace-style': ['error', '1tbs', { allowSingleLine: false }],
        // Enforce single quotes, allows double quotes to avoid escaping.
        'style/quotes': ['error', 'single', { avoidEscape: true }],
        // Require parentheses around arrow function parameters.
        'style/arrow-parens': ['error', 'always'],

        /* Code quality */
        // Error on unused vars/imports but ignore ones prefixed with _, ignore rest siblings, and ignore caught errors with _.
        'unused-imports/no-unused-vars': [
          'error',
          {
            argsIgnorePattern: '^_',
            varsIgnorePattern: '^_',
            caughtErrorsIgnorePattern: '^_',
            ignoreRestSiblings: true,
          },
        ],
      },
    },
    {
      files: ['**/*.md/**/*.{ts,tsx,js,jsx}'],
      rules: {
        // Skip unused checks inside markdown code blocks.
        'unused-imports/no-unused-vars': 'off',
      },
    },
    {
      plugins: {
        'check-file': checkFile,
      },
      rules: {
        // Enforce .usecase.ts naming (lowercase), rejecting variants like useCase, UseCase, useCases, etc. via these mappings:
        'check-file/filename-blocklist': [
          'error',
          {
            '**/*.useCase.ts': '*.usecase.ts',
            '**/*.useCases.ts': '*.usecase.ts',
            '**/*UseCase.ts': '*.usecase.ts',
            '**/*UseCases.ts': '*.usecase.ts',
          },
        ],
      },
    },
    ...userConfigs,
  );
}

export const globals = globalsLib;
