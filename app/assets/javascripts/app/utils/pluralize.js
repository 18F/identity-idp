export default (word, count) => {
  const I18n = window.LoginGov.I18n;
  const tString = I18n[word] || word;

  return `${tString}${count !== 1 ? 's' : ''}`;
};
