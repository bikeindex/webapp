# Preview emails at http://localhost:3000/rails/mailers/organized_mailer
class OrganizedMailerPreview < ActionMailer::Preview
  
  def partial_registration_email
    b_param = BParam.find(262)
    # @vars = {
    #   b_param_token: b_param.id_token
    # }
    # @send_to = b_param.owner_email
    # @organization = b_param.creation_organization
    # title = 'Finish your Bike Index registration!'
    OrganizedMailer.partial_registration_email(b_param)
    # mail('Reply-To' => 'bikeindex@user.com', to: 'seth@bikeindex.com', subject: 'sample') do |format|
    #   format.text
    #   format.html { render layout: 'revised_email' }
    # end
  end
end
