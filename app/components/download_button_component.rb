# frozen_string_literal: true

class DownloadButtonComponent < ButtonComponent
  attr_reader :file_data, :file_name, :tag_options

  def initialize(file_data:, file_name:, **tag_options)
    super(
      **tag_options,
      icon: :download,
      url: "data:text/plain;charset=utf-8,#{ERB::Util.url_encode(file_data)}",
      download: file_name,
    )

    @file_data = file_data
    @file_name = file_name
  end

  def content
    super || t('components.download_button.label')
  end
end
