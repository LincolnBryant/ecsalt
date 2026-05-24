-module(ecsalt_component).
-moduledoc "Put, remove, and query named data on entities.".

-include("ecsalt.hrl").

-export([put/3, remove/3, update/4, match/2, fold/4, foreach/3]).

-doc """
Associate a component defined as the tuple {key,value} with an entity. If the
component already exists, it will be replaced with the new value. Returns the
opaque world() type.
""".
-spec put([{term(), term()}], id(), world()) -> world().
put(Components, EntityID, World) ->
    F =
        fun({Name, Data}) ->
            put_one(Name, Data, EntityID, World)
        end,
    lists:foreach(F, Components),
    World.

-doc """
Remove a component from a given entity. This function will always succeed even
if the component does not exist.
""".
-spec remove([term()], id(), world()) -> world().
remove(Components, EntityID, World) ->
    F =
        fun(Component) ->
            remove_one(Component, EntityID, World)
        end,
    ok = lists:foreach(F, Components),
    World.

-doc """
Update a component's value by applying a function to it. The component
must already exist on the entity.
""".
-spec update(term(), fun((term()) -> term()), id(), world()) -> world().
update(Name, Fun, EntityID, World) ->
    #world{entities = E} = World,
    [{EntityID, ComponentList}] = ets:lookup(E, EntityID),
    {Name, OldData} = lists:keyfind(Name, 1, ComponentList),
    put_one(Name, Fun(OldData), EntityID, World),
    World.

-doc """
Return all entities matching a given set of components. Returns empty list if
there are no matches.
""".
-spec match([term()], world()) -> [entity()].
match(ComponentList, World) ->
    % Multi-match. Try to match several components and return the common
    % elements. Use sets v2 introduced in OTP 24
    Sets = [
        sets:from_list(match_one(X, World), [{version, 2}])
     || X <- ComponentList
    ],
    sets:to_list(sets:intersection(Sets)).

-doc """
Fold a function over all entities matching a given set of components,
accumulating a result.
""".
-spec fold([term()], fun((id(), [component()], Acc) -> Acc), Acc, world()) -> Acc.
fold(ComponentList, Fun, Acc0, World) ->
    Entities = match(ComponentList, World),
    lists:foldl(fun({ID, Components}, Acc) -> Fun(ID, Components, Acc) end, Acc0, Entities).

-doc """
For each entity with the specified Component, apply fun(EntityID, Values).
""".
-spec foreach([term()], fun((id(), [component()]) -> any()), world()) -> ok.
foreach(ComponentList, Fun, World) ->
    Entities = match(ComponentList, World),
    lists:foreach(fun({ID, Components}) -> Fun(ID, Components) end, Entities).

% Internal API
put_one(Name, Data, EntityID, World) ->
    #world{entities = E, components = C} = World,
    Components =
        case ets:lookup(E, EntityID) of
            [] ->
                % No components
                [{Name, Data}];
            [{EntityID, ComponentList}] ->
                lists:keystore(Name, 1, ComponentList, {Name, Data})
        end,
    true = ets:insert(E, {EntityID, Components}),
    true = ets:insert(C, {Name, EntityID}),
    ok.

remove_one(Name, EntityID, World) ->
    #world{entities = E, components = C} = World,
    % Remove the data from the entity
    case ets:lookup_element(E, EntityID, 2) of
        [] ->
            ok;
        ComponentList ->
            % Delete the key-value identified by ComponentName
            ComponentList1 = lists:keydelete(
                Name, 1, ComponentList
            ),
            % Update the entity table
            ets:insert(E, {EntityID, ComponentList1})
    end,
    % Remove the data from the component bag
    true = ets:delete_object(C, {Name, EntityID}),
    ok.

match_one(ComponentName, World) ->
    % From the component bag table, get all matches
    #world{entities = E, components = C} = World,
    Matches = ets:lookup(C, ComponentName),
    % Use the entity IDs from the lookup in the component table to
    % generate a list of IDs for which to return data to the caller
    IDs = [ets:lookup(E, EntityID) || {_, EntityID} <- Matches],
    lists:usort(lists:flatten(IDs)).
