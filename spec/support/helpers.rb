module SpecHelpers

  attr_reader :last_request

  def stub_request!
    Skylight::Excon.stub method: :post do |req|
      @last_request = req
      { :body => "Thanks!", :status => 200 }
    end
  end

end
