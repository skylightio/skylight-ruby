module SpecHelper

  def normalizers
    @normalizers ||= Skylight::Normalizers.build(config)
  end

  def normalize(*args)
    payload = Hash === args.last ? args.pop : {}

    description = self.class.metadata[:example_group][:description_args]
    name = description[1] ? description[1] : description[0]
    name = args.pop if String === args.last

    normalizers.normalize(trace, name, payload)
  end

end
