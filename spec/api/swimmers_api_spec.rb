# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SwimmersAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_swimmer) { FactoryBot.create(:swimmer) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
    expect(fixture_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/swimmer/:id' do
    context 'when using valid parameters,' do
      before(:each) do
        get api_v3_swimmer_path(id: fixture_swimmer.id), headers: fixture_headers
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_swimmer.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get api_v3_swimmer_path(id: fixture_swimmer.id), headers: { 'Authorization' => 'you wish!' }
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        get api_v3_swimmer_path(id: -1), headers: fixture_headers
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/swimmer/:id' do
    context 'when using valid parameters,' do
      let(:associated_user) { FactoryBot.create(:user) }
      let(:expected_changes) do
        [
          { gender_type_id: GogglesDb::GenderType.send(%w[male female].sample).id },
          { nickname: fixture_swimmer.first_name.downcase },
          { associated_user_id: associated_user.id },
          { complete_name: FFaker::Name.name },
          { first_name: FFaker::Name.first_name, last_name: FFaker::Name.last_name, complete_name: "#{FFaker::Name.first_name} #{FFaker::Name.last_name}" },
          { year_of_birth: (1960..2000).to_a.sample, is_year_guessed: false }
        ].sample
      end
      before(:each) do
        expect(associated_user).to be_a(GogglesDb::User).and be_valid
        put(
          api_v3_swimmer_path(id: fixture_swimmer.id),
          params: expected_changes,
          headers: fixture_headers
        )
      end
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'updates the row and returns true' do
        expect(response.body).to eq('true')
        updated_row = fixture_swimmer.reload
        expected_changes.each do |key, _value|
          expect(updated_row.send(key)).to eq(expected_changes[key])
        end
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        put(
          api_v3_swimmer_path(id: fixture_swimmer.id),
          params: { gender_type_id: 1 },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) do
        put(
          api_v3_swimmer_path(id: -1),
          params: { gender_type_id: 1 },
          headers: fixture_headers
        )
      end
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/swimmers/' do
    context 'when using a valid authentication' do
      let(:fixture_gender_type_id) { GogglesDb::GenderType.send(%w[male female].sample).id }
      let(:fixture_first_name)     { %w[Barbara Luca Marco Maria Paola Paolo Stefania Stefano].sample } # Choose among some pretty common names in the seed)
      let(:default_per_page)       { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_gender_type_id).to be_positive
        expect(fixture_first_name).to be_present
      end

      context 'without any filters,' do
        before(:each) do
          get(api_v3_swimmers_path, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          expect(result_array.count).to eq(default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific last_name,' do
        before(:each) do
          get(api_v3_swimmers_path, params: { first_name: fixture_first_name }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a paginated array of JSON rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::Swimmer.where(first_name: fixture_first_name).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      context 'filtering by a specific gender_type_id,' do
        before(:each) do
          get(api_v3_swimmers_path, params: { gender_type_id: fixture_gender_type_id }, headers: fixture_headers)
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns an array of JSON rows (when the result list has more than per_page rows)' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::Swimmer.where(gender_type_id: fixture_gender_type_id).count
          expect(result_array.count).to eq(full_count <= default_per_page ? full_count : default_per_page)
        end
        it_behaves_like 'response with pagination links & values in headers'
      end

      # Uses random fixtures, to have a quick 1-row result (no pagination, always):
      context 'filtering by a specific complete_name of a random single fixture,' do
        before(:each) do
          get(
            api_v3_swimmers_path,
            params: { complete_name: fixture_swimmer.complete_name, year_of_birth: fixture_swimmer.year_of_birth },
            headers: fixture_headers
          )
        end

        it 'is successful' do
          expect(response).to be_successful
        end
        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_swimmer].to_json)
        end
        it_behaves_like 'single response without pagination links in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        get(api_v3_swimmers_path, headers: { 'Authorization' => 'you wish!' })
      end
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) do
        get(api_v3_swimmers_path, params: { gender_type_id: -1 }, headers: fixture_headers)
      end
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
