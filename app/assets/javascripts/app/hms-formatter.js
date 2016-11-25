const root = window.LoginGov || {};

const pluralize = (word, count) => {
  return `${word}${count !== 1 ? 's' : ''}`;
};

const formatMinutes = minutes => {
  if (!minutes) return 0;

  return `${minutes} ${pluralize('minute', minutes)}`;
};

const formatSeconds = seconds => {
  return `${seconds} ${pluralize('second', seconds)}`;
};

root.hmsFormatter = function(milliseconds) {
  const seconds = milliseconds / 1000;
  const minutes = parseInt(seconds / 60, 10);
  const remainingSeconds = parseInt(seconds % 60, 10);

  const displayMinutes = formatMinutes(minutes);
  const displaySeconds = formatSeconds(remainingSeconds);

  return `${displayMinutes} and ${displaySeconds}`;
};
