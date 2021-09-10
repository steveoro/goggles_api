# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::LookupAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  before do
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/lookup/:entity_name' do
    context 'when using a valid authentication' do
      # Let's test just the most common Lookup entity values:
      %w[
        gender_types heat_types stroke_types timing_types
      ].each do |entity_name|
        [nil, 'it', 'en'].each do |locale|
          context "for #{entity_name} using a #{locale} locale," do
            let(:expected_row_count) { "GogglesDb::#{entity_name.singularize.camelize}".constantize.count }

            before do
              get(api_v3_lookup_path(entity_name: entity_name), params: { locale: locale }, headers: fixture_headers)
            end

            it_behaves_like('a successful request that has positive usage stats')

            it 'returns a non-empty list of JSON rows' do
              result_array = JSON.parse(response.body)
              expect(result_array).to be_an(Array)
              expect(result_array.count).to eq(expected_row_count).and be_positive
            end

            it 'does not contain the pagination values or links in the response headers' do
              expect(response.headers['Page']).to be nil
              expect(response.headers['Link']).to be nil
              expect(response.headers['Per-Page']).to be nil
              expect(response.headers['Total']).to be nil
            end
          end
        end
      end
    end

    context 'when using a valid authentication and filtering by a partial value,' do
      %w[
        event_types
      ].each do |entity_name|
        context "for #{entity_name}," do
          before do
            get(api_v3_lookup_path(entity_name: entity_name), params: { name: 'rana', locale: 'it' }, headers: fixture_headers)
          end

          it_behaves_like('a successful request that has positive usage stats')

          it 'returns a non-empty list of JSON rows' do
            result_array = JSON.parse(response.body)
            expect(result_array).to be_an(Array)
            expect(result_array.count).to be_positive
          end
        end
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_lookup_path(entity_name: 'gender_types'), params: { locale: 'it' }, headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_lookup_path(entity_name: 'gender_types'), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when using an invalid entity name,' do
      before { get(api_v3_lookup_path(entity_name: 'non_existing_table_rows'), headers: fixture_headers) }

      it_behaves_like 'an empty but successful JSON list response'
    end
  end
end
