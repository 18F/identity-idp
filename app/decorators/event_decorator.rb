EventDecorator = Struct.new(:event) do
  def event_partial
    'accounts/event_item'
  end

  def event_type
    I18n.t("event_types.#{event.event_type}")
  end

  def happened_at
    event.created_at
  end

  def happened_at_in_words
    UtcTimePresenter.new(happened_at).to_s
  end
end
