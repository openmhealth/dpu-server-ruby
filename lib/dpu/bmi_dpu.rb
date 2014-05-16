class BmiDpu
  def self.requirements(start_dt, end_dt, params)
    [
      {
        schema_id: 'omh:omh:body-height',
        version: 1,
        include_one_previous: true,
        t_start: start_dt,
        t_end: end_dt,
      },
      {
        schema_id: 'omh:omh:body-weight',
        version: 1,
        t_start: start_dt,
        t_end: end_dt,
      }
    ]
  end

  def self.schema(start_dt, end_dt, params)
    {
      type: 'object',
      fields: [
        {
          type: 'object',
          name: 'effective-timeframe',
          fields: [
            {
              type: 'number',
              name: 'start-time'
            }
          ]
        },
        {
          type: 'number',
          doc: 'BMI',
          name: 'value'
        },
        {
          type: 'string',
          name: 'unit'
        }
      ]
    }
  end

  def self.process(start_dt, end_dt, params, input)
    heights = input['omh:omh:body-height']
    weights = input['omh:omh:body-weight']

    unless heights && weights
      raise 'missing data'
    end

    output = []

    unless heights.empty?
      height_index = 0
      weights.each do |weight|
        weight_timestamp = 
          weight['data']['effective-timeframe']['start-time']
        raise 'weight missing start-time' unless weight_timestamp
        weight_datetime = Time.at(weight_timestamp).to_datetime

        # Find the matching height. Most recent before the weight.
        while height_index < heights.size
          height_data = heights[height_index]['data']
          height_timestamp =
            height_data['effective-timeframe']['start-time']
          raise 'height missing start-time' unless height_timestamp
          height_datetime = Time.at(height_timestamp).to_datetime

          if height_datetime > weight_datetime
            height_index += 1
          else
            break
          end
        end
        break if height_index >= heights.size

        height = heights[height_index]

        raise 'height not in m' unless height['data']['unit'] == 'm'
        raise 'weight not in kg' unless weight['data']['unit'] == 'kg'

        bmi = 
          (weight['data']['value'] / (height['data']['value'] ** 2))

        output << {
          metadata: {
            timestamp: weight_datetime.to_s
          },
          data: {
            'effective-timeframe' => {
              'start-time' => weight_timestamp
            },
            value: bmi,
            unit: 'bmi'
          },
        }
      end
    end

    output
  end
end
DpuRegistry.register("omh:dpu:bmi", 1, BmiDpu)
