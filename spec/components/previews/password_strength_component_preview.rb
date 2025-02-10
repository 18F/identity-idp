class PasswordStrengthComponentPreview < BaseComponentPreview
  # @after_render :inject_input_html
  # @!group Preview
  def default
    render(PasswordStrengthComponent.new(input_id: 'preview-input'))
  end
  # @!endgroup

  # @after_render :inject_input_html
  # @param minimum_length text
  # @param forbidden_passwords text
  def workbench(minimum_length: '12', forbidden_passwords: 'password')
    render(
      PasswordStrengthComponent.new(
        input_id: 'preview-input',
        minimum_length:,
        forbidden_passwords: forbidden_passwords.split(','),
      ),
    )
  end

  private

  def inject_input_html(html, _context)
    <<~HTML
      <label for="preview-input" class="usa-label">Password</label>
      <input id="preview-input" class="usa-input">
      #{html}
    HTML
  end
end
