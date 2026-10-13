/**
 * Behaviour for the delegated-access consent control on the agency handoff screen.
 *
 * - "Allow all" and the per-application list are mutually exclusive: checking "allow all"
 *   clears and disables the per-application choices, and choosing any application clears
 *   "allow all".
 * - The per-application list is paginated client-side, whole agency groups at a time, so long
 *   lists stay navigable without a round trip.
 */

function initPagination(list: HTMLElement) {
  const groups = Array.from(list.querySelectorAll<HTMLElement>('[data-delegation-agency]'));
  const pager = list.querySelector<HTMLElement>('[data-delegation-pager]');
  const prev = list.querySelector<HTMLButtonElement>('[data-delegation-prev]');
  const next = list.querySelector<HTMLButtonElement>('[data-delegation-next]');
  const status = list.querySelector<HTMLElement>('[data-delegation-page-status]');
  const pageSize = Number(list.dataset.pageSize) || 5;

  // Page by application count but never split an agency group: each page holds whole groups
  // until pageSize applications are reached (and always at least one group).
  const pages: HTMLElement[][] = [];
  let current: HTMLElement[] = [];
  let count = 0;
  groups.forEach((group) => {
    const size = group.querySelectorAll('[data-delegation-application]').length;
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
  const allBox = root.querySelector<HTMLInputElement>('[data-delegation-all]');
  const list = root.querySelector<HTMLElement>('[data-delegation-applications]');
  const applicationBoxes = Array.from(
    root.querySelectorAll<HTMLInputElement>('[data-delegation-application] input[type=checkbox]'),
  );

  function syncDependents() {
    const all = allBox?.checked ?? false;
    applicationBoxes.forEach((box) => {
      box.disabled = all;
      if (all) {
        box.checked = false;
      }
    });
  }

  allBox?.addEventListener('change', syncDependents);
  applicationBoxes.forEach((box) =>
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

document.querySelectorAll<HTMLElement>('[data-delegation-consent]').forEach(init);
