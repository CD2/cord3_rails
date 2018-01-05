# frozen_string_literal: true

require 'rails_helper'
require_dependency 'support/valid_api_spec.rb'
Dir[Rails.root + './app/apis/**/*.rb'].each { |file| require_dependency file }

ApplicationApi.descendants.each { |api| RSpec.describe(api) { it_behaves_like 'a valid api' } }
