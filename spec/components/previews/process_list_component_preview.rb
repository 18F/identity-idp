class ProcessListComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(ProcessListComponent.new) do |c|
      c.item(heading: 'Item 1') { 'Item 1 Content' }
      c.item(heading: 'Item 2') { 'Item 2 Content' }
    end
  end

  def connected
    render(ProcessListComponent.new(connected: true)) do |c|
      c.item(heading: 'Item 1') { 'Item 1 Content' }
      c.item(heading: 'Item 2') { 'Item 2 Content' }
    end
  end

  def big
    render(ProcessListComponent.new(big: true)) do |c|
      c.item(heading: 'Item 1') { 'Item 1 Content' }
      c.item(heading: 'Item 2') { 'Item 2 Content' }
    end
  end

  def big_and_connected
    render(ProcessListComponent.new(big: true, connected: true)) do |c|
      c.item(heading: 'Item 1') { 'Item 1 Content' }
      c.item(heading: 'Item 2') { 'Item 2 Content' }
    end
  end
  # @!endgroup

  # @param connected toggle
  # @param big toggle
  def workbench(big: false, connected: false)
    render(ProcessListComponent.new(big: big, connected: connected)) do |c|
      c.item(heading: 'Item 1') { 'Item 1 Content' }
      c.item(heading: 'Item 2') { 'Item 2 Content' }
    end
  end
end
