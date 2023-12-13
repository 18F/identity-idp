import { forceNavigate } from '@18f/identity-url';
document.body.classList.add('usa-sr-only');
const link: HTMLLinkElement = document.getElementById('openid-connect-redirect')!;
forceRedirect(link.href);
