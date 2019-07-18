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

    api = Storedsafe.configure do |config| end

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

