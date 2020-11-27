SimpleForm::ErrorNotification.class_eval do
  alias_method :old_render, :render
  def render
    return unless has_errors?
    template.render 'shared/alert',
                    type: 'error',
                    message: error_message,
                    class: 'margin-bottom-8'
  end
end
