// Enhances native <details> dropdown menus (header account menu, mobile menu,
// connected-service agency menu) with dismiss-on-Escape and dismiss-on-outside-click.
// The native <details> element opens/closes on summary activation but offers no
// keyboard or pointer affordance to dismiss an open panel, so we add one globally.
const SELECTOR = 'details[data-dismissable-menu]';

function openMenus(): HTMLDetailsElement[] {
  return Array.from(document.querySelectorAll<HTMLDetailsElement>(`${SELECTOR}[open]`));
}

document.addEventListener('click', (event) => {
  const target = event.target as Node | null;
  openMenus().forEach((details) => {
    if (!target || !details.contains(target)) {
      details.open = false;
    }
  });
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') {
    return;
  }

  const menus = openMenus();
  if (!menus.length) {
    return;
  }

  const { activeElement } = document;
  const focused = menus.find((details) => activeElement && details.contains(activeElement));

  // Close the menu that contains focus; otherwise close every open menu.
  (focused ? [focused] : menus).forEach((details) => {
    details.open = false;
  });

  // Return focus to the trigger so keyboard users are not left in the void.
  focused?.querySelector<HTMLElement>('summary')?.focus();
});
