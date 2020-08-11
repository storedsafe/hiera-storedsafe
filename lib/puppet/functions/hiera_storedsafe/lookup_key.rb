Puppet::Functions.create_function(:'hiera_storedsafe::lookup_key') do
  begin
    require 'storedsafe'
  rescue
    raise Puppet::DataBinding::LookupError, '[hiera_storedsafe] Must install \
      storedsafe gem to use hiera_storedsafe backend.'
  end

  dispatch :lookup_key do
    param 'String', :key
    param 'Hash[String,Any]', :options
    param 'Puppet::LookupContext', :context
  end

  class StoredSafeError < StandardError; end

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
    config_sources.push(StoredSafe::Config::RcReader.parse_file) if options['use_rc']
    config_sources.push(StoredSafe::Config::EnvReader.parse_env) if options['use_env']

    api = StoredSafe.configure do |config|
      config.config_sources = config_sources if config_sources.any?
    end

    raise StoredSafeError, '`nil` is not a valid StoredSafe host' if api.host.nil?
    raise StoredSafeError, '`nil` is not a valid StoredSafe token' if api.token.nil?

    api
  end

  def lookup_exact(api, ns, obj_id, field)
    res = api.get_object(obj_id)
    if res['CALLINFO']['status'] == 'FAIL'
      raise StoredSafeError, res['ERRORS']
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
        res = api.decrypt_object(obj_id)
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

