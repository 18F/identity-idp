$(document).on('page:change', function () {
  var maxH = 0;
  $('.same-height-panel').each( function () {
    var thisH = $(this).height();
    if (thisH > maxH) {
      maxH = thisH;
    }
  });

  $('.same-height-panel').each( function () {
    $(this).css('minHeight',maxH+'px');
  });
});
