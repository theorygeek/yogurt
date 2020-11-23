# typed: ignore
# frozen_string_literal: true

RSpec.describe GraphQLClient::CodeGenerator::Utils do
  let(:utils) {GraphQLClient::CodeGenerator::Utils}

  describe 'underscore' do
    it "converts camel case words to underscore" do
      expect(utils.underscore("SomeName")).to eq 'some_name'
    end
  end

  describe 'indent' do
    it "properly indents strings" do
      input_string = <<-STRING
        this is
          a string
            of text
              with some nested
            text
          inside of it
      STRING
      
      indent1 = <<-STRING
          this is
            a string
              of text
                with some nested
              text
            inside of it
      STRING

      indent2 = <<-STRING
            this is
              a string
                of text
                  with some nested
                text
              inside of it
      STRING

      expect(utils.indent(input_string, 0)).to equal input_string
      expect(utils.indent(input_string, 1)).to eq indent1
      expect(utils.indent(input_string, 2)).to eq indent2
    end

    it "properly indents strings that don't end with newlines" do
      input_string = "query SomeQuery {\n  viewer {\n    login\n    createdAt\n  }\n  codesOfConduct {\n    id\n    body\n  }\n}"
      output_string = "  query SomeQuery {\n    viewer {\n      login\n      createdAt\n    }\n    codesOfConduct {\n      id\n      body\n    }\n  }"
      expect(utils.indent(input_string, 1)).to eq output_string
    end
  end
end
