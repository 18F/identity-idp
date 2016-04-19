// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require turbolinks
//= require_tree ../../../vendor/assets/javascripts
//= require_tree .
var Upaya = {
  name: 'Upaya',
  linkErrorDescription: function (elm) {
    var $elm = elm;
    $elm.siblings('.error-description').each(function () {
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
  bindAlertFlash: function () {
    if ($('.alert').length) {
      $('.alert').each(function () {
        if ($(this).hasClass('alert-success')) {
          $(this).colorFade([
            189,
            231,
            172
          ]);
          $('.gets-focus:first').focus();
        } else if ($(this).hasClass('alert-danger')) {
          $(this).colorFade([
            228,
            180,
            180
          ]);
          if ($(this).find('#flash_alert').length) {
            $(this).find('#flash_alert').focus();
          } else {
            $(this).find('#flash_error').focus();
          }
        } else {
          $(this).colorFade();
        }
      });
    } else {
      $('.gets-focus:first').focus();
    }
  },
  giveModalFocus: function (dialogEl) {
    var $dialog = $(dialogEl);
    var $ffchild = $dialog.find(':tabbable').first();
    $ffchild.focus();
  },
  manageModalFocus: function () {
    $('button[data-dismiss="modal"]').blur(function (event) {
      event.stopPropagation();
      var dialogEl = $('.modal.in')[0];
      setTimeout(function () {
        Upaya.giveModalFocus(dialogEl);
      }, 1);
      return false;
    });
    $('a[href="https://www.upaya.gov/privacy"]').blur(function () {
      $('button[data-dismiss="modal"]').focus();
    });
  }
};
  $(function () {
  initializePage();
});
$(document).on('page:load', function () {
  initializePage();
});
function initializePage() {
  $('[aria-invalid^="true"]').each(function () {
    Upaya.linkErrorDescription($(this));
  });
  $('.js-skip-to-content').click(function () {
    return $('#start-of-content').next().attr('tabindex', '-1').focus();
  });
  //workaround for IE9 focus rect bug
  var ua = window.navigator.userAgent;
  var msie = ua.indexOf('MSIE ');
  if (msie > 0 && parseInt(ua.substring(msie + 5, ua.indexOf('.', msie))) < 10) {
    $('a[href$="http://upaya.18f.gov/"]').blur(function () {
      $(this).parent().addClass('z').removeClass('z');
    });
  }
  $('.flash-messages').change(function () {
    Upaya.bindAlertFlash();
  });
  Upaya.bindAlertFlash();

  $('form').validate();
}
// debugging for 508 tab order
//  $(document).find(':tabbable').focus(function(e){
//    console.log("focusing on " + $(this).html());
//  });

// Validation plugin https://github.com/garyv/jQuery-Validation-plugin
(function($){
    var defaults = {
        message: 'Please fill in all required fields.',
        feedbackClass: 'feedback'
    };
    $.fn.validate = function(options) {
        options = $.extend(defaults, options||{});
        return this.each(function() {
            var $form = $(this);
            $form.bind('submit', function (e) {
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
                    e.preventDefault(); return false;
                }
            });
        });
    };
})(jQuery);
