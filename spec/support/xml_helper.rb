require 'rexml/document'
require 'rexml/xpath'

module XmlHelper
  module_function

  def xml_text_at_path(xml, xpath)
    document = REXML::Document.new(xml)
    REXML::XPath.first(document, xpath).text
  end

  def modify_xml_at_xpath(xml, xpath, new_contents)
    document = REXML::Document.new(xml)
    REXML::XPath.first(document, xpath).text = new_contents
    document.to_s
  end

  def delete_xml_at_xpath(xml, xpath)
    document = REXML::Document.new(xml)
    element = REXML::XPath.first(document, xpath)
    element.parent.delete(element)
    document.to_s
  end

  def pretty_xml_from_string(document)
    output = String.new(encoding: 'UTF-8')
    doc = REXML::Document.new(document)
    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    formatter.write(doc, output)
    output.to_s
  end
end
