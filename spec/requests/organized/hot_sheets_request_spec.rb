require "rails_helper"

RSpec.describe Organized::HotSheetsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/hot_sheet" }

  context "organization not enabled" do
    include_context :request_spec_logged_in_as_organization_member
    let(:current_organization) { FactoryBot.create(:organization) }
    it "redirects" do
      get base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end

  context "logged_in_as_organization_member" do
    include_context :request_spec_logged_in_as_organization_member
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }

    describe "show" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
      end
      context "current hot_sheet" do
        let!(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: current_organization) }
        it "renders" do
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
          expect(assigns(:hot_sheet)).to eq(hot_sheet)
          expect(assigns(:today)).to be_truthy
        end
      end
    end

    describe "edit" do
      it "redirects to the organization root path" do
        get "#{base_url}/edit"
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin

    describe "show" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
      end
    end

    describe "edit" do
      it "renders" do
        get "#{base_url}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template("edit")
      end
      context "with configuration" do
        let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_enabled: true) }
        it "renders" do
          get "#{base_url}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template("edit")
        end
      end
    end

    describe "update" do
      it "enables the features we expect" do
        expect(current_organization.hot_sheet_configuration).to be_blank
        expect do
          put base_url, params: {
                          hot_sheet_configuration: {
                            is_enabled: true,
                          },
                        }
        end.to change(HotSheetConfiguration, :count).by 1
        current_organization.reload
        expect(current_organization.hot_sheet_configuration).to be_present
        expect(current_organization.hot_sheet_configuration.enabled?).to be_truthy
      end
      context "already enabled" do
        let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_enabled: true) }
        it "updates" do
          expect do
            put base_url, params: {
                            hot_sheet_configuration: {
                              is_enabled: false,
                            },
                          }
          end.to_not change(HotSheetConfiguration, :count)
          current_organization.reload
          expect(current_organization.hot_sheet_configuration).to be_present
          expect(current_organization.hot_sheet_configuration.enabled?).to be_falsey
        end
      end
    end
  end
end
