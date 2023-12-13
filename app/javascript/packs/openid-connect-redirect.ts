import { forceRedirect } from '@18f/identity-url';

document.body.classList.add('usa-sr-only');
const link = document.querySelector<HTMLLinkElement>('#openid-connect-redirect')!;
forceRedirect(link.href);
