-module(ecsalt).
-moduledoc "Entity Component System".

-export([new/0, delete/1]).
-export([proc/2, to_map/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Types and Records
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-include("ecsalt.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-doc """
Create a new ECS world with default ETS options. Returns an opaque world record
used by all other API functions.

See also new/1, especially if you need to start ECSalt with public tables for
multi-process access.
""".
-spec new() -> world().
new() ->
    new([]).

-doc """
Create a new ECS world with custom ETS options (e.g., read concurrency, public
tables). Table types are enforced internally and cannot be overridden. Returns
an opaque world record used by all other API functions.
""".
-spec new(list()) -> world().
new(ETSOpts) ->
    SafeOpts = ETSOpts -- [set, bag, duplicate_bag, ordered_set],
    #world{
        systems = [],
        entities = ets:new(entities, [set | SafeOpts]),
        components = ets:new(components, [bag | SafeOpts])
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
For every registered system, trigger the proc callback with some extra data
specified by Data and gather results.
""".
-spec proc(term(), world()) -> [any()].
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
