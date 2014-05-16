class BloodPressureRiskDpu
  def self.requirements(start_dt, end_dt, params)
    [
      {
        schema_id: 'omh:omh:diastolic-blood-pressure',
        version: 1,
        t_start: start_dt,
        t_end: end_dt,
      },
      {
        schema_id: 'omh:omh:systolic-blood-pressure',
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
    diastolics = input['omh:omh:diastolic-blood-pressure']
    systolics = input['omh:omh:systolic-blood-pressure']

    unless diastolics && systolics
      raise 'missing data'
    end

    diastolic_map = {}
    diastolics.each do |diastolic|
      unix_timestamp =
        diastolic['data']['effective-timeframe']['start-time']
      raise 'diastolic missing start-time' unless unix_timestamp
      unless diastolic['data']['unit'] == 'mm Hg'
        raise 'diastolic unit not mm Hg'
      end
      diastolic_map[Time.at(unix_timestamp).to_datetime] = 
        diastolic['data']['value']
    end

    output = []

    systolics.each do |systolic|
      unix_timestamp =
        systolic['data']['effective-timeframe']['start-time']
      timestamp = Time.at(unix_timestamp).to_datetime

      # Skip any data points that don't have a matching diastolic value.
      diastolic_value = diastolic_map[timestamp]
      next unless diastolic_value

      systolic_value = systolic['data']['value']
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
        metadata: {
          timestamp: timestamp
        },
        data: {
          'effective-timeframe' => {
            'start-time' => unix_timestamp
          },
          category: category
        },
      }
    end

    output
  end
end
DpuRegistry.register("omh:dpu:blood-pressure-risk", 1, BloodPressureRiskDpu)
