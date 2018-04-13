module JavascriptDriverHelper
  def javascript_enabled?
    Capybara.current_driver == Capybara.javascript_driver
  end
end
