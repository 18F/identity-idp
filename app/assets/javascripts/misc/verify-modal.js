const I18n = window.LoginGov.I18n;

function verifyModal() {
  const flash = document.querySelector("[id^='js-modal']");

  if (flash) {
    const name = flash.id.split('-').pop();
    const heading = flash.querySelector('strong:first-of-type');
    const content = flash.querySelector('span:first-of-type');
    const attempts = flash.querySelector('span:last-of-type');

    if ((name === 'warning' || name === 'error') && (heading !== null && content !== null)) {
      const button = I18n.t(`idv.modal.button.${name}`);

      // Hide flash message
      flash.classList.add('display-none');

      // Add modal
      const el = document.createElement('div');
      el.classList.add('modal-cntnr');
      el.innerHTML = `
        <div class="px2 py4 modal-inner">
          <div class="mx-auto p4 cntnr-xskinny border-box bg-white rounded-xxl modal-${name}">
            <h2 class="my2 fs-20p sans-serif regular center">${heading.innerHTML}</h2>
            <hr class="mb3 bw4 rounded">
            <p>${content.innerHTML}</p>
            <p class="mb5">${attempts.innerHTML}</p>
            <div class="center">
              <a href="#" id="js-close-modal" class="btn btn-wide px2 py1 rounded-lg border bw2">
                ${button}
              </a>
            </div>
          </div>
        </div>`;
      document.body.appendChild(el);

      // Remove modal
      const close = document.getElementById(`js-close-modal`);
      close.addEventListener('click', function() {
        el.parentNode.removeChild(el);
      });
    }
  }
}


document.addEventListener('DOMContentLoaded', verifyModal);
