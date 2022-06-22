function submitLink(event: MouseEvent) {
  event.preventDefault();
  if (event.target instanceof HTMLAnchorElement) {
    const { formId } = event.target.dataset;
    if (formId) {
      const form = document.getElementById(formId) as HTMLFormElement | null;
      form?.submit();
    }
  }
}

const links = document.querySelectorAll<HTMLAnchorElement>('a[data-form-id]');
links.forEach((link) => link.addEventListener('click', submitLink));
