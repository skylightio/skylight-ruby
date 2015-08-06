%w[ event span trace endpoint batch ].each do |message|
  require(File.expand_path("../messages/#{message}", __FILE__))
end
