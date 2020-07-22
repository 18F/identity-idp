export default function toggleBanner() {
  const enableBannerToggling = () => {
    const bannerButton = document.querySelector('.usa-banner__button');

    const toggleBannerSection = (evt) => {
      evt.currentTarget.setAttribute(
        'aria-expanded',
        evt.currentTarget.getAttribute('aria-expanded') === 'true'
          ? 'false'
          : 'true',
      );
      const howYouKnowSection = document.querySelector('#gov-banner');
      if (howYouKnowSection) howYouKnowSection.classList.toggle('hide');
    };

    if (bannerButton) {
      bannerButton.addEventListener('click', toggleBannerSection);
    }
  };

  window.onload = enableBannerToggling;
}
