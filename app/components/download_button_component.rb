class DownloadButtonComponent < ButtonComponent
  attr_reader :file_data, :file_name, :tag_options

  def initialize(file_data:, file_name:, **tag_options)
    super(
      icon: :file_download,
      action: ->(**tag_options, &block) do
        link_to(
          "data:text/plain;charset=utf-8,#{ERB::Util.url_encode(file_data)}",
          download: file_name,
          **tag_options,
          &block
        )
      end,
      **tag_options,
    )

    @file_data = file_data
    @file_name = file_name
  end

  def call
    content_tag(:'lg-download-button', super)
  end

  def content
    super || t('components.download_button.label')
  end
end
