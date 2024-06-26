import { tooltip } from '@18f/identity-design-system';

document.querySelectorAll<HTMLElement>('.badge-tooltip').forEach((element) => tooltip.on(element));
