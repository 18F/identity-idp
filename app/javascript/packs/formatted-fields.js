import Cleave from 'cleave.js';

const SELECTOR_CONFIGS = {
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

Object.entries(SELECTOR_CONFIGS)
  .map(([selector, config]) => [document.querySelector(selector), config])
  .filter(([element]) => element)
  .forEach(([element, config]) => new Cleave(element, config));
