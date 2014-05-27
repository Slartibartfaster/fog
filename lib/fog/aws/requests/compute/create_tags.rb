module Fog
  module Compute
    class AWS
      class Real
        require 'fog/aws/parsers/compute/basic'

        # Adds tags to resources
        #
        # ==== Parameters
        # * resources<~String> - One or more resources to tag
        # * tags<~String> - hash of key value tag pairs to assign
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>:
        #     * 'requestId'<~String> - Id of request
        #     * 'return'<~Boolean> - success?
        #
        # {Amazon API Reference}[http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/ApiReference-query-CreateTags.html]
        def create_tags(resources, tags)
          resources = [*resources]
          for key, value in tags
            if value.nil?
              tags[key] = ''
            end
          end
          params = {}
          params.merge!(Fog::AWS.indexed_param('ResourceId', resources))
          params.merge!(Fog::AWS.indexed_param('Tag.%d.Key', tags.keys))
          params.merge!(Fog::AWS.indexed_param('Tag.%d.Value', tags.values))
          request({
            'Action'    => 'CreateTags',
            :idempotent => true,
            :parser     => Fog::Parsers::Compute::AWS::Basic.new
          }.merge!(params))
        end
      end

      class Mock
        def create_tags(resources, tags)
          resources = [*resources]

          tagged = resources.map do |resource_id|
            type = case resource_id
                   when /^ami\-[a-z0-9]{8}$/i
                     'image'
                   when /^i\-[a-z0-9]{8}$/i
                     'instance'
                   when /^snap\-[a-z0-9]{8}$/i
                     'snapshot'
                   when /^vol\-[a-z0-9]{8}$/i
                     'volume'
                   when /^igw\-[a-z0-9]{8}$/i
                     'internet_gateway'
                   when /^vpc\-[a-z0-9]{8}$/i
                     'vpc'
                   when /^rtb\-[a-z0-9]{8}$/i
                     'route_table'
                   when /^subnet\-[a-z0-9]{8}$/i
                     'subnet'
                   when /^sg\-[a-z0-9]{8}$/i
                     'security_group'
                   when /^dopt\-[a-z0-9]{8}$/i
                     'dhpc_options'
                   when /^acl\-[a-z0-9]{8}$/i
                     'network_acls'
                   when /^eni\-[a-z0-9]{8}$/i
                     'network_interface'
                   end
            if type && self.send("#{type}s".to_sym).send(:get, resource_id)
              { 'resourceId' => resource_id, 'resourceType' => type }
            elsif type=='security_group' && self.security_groups.all({'group-id' => resource_id}) != []
            else
              raise(Fog::Service::NotFound.new("The #{type} ID '#{resource_id}' does not exist"))
            end
          end


          tags.each do |key, value|
            self.data[:tags][key] ||= {}
            self.data[:tags][key][value] ||= []
            self.data[:tags][key][value] ||= tagged

            tagged.each do |resource|
              self.data[:tag_sets][resource['resourceId']][key] = value
            end
          end

          response = Excon::Response.new
          response.status = 200
          response.body = {
            'requestId' => Fog::AWS::Mock.request_id,
            'return'    => true
          }
          response
        end
      end
    end
  end
end
