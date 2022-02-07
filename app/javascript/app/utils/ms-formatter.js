const formatTime = (time) => `0${time}`.slice(-2);

export default (milliseconds, screenReader) => {
  const seconds = milliseconds / 1000;
  const minutes = parseInt(seconds / 60, 10);
  const remainingSeconds = parseInt(seconds % 60, 10);

  const displayMinutes = formatTime(minutes);
  const displaySeconds = formatTime(remainingSeconds);

  const displayTime = screenReader
    ? `00:${displayMinutes}:${displaySeconds}`
    : `${minutes > 0 ? `${displayMinutes} minute(s) and ` : ''}${displaySeconds} second(s)`;

  return displayTime;
};
