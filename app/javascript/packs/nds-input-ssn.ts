import * as designSystem from '@18f/identity-design-system';

interface NDSBehavior {
  on(root?: ParentNode): void;
  off(): void;
}

// `inputSsn` ships in the design system's next release; until the published
// typings include it, read it off the module without a static member check.
const { inputSsn } = designSystem as unknown as { inputSsn: NDSBehavior };

inputSsn.on(document.body);
