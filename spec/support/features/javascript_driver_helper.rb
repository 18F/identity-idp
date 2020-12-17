module JavascriptDriverHelper
  def javascript_enabled?
    %i[headless_chrome headless_chrome_mobile].include?(Capybara.current_driver)
  end
end
