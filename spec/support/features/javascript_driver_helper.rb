module JavascriptDriverHelper
  def javascript_enabled?
    %i[headless_chrome headless_chrome_mobile].include?(Capybara.current_driver)
  end

  def with_awaited_fetch
    setup_js = <<~JS
      window._fetch = window.fetch;
      window.fetch = async (...args) => {
        window.isFetching = true;
        const result = await window._fetch.call(window, ...args);
        window.isFetching = false;
        return result;
      };
    JS
    teardown_js = 'window.fetch = window._fetch; delete window._fetch;'

    page.execute_script(setup_js)
    yield
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop if page.evaluate_script('window.isFetching')
    end
    page.execute_script(teardown_js)
  end
end
