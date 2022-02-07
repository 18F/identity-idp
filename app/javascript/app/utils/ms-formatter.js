const formatTime = (time) => `0${time}`.slice(-2);

export default (milliseconds, screenReader) => {
  const seconds = milliseconds / 1000;
  const minutes = parseInt(seconds / 60, 10);
  const remainingSeconds = parseInt(seconds % 60, 10);

  const displayMinutes = formatTime(minutes);
  const displaySeconds = formatTime(remainingSeconds);

  const displayTime = screenReader
    ? `${minutes > 0 ? `${displayMinutes} minute(s) and ` : ''}${displaySeconds} second(s)`
    : `00:${displayMinutes}:${displaySeconds}`;

  return displayTime;
};
