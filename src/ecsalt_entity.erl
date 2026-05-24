-module(ecsalt_entity).

-include("ecsalt.hrl").

-export([new/2, delete/2, get/2, list/1]).

-doc "Insert a new entity into the entity table, identified by EntityID".
-spec new(id(), world()) -> world().
new(EntityID, World) ->
    #world{entities = E} = World,
    case ets:lookup(E, EntityID) of
        [] ->
            % ok, add 'em
            ets:insert(E, {EntityID, []});
        _Entity ->
            ok
    end,
    World.

-doc "Delete a given entity from the entity table".
-spec delete(id(), world()) -> world().
delete(EntityID, World) ->
    #world{entities = E, components = C} = World,
    case ets:lookup(E, EntityID) of
        [] ->
            % ok, nothing to do
            ok;
        [{EntityID, Components}] ->
            % Remove the entity from the entity table
            ets:delete(E, EntityID),
            % Delete all instances of it from the component table as well
            [
                ets:delete_object(C, {N, EntityID})
             || {N, _} <- Components
            ],
            ok
    end,
    World.

-doc "Get an entity and all attached components, otherwise false".
-spec get(id(), world()) -> {id(), [term()]} | false.
get(EntityID, World) ->
    #world{entities = E} = World,
    case ets:lookup(E, EntityID) of
        [] ->
            false;
        [Entity] ->
            Entity
    end.

-doc "List all entities in #world{}".
-spec list(world()) -> [{id(), [term()]}].
list(World) ->
    #world{entities = E} = World,
    ets:match_object(E, {'$0', '$1'}).
