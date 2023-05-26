class TroubleshootingOptionsComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(TroubleshootingOptionsComponent.new) do |c|
      c.with_header { 'Header' }
      c.with_option(url: '') { 'Option 1' }
      c.with_option(url: '') { 'Option 2' }
      c.with_option(url: '', new_tab: true) { 'Option 3 (New Tab)' }
    end
  end
  # @!endgroup

  # @param header text
  def workbench(header: 'Header')
    render(TroubleshootingOptionsComponent.new) do |c|
      c.with_header { header }
      c.with_option(url: '') { 'Option 1' }
      c.with_option(url: '') { 'Option 2' }
      c.with_option(url: '', new_tab: true) { 'Option 3 (New Tab)' }
    end
  end
end
