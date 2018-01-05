# frozen_string_literal: true

require 'rails_helper'
require_dependency 'spec_helper'

RSpec.describe 'api requests' do
  def response_body
    return @body if @body
    @body = JSON.parse(response.body).with_indifferent_access
  end
end
