class DownloadButtonComponent < ButtonComponent
  attr_reader :data, :file_name, :tag_options

  def initialize(data:, file_name:, **tag_options)
    super(
      icon: :file_download,
      action: ->(**tag_options, &block) do
        link_to(
          "data:text/plain;charset=utf-8,#{CGI.escape(data)}",
          download: file_name,
          **tag_options,
          &block
        )
      end,
      **tag_options,
    )

    @data = data
    @file_name = file_name
  end

  def call
    content_tag(:'lg-download-button', super)
  end

  def content
    t('components.download_button.label')
  end
end
