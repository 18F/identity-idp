import Clipboard from 'clipboard';

const clipboard = new Clipboard('.clipboard');

clipboard.on('success', function(e) {
  e.clearSelection();
});
