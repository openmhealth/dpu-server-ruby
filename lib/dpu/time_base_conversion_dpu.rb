require 'open-uri'

class TimeBaseConversionDpu
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

    output = []

    # Iterate over each period in the give time range.
    period = 
      if params['period-secs']
        params['period-secs'].to_i
      else
        end_dt.to_time.to_i - start_dt.to_time.to_i
      end
    raise 'invalid period' unless period > 0
    period_end = end_dt
    period_start = (end_dt.to_time - period).to_datetime
    while period_end > start_dt
      # Gather all the values for the period.
      values = 
        data_points.
          select do |p|
            timestamp = p['data']['effective-timeframe']['start-time']
            raise 'missing timestamp' unless timestamp
            datetime = Time.at(timestamp).to_datetime
            datetime >= period_start && datetime < period_end
          end.
          map {|p| p['data']['value']}

      # Skip empty periods.
      unless values.empty?
        # Filter the values.
        output_value =
          case params['mode']
          when 'average' then values.inject(0, :+) / values.count
          when 'sum' then values.inject(0, :+)
          when 'minimum' then values.min
          when 'maximum' then values.max
          else raise 'unknown mode'
          end

        output << {
          metadata: {
            timestamp: period_start
          },
          data: {
            'effective-timeframe' => {
              'start-time' => period_start,
              'duration' => period
            },
            value: output_value,
            unit: data_points.first['data']['unit']
          }
        }
      end

      period_end = period_start
      period_start = (period_start.to_time - period).to_datetime
    end

    output
  end

 private
  
   def self.verify_params(params)
    unless (params['input-schema-id'] && 
            params['input-schema-version'] &&
            params['mode'])
      raise 'missing required parameter'
    end
  end
end
DpuRegistry.register("omh:dpu:time-base-conversion", 1, TimeBaseConversionDpu)
