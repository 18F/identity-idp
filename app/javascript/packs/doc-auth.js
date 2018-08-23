function docAuth() {
  const player = document.getElementById('player');
  const canvas = document.getElementById('canvas');
  const context = canvas.getContext('2d');
  const captureButton = document.getElementById('capture');
  const input = document.getElementById('_doc_auth_image');

  const constraints = {
    video: true,
  };

  const state = {
    video: true,
  };

  function captureImage() {
    // Draw the video frame to the canvas.
    context.drawImage(player, 0, 0, player.width, player.height);
    input.value = canvas.toDataURL('image/png', 1.0);
    player.style.display = 'none';
    canvas.style.display = 'inline-block';
    captureButton.innerHTML = 'X';
    player.srcObject.getVideoTracks().forEach(track => track.stop());
    player.srcObject = null;
  }

  function startVideo() {
    // Attach the video stream to the video element and autoplay.
    navigator.mediaDevices.getUserMedia(constraints)
      .then((stream) => {
        player.srcObject = stream;
      });
  }

  function resetImage() {
    startVideo();
    canvas.style.display = 'none';
    player.style.display = 'inline-block';
    captureButton.innerHTML = 'Capture';
    input.value = '';
    context.clearRect(0, 0, canvas.width, canvas.height);
  }

  captureButton.addEventListener('click', () => {
    if (state.video) {
      captureImage();
    } else {
      resetImage();
    }
    state.video = !state.video;
  });

  startVideo();
}

document.addEventListener('DOMContentLoaded', docAuth);
