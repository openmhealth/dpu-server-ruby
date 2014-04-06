class BmiDpu
  def self.requirements(start_dt, end_dt, params)
    [
      {
        schema_id: 'omh:withings:height_m',
        version: 1,
        min_num_to_return: 1,
        t_start: start_dt,
        t_end: end_dt,
      },
      {
        schema_id: 'omh:withings:weight_kg',
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
          type: 'number',
          doc: 'BMI',
          name: 'bmi'
        }
      ]
    }
  end

  def self.process(start_dt, end_dt, params, input)
    heights = input['omh:withings:height_m']
    weights = input['omh:withings:weight_kg']

    unless heights && weights
      raise 'missing data'
    end

    output = []

    unless heights.empty?
      height_index = 0
      weights.each do |weight|
        weight_datetime = DateTime.parse(weight['metadata']['timestamp'])

        while (height_index + 1) < heights.size
          next_height_datetime =
            DateTime.parse(heights[height_index + 1]['metadata']['timestamp'])

          height_index += 1 if next_height_datetime < weight_datetime
        end

        bmi = 
          (weight['data']['weight_kg'] / 
           (heights[height_index]['data']['height_m'] ** 2))

        output << {
          metadata: {
            timestamp: weight['metadata']['timestamp']
          },
          data: {
            bmi: bmi
          },
        }
      end
    end

    output
  end
end
DpuRegistry.register("omh:dpu:bmi", 1, BmiDpu)
