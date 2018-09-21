module Cord
  class IdsHandler < Handler
    # {
    #   api: '',
    #   scope: '',
    #   search?: '',
    #   sort?: '',
    # }

    def process_each(blob)
      api = Cord.helpers.find_api(blob['data']['api'])
      data = api.render_ids(
        [blob['data']['scope']],
        blob['data']['search'],
        blob['data']['sort']
      ).values[0]
      render blob, data
    end
  end
end
