class BadgeComponentPreview < BaseComponentPreview
  # @!group Preview
  def check_circle_icon
    render(BadgeComponent.new(icon: :check_circle).with_content('Verified Account'))
  end

  def lock_icon
    render(BadgeComponent.new(icon: :lock).with_content('Unphishable'))
  end

  def warning_icon
    render(BadgeComponent.new(icon: :warning).with_content('Unverified'))
  end

  def info_icon
    render(BadgeComponent.new(icon: :info).with_content('Pending'))
  end
  # @!endgroup

  # @param icon select [check_circle,lock,warning,info]
  # @param content text
  def workbench(icon: :check_circle, content: 'Verified Account')
    render(BadgeComponent.new(icon: icon&.to_sym).with_content(content))
  end
end
