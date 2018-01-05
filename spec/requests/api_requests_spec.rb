# frozen_string_literal: true

require 'rails_helper'
require_dependency 'spec_helper'

RSpec.describe 'Cord::ApiBaseController' do
  def send_request body = []
    @body = nil
    post '/cord/', params: { _json: Array.wrap(body) }
  end

  def response_body
    @body ||= JSON.parse(response.body).map &:with_indifferent_access
  end

  describe 'uses strict matching to find the requested api' do
    before(:all) do
      class Example < ApplicationRecord
        def self.column_names
          []
        end
      end
      class ExampleApi < ApplicationApi; end
      class ExamplesApi < ApplicationApi; end
    end

    after(:all) do
      Object.send(:remove_const, :Example)
      Object.send(:remove_const, :ExampleApi)
      Object.send(:remove_const, :ExamplesApi)
    end

    it 'does not pluralize the input' do
      expect(ExampleApi).to receive :new
      expect(ExamplesApi).not_to receive :new
      send_request api: 'example'
    end

    it 'does not singularize the input' do
      expect(ExamplesApi).to receive :new
      expect(ExampleApi).not_to receive :new
      send_request api: 'examples'
    end
  end
end
