#!/usr/bin/env node

import { lint, loadConfig } from '@redocly/openapi-core';
import assert from 'node:assert';

const pathToApi = './docs/attempts-api/openapi.yml';
const config = await loadConfig({ configPath: '' });
const lintResults = await lint({ ref: pathToApi, config });

assert(
  !lintResults.length,
  `The OpenAPI spec is not valid.

  Found ${JSON.stringify(lintResults)}
  `)