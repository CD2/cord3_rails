class ActionWriter
  Dir['./app/apis/**/*.rb'].each { |file| require_dependency file }
  base_url = '/v1/'
  def self.write_actions
    File.open(Rails.root.join(Cord.action_writer_path), 'w') { |file| file.write('') }
    File.open(Rails.root.join(Cord.action_writer_path), 'a') do |file|
      file.write("## Action list for Api's \n")
      ApplicationApi.descendants.each do |api|
        file.write("### #{api} \n")
        if api.member_actions.keys.count > 0
          file.write("\n#### Member Actions:\n")
          file.write('```')
          api.member_actions.map do |key, value|
            file.write("\n #{key} \n")
            get_comments(value).map do |comment|
              file.write(" -> #{comment} \n")
            end
          end
          file.write('```')
        end
        if api.collection_actions.keys.count > 0
          file.write("\n#### Collection Actions:\n")
          file.write('```')
          api.collection_actions.map do |key, value|
            file.write("\n #{key} \n")
            get_comments(value).map do |comment|
              file.write(" -> #{comment} \n")
            end
          end
          file.write('```')
        end
        file.write("\n")
      end
    end
  end

  COMMENT_REGEX = /^\s*?#\s*(.*?)\s*$/.freeze

  def self.get_comments(action_block)
    return [] unless action_block.source_location
    file_path, line_num = action_block.source_location
    lines = open(file_path).read.split("\n")
    # Read backwards until there are no more comments
    i = line_num - 2
    while lines[i].match COMMENT_REGEX
      i -= 1
    end
    lines[i+1..line_num-2].map { |line| line.match(COMMENT_REGEX)[1] }
  end
end
