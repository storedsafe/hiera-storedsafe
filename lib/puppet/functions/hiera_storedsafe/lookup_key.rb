Puppet::Functions.create_function(:'hiera_storedsafe::lookup_key') do
  begin
    require 'storedsafe'
  rescue
    raise Puppet::DataBinding::LookupError, '[hiera_storedsafe] Must install \
      storedsafe-ruby gem to use hiera_storedsafe backend.'
  end

  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  class StoredsafeError < StandardError; end

  def lookup_key(key, options, context)
    ns, obj_id, field = key.split('::')

    if ns != 'storedsafe' or obj_id.nil? or field.nil?
      context.not_found
    end

    config_sources = []
    config_sources.push(options['config']) unless options['config'].nil?
    config_sources.push(Storedsafe::Config::RcReader.parse_file) if options['use_rc']
    config_sources.push(Storedsafe::Config::EnvReader.parse_env) if options['use_env']

    api = Storedsafe.configure do |config|
      config.config_sources = config_sources if config_sources.any?
    end

    res = api.object(obj_id)

    if res['CALLINFO']['status'] == 'FAIL'
      raise StoredsafeError, res['ERRORS']
    elsif res['OBJECT'].any?
      # Identify whether or not the field needs to be decrypted
      template_id = res['OBJECT'][obj_id]['templateid']
      template = res['TEMPLATESINFO'][template_id]
      if template['STRUCTURE'][field]
        encrypted = template['STRUCTURE'][field]['encrypted']
      else
        # Field doesn't exist
        context.not_found
      end

      if encrypted
        res = api.object(obj_id, true)
        res['OBJECT'][obj_id]['crypted'][field]
      else
        res['OBJECT'][obj_id][field]
      end
    else
      # Object doesn't exist
      context.not_found
    end
  end
end

