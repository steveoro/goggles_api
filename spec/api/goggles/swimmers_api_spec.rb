# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SwimmersAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:api_user) { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_row) { FactoryBot.create(:swimmer) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }
  let(:crud_user) { FactoryBot.create(:user) }
  let(:crud_grant) { FactoryBot.create(:admin_grant, user: crud_user, entity: 'Swimmer') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }

  # Enforce domain context creation
  before do
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    expect(fixture_row).to be_a(GogglesDb::Swimmer).and be_valid
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
  end

  describe 'GET /api/v3/swimmer/:id' do
    context 'when using valid parameters,' do
      before { get(api_v3_swimmer_path(id: fixture_row.id), headers: fixture_headers) }

      it_behaves_like('a successful JSON row response')
    end

    context 'when using valid parameters but during Maintenance mode,' do
      before do
        GogglesDb::AppParameter.maintenance = true
        get(api_v3_swimmer_path(id: fixture_row.id), headers: fixture_headers)
        GogglesDb::AppParameter.maintenance = false
      end

      it_behaves_like('a request refused during Maintenance (except for admins)')
    end

    context 'when using an invalid JWT,' do
      before { get api_v3_swimmer_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' } }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { get api_v3_swimmer_path(id: -1), headers: fixture_headers }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/swimmer/:id' do
    let(:associated_user) { FactoryBot.create(:user) }
    let(:expected_changes) do
      [
        { gender_type_id: GogglesDb::GenderType.send(%w[male female].sample).id },
        { nickname: fixture_row.first_name.downcase },
        { associated_user_id: associated_user.id },
        { complete_name: FFaker::Name.name },
        { first_name: FFaker::Name.first_name, last_name: FFaker::Name.last_name, complete_name: "#{FFaker::Name.first_name} #{FFaker::Name.last_name}" },
        { year_of_birth: (1960..2000).to_a.sample, year_guessed: false }
      ].sample
    end

    before do
      expect(associated_user).to be_a(GogglesDb::User).and be_valid
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters' do
      context 'with an account having CRUD grants,' do
        before { put(api_v3_swimmer_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      context 'when using valid parameters but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_swimmer_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'with an account not having the proper grants,' do
        before { put(api_v3_swimmer_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_swimmer_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a non-existing ID,' do
      before { put(api_v3_swimmer_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'POST /api/v3/swimmer' do
    let(:built_row) { FactoryBot.build(:swimmer) }
    let(:admin_user)  { FactoryBot.create(:user) }
    let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
    let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }

    before do
      expect(admin_user).to be_a(GogglesDb::User).and be_valid
      expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
      expect(admin_headers).to be_an(Hash).and have_key('Authorization')
      expect(built_row).to be_a(GogglesDb::Swimmer).and be_valid
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { post(api_v3_swimmer_path, params: built_row.attributes, headers: admin_headers) }

        it_behaves_like('a successful JSON POST response')
      end

      context 'with an account having just CRUD grants,' do
        before { post(api_v3_swimmer_path, params: built_row.attributes, headers: crud_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'with an account not having any grants,' do
        before { post(api_v3_swimmer_path, params: built_row.attributes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using an invalid JWT,' do
      before { post(api_v3_swimmer_path, params: built_row.attributes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when using invalid parameters,' do
      before { post(api_v3_swimmer_path, params: built_row.attributes.merge(complete_name: nil), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.creation_failure'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
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
      before do
        expect(fixture_gender_type_id).to be_positive
        expect(fixture_first_name).to be_present
      end

      context 'without any filters,' do
        before { get(api_v3_swimmers_path, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_swimmers_path, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'when filtering by a specific last_name,' do
        before { get(api_v3_swimmers_path, params: { first_name: fixture_first_name }, headers: fixture_headers) }

        let(:expected_row_count) { GogglesDb::Swimmer.where('first_name LIKE ?', "%#{fixture_first_name}%").count }

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by name (generic search),' do
        before { get(api_v3_swimmers_path, params: { name: fixture_first_name }, headers: fixture_headers) }

        let(:expected_row_count) { GogglesDb::Swimmer.for_name(fixture_first_name).count }

        it_behaves_like('successful multiple row response either with OR without pagination links')
      end

      context 'when filtering by a specific gender_type_id,' do
        before { get(api_v3_swimmers_path, params: { gender_type_id: fixture_gender_type_id }, headers: fixture_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      # Uses random fixtures to have a quick 1-row result (no pagination, always):
      context 'when filtering by a specific complete_name of a random single fixture,' do
        before do
          get(
            api_v3_swimmers_path,
            params: { complete_name: fixture_row.complete_name, year_of_birth: fixture_row.year_of_birth },
            headers: fixture_headers
          )
        end

        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_row].to_json)
        end

        it_behaves_like('successful single response without pagination links in headers')
      end

      context 'when enabling custom Select2 output,' do
        let(:fixture_last_name) { %w[John White Rowe Smith].sample }
        let(:expected_row_count) { GogglesDb::Swimmer.where('last_name LIKE ?', "%#{fixture_last_name}%").limit(100).count }

        before { get(api_v3_swimmers_path, params: { last_name: fixture_last_name, select2_format: true }, headers: fixture_headers) }

        it_behaves_like('successful response in Select2 bespoke format')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_swimmers_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when filtering by a non-existing value,' do
      before { get(api_v3_swimmers_path, params: { gender_type_id: -1 }, headers: fixture_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
