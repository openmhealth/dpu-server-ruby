class BloodPressureRiskDpu
  def self.requirements(start_dt, end_dt, params)
    [
      {
        schema_id: 'omh:twonet:diastolic_mmhg',
        version: 1,
        t_start: start_dt,
        t_end: end_dt,
      },
      {
        schema_id: 'omh:twonet:systolic_mmhg',
        version: 1,
        t_start: start_dt,
        t_end: end_dt,
      }
    ]
  end

  def self.schema
    {
      type: 'object',
      fields: [
        {
          type: 'string',
          doc: 'Blood Pressure Category',
          name: 'category'
        }
      ]
    }
  end

  def self.process(start_dt, end_dt, params, input)
    diastolics = input['omh:twonet:diastolic_mmhg']
    systolics = input['omh:twonet:systolic_mmhg']

    unless diastolics && systolics
      raise 'missing data'
    end

    diastolic_map = {}
    diastolics.each do |diastolic|
      diastolic_map[DateTime.parse(diastolic['metadata']['timestamp'])] =
        diastolic['data']['diastolic_mmhg']
    end

    output = []

    systolics.each do |systolic|
      timestamp = DateTime.parse(systolic['metadata']['timestamp'])

      # Skip any data points that don't have a matching diastolic value.
      diastolic_value = diastolic_map[timestamp]
      next unless diastolic_value

      systolic_value = systolic['data']['systolic_mmhg']
      category =
        if systolic_value > 180 || diastolic_value > 110
          'Hypertensive Crisis'
        elsif systolic_value >= 160 || diastolic_value >= 100
          'High Blood Pressure Stage 2'
        elsif systolic_value >= 140 || diastolic_value >= 90
          'High Blood Pressure Stage 1'
        elsif systolic_value >= 120 || diastolic_value >= 80
          'Prehypertension'
        else
          'Normal'
        end

      output << {
        metadata: {timestamp: timestamp},
        data: {category: category}
      }
    end

    output
  end
end
DpuRegistry.register("omh:dpu:blood_pressure_risk", 1, BloodPressureRiskDpu)
