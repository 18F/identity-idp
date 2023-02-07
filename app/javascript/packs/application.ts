import { accordion, banner, skipnav } from 'identity-style-guide';

const components = [accordion, banner, skipnav];
components.forEach((component) => component.on());
const mainContent = document.getElementById('main-content');
document.querySelector('.usa-skipnav')?.addEventListener('click', (event) => {
  event.preventDefault();
  mainContent?.scrollIntoView();
});
