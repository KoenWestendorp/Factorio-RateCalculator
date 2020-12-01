local table = require("__flib__.table")

local constants = require("constants")

local player_data = require("scripts.player-data")

local rates_gui = require("scripts.gui.rates")

local calculators = {}

for entity_type, type_data in pairs(constants.entity_type_data) do
  calculators[entity_type] = {}
  for measure, filenames in pairs(type_data.calculators) do
    calculators[entity_type][measure] = table.map(
      filenames,
      function(filename)
        return require("scripts.calc."..measure.."."..filename)
      end
    )
  end
end

local selection_tool = {}

function selection_tool.setup_selection(e, player, player_table, tool_measure)
  local force = player.force
  local current_research = force.current_research
  local research_data
  if current_research then
    research_data = {
      ingredients = current_research.research_unit_ingredients,
      multiplier = 1 / (current_research.research_unit_energy / 60),
      speed_modifier = force.laboratory_speed_modifier
    }
  end

  local area = e.area
  local entities = e.entities
  local color = constants.selection_tools[tool_measure].color

  if #entities > 0 then
    player_table.iteration_data = {
      area = area,
      color = color,
      entities = entities,
      measure = tool_measure,
      rates = table.map(
        constants.selection_tools,
        function(_, k)
          if k ~= "all" then
            return {inputs = {}, outputs = {}}
          end
        end
      ),
      render_objects = {
        rendering.draw_rectangle{
          color = color,
          width = 4,
          filled = false,
          left_top = area.left_top,
          right_bottom = area.right_bottom,
          surface = e.surface,
          players = {player.index},
          draw_on_ground = true
        }
      },
      research_data = research_data,
      surface = e.surface
    }
    player_data.register_for_iteration(player.index, player_table)
    REGISTER_ON_TICK()
  end
end

function selection_tool.iterate(players_to_iterate)
  local prototypes = {
    entity = game.entity_prototypes,
    fluid = game.fluid_prototypes,
    item = game.item_prototypes
  }
  local player_tables = global.players
  local iterations_per_player = math.max(global.settings.entities_per_tick / table_size(players_to_iterate), 1)
  for player_index in pairs(players_to_iterate) do
    local player = game.get_player(player_index)
    local player_table = player_tables[player_index]

    local iteration_data = player_table.iteration_data
    local color = iteration_data.color
    local entities = iteration_data.entities
    local rates = iteration_data.rates
    local render_objects = iteration_data.render_objects
    local research_data = iteration_data.research_data
    local surface = iteration_data.surface

    local next_index = table.for_n_of(entities, iteration_data.next_index, iterations_per_player, function(entity)
      if not entity.valid then return end

      -- process entity
      for measure, calculators in pairs(calculators[entity.type]) do
        for _, calculator in ipairs(calculators) do
          calculator(rates[measure], entity, prototypes, research_data)
        end
      end

      -- add indicator dot
      render_objects[#render_objects+1] = rendering.draw_circle{
        color = color,
        radius = 0.2,
        filled = true,
        target = entity,
        surface = surface,
        players = {player_index}
      }
    end)

    iteration_data.next_index = next_index

    -- if we are done
    if not next_index then
      -- TODO: open GUI
      selection_tool.stop_iteration(player.index, player_table)
    end
  end
end

function selection_tool.stop_iteration(player_index, player_table)
  local objects = player_table.iteration_data.render_objects
  local destroy = rendering.destroy
  for i = 1, #objects do
    destroy(objects[i])
  end
  player_data.deregister_from_iteration(player_index, player_table)
end

return selection_tool
