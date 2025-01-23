#!/usr/bin/env node

import assert from 'node:assert';
import { readFile, glob } from 'node:fs/promises';
import { dirname, relative, join } from 'node:path';

// Do not add to this list! All new scripts should be written in TypeScript, so this list should
// only ever shrink over time. Scripts which are loaded directly by Node.js should exist within
// packages with a defined entrypoint.
const LEGACY_FILE_EXCEPTIONS = [
  'app/javascript/packages/device/index.js',
  'app/javascript/packages/document-capture/index.js',
  'app/javascript/packages/document-capture/components/acuant-capture-canvas.jsx',
  'app/javascript/packages/document-capture/components/acuant-selfie-capture-canvas.jsx',
  'app/javascript/packages/document-capture/components/callback-on-mount.jsx',
  'app/javascript/packages/document-capture/components/file-image.jsx',
  'app/javascript/packages/document-capture/components/submission-interstitial.jsx',
  'app/javascript/packages/document-capture/components/submission.jsx',
  'app/javascript/packages/document-capture/context/device.js',
  'app/javascript/packages/document-capture/higher-order/with-props.jsx',
  'app/javascript/packages/document-capture/hooks/use-async.js',
  'app/javascript/packages/document-capture/hooks/use-cookie.js',
  'app/javascript/packages/document-capture/hooks/use-counter.js',
  'app/javascript/packages/document-capture/hooks/use-previous.js',
  'app/javascript/packages/masked-text-toggle/index.js',
  'spec/javascript/packs/form-steps-wait-spec.js',
  'spec/javascript/packs/state-guidance-spec.js',
  'spec/javascript/packs/webauthn-setup-spec.js',
  'spec/javascript/support/document-capture.jsx',
  'spec/javascript/support/dom.js',
  'spec/javascript/support/file.js',
  'spec/javascript/support/mocha.js',
  'spec/javascript/packages/device/index-spec.js',
  'spec/javascript/packages/document-capture-polling/index-spec.js',
  'spec/javascript/packages/masked-text-toggle/index-spec.js',
  'spec/javascript/packages/document-capture/components/acuant-camera-spec.jsx',
  'spec/javascript/packages/document-capture/components/acuant-capture-canvas-spec.jsx',
  'spec/javascript/packages/document-capture/components/acuant-capture-spec.jsx',
  'spec/javascript/packages/document-capture/components/acuant-sdk-spec.js',
  'spec/javascript/packages/document-capture/components/acuant-selfie-camera-spec.jsx',
  'spec/javascript/packages/document-capture/components/acuant-selfie-capture-canvas-spec.jsx',
  'spec/javascript/packages/document-capture/components/callback-on-mount-spec.jsx',
  'spec/javascript/packages/document-capture/components/document-capture-spec.jsx',
  'spec/javascript/packages/document-capture/components/document-capture-warning-spec.jsx',
  'spec/javascript/packages/document-capture/components/file-image-spec.jsx',
  'spec/javascript/packages/document-capture/components/file-input-spec.jsx',
  'spec/javascript/packages/document-capture/components/review-issues-step-spec.jsx',
  'spec/javascript/packages/document-capture/components/submission-complete-spec.jsx',
  'spec/javascript/packages/document-capture/components/submission-interstitial-spec.jsx',
  'spec/javascript/packages/document-capture/components/submission-spec.jsx',
  'spec/javascript/packages/document-capture/components/suspense-error-boundary-spec.jsx',
  'spec/javascript/packages/document-capture/components/tip-list-spec.jsx',
  'spec/javascript/packages/document-capture/components/general-error-spec.jsx',
  'spec/javascript/packages/document-capture/components/warning-spec.jsx',
  'spec/javascript/packages/document-capture/context/acuant-spec.jsx',
  'spec/javascript/packages/document-capture/context/device-spec.jsx',
  'spec/javascript/packages/document-capture/context/failed-capture-attempts-spec.jsx',
  'spec/javascript/packages/document-capture/context/file-base64-cache-spec.js',
  'spec/javascript/packages/document-capture/context/index-spec.js',
  'spec/javascript/packages/document-capture/context/selfie-capture-spec.jsx',
  'spec/javascript/packages/document-capture/context/service-provider-spec.jsx',
  'spec/javascript/packages/document-capture/context/upload-spec.jsx',
  'spec/javascript/packages/document-capture/higher-order/with-props-spec.jsx',
  'spec/javascript/packages/document-capture/hooks/use-async-spec.jsx',
  'spec/javascript/packages/document-capture/hooks/use-cookie-spec.jsx',
  'spec/javascript/packages/document-capture/hooks/use-counter-spec.jsx',
  'spec/javascript/packages/document-capture/hooks/use-previous.spec.js',
  'spec/javascript/packages/document-capture/services/upload-spec.js',
];

const packagesWithEntrypoints = await Array.fromAsync(
  glob('app/javascript/packages/*/package.json'),
)
  .then((files) => Promise.all(files.map(async (file) => [file, await readFile(file, 'utf-8')])))
  .then((contents) => contents.map(([file, content]) => [file, JSON.parse(content)]))
  .then((manifests) => manifests.filter(([_file, manifest]) => manifest.exports || manifest.main))
  .then((manifests) => manifests.map(([file]) => dirname(file)));

const jsFileEntries = await Array.fromAsync(
  glob(['app/{javascript/packages,components}/**/*.{js,jsx}', 'spec/javascript/*/**/*.{js,jsx}'], {
    exclude: (fileName) =>
      packagesWithEntrypoints.some((path) =>
        relative(process.cwd(), fileName.parentPath).startsWith(path),
      ),
    withFileTypes: true,
  }),
);

const jsFiles = jsFileEntries.map(({ parentPath, name }) =>
  relative(process.cwd(), join(parentPath, name)),
);

const invalidExceptions = LEGACY_FILE_EXCEPTIONS.filter((file) => !jsFiles.includes(file));

assert(
  !invalidExceptions.length,
  `Unnecessary exception should be removed from LEGACY_FILE_EXCEPTIONS allowlist.

Found ${JSON.stringify(invalidExceptions)}`,
);

const unexpectedJSFiles = jsFiles.filter((file) => !LEGACY_FILE_EXCEPTIONS.includes(file));

assert(
  !unexpectedJSFiles.length,
  `All new JavaScript files should be written with TypeScript extensions (.ts, .tsx).

Found ${JSON.stringify(unexpectedJSFiles)}
`,
);
