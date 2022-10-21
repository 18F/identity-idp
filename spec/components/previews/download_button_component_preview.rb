class DownloadButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(DownloadButtonComponent.new(file_data: 'File Data', file_name: 'file_name.txt'))
  end
  # @!endgroup

  # @param file_data text
  # @param file_name text
  def workbench(file_data: 'File Data', file_name: 'file_name.txt')
    render(DownloadButtonComponent.new(file_data: file_data, file_name: file_name))
  end
end
