class DpuRegistry
  @registry = {}

  def self.register(id, version, klass)
    @registry[id] ||= {}
    @registry[id][version] = klass
  end

  def self.ids
    @registry.keys
  end

  def self.versions(id)
    versions = @registry[id].try(:keys)
    raise "unknown DPU id" unless versions
    versions
  end

  def self.get(id, version)
    @registry[id].try(:[], version)
  end
end
Dir[File.join(settings.root, "lib/dpu/*.rb")].each { |f| load f }
