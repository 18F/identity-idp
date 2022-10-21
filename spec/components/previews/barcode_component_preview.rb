class BarcodeComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(BarcodeComponent.new(barcode_data: '1234567812345678', label: 'Barcode'))
  end
  # @!endgroup

  # @param barcode_data text
  # @param label text
  def workbench(barcode_data: '1234567812345678', label: 'Barcode')
    render(BarcodeComponent.new(barcode_data: barcode_data, label: label))
  end
end
