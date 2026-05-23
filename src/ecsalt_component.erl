-module(ecsalt_component).

-include("ecsalt.hrl").

-export([put/3, remove/3, find/3, match/2, foreach/3]).

-spec put([{term(), term()}], id(), world()) -> ok.
put(Components, EntityID, World) ->
    F =
        fun({Component, Data}) ->
            put_one(Component, Data, EntityID, World)
        end,
    ok = lists:foreach(F, Components).

-spec remove([term()], id(), world()) -> ok.
remove(Components, EntityID, World) ->
    F =
        fun(Component) ->
            remove_one(Component, EntityID, World)
        end,
    ok = lists:foreach(F, Components).

-spec find(term(), id(), world()) -> {ok, [term()]} | error.
find(ComponentName, EntityID, World) ->
    #world{entities = E, components = C} = World,
    case ets:match_object(C, {ComponentName, EntityID}) of
        [] ->
            false;
        _Match ->
            % It exists in the component table, so return the Entity data
            % back to the caller
            [{EntityID, Data}] = ets:lookup(E, EntityID),
            {ok, Data}
    end.

-spec match([term()], world()) -> [entity()].
match(List, World) ->
    % Multi-match. Try to match several components and return the common
    % elements. Use sets v2 introduced in OTP 24
    Sets = [
        sets:from_list(match_one(X, World), [{version, 2}])
     || X <- List
    ],
    sets:to_list(sets:intersection(Sets)).

-spec foreach(fun(), term(), world()) -> ok.
foreach(Fun, Component, World) ->
    Entities = match_one(Component, World),
    F =
        fun({ID, EntityComponents}) ->
            Values = proplists:get_value(Component, EntityComponents),
            Fun(ID, Values)
        end,
    ok = lists:foreach(F, Entities).

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
