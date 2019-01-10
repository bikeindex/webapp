shared_context :logged_in_as_user do
  let(:user) { FactoryGirl.create(:user_confirmed) }
  before { set_current_user(user) }
end

shared_context :logged_in_as_super_admin do
  let(:user) { FactoryGirl.create(:admin) }
  before { set_current_user(user) }
end

shared_context :logged_in_as_organization_admin do
  let(:user) { FactoryGirl.create(:organization_admin) }
  let(:organization) { user.organizations.first }
  before :each do
    set_current_user(user)
  end
end

shared_context :logged_in_as_organization_member do
  let(:user) { FactoryGirl.create(:organization_member) }
  let(:organization) { user.organizations.first }
  before :each do
    set_current_user(user)
  end
end
