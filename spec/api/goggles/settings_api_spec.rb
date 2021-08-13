# frozen_string_literal: true

require 'rails_helper'
require 'support/api_session_helpers'
require 'support/shared_api_response_behaviors'

RSpec.describe Goggles::SettingsAPI, type: :request do
  include GrapeRouteHelpers::NamedRouteMatcher
  include APISessionHelpers

  # Admin:
  let(:admin_user)  { FactoryBot.create(:user) }
  let(:admin_grant) { FactoryBot.create(:admin_grant, user: admin_user, entity: nil) }
  let(:admin_headers) { { 'Authorization' => "Bearer #{jwt_for_api_session(admin_user)}" } }
  # CRUD user (must result as unauthorized):
  let(:crud_user)       { FactoryBot.create(:user) }
  let(:crud_grant)      { FactoryBot.create(:admin_grant, user: crud_user, entity: 'APIDailyUse') }
  let(:crud_headers)    { { 'Authorization' => "Bearer #{jwt_for_api_session(crud_user)}" } }
  # Standard user (no grants whatsoever):
  let(:api_user)    { FactoryBot.create(:user) }
  let(:jwt_token)   { jwt_for_api_session(api_user) }
  let(:fixture_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  # Enforce domain context creation
  before(:each) do
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

  describe 'GET /api/v3/setting/:group_key' do
    (GogglesDb::AppParameter::SETTINGS_GROUPS + [:prefs]).each do |group_key|
      context "when using valid parameters (group: '#{group_key}')," do
        context 'with an account having ADMIN grants,' do
          let(:fixture_row) do
            cfg_row = group_key.to_sym == :prefs ? admin_user : GogglesDb::AppParameter.config
            cfg_row.settings(group_key.to_sym).value
          end
          before(:each) { get(api_v3_setting_path(group_key: group_key), headers: admin_headers) }
          it_behaves_like('a successful JSON row response')
        end
        context 'with an account having just CRUD grants,' do
          before(:each) { get(api_v3_setting_path(group_key: group_key), headers: crud_headers) }
          it_behaves_like('a failed auth attempt due to unauthorized credentials')
        end
        context 'with an account not having any grants,' do
          before(:each) { get(api_v3_setting_path(group_key: group_key), headers: fixture_headers) }
          it_behaves_like('a failed auth attempt due to unauthorized credentials')
        end
      end

      context 'when using valid parameters but during Maintenance mode,' do
        context 'with an account having ADMIN grants,' do
          let(:fixture_row) do
            cfg_row = group_key.to_sym == :prefs ? admin_user : GogglesDb::AppParameter.config
            cfg_row.settings(group_key.to_sym).value
          end
          before(:each) do
            GogglesDb::AppParameter.maintenance = true
            get(api_v3_setting_path(group_key: group_key), headers: admin_headers)
            GogglesDb::AppParameter.maintenance = false
          end
          it_behaves_like('a successful JSON row response')
        end
        context 'with an account having lesser grants,' do
          before(:each) do
            GogglesDb::AppParameter.maintenance = true
            get(api_v3_setting_path(group_key: group_key), headers: crud_headers)
            GogglesDb::AppParameter.maintenance = false
          end
          it_behaves_like('a request refused during Maintenance (except for admins)')
        end
      end

      context 'when using an invalid JWT,' do
        before(:each) { get(api_v3_setting_path(group_key: group_key), headers: { 'Authorization' => 'you wish!' }) }
        it_behaves_like('a failed auth attempt due to invalid JWT')
      end
    end

    context 'when requesting a non-existing group key,' do
      before(:each) { get(api_v3_setting_path(group_key: 'NON-existing'), headers: admin_headers) }
      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with the maintenance error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_setting_group_key'))
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'PUT /api/v3/setting/:id' do
    let(:expected_changes) do
      [ # group_key => hash of params for the update call
        { framework_urls: { key: 'main', value: '0.0.0.0:1234' } },
        { framework_emails: { key: 'contact', value: admin_user.email } },
        { prefs: { key: 'hide_search_help', value: true } }
      ].sample
    end
    let(:group_key) { expected_changes.keys.first }
    let(:params) { expected_changes.values.first }
    before(:each) do
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        let(:fixture_row) do
          cfg_row = group_key.to_sym == :prefs ? admin_user : GogglesDb::AppParameter.config
          cfg_row.settings(group_key.to_sym).value
        end
        before(:each) { put(api_v3_setting_path(group_key: group_key), params: params, headers: admin_headers) }
        it_behaves_like('a successful request that has positive usage stats')
        it 'returns true' do
          expect(response.body).to eq('true')
        end
        it 'updates the setting value' do
          expect(fixture_row[params[:key]]).to eq(params[:value].to_s)
        end
      end
      context 'with an account having just CRUD grants,' do
        before(:each) { put(api_v3_setting_path(group_key: group_key), params: params, headers: crud_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
      context 'with an account not having any grants,' do
        before(:each) { put(api_v3_setting_path(group_key: group_key), params: params, headers: fixture_headers) }
        it_behaves_like('a failed auth attempt due to unauthorized credentials')
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      let(:fixture_row) do
        cfg_row = group_key.to_sym == :prefs ? admin_user : GogglesDb::AppParameter.config
        cfg_row.settings(group_key.to_sym).value
      end
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_setting_path(group_key: group_key), params: params, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a successful request that has positive usage stats')
        it 'returns true' do
          expect(response.body).to eq('true')
        end
        it 'updates the setting value' do
          expect(fixture_row[params[:key]]).to eq(params[:value].to_s)
        end
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          put(api_v3_setting_path(group_key: group_key), params: params, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) { put(api_v3_setting_path(group_key: group_key), params: params, headers: { 'Authorization' => 'you wish!' }) }
      it_behaves_like 'a failed auth attempt due to invalid JWT'
    end
    context 'when requesting a non-existing group key,' do
      before(:each) { put(api_v3_setting_path(group_key: 'NON-existing'), params: params, headers: admin_headers) }
      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with the maintenance error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_setting_group_key'))
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++

  describe 'DELETE /api/v3/setting/:id' do
    let(:expected_changes) do
      [ # group_key => { key: key name }
        { framework_emails: { key: 'contact' } },
        { framework_urls: { key: 'chrono' } },
        { social_urls: { key: 'linkedin' } },
        { prefs: { key: 'hide_search_help' } }
      ].sample
    end
    let(:group_key) { expected_changes.keys.first }
    let(:key) { expected_changes.values.first[:key] }
    before(:each) do
      expect(expected_changes).to be_an(Hash).and be_present
    end

    context 'when using valid parameters,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          delete(api_v3_setting_path(group_key: group_key), params: { key: key }, headers: admin_headers)
        end
        it_behaves_like('a successful request that has positive usage stats')
        it 'returns true' do
          expect(response.body).to eq('true')
        end
        it 'clears the specified setting' do
          cfg_row = if group_key == :prefs
                      GogglesDb::User.includes(:setting_objects).find(admin_user.id)
                    else
                      GogglesDb::AppParameter.config
                    end
          expect(cfg_row.settings(group_key).send(key)).to be nil
        end
      end
      context 'with an account having just CRUD grants,' do
        before(:each) do
          delete(api_v3_setting_path(group_key: group_key), params: { key: key }, headers: crud_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
      context 'with an account not having any grants,' do
        before(:each) do
          delete(api_v3_setting_path(group_key: group_key), params: { key: key }, headers: fixture_headers)
        end
        it_behaves_like 'a failed auth attempt due to unauthorized credentials'
      end
    end

    context 'when using valid parameters but during Maintenance mode,' do
      context 'with an account having ADMIN grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_setting_path(group_key: group_key), params: { key: key }, headers: admin_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a successful request that has positive usage stats')
        it 'returns true' do
          expect(response.body).to eq('true')
        end
        it 'clears the specified setting' do
          cfg_row = if group_key == :prefs
                      GogglesDb::User.includes(:setting_objects).find(admin_user.id)
                    else
                      GogglesDb::AppParameter.config
                    end
          expect(cfg_row.settings(group_key).send(key)).to be nil
        end
      end
      context 'with an account having lesser grants,' do
        before(:each) do
          GogglesDb::AppParameter.maintenance = true
          delete(api_v3_setting_path(group_key: group_key), params: { key: key }, headers: crud_headers)
          GogglesDb::AppParameter.maintenance = false
        end
        it_behaves_like('a request refused during Maintenance (except for admins)')
      end
    end

    context 'when using an invalid JWT,' do
      before(:each) do
        delete(
          api_v3_setting_path(group_key: group_key),
          params: { key: key },
          headers: { 'Authorization' => 'you wish!' }
        )
      end
      it_behaves_like('a failed auth attempt due to invalid JWT')
    end
    context 'when requesting a non-existing group key,' do
      before(:each) do
        delete(api_v3_setting_path(group_key: 'NON-existing'), params: { key: 'dummy' }, headers: admin_headers)
      end
      it 'is NOT successful' do
        expect(response).not_to be_successful
      end
      it 'responds with the maintenance error message' do
        result = JSON.parse(response.body)
        expect(result).to have_key('error')
        expect(result['error']).to eq(I18n.t('api.message.invalid_setting_group_key'))
      end
    end
  end
  #-- -------------------------------------------------------------------------
  #++
end
