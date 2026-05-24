-module(ecsalt_readme_test).

-include_lib("eunit/include/eunit.hrl").

%%---------------------------------------------------------------------
%% Helpers
%%---------------------------------------------------------------------

new_world() ->
    ecsalt:new().

%%---------------------------------------------------------------------
%% World creation
%%---------------------------------------------------------------------

new_world_test() ->
    World = new_world(),
    ?assertMatch({world, [], _, _}, World).

%%---------------------------------------------------------------------
%% Components: put and match
%%---------------------------------------------------------------------

put_single_component_test() ->
    World = new_world(),
    Fireplace = make_ref(),
    ecsalt_component:put([{burning, true}], Fireplace, World),
    Matches = ecsalt_component:match([burning], World),
    ?assertMatch([{Fireplace, [{burning, true}]}], Matches).

put_multiple_components_test() ->
    World = new_world(),
    GoblinCat = make_ref(),
    ecsalt_component:put([{burning, true}], GoblinCat, World),
    ecsalt_component:put([{hp, 35}, {color, green}, {brain_cells, 1}], GoblinCat, World),
    Matches = ecsalt_component:match([hp, burning], World),
    ?assertMatch([{GoblinCat, _}], Matches),
    [{_, Components}] = Matches,
    ?assertEqual(35, proplists:get_value(hp, Components)),
    ?assertEqual(true, proplists:get_value(burning, Components)),
    ?assertEqual(green, proplists:get_value(color, Components)),
    ?assertEqual(1, proplists:get_value(brain_cells, Components)).

match_filters_correctly_test() ->
    World = new_world(),
    Fireplace = make_ref(),
    GoblinCat = make_ref(),
    ecsalt_component:put([{burning, true}], Fireplace, World),
    ecsalt_component:put([{burning, true}, {hp, 35}], GoblinCat, World),
    %% Only GoblinCat has both hp and burning
    Matches = ecsalt_component:match([hp, burning], World),
    ?assertEqual(1, length(Matches)),
    [{MatchedID, _}] = Matches,
    ?assertEqual(GoblinCat, MatchedID).

match_empty_test() ->
    World = new_world(),
    Fireplace = make_ref(),
    ecsalt_component:put([{burning, true}], Fireplace, World),
    ?assertEqual([], ecsalt_component:match([hp, burning], World)).

%%---------------------------------------------------------------------
%% Component: update
%%---------------------------------------------------------------------

update_component_test() ->
    World = new_world(),
    Entity = make_ref(),
    ecsalt_component:put([{hp, 100}], Entity, World),
    ecsalt_component:update(hp, fun(HP) -> HP - 10 end, Entity, World),
    [{_, Components}] = ecsalt_component:match([hp], World),
    ?assertEqual(90, proplists:get_value(hp, Components)).

%%---------------------------------------------------------------------
%% Component: remove
%%---------------------------------------------------------------------

remove_component_test() ->
    World = new_world(),
    Entity = make_ref(),
    ecsalt_component:put([{hp, 50}, {burning, true}], Entity, World),
    ecsalt_component:remove([burning], Entity, World),
    ?assertEqual([], ecsalt_component:match([hp, burning], World)),
    ?assertMatch([{Entity, _}], ecsalt_component:match([hp], World)).

%%---------------------------------------------------------------------
%% Component: foreach
%%---------------------------------------------------------------------

foreach_test() ->
    World = new_world(),
    E1 = make_ref(),
    E2 = make_ref(),
    E3 = make_ref(),
    ecsalt_component:put([{hp, 100}, {burning, true}], E1, World),
    ecsalt_component:put([{hp, 50}, {burning, true}], E2, World),
    ecsalt_component:put([{hp, 75}], E3, World),
    %% Use foreach to damage all burning entities
    ecsalt_component:foreach([hp, burning], fun(ID, _Components) ->
        ecsalt_component:update(hp, fun(HP) -> HP - 10 end, ID, World)
    end, World),
    %% E1 and E2 should have taken damage, E3 should not
    [{_, E3Comps}] = ecsalt_component:match([hp], World) -- ecsalt_component:match([hp, burning], World),
    ?assertEqual(75, proplists:get_value(hp, E3Comps)),
    BurnedEntities = ecsalt_component:match([hp, burning], World),
    HPs = lists:sort([proplists:get_value(hp, C) || {_, C} <- BurnedEntities]),
    ?assertEqual([40, 90], HPs).

%%---------------------------------------------------------------------
%% Systems: register and proc
%%---------------------------------------------------------------------

register_system_test() ->
    World = new_world(),
    System = fun(_Data, _W) -> system_ran end,
    World1 = ecsalt_system:register(System, World),
    ?assertMatch({world, [{0, System}], _, _}, World1).

proc_runs_systems_test() ->
    World = new_world(),
    Self = self(),
    System = fun(_Data, _W) ->
        Self ! system_triggered,
        ok
    end,
    World1 = ecsalt_system:register(System, World),
    ecsalt:proc([], World1),
    receive
        system_triggered -> ok
    after 1000 ->
        ?assert(false)
    end.

%%---------------------------------------------------------------------
%% Full demo: goblin-cat burns to death
%%---------------------------------------------------------------------

burn_demo_test() ->
    World = new_world(),
    GoblinCat = make_ref(),
    ecsalt_component:put([{hp, 35}, {burning, true}], GoblinCat, World),
    BurnSystem = fun(_Data, W) ->
        ecsalt_component:foreach([hp, burning], fun(ID, _Components) ->
            ecsalt_component:update(hp, fun(HP) -> HP - 10 end, ID, W)
        end, W)
    end,
    World1 = ecsalt_system:register(BurnSystem, World),
    %% Tick 1: 35 -> 25
    ecsalt:proc([], World1),
    ?assertEqual(25, get_hp(World)),
    %% Tick 2: 25 -> 15
    ecsalt:proc([], World1),
    ?assertEqual(15, get_hp(World)),
    %% Tick 3: 15 -> 5
    ecsalt:proc([], World1),
    ?assertEqual(5, get_hp(World)),
    %% Tick 4: 5 -> -5, kitty is cooked
    ecsalt:proc([], World1),
    ?assertEqual(-5, get_hp(World)).

% assumes a single match, contrived
get_hp(World) ->
    [{_, Components}] = ecsalt_component:match([hp], World),
    proplists:get_value(hp, Components).

%%---------------------------------------------------------------------
%% System priority
%%---------------------------------------------------------------------

system_priority_test() ->
    World = new_world(),
    Self = self(),
    First = fun(_Data, _W) -> Self ! {ran, first} end,
    Second = fun(_Data, _W) -> Self ! {ran, second} end,
    World1 = ecsalt_system:register(Second, 10, World),
    World2 = ecsalt_system:register(First, 0, World1),
    ecsalt:proc([], World2),
    ?assertEqual({ran, first}, receive M1 -> M1 after 1000 -> timeout end),
    ?assertEqual({ran, second}, receive M2 -> M2 after 1000 -> timeout end).

%%---------------------------------------------------------------------
%% World: delete
%%---------------------------------------------------------------------

delete_world_test() ->
    World = new_world(),
    ecsalt:delete(World).
