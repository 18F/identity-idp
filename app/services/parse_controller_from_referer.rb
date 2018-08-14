class ParseControllerFromReferer
  def initialize(referer)
    @referer = referer
  end

  def call
    { request_came_from: controller_and_action_from_referer }
  end

  private

  attr_reader :referer

  def controller_and_action_from_referer
    return 'no referer' if referer.nil?
    "#{controller_that_made_the_request}##{controller_action}"
  end

  def controller_that_made_the_request
    parsed_referer[:controller]
  end

  def controller_action
    parsed_referer[:action]
  end

  def parsed_referer
    @parsed_referer ||= Rails.application.routes.recognize_path(referer)
  end
end
