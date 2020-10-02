# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'

RSpec.describe Goggles::BadgesAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_badge) { FactoryBot.create(:badge) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_badge).to be_a(GogglesDb::Badge).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/badge/:id' do
    context 'when using valid parameters,' do
      before(:each) do
        get api_v3_badge_path(id: fixture_badge.id), headers: fixture_headers
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_badge.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get api_v3_badge_path(id: fixture_badge.id), headers: { 'Authorization' => 'you wish!' }
      end
      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.unauthorized'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to eq(I18n.t('api.message.jwt.invalid'))
      end
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        get api_v3_badge_path(id: -1), headers: fixture_headers
      end
      it 'is successful anyway' do
        expect(response).to be_successful
      end
      it 'returns a nil JSON body' do
        expect(JSON.parse(response.body)).to be nil
      end
    end
  end

  describe 'PUT /api/v3/badge/:id' do
    context 'when using valid parameters,' do
      let(:expected_changes) do
        [
          { number: 'TEST_CODE' },
          { number: 'TEST_CODE', entry_time_type_id: GogglesDb::EntryTimeType.send(%w[manual personal gogglecup prec_year last_race].sample).id },
          { number: 'TEST_CODE', has_to_pay_fees: true },
          { number: 'TEST_CODE', has_to_pay_relays: true, has_to_pay_badge: [false, true].sample }
        ].sample
      end
      before(:each) do
        put(
          api_v3_badge_path(id: fixture_badge.id),
          params: expected_changes,
          headers: fixture_headers
        )
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'updates the row and returns true' do
        expect(response.body).to eq('true')
        updated_row = fixture_badge.reload
        expected_changes.each do |key, _value|
          expect(updated_row.send(key)).to eq(expected_changes[key])
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_badge_path(id: fixture_badge.id),
          params: { number: 'TEST_CODE' },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.unauthorized'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to eq(I18n.t('api.message.jwt.invalid'))
      end
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_badge_path(id: -1),
          params: { number: 'TEST_CODE' },
          headers: fixture_headers
        )
      end
      it 'is successful anyway' do
        expect(response).to be_successful
      end
      it 'returns a nil JSON body' do
        expect(JSON.parse(response.body)).to be nil
      end
    end
  end
end
