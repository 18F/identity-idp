module BrowserEmulationHelper
  def emulate_reduced_motion
    page.driver.browser.page.command('Emulation.setEmulatedMedia', name: 'prefers-reduced-motion', value: 'reduce')
  end
end
