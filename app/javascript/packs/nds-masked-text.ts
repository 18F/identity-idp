document.querySelectorAll<HTMLElement>('[data-nds-masked]').forEach((wrapper) => {
  const toggle = wrapper.querySelector<HTMLButtonElement>('[data-nds-masked-toggle]');
  if (!toggle) {
    return;
  }
  toggle.addEventListener('click', () => {
    const revealed = toggle.getAttribute('aria-pressed') !== 'true';
    toggle.setAttribute('aria-pressed', String(revealed));
    wrapper.querySelectorAll<HTMLElement>('.masked-text__text').forEach((el) => {
      el.classList.toggle('display-none', (el.dataset.masked === 'true') === revealed);
    });
    wrapper
      .querySelector<HTMLElement>('.nds-masked__icon-show')
      ?.toggleAttribute('hidden', revealed);
    wrapper
      .querySelector<HTMLElement>('.nds-masked__icon-hide')
      ?.toggleAttribute('hidden', !revealed);
  });
});
