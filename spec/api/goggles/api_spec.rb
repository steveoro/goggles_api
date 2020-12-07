# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goggles::API, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher

  describe 'GET /api/v3/status' do
    context 'when the app is running ok,' do
      it 'returns the OK status message and the current version' do
        GogglesDb::AppParameter.maintenance = false
        get api_v3_status_path
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result).to be_an(Hash)
        expect(result['msg']).to eq(I18n.t('api.message.status.ok'))
        expect(result['version']).to eq(Version::FULL)
      end
    end

    context 'when the app is running on maintenance mode,' do
      it 'returns the maintenance status message and the current version' do
        GogglesDb::AppParameter.maintenance = true
        get api_v3_status_path
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result).to be_an(Hash)
        expect(result['msg']).to eq(I18n.t('api.message.status.maintenance'))
        expect(result['version']).to eq(Version::FULL)
      end
    end
  end
end
