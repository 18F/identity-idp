function formatMinutes(minutes) {
  return minutes < 10 ? `0${minutes}` : minutes;
}

function formatSeconds(seconds) {
  return seconds < 10 ? `0${seconds}` : seconds;
}

export default (milliseconds) => {
  const seconds = milliseconds / 1000;
  const minutes = parseInt(seconds / 60, 10);
  const remainingSeconds = parseInt(seconds % 60, 10);

  const displayMinutes = formatMinutes(minutes);
  const displaySeconds = formatSeconds(remainingSeconds);

  return `00:${displayMinutes}:${displaySeconds}`;
};
