class SessionTimeoutWarningModalPresenter
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TranslationHelper

  attr_reader :time_left_in_session

  def initialize(time_left_in_session)
    @time_left_in_session = time_left_in_session
  end

  def message
    raise NotImplementedError
  end

  def continue
    raise NotImplementedError
  end

  def sign_out
    raise NotImplementedError
  end
end
