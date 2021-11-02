# Monkey-patch SimpleForm::ErrorNotification to customize markup to reuse alert partial, which
# requires more markup customization than is possible through default options.
#
# See: https://github.com/heartcombo/simple_form/blob/master/lib/simple_form/error_notification.rb

module Extensions
  SimpleForm::ErrorNotification.class_eval do
    def render
      return unless has_errors?
      template.render AlertComponent.new(
        type: :error,
        message: error_message,
        class: 'margin-bottom-8',
      )
    end
  end
end
