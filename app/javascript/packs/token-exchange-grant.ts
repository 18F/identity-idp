/**
 * Behaviour for the token-exchange grant control on the agency handoff screen.
 *
 * - "Allow all" and the per-application list are mutually exclusive: checking
 *   "allow all" clears and disables the per-application choices, and choosing
 *   any application clears "allow all".
 * - Auto-enrollment depends on "allow all" when the user has linked agencies;
 *   it is only enabled once "allow all" is checked.
 * - The per-application list is paginated client-side, one agency group at a
 *   time per page, so long lists stay navigable without a round trip.
 */

function initPagination(list: HTMLElement) {
  const groups = Array.from(list.querySelectorAll<HTMLElement>('[data-token-exchange-agency]'));
  const pager = list.querySelector<HTMLElement>('[data-token-exchange-pager]');
  const prev = list.querySelector<HTMLButtonElement>('[data-token-exchange-prev]');
  const next = list.querySelector<HTMLButtonElement>('[data-token-exchange-next]');
  const status = list.querySelector<HTMLElement>('[data-token-exchange-page-status]');
  const pageSize = Number(list.dataset.pageSize) || 5;

  // Flatten to rows (agency heading + its targets) and page by target count so
  // a page never splits an agency awkwardly: each page holds whole agency
  // groups until pageSize targets are reached (at least one group per page).
  const pages: HTMLElement[][] = [];
  let current: HTMLElement[] = [];
  let count = 0;
  groups.forEach((group) => {
    const size = group.querySelectorAll('[data-token-exchange-target]').length;
    if (current.length > 0 && count + size > pageSize) {
      pages.push(current);
      current = [];
      count = 0;
    }
    current.push(group);
    count += size;
  });
  if (current.length > 0) {
    pages.push(current);
  }

  if (pages.length <= 1 || !pager) {
    return;
  }

  let index = 0;
  function render() {
    groups.forEach((group) => {
      group.hidden = !pages[index].includes(group);
    });
    if (prev) {
      prev.disabled = index === 0;
    }
    if (next) {
      next.disabled = index === pages.length - 1;
    }
    if (status) {
      status.textContent = `${index + 1} / ${pages.length}`;
    }
  }

  pager.hidden = false;
  prev?.addEventListener('click', () => {
    index = Math.max(0, index - 1);
    render();
  });
  next?.addEventListener('click', () => {
    index = Math.min(pages.length - 1, index + 1);
    render();
  });
  render();
}

function init(root: HTMLElement) {
  const allBox = root.querySelector<HTMLInputElement>('[data-token-exchange-all]');
  const autoBox = root.querySelector<HTMLInputElement>('[data-token-exchange-auto-enroll]');
  const list = root.querySelector<HTMLElement>('[data-token-exchange-targets]');
  const targetBoxes = Array.from(
    root.querySelectorAll<HTMLInputElement>('[data-token-exchange-target] input[type=checkbox]'),
  );

  function syncDependents() {
    const all = allBox?.checked ?? false;
    if (autoBox && allBox) {
      autoBox.disabled = !all;
      if (!all) {
        autoBox.checked = false;
      }
    }
    targetBoxes.forEach((box) => {
      box.disabled = all;
      if (all) {
        box.checked = false;
      }
    });
  }

  allBox?.addEventListener('change', syncDependents);
  targetBoxes.forEach((box) =>
    box.addEventListener('change', () => {
      if (box.checked && allBox) {
        allBox.checked = false;
        syncDependents();
      }
    }),
  );
  syncDependents();

  if (list) {
    initPagination(list);
  }
}

document.querySelectorAll<HTMLElement>('[data-token-exchange-grant]').forEach(init);
