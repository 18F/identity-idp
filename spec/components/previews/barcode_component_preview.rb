class BarcodeComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(BarcodeComponent.new(barcode_data: '1234567812345678', label: 'Barcode', logo_image_url: asset_url('logo.svg')))
  end
  # @!endgroup

  # @param barcode_data text
  # @param label text
  def workbench(barcode_data: '1234567812345678', label: 'Barcode')
    render(BarcodeComponent.new(barcode_data:, label:, logo_image_url: asset_url('logo.svg')))
  end
end
