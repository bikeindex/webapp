require "spec_helper"

describe Organized::AmbassadorDashboardController, type: :controller do
  describe "#index" do
    context "given an unauthenticated user" do
      it "redirects to the user homepage" do
        organization = FactoryBot.create(:organization)
        get :index, organization_id: organization.id
        expect(response).to redirect_to(user_home_url)
      end
    end

    context "given an authenticated ambassador" do
      include_context :logged_in_as_ambassador

      describe "index" do
        it "renders the ambassador dashboard" do
          get :index, organization_id: organization.id

          expect(response).to be_ok
          expect(assigns(:ambassadors).count).to eq(1)
          expect(response).to render_template(:index)
        end
      end

      describe "resources" do
        it "renders the ambassador resources" do
          get :resources, organization_id: organization.id
          expect(response).to be_ok
          expect(response).to render_template(:resources)
        end
      end

      describe "getting_started" do
        it "renders the ambassador resources" do
          get :resources, organization_id: organization.id
          expect(response).to be_ok
          expect(response).to render_template(:getting_started)
        end
      end
    end

    context "given an authenticated non-ambassador" do
      include_context :logged_in_as_user

      it "redirects the user's homepage" do
        organization = FactoryBot.create(:organization)
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to(user_home_url)
      end
    end
  end
end
