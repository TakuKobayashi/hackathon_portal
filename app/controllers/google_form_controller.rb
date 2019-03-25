class GoogleFormController < ApplicationController
  skip_before_action :verify_authenticity_token

  def input
    input = JSON.parse(request.body.read, {:symbolize_names => true})
    logger.info(input)
    head(:ok)
  end
end
