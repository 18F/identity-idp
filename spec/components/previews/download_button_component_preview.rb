class DownloadButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(DownloadButtonComponent.new(file_data: 'File Data', file_name: 'file_name.txt'))
  end
  # @!endgroup

  # @param file_data text
  # @param file_name text
  # @param big toggle
  def workbench(file_data: 'File Data', big: false, file_name: 'file_name.txt')
    render(DownloadButtonComponent.new(file_data:, file_name:, big:))
  end
end
