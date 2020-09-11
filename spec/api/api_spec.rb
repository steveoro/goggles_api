# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goggles::API, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher

  context 'GET /api/v3/status' do
    it 'returns the status message and the current version' do
      get api_v3_status_path
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result).to be_an(Hash)
      expect(result['msg']).to eq(I18n.t('api.message.status.ok'))
      expect(result['version']).to eq(Version::FULL)
    end
  end
end
