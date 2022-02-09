const { t } = window.LoginGov.I18n;
const formatTime = (time, unit) =>
  // i18n-tasks-use t('datetime.dotiw.seconds.one')
  // i18n-tasks-use t('datetime.dotiw.seconds.other')
  // i18n-tasks-use t('datetime.dotiw.minutes.one')
  // i18n-tasks-use t('datetime.dotiw.minutes.other')
  time === 1 ? t(`datetime.dotiw.${unit}.one`) : t(`datetime.dotiw.${unit}.other`, { count: time });

export default (milliseconds) => {
  const seconds = milliseconds / 1000;
  const minutes = parseInt(seconds / 60, 10);
  const remainingSeconds = parseInt(seconds % 60, 10);

  const displayMinutes = formatTime(minutes, 'minutes');
  const displaySeconds = formatTime(remainingSeconds, 'seconds');

  const displayTime = `${displayMinutes} ${t(
    'datetime.dotiw.two_words_connector',
  )} ${displaySeconds}`;

  return displayTime;
};
