import $ from 'jquery';


// Validation plugin https://github.com/garyv/jQuery-Validation-plugin
(function() {
  var defaults = {
    message: 'Please fill in all required fields.',
    feedbackClass: 'feedback'
  };
  $.fn.validate = function(options) {
    options = $.extend(defaults, options || {});
    return this.each(function() {
      var $form = $(this);
      $form.bind('submit', function(e) {
        var valid = true;
        $form.find('[required]').each(function(i, field) {
          if (valid && !field.value) {
            valid = false;
            $(field).trigger('focus').fadeOut().fadeIn();
            if (field.id) {
              $form.find('label[for="' + field.id + '"]')
                .fadeOut().fadeIn();
            }
          }
        });
        if (!valid) {
          if (!$form.find('.' + options.feedbackClass).length) {
            $form.prepend('<div class="' + options.feedbackClass + '"/>');
          }
          $form.find('.' + options.feedbackClass)
            .html(options.message).fadeOut().fadeIn();
          e.preventDefault();
          return false;
        }
      });
    });
  };
})();


var Upaya = {
  name: 'Upaya',
  linkErrorDescription: function(elm) {
    var $elm = elm;
    $elm.siblings('.error-description').each(function() {
      $(this).attr('id', $elm.attr('id') + '-error-description');
      $elm.attr('aria-describedby', $(this).attr('id'));
    });
    if ($elm.next('.error-description')) {
      var description = $elm.next('.error-description').html();
      var hiddenSpan = '<span class=\'sr-only\'>' + description + '</span>';
      //this next line needs to be ugly to add an extra space for screen reader
      $('label[for=' + $elm.attr('id') + ']').html($('label[for=' + $elm.attr('id') + ']')
        .html() + ' ' + hiddenSpan);
    }
  },
  giveModalFocus: function(dialogEl) {
    var $dialog = $(dialogEl);
    var $ffchild = $dialog.find(':tabbable').first();
    $ffchild.focus();
  },
  manageModalFocus: function() {
    $('button[data-dismiss="modal"]').blur(function(event) {
      event.stopPropagation();
      var dialogEl = $('.modal.in')[0];
      setTimeout(function() {
        Upaya.giveModalFocus(dialogEl);
      }, 1);
      return false;
    });
    $('a[href="https://www.upaya.gov/privacy"]').blur(function() {
      $('button[data-dismiss="modal"]').focus();
    });
  }
};

$(function() {
  initializePage();
});

$(document).on('page:load', function() {
  initializePage();
});

function initializePage() {
  $('[aria-invalid^="true"]').each(function() {
    Upaya.linkErrorDescription($(this));
  });
  $('.js-skip-to-content').click(function() {
    return $('#start-of-content').next().attr('tabindex', '-1').focus();
  });
  //workaround for IE9 focus rect bug
  var ua = window.navigator.userAgent;
  var msie = ua.indexOf('MSIE ');
  if (msie > 0 && parseInt(ua.substring(msie + 5, ua.indexOf('.', msie))) < 10) {
    $('a[href$="http://upaya.18f.gov/"]').blur(function() {
      $(this).parent().addClass('z').removeClass('z');
    });
  }

  $('form').validate();
}
