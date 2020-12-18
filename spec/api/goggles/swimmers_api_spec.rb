# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SwimmersAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include ApiSessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
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
      before(:each) { get api_v3_swimmer_path(id: fixture_swimmer.id), headers: fixture_headers }
      it 'is successful' do
        expect(response).to be_successful
      end
      it 'returns the selected user as JSON' do
        expect(response.body).to eq(fixture_swimmer.to_json)
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get api_v3_swimmer_path(id: fixture_swimmer.id), headers: { 'Authorization' => 'you wish!' } }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when requesting a non-existing ID,' do
      before(:each) { get api_v3_swimmer_path(id: -1), headers: fixture_headers }
      it_behaves_like 'an empty but successful JSON response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/swimmer/:id' do
    let(:crud_user) { FactoryBot.create(:user) }
    let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Swimmer') }
    let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
    before(:each) do
      expect(crud_user).to be_a(GogglesDb::User).and be_valid
      expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    end

    context 'when using valid parameters' do
      let(:associated_user) { FactoryBot.create(:user) }
      let(:expected_changes) do
        [
          { gender_type_id: GogglesDb::GenderType.send(%w[male female].sample).id },
          { nickname: fixture_swimmer.first_name.downcase },
          { associated_user_id: associated_user.id },
          { complete_name: FFaker::Name.name },
          { first_name: FFaker::Name.first_name, last_name: FFaker::Name.last_name, complete_name: "#{FFaker::Name.first_name} #{FFaker::Name.last_name}" },
          { year_of_birth: (1960..2000).to_a.sample, year_guessed: false }
        ].sample
      end
      before(:each) do
        expect(associated_user).to be_a(GogglesDb::User).and be_valid
      end

      context 'with an account having CRUD grants,' do
        before(:each) do
          put(api_v3_swimmer_path(id: fixture_swimmer.id), params: expected_changes, headers: crud_headers)
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

      context 'with an account not having the proper grants,' do
        before(:each) do
          put(api_v3_swimmer_path(id: fixture_swimmer.id), params: expected_changes, headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
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
          headers: crud_headers
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
      let(:fixture_first_name) do
        %w[Aisha Carrol Chris Christoper Cordell Elvira Elisha Estelle Gilberto
           Jarrod Jenna Kam Lita Mamie Merissa Noel Olympia Patsy].sample
      end
      let(:default_per_page) { 25 }

      # Make sure the Domain contains the expected seeds:
      before(:each) do
        expect(fixture_gender_type_id).to be_positive
        expect(fixture_first_name).to be_present
      end

      context 'without any filters,' do
        before(:each) { get(api_v3_swimmers_path, headers: fixture_headers) }
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      context 'when filtering by a specific last_name,' do
        before(:each) { get(api_v3_swimmers_path, params: { first_name: fixture_first_name }, headers: fixture_headers) }
        let(:expected_row_count) { GogglesDb::Swimmer.where('first_name LIKE ?', "%#{fixture_first_name}%").count }
        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end

      context 'when filtering by name (generic search),' do
        before(:each) { get(api_v3_swimmers_path, params: { name: fixture_first_name }, headers: fixture_headers) }
        let(:expected_row_count) { GogglesDb::Swimmer.for_name(fixture_first_name).count }
        it_behaves_like 'successful multiple row response either with OR without pagination links'
      end

      context 'when filtering by a specific gender_type_id,' do
        before(:each) { get(api_v3_swimmers_path, params: { gender_type_id: fixture_gender_type_id }, headers: fixture_headers) }
        it_behaves_like 'successful response with pagination links & values in headers'
      end

      # Uses random fixtures to have a quick 1-row result (no pagination, always):
      context 'when filtering by a specific complete_name of a random single fixture,' do
        before(:each) do
          get(
            api_v3_swimmers_path,
            params: { complete_name: fixture_swimmer.complete_name, year_of_birth: fixture_swimmer.year_of_birth },
            headers: fixture_headers
          )
        end

        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_swimmer].to_json)
        end
        it_behaves_like 'successful single response without pagination links in headers'
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { get(api_v3_swimmers_path, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end

    context 'when filtering by a non-existing value,' do
      before(:each) { get(api_v3_swimmers_path, params: { gender_type_id: -1 }, headers: fixture_headers) }
      it_behaves_like 'an empty but successful JSON list response'
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
