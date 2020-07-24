Puppet::Functions.create_function(:'hiera_storedsafe::lookup_key') do
  begin
    require 'storedsafe'
  rescue
    raise Puppet::DataBinding::LookupError, '[hiera_storedsafe] Must install \
      storedsafe gem to use hiera_storedsafe backend.'
  end

  dispatch :lookup_key do
    param 'String[1]', :key
    param 'Hash[String[1],Any]', :options
    param 'Puppet::LookupContext', :context
  end

  # class StoredsafeError < StandardError; end

  def lookup_key(key, options, context)
    api = get_handler(options)

    ns, obj_id, field = key.split('::')
    if ns != 'storedsafe' or obj_id.nil? or field.nil?
      context.not_found
    end
    lookup_exact(api, ns, obj_id, field)
  end

  def get_handler(options)
    config_sources = []
    config_sources.push(options['config']) unless options['config'].nil?
    config_sources.push(Storedsafe::Config::RcReader.parse_file) if options['use_rc']
    config_sources.push(Storedsafe::Config::EnvReader.parse_env) if options['use_env']

    Storedsafe.configure do |config|
      config.config_sources = config_sources if config_sources.any?
    end
  end

  def lookup_exact(api, ns, obj_id, field)
    # return "storedsafe lookup: #{ns}, #{obj_id}, #{field}"
    res = api.object(obj_id)
    if res['CALLINFO']['status'] == 'FAIL'
      raise StoredsafeError, res['ERRORS']
    elsif res['OBJECT'].any?
      # Identify whether or not the field needs to be decrypted
      obj = res['OBJECT'].find { |o| o['id'] == obj_id }
      template_id = obj['templateid']
      template = res['TEMPLATES'].find { |t| t['id'] == template_id }
      template_field = template['structure'].find { |s| s['fieldname'] == field }
      if !template_field.nil?
        encrypted = template_field['encrypted']
      else
        # Field doesn't exist
        context.not_found
      end

      if encrypted
        res = api.object(obj_id, true)
        obj = res['OBJECT'].find{ |o| o['id'] == obj_id }
        obj['crypted'][field]
      else
        obj = res['OBJECT'].find{ |o| o['id'] == obj_id }
        obj['public'][field]
      end
    else
      # Object doesn't exist
      context.not_found
    end
  end
end

