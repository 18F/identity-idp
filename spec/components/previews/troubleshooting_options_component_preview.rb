class TroubleshootingOptionsComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(TroubleshootingOptionsComponent.new) do |c|
      c.header { 'Header' }
      c.option(url: '') { 'Option 1' }
      c.option(url: '') { 'Option 2' }
      c.option(url: '', new_tab: true) { 'Option 3 (New Tab)' }
    end
  end
  # @!endgroup

  # @param header text
  def workbench(header: 'Header')
    render(TroubleshootingOptionsComponent.new) do |c|
      c.header { header }
      c.option(url: '') { 'Option 1' }
      c.option(url: '') { 'Option 2' }
      c.option(url: '', new_tab: true) { 'Option 3 (New Tab)' }
    end
  end
end
