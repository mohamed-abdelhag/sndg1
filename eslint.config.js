// @ts-check
/** @type {import('eslint').Linter.FlatConfig[]} */

import eslintPluginSvelte from 'eslint-plugin-svelte';
import tseslint from '@typescript-eslint/eslint-plugin';
import tseslintParser from '@typescript-eslint/parser';

export default [
	{
		ignores: ['**/node_modules/**', '.svelte-kit/**', 'build/**']
	},
	{
		files: ['**/*.{js,ts,svelte}'],
		plugins: {
			'@typescript-eslint': tseslint,
			svelte: eslintPluginSvelte
		},
		languageOptions: {
			parser: tseslintParser,
			parserOptions: {
				ecmaVersion: 2022,
				sourceType: 'module',
				extraFileExtensions: ['.svelte']
			}
		}
	},
	{
		files: ['**/*.svelte'],
		processor: 'svelte/svelte'
	}
];
