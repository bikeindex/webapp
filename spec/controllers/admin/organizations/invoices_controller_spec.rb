require "spec_helper"

describe Admin::Organizations::InvoicesController, type: :controller do
  let(:organization) { FactoryGirl.create(:organization) }
  let(:invoice) { FactoryGirl.create(:invoice, organization: organization) }
  context "super admin" do
    include_context :logged_in_as_super_admin

    describe "index" do
      it "renders" do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "edit" do
      it "renders" do
        get :edit, organization_id: organization.to_param, id: invoice.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

  #   describe "organization update" do
  #     context "landing_page" do
  #       let(:update_attributes) { { landing_html: "<p>html for the landing page</p>" } }
  #       it "updates and redirects to the landing_page edit" do
  #         put :update, organization_id: organization.to_param,
  #             organization: update_attributes, id: "landing_page"
  #         target = edit_admin_organization_custom_layout_path(organization_id: organization.to_param, id: "landing_page")
  #         expect(response).to redirect_to target
  #         organization.reload
  #         expect(organization.landing_html).to eq update_attributes[:landing_html]
  #       end
  #     end
  #     context "mail_snippet" do
  #       let(:snippet_type) { MailSnippet.organization_snippet_types.last }
  #       let(:mail_snippet) do
  #         FactoryGirl.create(:organization_mail_snippet,
  #                            organization: organization,
  #                            name: snippet_type,
  #                            is_enabled: false)
  #       end
  #       let(:update_attributes) do
  #         {
  #           mail_snippets_attributes: {
  #             "0" => {
  #               id: mail_snippet.id,
  #               name: "CRAZZY new name", # ignore
  #               body: "<p>html for snippet 1</p>",
  #               organization_id: 844, # Ignore
  #               is_enabled: true
  #             }
  #           }
  #         }
  #       end
  #       it "updates the mail snippets" do
  #         expect(mail_snippet.is_enabled).to be_falsey
  #         expect do
  #           put :update, organization_id: organization.to_param,
  #               organization: update_attributes, id: snippet_type
  #         end.to change(MailSnippet, :count).by 0
  #         target = edit_admin_organization_custom_layout_path(organization_id: organization.to_param, id: mail_snippet.name)
  #         expect(response).to redirect_to target
  #         mail_snippet.reload
  #         expect(mail_snippet.name).to eq snippet_type
  #         expect(mail_snippet.body).to eq "<p>html for snippet 1</p>"
  #         expect(mail_snippet.organization).to eq organization
  #         expect(mail_snippet.is_enabled).to be_truthy
  #       end
  #     end
  #   end
  end
end
