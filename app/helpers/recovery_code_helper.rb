module RecoveryCodeHelper
  def recovery_code_modal_controller_js
    nonced_javascript_tag do
      render(
        partial: 'sign_up/recovery_codes/modal_controller',
        formats: [:js],
        locals: {
          el: '#recovery-code-confirm'
        }
      )
    end
  end
end

ActionView::Base.send :include, RecoveryCodeHelper
