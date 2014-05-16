require 'open-uri'

class UnitConversionDpu
  def self.requirements(start_dt, end_dt, params)
    verify_params(params)

    [
      {
        schema_id: params['input-schema-id'],
        version: params['input-schema-version'].to_i,
        t_start: start_dt,
        t_end: end_dt,
      }
    ]
  end

  def self.schema(start_dt, end_dt, params)
    verify_params(params)

    JSON.parse(
      open(
        "http://localhost:8080/omh/v1/#{params['input-schema-id']}" +
        "/#{params['input-schema-version']}").read)
  end

  def self.process(start_dt, end_dt, params, input)
    verify_params(params)

    data_points = input[params['input-schema-id']]
    unless data_points
      raise 'missing data'
    end

    output_unit = params['output-unit']

    data_points.map do |d|
      value = d['data']['value']
      unit = d['data']['unit']

      raise 'missing value or unit' unless value && unit

      d['data']['value'] = 
        Unit.new("#{value} #{unit}").convert_to(output_unit).scalar
      d['data']['unit'] = output_unit

      d.select {|k, v| ['data', 'metadata'].include?(k)}
    end
  end

 private
  
   def self.verify_params(params)
    unless (params['input-schema-id'] && 
            params['input-schema-version'] &&
            params['output-unit'])
      raise 'missing required parameter'
    end
  end
end
DpuRegistry.register("omh:dpu:unit-conversion", 1, UnitConversionDpu)
