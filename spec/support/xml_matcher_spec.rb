require 'rails_helper'

RSpec.describe 'match_xml custom matcher' do
  let(:weirdly_formatted_carrot_xml) do
    <<~XML
      <vegetable>
                            <name>Carrot</name><color>Orange (usually)</color>
                            
                            
                            
                </vegetable>
    XML
  end

  let(:normally_formatted_carrot_xml) do
    <<~XML
      <vegetable>
        <name>Carrot</name>
        <color>Orange (usually)</color>
      </vegetable>
    XML
  end

  let(:carrot_xml_in_a_different_order) do
    <<~XML
      <vegetable>
        <color>Orange (usually)</color>
        <name>Carrot</name>
      </vegetable>
    XML
  end

  let(:all_caps_carrot_xml) do
    <<~XML
      <VEGETABLE>
        <name>Carrot</name>
        <color>Orange (usually)</color>
      </VEGETABLE>
    XML
  end

  let(:tubers_xml) do
    <<~XML
      <tubers>
        <carrot/>
        <potato/>
      </tubers>
    XML
  end

  describe 'match_xml' do
    context 'when the documents are identical' do
      it 'matches' do
        expect(weirdly_formatted_carrot_xml).to match_xml(weirdly_formatted_carrot_xml)
      end
    end

    context 'when the documents are formatted differently but have the same content' do
      it 'matches' do
        expect(weirdly_formatted_carrot_xml).to match_xml(normally_formatted_carrot_xml)
      end
    end

    context 'when there is a case difference between tags' do
      let(:code_under_test) do
        -> { expect(normally_formatted_carrot_xml).to match_xml(all_caps_carrot_xml) }
      end

      it 'does not match' do
        expect(normally_formatted_carrot_xml).to_not match_xml(all_caps_carrot_xml)
      end

      it 'generates a useful diff' do
        expect(&code_under_test).to raise_error(RSpec::Expectations::ExpectationNotMetError) do |e|
          assert_error_messages_equal(e, <<~ERROR)
            Expected XML documents to be the same, but they differed:
            Diff:

            @@ -1,4 +1,4 @@
            -<VEGETABLE>
            +<vegetable>
               <name>Carrot</name>
               <color>Orange (usually)</color>
            -</VEGETABLE>
            +</vegetable>
          ERROR
        end
      end
    end

    context 'when the data is the same but ordered differently' do
      let(:code_under_test) do
        -> { expect(normally_formatted_carrot_xml).to match_xml(carrot_xml_in_a_different_order) }
      end

      # This illustrates current behavior, but is not necessarily a mandate.
      it 'does not match' do
        expect(normally_formatted_carrot_xml).not_to match_xml(carrot_xml_in_a_different_order)
      end

      it 'generates a useful diff' do
        expect(&code_under_test).to raise_error(RSpec::Expectations::ExpectationNotMetError) do |e|
          assert_error_messages_equal(e, <<~ERROR)
            Expected XML documents to be the same, but they differed:
            Diff:

            @@ -1,4 +1,4 @@
             <vegetable>
            -  <color>Orange (usually)</color>
               <name>Carrot</name>
            +  <color>Orange (usually)</color>
             </vegetable>
          ERROR
        end
      end
    end

    context 'when the documents are wholly different' do
      let(:code_under_test) do
        -> { expect(normally_formatted_carrot_xml).to match_xml(tubers_xml) }
      end

      it 'does not match' do
        expect(normally_formatted_carrot_xml).not_to match_xml(tubers_xml)
      end

      it 'generates a useful diff' do
        expect(&code_under_test).to raise_error(RSpec::Expectations::ExpectationNotMetError) do |e|
          assert_error_messages_equal(e, <<~ERROR)
            Expected XML documents to be the same, but they differed:
            Diff:
            @@ -1,4 +1,4 @@
            -<tubers>
            -  <carrot/>
            -  <potato/>
            -</tubers>
            +<vegetable>
            +  <name>Carrot</name>
            +  <color>Orange (usually)</color>
            +</vegetable>
          ERROR
        end
      end
    end
  end
end
