-module(ecsalt).
-doc "Entity Component System".

-export([new/0, delete/1]).
-export([proc/1, proc/2, to_map/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Types and Records
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-include("ecsalt.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-doc """
Start the ECS with ETS tables set to public, return them in an opaque
world() type to the caller 
""".
-spec new() -> world().
new() ->
    #world{
        systems = [],
        entities = ets:new(entities, [set, public]),
        components = ets:new(components, [bag, public])
    }.

-doc "Stop the ECS and delete the ETS tables".
-spec delete(world()) -> ok.
delete(#world{entities = ETable, components = CTable}) ->
    true = ets:delete(ETable),
    true = ets:delete(CTable),
    ok.

-doc """
Convert the component list for a given entity ID to a map.
Warning: this can potentially create an unbounded number of
atoms!
""".
-spec to_map(entity()) -> map().
to_map({EntityID, Components}) ->
    % Create the component map
    EMap = maps:from_list(Components),
    % Add the ID
    EMap#{id => EntityID}.

-doc """
For every registered system, trigger the proc callback and gather results.
""".
-spec proc(world()) -> any().
proc(World) ->
    proc([], World).

-doc """
For every registered system, trigger the proc callback with some extra data
specified by Data and gather results.
""".
-spec proc(any(), world()) -> [any()].
proc(Data, World) ->
    #world{systems = Systems} = World,
    Fun = fun({_Prio, Sys}, Acc) ->
        Result =
            case Sys of
                {M, F, 2} ->
                    M:F(Data, World);
                SysFun ->
                    SysFun(Data, World)
            end,
        [{Sys, Result} | Acc]
    end,
    lists:foldl(Fun, [], Systems).
