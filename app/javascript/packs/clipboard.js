import ClipboardJS from 'clipboard';

const clipboard = new ClipboardJS('.clipboard');

clipboard.on('success', function (e) {
  e.clearSelection();
});
