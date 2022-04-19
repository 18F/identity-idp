import Cleave from 'cleave.js';
import type { CleaveOptions } from 'cleave.js/options';

const SELECTOR_CONFIGS: Record<string, CleaveOptions> = {
  '.personal-key': {
    blocks: [4, 4, 4, 4],
    delimiter: '-',
  },
  '.backup-code': {
    blocks: [4, 4, 4],
    delimiter: '-',
  },
  '.zipcode': {
    numericOnly: true,
    blocks: [5, 4],
    delimiter: '-',
    delimiterLazyShow: true,
  },
};

for (const [selector, config] of Object.entries(SELECTOR_CONFIGS)) {
  const element = document.querySelector(selector);
  if (element) {
    // eslint-disable-next-line no-new
    new Cleave(element as HTMLElement, config);
  }
}
