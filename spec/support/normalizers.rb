module SpecHelper

  def normalizers
    @normalizers ||= Skylight::Normalizers.build(config)
  end

  # avoid polluting allocation counter
  BEHAVE_LIKE = "it should behave like".freeze
  PAYLOAD = {}.freeze

  def normalize(name=nil, payload=nil)
    if Hash === name
      payload = name
      name = nil
    end

    group = self.class.metadata[:example_group]
    group = group[:example_group] if group[:description].start_with?(BEHAVE_LIKE)

    description = group[:description_args]
    name ||= description[1] ? description[1] : description[0]

    normalizers.normalize(trace, name, payload)
  end

end
