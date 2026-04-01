# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Grape route helpers bootstrap' do # rubocop:disable RSpec/DescribeClass
  include GrapeRouteHelpers::NamedRouteMatcher

  it 'provides the session helper path' do
    expect(api_v3_session_path).to eq('/api/v3/session')
  end

  it 'provides the status helper path' do
    expect(api_v3_status_path).to eq('/api/v3/status')
  end
end
