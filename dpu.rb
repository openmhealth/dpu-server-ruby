require 'json'
require 'sinatra'

require 'bundler'
Bundler.require(:default, Sinatra::Base.environment)

require_relative 'lib/dpu_registry'

if development?
  require 'sinatra/reloader'
  also_reload('lib/*.rb')
  also_reload('lib/dpu/*.rb')

  configure :development do
    use BetterErrors::Middleware
    BetterErrors.application_root = __dir__
  end
end

configure do
  set :server, :puma
end

before do
  content_type 'application/json'
end

namespace '/omh/v1' do
  get 'omh' do
    DpuRegistry.ids.to_json
  end

  get 'omh/:dpu_id/?' do
    DpuRegistry.versions(params[:dpu_id]).to_json
  end

  namespace '/:dpu_id/:dpu_version' do
    before do
      @dpu = DpuRegistry.get(params[:dpu_id], params[:dpu_version].to_i)
      raise "unknown DPU" unless @dpu
    end

    before '/*' do
      unless params['t_start'] && params['t_end']
        raise 't_start and t_end required'
      end

      @start_dt = DateTime.parse(params['t_start'])
      @end_dt = DateTime.parse(params['t_end'])
    end

    get '' do
      @dpu.schema.to_json
    end

    get '/requirements' do
      @dpu.requirements(@start_dt, @end_dt, params).to_json
    end

    post '/process' do
      @dpu.process(
        @start_dt, @end_dt, params, JSON.parse(request.body.read)).to_json
    end
  end
end
