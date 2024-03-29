# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::UsersAPI do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  let(:fixture_row) { FactoryBot.create(:user) }
  # Admin:
  let(:admin_user)    { FactoryBot.create(:user) }
  let(:admin_grant)   { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)    { FactoryBot.create(:user) }
  let(:crud_grant)   { FactoryBot.create(:admin_grant, user: crud_user, entity: 'User') }
  let(:crud_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)  { FactoryBot.create(:user) }
  let(:jwt_token) { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before do
    expect(fixture_row).to be_a(GogglesDb::User).and be_valid
    expect(admin_user).to be_a(GogglesDb::User).and be_valid
    expect(admin_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(admin_headers).to be_an(Hash).and have_key('Authorization')
    expect(crud_user).to be_a(GogglesDb::User).and be_valid
    expect(crud_grant).to be_a(GogglesDb::AdminGrant).and be_valid
    expect(crud_headers).to be_an(Hash).and have_key('Authorization')
    expect(api_user).to be_a(GogglesDb::User).and be_valid
    expect(jwt_token).to be_a(String).and be_present
    expect(fixture_headers).to be_an(Hash).and have_key('Authorization')
  end

  describe 'GET /api/v3/user/:id' do
    context 'when using valid credentials' do
      # Same user, maintenance off
      context 'and the user gets her details,' do
        before { get(api_v3_user_path(id: api_user.id), headers: fixture_headers) }

        it_behaves_like('a successful request that has positive usage stats')
        it 'returns the selected row as JSON' do
          expect(response.body).to eq(api_user.to_json)
        end
      end

      # Same user, maintenance on
      context 'and the user tries to get her details but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_path(id: api_user.id), headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      # Different user, maintenance off
      context 'and the user tries to get other users\' details,' do
        before { get(api_v3_user_path(id: fixture_row.id), headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      # CRUD user, maintenance off
      context 'with CRUD grants and the user tries to get other users\' details,' do
        before { get(api_v3_user_path(id: fixture_row.id), headers: crud_headers) }

        it_behaves_like('a successful JSON row response')
      end

      # CRUD user, maintenance on
      context 'with CRUD grants and the user tries to get other users\' details but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_user_path(id: fixture_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_user_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'with CRUD grants but requesting a non-existing ID,' do
      before { get(api_v3_user_path(id: -1), headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/user/:id' do
    let(:new_user_values) { FactoryBot.build(:user) }
    let(:new_swimmer) { FactoryBot.create(:swimmer) }
    let(:expected_changes) do
      [
        { name: new_user_values.name },
        { first_name: new_user_values.first_name, last_name: new_user_values.last_name },
        { description: new_user_values.description },
        { year_of_birth: new_user_values.year_of_birth },
        { locked: true },
        { active: false },
        { swimmer_id: new_swimmer.id }
      ].sample
    end

    before do
      expect(new_swimmer).to be_a(GogglesDb::Swimmer).and be_valid
      expect(new_user_values).to be_a(GogglesDb::User)
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid credentials' do
      # Same user, maintenance off
      context 'and the user edits her details,' do
        before { put(api_v3_user_path(id: api_user.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a successful request that has positive usage stats')
        it 'returns true' do
          expect(response.body).to eq('true')
        end

        it 'updates the row' do
          updated_row = api_user.reload
          expected_changes.each do |key, value|
            if key == :locked # user#locked => locked_at.present?
              expect(updated_row.locked_at.present?).to eq(value)
            else
              expect(updated_row.send(key)).to eq(value)
            end
          end
        end
      end

      # Same user, maintenance on
      context 'and the user tries to edit her details but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_path(id: api_user.id), params: expected_changes, headers: fixture_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      # Different user, maintenance off
      context 'and the user tries to edit other users\' details,' do
        before { put(api_v3_user_path(id: fixture_row.id), params: expected_changes, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      # CRUD user, maintenance off
      context 'with CRUD grants and the user tries to edit other users\' details,' do
        before { put(api_v3_user_path(id: fixture_row.id), params: expected_changes, headers: crud_headers) }

        it_behaves_like('a successful JSON PUT response')
      end

      # CRUD user, maintenance on
      context 'with CRUD grants and the user tries to get other users\' details but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_user_path(id: fixture_row.id), params: expected_changes, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { put(api_v3_user_path(id: fixture_row.id), params: expected_changes, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'with CRUD grants but requesting a non-existing ID,' do
      before { put(api_v3_user_path(id: -1), params: expected_changes, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/user/:id' do
    let(:deletable_row) { FactoryBot.create(:user) }

    before { expect(deletable_row).to be_a(GogglesDb::User).and be_valid }

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before { delete(api_v3_user_path(id: deletable_row.id), headers: admin_headers) }

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having just CRUD grants,' do
        before { delete(api_v3_user_path(id: deletable_row.id), headers: crud_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end

      context 'with an account not having any grants,' do
        before { delete(api_v3_user_path(id: deletable_row.id), headers: fixture_headers) }

        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_path(id: deletable_row.id), headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a successful JSON DELETE response')
      end

      context 'with an account having lesser grants,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_user_path(id: deletable_row.id), headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before { delete(api_v3_user_path(id: fixture_row.id), headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'when requesting a *required* ID,' do
      before { delete(api_v3_user_path(id: [1, 2, 3, 4].sample), headers: admin_headers) }

      it 'is NOT successful' do
        expect(response).not_to be_successful
      end

      it 'responds with a generic error message and its details in the header' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_parameter'))
        expect(response.headers).to have_key('X-Error-Detail')
        expect(response.headers['X-Error-Detail']).to be_present
      end
    end

    context 'when requesting a non-existing ID,' do
      before { delete(api_v3_user_path(id: -1), headers: admin_headers) }

      it_behaves_like('a successful response with an empty body')
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'GET /api/v3/users/' do
    context 'when using a valid authentication' do
      # [Steve A.] Note: if we don't select at least the 3 field below, user.associate_to_swimmer! will make the select fail
      let(:rand_fixture) { GogglesDb::User.limit(100).sample }
      let(:fixture_first_name) { rand_fixture.first_name }
      let(:fixture_last_name)  { rand_fixture.last_name }
      # Choose among the many existing rows in the seed w/ more than 25 rows per domain => pagination guaranteed)
      let(:fixture_email)    { '@fake.example.' }
      let(:default_per_page) { 25 }

      # Make sure the Domain contains the expected seeds:
      before do
        expect(fixture_first_name).to be_present
        expect(fixture_last_name).to be_present
        expect(fixture_email).to be_present
        expect(GogglesDb::User.where('first_name LIKE ?', "%#{fixture_first_name}%").count).to be_positive
        expect(GogglesDb::User.where('email LIKE ?', "%#{fixture_email}%").count).to be_positive.and be > 25
      end

      context 'with an account having CRUD grants,' do
        before { get(api_v3_users_path, headers: crud_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      context 'with an account not having the proper grants,' do
        before { get(api_v3_users_path, headers: fixture_headers) }

        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end

      context 'and CRUD grants but during Maintenance mode,' do
        before do
          GogglesDb::AppParameter.maintenance = true
          get(api_v3_users_path, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end

        it_behaves_like('a request refused during Maintenance (except for admins)')
      end

      context 'CRUD grants and filtering by a specific first_name,' do
        before { get(api_v3_users_path, params: { first_name: fixture_first_name }, headers: crud_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::User.where('first_name LIKE ?', "%#{fixture_first_name}%").count
          expect(result_array.count).to eq([full_count, default_per_page].min)
        end
        # (We can't really assert pagination links here)
      end

      context 'CRUD grants and filtering by a specific last_name,' do
        before { get(api_v3_users_path, params: { last_name: fixture_last_name }, headers: crud_headers) }

        it_behaves_like('a successful request that has positive usage stats')

        it 'returns a JSON array of associated, filtered rows' do
          result_array = JSON.parse(response.body)
          expect(result_array).to be_an(Array)
          full_count = GogglesDb::User.where('last_name LIKE ?', "%#{fixture_last_name}%").count
          expect(result_array.count).to eq([full_count, default_per_page].min)
        end
        # (We can't really assert pagination links here)
      end

      context 'CRUD grants and filtering by a portion of an email address,' do
        before { get(api_v3_users_path, params: { email: fixture_email }, headers: crud_headers) }

        it_behaves_like('successful response with pagination links & values in headers')
      end

      # This will result in a single row without pagination, always:
      context 'when filtering with a specific email address,' do
        before { get(api_v3_users_path, params: { email: fixture_row.email }, headers: crud_headers) }

        it 'returns a JSON array containing the single associated row' do
          expect(response.body).to eq([fixture_row].map(&:to_hash).to_json)
        end

        it_behaves_like('successful single response without pagination links in headers')
      end
    end

    context 'when using an invalid JWT,' do
      before { get(api_v3_users_path, headers: { 'Authorization' => 'you wish!' }) }

      it_behaves_like('a failed auth attempt due to invalid JWT')
    end

    context 'CRUD grants and filtering by a non-existing value,' do
      before { get(api_v3_users_path, params: { name: 'NOT-A-NAME' }, headers: crud_headers) }

      it_behaves_like('an empty but successful JSON list response')
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
