/**
 * On pages that use the # value for navigation, we need to intercept
 * and alter the functionality of the 'Skip to main content' link.
 * This function prevents the link from appending the hash to the url,
 * and instead it focuses on the main-content section of the page.
 * When the React FSM navigation is changed so that we no longer use the # value,
 * we should remove this code.
 * @param - null
 *
 * @return - null
 */

export default function hijackSkipNav(): void {
  const skipNavLink = document.querySelector<HTMLFormElement>('.usa-skipnav');
  const mainContent = document.querySelector<HTMLFormElement>('#main-content');

  skipNavLink?.addEventListener('click', (e) => {
    e.preventDefault();
    mainContent?.focus();
    mainContent?.scrollIntoView();
  });
}
