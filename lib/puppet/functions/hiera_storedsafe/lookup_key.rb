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

  def lookup_key(key, options, context)
    ns, obj_id, field = key.split('::')

    if ns != 'storedsafe' or obj_id.nil? or field.nil?
      context.not_found
    end

    begin
      api = Storedsafe.configure do |config| end

      encrypted = ['password']
      decrypt = encrypted.include? field

      res = api.object(obj_id, decrypt)
      obj = res['OBJECT'][obj_id]

      if decrypt
        obj['crypted'][field]
      else
        obj[field]
      end
    rescue StandardError => e
      raise e
    end
  end
end

