module Libertree
  module Server
    module Responder
      module Forest
        def rsp_forest(params)
          require_parameters(params, 'name', 'trees')

          begin
            forest = Model::Forest[
              origin_server_id: @remote_tree.id,
              remote_id: params['id']
            ]
            if forest
              forest.name = params['name']
            else
              forest = Model::Forest.create(
                origin_server_id: @remote_tree.id,
                remote_id: params['id'],
                name: params['name']
              )
            end

            trees = params['trees'].reject { |t|
              t['domain'] == Server.conf['domain']
            }
            forest.set_trees_by_domain trees
          rescue PGError => e
            fail InternalError, "Error on FOREST request: #{e.message}", nil
          end
        end

        def rsp_introduce(params)
          require_parameters(params, 'public_key', 'contact')

          if @remote_tree.nil?
            @remote_tree = Model::Server.create(
              'domain'     => @domain,
              'public_key' => params['public_key'],
              'contact'    => params['contact'],
            )

            log "#{@domain} is a new server (id: #{@remote_tree.id})."
          else
            log "updating server record for #{@domain} (id: #{@remote_tree.id})."
            # TODO: validate before storing these values
            @remote_tree.public_key = params['public_key']
            @remote_tree.contact    = params['contact']
            @remote_tree.name_given = params['name_given']
          end
        end

      end
    end
  end
end
