var root = window.LoginGov || {};

root.hmsFormatter = function(milliseconds) {
  var seconds = milliseconds / 1000;
  var minutes = parseInt(seconds / 60, 10);
  var remainingSeconds = parseInt(seconds % 60, 10);

  var displayMinutes = minutes == 0 ? '' :
    minutes + ' minute' + (minutes !== 1 ? 's' : '') + ' and ';
  var displaySeconds = remainingSeconds + ' second' + (remainingSeconds !== 1 ? 's' : '');

  return (displayMinutes + displaySeconds);
};
