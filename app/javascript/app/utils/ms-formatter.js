import { t } from '@18f/identity-i18n';

// i18n-tasks-use t('datetime.dotiw.seconds')
// i18n-tasks-use t('datetime.dotiw.minutes')
const formatTime = (time, unit) => t(`datetime.dotiw.${unit}`, { count: time });

export function msFormatter(milliseconds) {
  const seconds = milliseconds / 1000;
  const minutes = parseInt(seconds / 60, 10);
  const remainingSeconds = parseInt(seconds % 60, 10);

  const displayMinutes = formatTime(minutes, 'minutes');
  const displaySeconds = formatTime(remainingSeconds, 'seconds');

  const displayTime = `${displayMinutes}${t(
    'datetime.dotiw.two_words_connector',
  )}${displaySeconds}`;

  return displayTime;
}
