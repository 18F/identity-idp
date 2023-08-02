class SessionTimeoutModalComponent < BaseComponent
  attr_reader :timeout, :warning_offset, :timeout_url, :tag_options

  delegate :label_id, :description_id, to: :modal

  def initialize(timeout:, warning_offset:, timeout_url:, **tag_options)
    @timeout = timeout
    @warning_offset = warning_offset
    @timeout_url = timeout_url
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-session-timeout-modal',
      modal_content,
      timeout: timeout.as_json,
      'warning-offset-in-seconds': warning_offset,
      'timeout-url': timeout_url,
    )
  end

  def modal_content
    render modal.with_content(content)
  end

  def modal
    @modal ||= ModalComponent.new
  end

  def keep_alive_button(**button_options, &block)
    render(
      ButtonComponent.new(
        type: :button,
        **button_options,
        class: [*button_options[:class], 'lg-session-timeout-modal__keep-alive-button'],
      ),
      &block
    )
  end
end
