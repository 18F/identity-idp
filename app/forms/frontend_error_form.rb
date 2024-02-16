class FrontendErrorForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validate :validate_filename_extension
  validate :validate_filename_host

  attr_reader :filename

  def submit(filename:)
    @filename = filename

    FormResponse.new(success: valid?, errors:, serialize_error_details_only: true)
  end

  private

  def validate_filename_extension
    return if File.extname(filename) == '.js'
    errors.add(:filename, :invalid_extension, message: t('errors.general'))
  end

  def validate_filename_host
    begin
      return if URI(filename).host == IdentityConfig.store.domain_name
    rescue URI::InvalidURIError; end

    errors.add(:filename, :invalid_host, message: t('errors.general'))
  end
end
