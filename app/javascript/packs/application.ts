import { accordion, banner, skipnav } from '@18f/identity-design-system';

const components = [accordion, banner, skipnav];
components.forEach((component) => component.on());
const mainContent = document.getElementById('main-content');
document.querySelector('.usa-skipnav')?.addEventListener('click', (event) => {
  event.preventDefault();
  mainContent?.scrollIntoView();
});
